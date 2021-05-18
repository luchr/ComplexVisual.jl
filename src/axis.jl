macro import_axis_huge()
    :(
        using ComplexVisual:
            CV_TickLabel, cv_format_ticks,
            CV_TickLabelAppearance, CV_Ruler,
            cv_create_2daxis_canvas, cv_ticks_labels, cv_anchor
    )
end

import Base: show


"""
Location (math coordinate) and description for a tick
(typically placed at axis at a axis-tick).
"""
struct CV_TickLabel{LocT}
    location    :: LocT
    text        :: AbstractString
end

show(io::IO, tl::CV_TickLabel) = cv_show_impl(io, tl)
show(io::IO, m::MIME{Symbol("text/plain")}, tl::CV_TickLabel) =
    cv_show_impl(io, m, tl)

"""
Styles and data needed to render/draw axis-ticks with labels.
"""
struct CV_TickLabelAppearance{tsT <: CV_ContextStyle, lsT <: CV_ContextStyle} # {{{
    tick_length  :: Int32
    gap          :: Int32
    tick_style   :: tsT
    label_style  :: lsT

    function CV_TickLabelAppearance(tick_length::Integer, gap::Integer,
        tick_style::CV_ContextStyle, label_style::CV_ContextStyle)
        return new{typeof(tick_style), typeof(label_style)}(
            Int32(tick_length), Int32(gap), tick_style, label_style)
    end
end

show(io::IO, app::CV_TickLabelAppearance) = cv_show_impl(io, app)

show(io::IO, m::MIME{Symbol("text/plain")}, app::CV_TickLabelAppearance) =
    cv_show_impl(io, m, app)
# }}}

function CV_TickLabelAppearance(;
        tick_length::Integer=Int32(10),
        gap::Integer=cv_half(tick_length),
        tick_style::CV_ContextStyle=cv_linewidth(2) → cv_black,
        label_style::CV_ContextStyle=cv_black →
            cv_fontface("serif") → cv_fontsize(15))
    return CV_TickLabelAppearance(tick_length, gap, tick_style, label_style)
end

"""
Ticks with their labels and appearance.
"""
struct CV_Ruler{N, LocT, tsT, lsT}    # {{{
    ticklabels :: NTuple{N, CV_TickLabel{LocT}}
    app        :: CV_TickLabelAppearance{tsT, lsT}
end

show(io::IO, ruler::CV_Ruler) = cv_show_impl(io, ruler)
show(io::IO, m::MIME{Symbol("text/plain")}, ruler::CV_Ruler) =
    cv_show_impl(io, m, ruler)

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
    fmt_func = isempty(printf_format) ?
        x -> "" : @eval x -> @sprintf($printf_format, x)
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
struct used internally for constructing the ticks and labels.

Needed in advance (before allocating the axis canvas) in order to
be able to determine the size needed for the axis canvas.

```
                     ┌─────── cv_north ────────┐
                     │ label                   │
                     │                         │               ┌─────────┐
                     │   │                     │               │         │
              ┌──────┴─*─┴─────────────────────┴───────────────*         c
              │        │                                       │         v
              │        │                                       │         _
              c        │                                       ├── lab   e
              v lab1 ──┤                                       │         a
              _        │                                       │         s
              w        │                                       │         t
              e        │      math canvas                      │         │
              s        │                                       │         │
              t lab2 ──┤                                       ├─────────┘
              │        │                                       │
              │        │                                       │
              │        │                                       │
              └────────┤                                       │
                       │                                       │
                       │                                       │
                       │                                       │
                  ┌────*──┬───────────────┬───────────────┬────┘
                  │       │tick_length    │               │
                  │       │               │               │
                  │         gap                           │
                  │                                       │
                  │  tick label         label2            │
                  └─────────────── cv_south ──────────────┘

         *   is (0,0) for axis canvas units (and :default-anchor from outside)
```
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

function cv_ticks_labels_draw(con::CV_2DCanvasContext,
        attach::CV_AttachType, app::CV_TickLabelAppearance,
        ticklabelsdata::NTuple{N, CV_TickLabelData{Float64}};
        debug::Union{Val{true}, Val{false}}=Val(false)) where {N}  # {{{

    tick_length, tick_style = app.tick_length, app.tick_style
    label_style = app.label_style
    canvas = con.canvas

    ctx = con.ctx
    ubox = canvas.user_box
    # ticks
    cv_prepare(con, tick_style)
    for td in ticklabelsdata
        if attach isa CV_southT
            move_to(ctx, td.tick_location, 0)
            rel_line_to(ctx, 0, tick_length)
        elseif attach isa CV_northT
            move_to(ctx, td.tick_location, 0)
            rel_line_to(ctx, 0, -tick_length)
        elseif attach isa CV_eastT
            move_to(ctx, 0, td.tick_location)
            rel_line_to(ctx, tick_length, 0)
        elseif attach isa CV_westT
            move_to(ctx, 0, td.tick_location)
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
        attach isa CV_northT ? -tick_length - gap - tlm.max_depth  :
        attach isa CV_eastT  ? tick_length + gap                   :
        attach isa CV_westT  ? -tick_length - gap                  :
        cv_error("Unknown attach value")) :: Int32
end # }}}

function cv_set_tick_location!(ticklabelsdata, for_canvas, attach) # {{{
    for td in ticklabelsdata
        td.tick_location = (
            ((attach isa CV_northT) || (attach isa CV_southT))    ?
            cv_math2pixel(for_canvas, td.math_location, 0.0)[1]   :
            cv_math2pixel(for_canvas, 0.0, td.math_location)[2])
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
    if min_loc == max_loc
        max_loc += o
    end
    cv_add_rectangle!(rstore, (
        attach isa CV_southT ? CV_Rectangle(tick_length, min_loc, z, max_loc)  :
        attach isa CV_northT ? CV_Rectangle(z, min_loc, -tick_length, max_loc) :
        attach isa CV_eastT  ? CV_Rectangle(max_loc, z, min_loc, tick_length)  :
        attach isa CV_westT  ? CV_Rectangle(max_loc, -tick_length, min_loc, z) :
        cv_error("Unknown attach value")) :: CV_Rectangle{Int32})
    return nothing
end # }}}

function cv_add_rect_for_default_anchor(rstore, attach) # {{{
    z, o = zero(Int32), one(Int32)
    cv_add_rectangle!(rstore, (
        attach isa CV_southT ? CV_Rectangle(o, z, z, o)      :
        attach isa CV_northT ? CV_Rectangle(z, z, -o, o)     :
        attach isa CV_eastT  ? CV_Rectangle(o, z, z, o)      :
        attach isa CV_westT  ? CV_Rectangle(o, -o, z, z)     :
        cv_error("Unknown attach value")) :: CV_Rectangle{Int32})
    return nothing
end # }}}
# }}}

function cv_get_default_anchor(rstore, attach)  # {{{
    z, o = zero(Int32), one(Int32)
    bb = rstore.bounding_box
    return (
        attach isa CV_southT ? (-bb.left, z)              :
        attach isa CV_northT ? (-bb.left, cv_height(bb))  :
        attach isa CV_eastT  ? (z, -bb.bottom)            :
        attach isa CV_westT  ? (cv_width(bb), -bb.bottom) :
        cv_error("Unknown attach value")) :: Tuple{Int32, Int32}

end # }}}

function cv_layout_ruler(for_canvas::CV_Math2DCanvas, attach::CV_AttachType,
        ruler::CV_Ruler, rstore::CV_RectangleStore{Int32})  # {{{
    app = ruler.app
    tick_length, tick_style = app.tick_length, app.tick_style
    gap, label_style = app.gap, app.label_style

    ticklabelsdata = cv_init_ticklables_data(label_style, ruler.ticklabels...)
    tlm = cv_ticks_labels_get_metric(ticklabelsdata)

    base = cv_ticks_labels_base(tick_length, gap, tlm, attach)
    cv_set_tick_location!(ticklabelsdata, for_canvas, attach)

    for td in ticklabelsdata
        xpos = cv_get_label_xpos(td, base, attach)
        ypos = cv_get_label_ypos(td, base, attach)
        td.bounding_box = cv_get_label_bb(td, xpos, ypos)
        td.startpoint = (xpos - round(Int32, td.text_extents.x_bearing), ypos)
        !td.bounding_box.empty && cv_add_rectangle!(rstore, td.bounding_box)
    end
    cv_add_rect_for_ticks(rstore, ticklabelsdata, tick_length, gap, attach)
    cv_add_rect_for_default_anchor(rstore, attach)

    return ticklabelsdata
end # }}}


function cv_create_2daxis_canvas(for_canvas::CV_Math2DCanvas,
        attach::CV_AttachType,
        ticklabels::Vararg{CV_TickLabel{Float64}, N};
        app::CV_TickLabelAppearance=CV_TickLabelAppearance()) where {N}
    return cv_create_2daxis_canvas(for_canvas,
        attach, (CV_Ruler(ticklabels, app),))
end

function cv_create_2daxis_canvas(for_canvas::CV_Math2DCanvas,
        attach::CV_AttachType,
        rulers::NTuple{N, CV_Ruler}) where {N} # {{{

    N < 1 && cv_error("Need at least one ruler")
    rstore = CV_RectangleStore(Int32)     # all bounding boxes of the labels

    ticklabelsdata = tuple(
        map(ruler -> cv_layout_ruler(
            for_canvas, attach, ruler, rstore), rulers)...)

    default_anchor = cv_get_default_anchor(rstore, attach)
    anchor_func = (can, anchor_name) -> (anchor_name === :default ?
            default_anchor : cv_anchor(can.bounding_box, anchor_name))
    canvas = CV_2DLayoutCanvas(rstore.bounding_box, anchor_func)

    con = cv_create_context(canvas; fill_with=cv_color(0,0,0,0))
    for index in 1:N
        cv_ticks_labels_draw(con,
            attach, rulers[index].app, ticklabelsdata[index])
    end
    cv_destroy(con)

    return canvas
end # }}}


function cv_ticks_labels(layout::CV_Abstract2DLayout,
        for_canvas_l::CV_2DLayoutPosition{CV_Math2DCanvas, dcbT, styleT},
        attach::CV_AttachType,
        rulers::NTuple{N, CV_Ruler}) where {dcbT, styleT, N}
    canvas = cv_create_2daxis_canvas(for_canvas_l.canvas, attach, rulers)

    return cv_add_canvas!(layout, canvas, cv_anchor(canvas, :default), 
        cv_anchor(for_canvas_l, (
            attach isa CV_southT ? :southwest   :
            attach isa CV_northT ? :northwest   :
            attach isa CV_eastT  ? :northeast   : :northwest)))
end

function cv_ticks_labels(layout::CV_Abstract2DLayout,
        for_canvas_l::CV_2DLayoutPosition, attach::CV_AttachType,
        ticklabels::Vararg{CV_TickLabel{Float64}, N};
        app::CV_TickLabelAppearance=CV_TickLabelAppearance()) where {N}

    return cv_ticks_labels(layout, for_canvas_l,
        attach, (CV_Ruler(ticklabels, app), ))
end


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
