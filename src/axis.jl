macro import_axis_huge()
    :(
        using ComplexVisual:
            CV_TickLabel, cv_format_ticks, cv_create_context,
            CV_TickLabelAppearance, CV_Ruler,
            cv_create_2daxis_canvas, cv_ticks_labels, cv_anchor
    )
end

import Base: show


"""
Location (math coordinate) and description for a tick
(typically placed at axis).
"""
struct CV_TickLabel{LocT}
    location    :: LocT
    text        :: AbstractString
end

"""
Styles and data needed to render/draw axis-ticks with labels.
"""
struct CV_TickLabelAppearance{tsT <: CV_ContextStyle, lsT <: CV_ContextStyle} # {{{
    attach       :: CV_AttachType
    tick_length  :: Int32
    gap          :: Int32
    tick_style   :: tsT
    label_style  :: lsT

    function CV_TickLabelAppearance(attach::CV_AttachType,
            tick_length::Integer, gap::Integer, tick_style::CV_ContextStyle,
            label_style::CV_ContextStyle)
        return new{typeof(tick_style), typeof(label_style)}(
            attach, Int32(tick_length), Int32(gap), tick_style, label_style)
    end
end

function show(io::IO, app::CV_TickLabelAppearance)
    print(io, "CV_TickLabelAppearance(attach: "); show(io, app.attach)
    print(io, ", tick_length: "); show(io, app.tick_length)
    print(io, ", gap: "); show(io, app.gap)
    print(io, ", tick_style: "); show(io, app.tick_style)
    print(io, ", label_style: "); show(io, app.label_style)
    print(io, ')')
    return nothing
end

function show(io::IO, m::MIME{Symbol("text/plain")}, app::CV_TickLabelAppearance)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, "CV_TickLabelAppearance(")
    print(io, indent, "attach: "); show(iio, app.attach); println(io)
    print(io, indent, "tick_length: "); show(iio, app.tick_length); println(io)
    print(io, indent, "gap: "); show(iio, app.gap); println(io)
    print(io, indent, "tick_style: "); show(iio, m, app.tick_style); println(io)
    print(io, indent, "label_style: "); show(iio, m, app.label_style); println(io)
    print(io, outer_indent, ')')
    return nothing
end # }}}

function CV_TickLabelAppearance(;
        attach::CV_AttachType=cv_south,
        tick_length::Integer=Int32(10),
        gap::Integer=cv_half(tick_length),
        tick_style::CV_ContextStyle=cv_linewidth(2) → cv_color(0,0,0),
        label_style::CV_ContextStyle=cv_color(0,0,0) →
            cv_fontface("serif") → cv_fontsize(15))
    return CV_TickLabelAppearance(attach, tick_length, gap, tick_style, label_style)
end

"""
Ticks with their labels and appearance.
"""
struct CV_Ruler{N, LocT, tsT, lsT}    # {{{
    ticklabels :: NTuple{N, CV_TickLabel{LocT}}
    app        :: CV_TickLabelAppearance{tsT, lsT}
end

function show(io::IO, ruler::CV_Ruler)
    print(io, "CV_Ruler(ticklabels: "); show(io, ruler.ticklabels)
    print(io, ", app: "); show(io, ruler.app)
    print(io, ')')
    return nothing
end

function show(io::IO, m::MIME{Symbol("text/plain")}, ruler::CV_Ruler)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, "CV_Ruler(")
    print(io, indent, "ticklabels: "); show(iio, ruler.ticklabels); println(io)
    print(io, indent, "app: "); show(iio, m, ruler.app); println(io)
    print(io, outer_indent, ')')
    return nothing
end

function CV_Ruler(ticklabels::Vararg{CV_TickLabel{LocT}, N}) where {N, LocT}
    return CV_Ruler(
        NTuple{N, CV_TickLabel{LocT}}(ticklabels),
        CV_TickLabelAppearance())
end
# }}}

"""
create for every location a `CV_TickLabel` by formatting the locations
with the given printf-format.
"""
function cv_format_ticks(printf_format::AbstractString, 
        locations::Vararg{Real, N}) where {N}
    @eval fmt_func = x -> @sprintf($printf_format, x)
    return NTuple{N, CV_TickLabel{Float64}}(
        map(x -> CV_TickLabel{Float64}(
                Float64(x), Base.invokelatest(fmt_func, Float64(x))),
            locations))
end

"""
create for every location a `CV_TickLabel` by formatting the locations
with the `"%.1f"` printf-format.
"""
function cv_format_ticks(locations::Vararg{Real, N}) where {N}
    return cv_format_ticks("%.1f", locations...)
end

"""
struct used internally for constructing the ticks, labels and axis canvas.
"""
mutable struct CV_TickLabelData{LocT}
    text           :: AbstractString
    text_extents   :: CV_TextExtents
    math_location  :: LocT
    tick_location  :: Int32
    startpoint     :: Tuple{Int32, Int32}
    bounding_box   :: CV_Rectangle{Int32}
end

"""
stores the maximum label sizes (height, depth, width, etc.)
"""
struct CV_TicksLabelsMetric
    max_height :: Int32
    max_depth  :: Int32
    max_width  :: Int32
end

function cv_ticks_labels_draw(canvas::CV_2DCanvas,
        attach::CV_AttachType, app::CV_TickLabelAppearance,
        ticklabelsdata::NTuple{N, CV_TickLabelData{Float64}};
        debug::Union{Val{true}, Val{false}}=Val(false)) where {N}  # {{{

    tick_length, tick_style = app.tick_length, app.tick_style
    label_style = app.label_style

    cv_create_context(canvas) do con
        ctx = con.ctx
        ubox = canvas.user_box
        # ticks
        cv_prepare(con, tick_style)
        for td in ticklabelsdata
            if attach isa CV_southT
                move_to(ctx, td.tick_location, 0)
                rel_line_to(ctx, 0, tick_length)
            elseif attach isa CV_northT
                move_to(ctx, td.tick_location, ubox.top)
                rel_line_to(ctx, 0, -tick_length)
            elseif attach isa CV_eastT
                move_to(ctx, 0, td.tick_location)
                rel_line_to(ctx, tick_length, 0)
            elseif attach isa CV_westT
                move_to(ctx, ubox.right, td.tick_location)
                rel_line_to(ctx, -tick_length, 0)
            else
                cv_error("Unknown attach value")
            end
            stroke(ctx)
        end

        # labels
        cv_prepare(con, label_style)
        for td in ticklabelsdata
            if !td.bounding_box.empty
                move_to(ctx, td.startpoint...)
                show_text(ctx, td.text)
            end
        end

        # bb check
        if debug isa Val{true}
            set_line_width(ctx, 1)
            set_source_rgb(ctx, 1, 0, 0)
            for td in ticklabelsdata
                bb = td.bounding_box
                rectangle(ctx, bb.left, bb.bottom, cv_width(bb), cv_height(bb))
                stroke(ctx)
            end

            set_source_rgb(ctx, 0, 1, 0)
            rectangle(ctx, ubox.left, ubox.bottom, cv_width(ubox), cv_height(ubox))
            stroke(ctx)
        end
    end
end # }}}

# Compute positions for ticks and labels and their bounding boxes, etc. {{{

function cv_init_ticklables_data(
        label_style::CV_ContextStyle,
        ticklabels::Vararg{CV_TickLabel{Float64}, N}) where {N}  # {{{
    temp_can = CV_Std2DCanvas(5, 5)
    con = cv_create_context(temp_can)
    use_mem = Vector{Float64}(undef, 6)
    try
        cv_prepare(con, label_style)
        return NTuple{N, CV_TickLabelData}(map(ticklabels) do ticklabel
            CV_TickLabelData(
                ticklabel.text,
                cv_get_text_extents(con.ctx, ticklabel.text; use_mem=use_mem),
                ticklabel.location,
                Int32(-1), (Int32(-1), Int32(-1)),
                CV_Rectangle(Int32))
        end)
    finally
        cv_destroy(con)
        cv_destroy(temp_can)
    end
end # }}}

function cv_ticks_labels_get_metric(ticklabelsdata) # {{{
    return CV_TicksLabelsMetric(
        ceil(Int32,  # max_height
            maximum(map(td -> td.text_extents.height, ticklabelsdata))),
        ceil(Int32,  # max_depth
            maximum(map(td -> td.text_extents.depth, ticklabelsdata))),
        ceil(Int32,  # max_width
            maximum(map(td -> td.text_extents.bb_width, ticklabelsdata))))
end # }}}

function cv_ticks_labels_base(tick_length, gap, tlm, attach) # {{{
    return (
        attach isa CV_southT ? tick_length + gap + tlm.max_height  :
        attach isa CV_northT ? tlm.max_height                      :
        attach isa CV_eastT  ? tick_length + gap                   :
        attach isa CV_westT  ? tlm.max_width                       :
        cv_error("Unknown attach value")) :: Int32
end # }}}

function cv_set_tick_location!(ticklabelsdata, for_canvas, attach) # {{{
    for td in ticklabelsdata
        if (attach isa CV_northT) || (attach isa CV_southT)
            td.tick_location = cv_math2pixel(
                for_canvas, td.math_location, 0.0)[1]
        else
            td.tick_location = cv_math2pixel(
                for_canvas, 0.0, td.math_location)[2]
        end
    end
    return nothing
end # }}}

function cv_get_label_xpos(td, base, attach::Union{CV_southT, CV_northT})
    return td.tick_location - round(Int32, cv_half(td.text_extents.bb_width))
end

function cv_get_label_xpos(td, base, attach::CV_eastT)
    return base
end

function cv_get_label_xpos(td, base, attach::CV_westT)
    return base - round(Int32, td.text_extents.bb_width)
end

function cv_get_label_ypos(td, base, attach::Union{CV_southT, CV_northT})
    return base
end

function cv_get_label_ypos(td, base, attach::Union{CV_eastT, CV_westT})
    return td.tick_location + round(Int32,
        td.text_extents.depth + td.text_extents.height/3)
end

function cv_get_label_bb(td, xpos, ypos)
    return CV_Rectangle(
        ceil(Int32, ypos + td.text_extents.depth),
        xpos,
        floor(Int32, ypos - td.text_extents.height),
        ceil(Int32, xpos + td.text_extents.bb_width))
end

function cv_add_rect_for_ticks(rstore, ticklabelsdata, tick_length,
        gap, attach) # {{{
    max_loc = ceil(Int32, maximum(map(td -> td.tick_location, ticklabelsdata)))
    min_loc = floor(Int32, minimum(map(td -> td.tick_location, ticklabelsdata)))
    z, o = zero(Int32), one(Int32)
    if (min_loc == max_loc)
        max_loc += o
    end
    cur_top, cur_right = rstore.bounding_box.top, rstore.bounding_box.right
    new_top = cur_top + tick_length + gap
    new_right = cur_right + tick_length + gap
    cv_add_rectangle!(rstore, (
        attach isa CV_southT ? CV_Rectangle(tick_length, min_loc, z, max_loc) :
        attach isa CV_northT ? CV_Rectangle(new_top, min_loc,
                                            new_top-o, max_loc)               :
        attach isa CV_eastT  ? CV_Rectangle(max_loc, z, min_loc, tick_length) :
        attach isa CV_westT  ? CV_Rectangle(max_loc, new_right-o,
                                            min_loc, new_right)               :
        cv_error("Unknown attach value")) :: CV_Rectangle{Int32})
    return nothing
end # }}}

function cv_add_rect_for_default_anchor(rstore, attach) # {{{
    z, o = zero(Int32), one(Int32)
    cur_top, cur_right = rstore.bounding_box.top, rstore.bounding_box.right
    cv_add_rectangle!(rstore, (
        attach isa CV_southT ? CV_Rectangle(o, z, z, o)                   :
        attach isa CV_northT ? CV_Rectangle(cur_top, z, cur_top-o, o)     :
        attach isa CV_eastT  ? CV_Rectangle(o, z, z, o)                   :
        attach isa CV_westT  ? CV_Rectangle(o, cur_right-o, z, cur_right) :
        cv_error("Unknown attach value")) :: CV_Rectangle{Int32})
    return nothing
end # }}}

# }}}

function cv_get_default_anchor(rstore, attach)  # {{{
    z, o = zero(Int32), one(Int32)
    bb = rstore.bounding_box
    return (
        attach isa CV_southT ? (-bb.left, z)             :
        attach isa CV_northT ? (-bb.left, bb.top)        :
        attach isa CV_eastT  ? (z, -bb.bottom)           :
        attach isa CV_westT  ? (bb.right, -bb.bottom)    :
        cv_error("Unknown attach value")) :: Tuple{Int32, Int32}
end # }}}


function cv_create_2daxis_canvas(for_canvas::CV_Math2DCanvas,
        ruler::CV_Ruler{N, Float64, tsT, lsT}) where {N, tsT, lsT}
    return cv_create_2daxis_canvas(
        for_canvas, ruler.ticklabels...; app=ruler.app)
end

function cv_create_2daxis_canvas(for_canvas::CV_Math2DCanvas,
        ticklabels::Vararg{CV_TickLabel{Float64}, N};
        app::CV_TickLabelAppearance=CV_TickLabelAppearance()) where {N}

    tick_length, tick_style = app.tick_length, app.tick_style
    gap, label_style, attach = app.gap, app.label_style, app.attach

    ticklabelsdata = cv_init_ticklables_data(label_style, ticklabels...)
    tlm = cv_ticks_labels_get_metric(ticklabelsdata)

    base = cv_ticks_labels_base(tick_length, gap, tlm, attach)
    cv_set_tick_location!(ticklabelsdata, for_canvas, attach)

    rstore = CV_RectangleStore(Int32)     # all bounding boxes of the labels
    for td in ticklabelsdata
        xpos = cv_get_label_xpos(td, base, attach)
        ypos = cv_get_label_ypos(td, base, attach)
        td.bounding_box = cv_get_label_bb(td, xpos, ypos)
        td.startpoint = (xpos - round(Int32, td.text_extents.x_bearing),
                         ypos)
        if !td.bounding_box.empty
            cv_add_rectangle!(rstore, td.bounding_box)
        end
    end

    cv_add_rect_for_ticks(rstore, ticklabelsdata, tick_length, gap, attach)
    cv_add_rect_for_default_anchor(rstore, attach)

    default_anchor = cv_get_default_anchor(rstore, attach)

    anchor_func = (can, anchor_name) -> (anchor_name === :default ?
            default_anchor : cv_anchor(can.bounding_box, anchor_name))

    canvas = CV_2DLayoutCanvas(rstore.bounding_box, anchor_func)

    cv_ticks_labels_draw(canvas, attach, app, ticklabelsdata)
    return canvas
end

function cv_ticks_labels(
        layout::CV_Abstract2DLayout,
        for_canvas_l::CV_2DLayoutPosition{CV_Math2DCanvas, dcbT, styleT},
        ruler::CV_Ruler{N, Float64, tsT, lsT}) where {dcbT, styleT, N,
                                                      tsT, lsT}
    return cv_ticks_labels(
        layout, for_canvas_l, ruler.ticklabels...; app=rulers.app)
end

function cv_ticks_labels(
        layout::CV_Abstract2DLayout,
        for_canvas_l::CV_2DLayoutPosition{CV_Math2DCanvas, dcbT, styleT},
        ticklabels::Vararg{CV_TickLabel{Float64}, N};
        app::CV_TickLabelAppearance=CV_TickLabelAppearance()) where {N, dcbT, styleT}

    canvas = cv_create_2daxis_canvas(for_canvas_l.canvas, ticklabels...; app)
    attach = app.attach

    return cv_add_canvas!(layout, canvas, cv_anchor(canvas, :default), 
        cv_anchor(for_canvas_l, (
            attach isa CV_southT ? :southwest   :
            attach isa CV_northT ? :northwest   :
            attach isa CV_eastT  ? :northeast   : :northwest)))
end


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
