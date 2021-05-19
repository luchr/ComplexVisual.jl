macro import_winding_huge()
    :(
        using ComplexVisual:
            CV_2DWindingPainterContext, CV_Math2DCanvasWindingPainter,
            cv_clear_cache, CV_2DWindingColorbarPainter,
            CV_WindingColorBarCreateData, cv_create_winding_colorbar,
            cv_setup_winding_colorbar
    )
end

"""
Painting Context for `CV_Math2DCanvasWindingPainter` describing the
trafo and what winding numbers to fill/show.
"""
struct CV_2DWindingPainterContext{trafoT} <: CV_PaintingContext
    trafo                   :: trafoT
    hide_winding_numbers    :: Dict{Int32, Bool}    # default: false
end
CV_2DWindingPainterContext(trafo) = CV_2DWindingPainterContext(
    trafo, Dict{Int32,Bool}())

"""
stores informations about a found connected component.
"""
struct CV_ConnectedComponent
    point_inside   :: Tuple{Int32, Int32}  # a position inside
    mask           :: BitMatrix            # bit-mask: 1 if pixel is inside
    winding_number :: Int32                # computed winding number
end

# {{{ Flood filling algorithm (kind of hack to find connected component)
"""
Informations for flood filling (to find connected components).
"""
struct CV_FloodFill_info{planT}
    data          :: Matrix{UInt32}
    empty_value   :: UInt32
    plan          :: planT
end

"""
scan row `y` from `lx` to `rx` to find new fill seeds and append
this new sees to the fill `plan`.
"""
function cv_fill_scan(info::CV_FloodFill_info,
        lx::Int32, rx::Int32, y::Int32)  # {{{
    data, empty_value, plan = info.data, info.empty_value, info.plan

    added = false
    for x in lx:rx
        if data[x, y] != empty_value
            added = false
        elseif !added
            push!(plan, (x, y))
            added = true
        end
    end
    return nothing
end # }}}

"""
flood fill the region (connected component) starting at `(x,y)` with
the given `value`.
"""
function cv_flood_fill(info::CV_FloodFill_info,
        x::Int32, y::Int32, value::UInt32)  # {{{

    data, empty_value, plan = info.data, info.empty_value, info.plan
    X, Y = size(data)
    o = Int32(1)
    push!(plan, (x, y))
    while !isempty(plan)
        x, y = pop!(plan)
        data[x, y] != empty_value && continue
        data[x, y] = value
        lx, rx = x, x
        while lx > o && data[lx-o, y] == empty_value
            lx -= o
            data[lx ,y] = value
        end
        while rx < X && data[rx+o, y] == empty_value
            rx += o
            data[rx, y] = value
        end
        y < Y && cv_fill_scan(info, lx, rx, y+o)
        y > o && cv_fill_scan(info, lx, rx, y-o)
    end
    return nothing
end # }}}


"""
Uses `data` (typically a black and white image) to find the connected
components/regions. To mark the regions, entries in the same regions
in `data` get the same value (starting with 0x1).

returns the number of components found.

`data` is changed.
"""
function cv_mark_connected_components!(data::Matrix{UInt32},
        empty_value::UInt32)
    # Vector used to prevent dependency on DataStructures.jl
    plan = Vector{Tuple{Int32, Int32}}() # may be optimized by using a Deque
    info = CV_FloodFill_info(data, empty_value, plan)

    compcount = UInt32(0)

    while true
        next = findfirst(value -> value == empty_value, data)
        next === nothing && break
        compcount += 0x1

        cv_flood_fill(info, Int32(next[1]), Int32(next[2]), compcount)
    end
    return compcount
end
# }}}


"""
Objects used to compute winding numbers.

This is done with a kind of "hack".

* We use a `CV_2DCanvasLinePainter` to draw (with `ANTIALIAS_NONE`) the 
  closed curve(s) in a "computational"/auxiliary `CV_Math2DCanvas`
* Then we use a flood fill algorithm to find and fill each connected region
  (connected component) with a unique value (we use the values `0x1`, `0x2`,
  etc.)
* We then compute/find for every connected component the maximal square
  inside this component. We use this as an heuristic to find a point
  inside the component which is "far" away from the curves/boundary.
* We take the center of each of such squares to use the "axis crossing method"
  to estimate/compute the winding number.
"""
mutable struct CV_WindingHelpers
    comp_canvas  :: CV_Math2DCanvas
    con_comps    :: Vector{CV_ConnectedComponent} # found connected components
    color_dict   :: Dict{Int32, UInt32}           # colors for winding numbers
end

const cv_windingpainter_line_painter_style = cv_black → cv_op_source →
        cv_linewidth(1) → cv_antialias(Cairo.ANTIALIAS_NONE)

struct CV_Math2DCanvasWindingPainter{linePainterT <: CV_StyledPainter} <: CV_2DCanvasPainter  # {{{
    styled_line_painter :: linePainterT
    helpers             :: CV_WindingHelpers
    cache_flag          :: Bool
    cache               :: CV_Math2DCanvasPainterCache

    function CV_Math2DCanvasWindingPainter(closed_curves::CV_LineSegments,
            cache_flag::Bool=true)
        line_painter = CV_2DCanvasLinePainter(closed_curves, true)
        helpers = CV_WindingHelpers(
            CV_Math2DCanvas(-1.0+1.0im, 1.0-1.0im, 1),
            Vector{CV_ConnectedComponent}(),
            Dict{Int32, UInt32}())
        styled_painter = cv_windingpainter_line_painter_style ↦ line_painter
        return new{typeof(styled_painter)}(
            styled_painter,
            helpers,
            cache_flag,
            CV_Math2DCanvasPainterCache())
    end
end

function cv_clear_cache(wp::CV_Math2DCanvasWindingPainter)
    if wp.cache_flag
        wp.cache.last_canvas = nothing
    end
    return nothing
end

"""
takes care that `wp.helpers.comp_canvas` is a clone (i.e. has some
size and resolution) as `canvas`.

make sure all pixels have the value empty_value
"""
function cv_similar_comp_canvas(wp::CV_Math2DCanvasWindingPainter,
                                canvas::CV_Math2DCanvas, empty_value::UInt32)
    comp_canvas = wp.helpers.comp_canvas
    if comp_canvas.corner_ul != canvas.corner_ul         ||
            comp_canvas.corner_lr != canvas.corner_lr    ||
            comp_canvas.resolution != canvas.resolution
        # needs to change
        cv_destroy(comp_canvas)
        comp_canvas = CV_Math2DCanvas(
            canvas.corner_ul, canvas.corner_lr, canvas.resolution)
        wp.helpers.comp_canvas = comp_canvas
    end
    csurf = wp.helpers.comp_canvas.surface
    cdata = csurf.data
    Cairo.flush(csurf)
    cdata[:] .= empty_value
    Cairo.mark_dirty(csurf)
    return nothing
end

"""
computes connected components.

This is a completely discrete algorithm. A flood fill algorithm (on the
discretized pixels) is used to get a bitmask for every connected component.

see also `CV_WindingHelpers`.
"""
function cv_compute_conn_masks_for_canvas(
        wp::CV_Math2DCanvasWindingPainter, canvas::CV_Math2DCanvas, trafo) # {{{
    # Prepare computational canvas
    empty_value = 0xffffffff
    cv_similar_comp_canvas(wp, canvas, empty_value)

    # draw curves
    ccon = cv_create_context(wp.helpers.comp_canvas)
    cv_prepare(ccon, wp.styled_line_painter.style)
    cv_paint_line_painter(ccon, wp.styled_line_painter.painter, trafo)
    cv_destroy(ccon)

    # find connected components with flood fill
    cdata = wp.helpers.comp_canvas.surface.data
    comp_count = cv_mark_connected_components!(cdata, empty_value)

    # get all bitmasks
    bitmasks = map(count -> cdata .== count, 0x1:comp_count)
    return bitmasks :: Vector{BitMatrix}
end # }}}

"""
finds largest square sub matrix inside `data` with ones-entries.

`use_mem` must be a matrix of the same size as `data`.

return value is `(x, y, len)`
"""
function cv_find_largest_square(data::BitMatrix, use_mem::Matrix{UInt32}) # {{{

    use_mem[:] .= 0x0
    use_mem[end, :] .= data[end, :]
    use_mem[:, end] .= data[:, end]
    for col in size(data, 2)-1:-1:1
        for row in size(data, 1)-1:-1:1
            use_mem[row, col] = data[row, col] ?
                0x1 + min(use_mem[row, col+1], use_mem[row+1, col],
                          use_mem[row+1, col+1]) : 0x0 
        end
    end
    len, pos = findmax(use_mem)
    return (Int32(pos[1]), Int32(pos[2]), Int32(len))
end # }}}

function cv_get_winding_number(lp::CV_2DCanvasLinePainter, trafo, z::ComplexF64) # {{{
    wnr_twice = Int32(0)
    o, t = Int32(1), Int32(2)

    for segment in lp.segments
        z1, w1 = segment[1], trafo(segment[1]) - z
        for z2 in (segment[2:end]..., segment[1])
            w2 = trafo(z2) - z
            w1 == w2 && continue
            iw1, iw2 = imag(w1), imag(w2)

            # axis crossing test
            if iw1 > 0  &&  iw2 > 0
            elseif iw1 < 0  &&  iw2 < 0
            elseif iw1 == 0 == iw2 
            elseif iw1 == 0
                if real(w1) ≥ 0
                    wnr_twice += (iw2 > 0) ? +o : -o    # +½ or -½
                end
            elseif iw2 == 0
                if real(w2) ≥ 0
                    wnr_twice += (iw1 > 0) ? -o : +o    # -½ or +½
                end
            else
                if (iw1*real(w2) - iw2*real(w1))/(iw1-iw2) ≥ 0
                    wnr_twice += (iw2 > 0) ? +t : -t  # +1 or -1
                end
            end

            z1, w1 = z2, w2
        end
    end

    return cv_half(wnr_twice)
end  # }}}

function cv_compute_connected_components_for_canvas(
        wp::CV_Math2DCanvasWindingPainter, canvas::CV_Math2DCanvas, trafo) # {{{
    empty!(wp.helpers.con_comps)  # Delete old data

    bitmasks = cv_compute_conn_masks_for_canvas(wp, canvas, trafo)

    # (mis-)use comp_canvas to compute largest sqaure in every bitmask
    wnr_min, wnr_max = typemax(Int32), typemin(Int32)
    comp_canvas = wp.helpers.comp_canvas
    cdata = comp_canvas.surface.data
    lp = wp.styled_line_painter.painter
    for bitmask in bitmasks
        sx, sy, len = cv_find_largest_square(bitmask, cdata)
        px, py = sx + cv_half(len), sy + cv_half(len)   # center of square
        x, y = cv_pixel2math(comp_canvas, px, py)
        wnr = cv_get_winding_number(lp, trafo, x + 1im*y)
        wnr_min, wnr_max = min(wnr_min, wnr), max(wnr_max, wnr)
        push!(wp.helpers.con_comps,
            CV_ConnectedComponent((px, py), bitmask, wnr))
    end
    return wnr_min, wnr_max
end # }}}

function cv_compute_color_dict(wp::CV_Math2DCanvasWindingPainter,
        wnr_min, wnr_max) # {{{
    color_dict = wp.helpers.color_dict
    empty!(color_dict)
    color_dict[0] = 0xffaaaaaa
    for wnr in wnr_min:wnr_max
        wnr == 0  &&  continue
        ratio = (wnr > 0) ? wnr/wnr_max : wnr/wnr_min # in (0, 1]
        res = round(UInt32, 255*0.9*sqrt(1-ratio))
        color_dict[wnr] = (wnr > 0) ? 
            0xff000000 | 0x000000ff << 8   | res << 16 | res :
            0xff000000 | 0x000000ff << 16  | res <<  8 | res
    end
    return nothing
end # }}}

function cv_paint(cc::CV_2DCanvasContext{canvasT},
                  wp::CV_Math2DCanvasWindingPainter,
                  pc::CV_2DWindingPainterContext) where {canvasT <: CV_Math2DCanvas}
    canvas = cc.canvas
    cache = wp.cache
    trafo = pc.trafo

    if wp.cache_flag && cv_is_in_cache(cache, canvas, pc)
    else
        wnr_min, wnr_max = cv_compute_connected_components_for_canvas(
            wp, canvas, trafo)
        cv_compute_color_dict(wp, wnr_min, wnr_max)
        if wp.cache_flag
            cache.last_canvas = canvas
            cache.last_pc = pc
        end
    end

    surface = cc.canvas.surface
    Cairo.flush(surface)
    data = surface.data

    color_dict = wp.helpers.color_dict
    for con_comp in wp.helpers.con_comps
        wnr = con_comp.winding_number
        get(pc.hide_winding_numbers, wnr, false) && continue
        data[con_comp.mask] .= color_dict[wnr]
    end
    Cairo.mark_dirty(surface)

    return nothing
end

"""
A painter for drawing a colorbar for a `CV_Math2DCanvasWindingPainter`.

For each windingnumber `wnr` the rectangle `(wnr-0.5, start, 1.0, len)` 
(in the math coordinate system) is filled with the color of the winding number.
"""
struct CV_2DWindingColorbarPainter <: CV_2DCanvasPainter # {{{
    winding_painter   :: CV_Math2DCanvasWindingPainter
    winding_pc        :: CV_2DWindingPainterContext
    start             :: Float64
    len               :: Float64
    vertical          :: Bool
end

function cv_paint(cc::CV_2DCanvasContext, 
                  wcb_painter::CV_2DWindingColorbarPainter,
                  pc::CV_PaintingContext)
    canvas, ctx = cc.canvas, cc.ctx

    # fill background (for unknown colors)
    set_operator(ctx, Cairo.OPERATOR_SOURCE)
    set_source_rgb(ctx, 1, 1, 1)
    rectangle(cc.ctx,
        real(canvas.corner_ul), imag(canvas.corner_lr),
        real(canvas.corner_lr) - real(canvas.corner_ul),
        imag(canvas.corner_ul) - imag(canvas.corner_lr))
    fill(ctx)

    # now every winding number
    color_dict = wcb_painter.winding_painter.helpers.color_dict
    hide_winding_numbers = wcb_painter.winding_pc.hide_winding_numbers
    for wnr in keys(color_dict)
        if get(hide_winding_numbers, wnr, false)
            set_source_rgb(ctx, 0, 0, 0)   # black for hide
        else
            value = color_dict[wnr]
            set_source_rgba(ctx,
                ((value & 0x00ff0000) >> 16)/255,
                ((value & 0x0000ff00) >>  8)/255,
                ((value & 0x000000ff)      )/255,
                ((value & 0xff000000) >> 24)/255)
        end
        if wcb_painter.vertical
            rectangle(ctx, wcb_painter.start, wnr - 0.5, wcb_painter.len, 1.0)
        else
            rectangle(ctx, wnr - 0.5, wcb_painter.start, 1.0, wcb_painter.len)
        end
        fill(ctx)
    end
    return nothing
end

# }}}

struct CV_WindingColorBarCreateData{ccsT, dcbT, contextT, rfuncT} <: CV_CreateData
    internal_slider     :: CV_SliderCreateData{ccsT, dcbT, contextT}
    colorbar_container  :: CV_SliderContainer{ccsT, dcbT}
    container_context   :: contextT
    react_func          :: rfuncT
    colorbar_painter    :: CV_2DWindingColorbarPainter
end

function cv_create_winding_colorbar(
        pixel_width::Integer, pixel_height::Integer,
        winding_painter::CV_Math2DCanvasWindingPainter,
        winding_pc::CV_2DWindingPainterContext,
        wnr_min::Integer, wnr_max::Integer,
        rulers::Union{NTuple{N, CV_Ruler}, Missing}=missing;
        attach::CV_AttachType=cv_south,
        decoraction_with_layout_and_position_callback=(inner_layout, pos) ->
            cv_border(inner_layout, pos, 1)) where {N} # {{{

    if rulers === missing
        rulers=(CV_Ruler(
            cv_format_ticks("%.0f", Float64.(wnr_min:1:wnr_max)...),
            CV_TickLabelAppearance()), )
    end

    slider_data = cv_create_hslider(pixel_width, pixel_height,
        wnr_min-0.5, wnr_max+0.5, rulers;
        attach, decoraction_with_layout_and_position_callback)

    react_func = z -> begin
        wnr = round(Int32, real(z))
        if haskey(winding_painter.helpers.color_dict, wnr)
            winding_pc.hide_winding_numbers[wnr] =
                !get(winding_pc.hide_winding_numbers, wnr, false)
            return CV_Response(; redraw_flag=true)
        else
            return nothing
        end
    end

    colorbar_painter = CV_2DWindingColorbarPainter(
        winding_painter, winding_pc,
        0.0, imag(slider_data.slider_container.can_slider.corner_ul), false)

    return CV_WindingColorBarCreateData(
        slider_data, slider_data.slider_container,
        slider_data.container_context, react_func, colorbar_painter)
end # }}}

function cv_setup_winding_colorbar(setup::CV_SceneSetupChain,
        colorbar_data::CV_WindingColorBarCreateData,
        cont_l::CV_2DLayoutPosition)
    return cv_setup_hslider(setup, colorbar_data.internal_slider,
        cont_l, colorbar_data.colorbar_painter,
        colorbar_data.react_func;
        react_to_actionpixel_update=false,
        react_to_statepixel_update=true)
end

# }}}

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
