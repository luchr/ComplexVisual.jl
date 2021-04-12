macro import_axis_huge()
    :(
        using ComplexVisual:
            CV_TickLabel, cv_format_ticks, CV_2DAxisCanvas, cv_create_context,
            cv_create_2daxis_canvas, cv_ticks_labels, cv_anchor
    )
end

"""
Location (math coordinate) and description for a tick
(typically placed at axis).
"""
struct CV_TickLabel{LocT}
    location    :: LocT
    text        :: AbstractString
end

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

"""
`CV_2DCanvas` with axis.
"""
struct CV_2DAxisCanvas <: CV_2DCanvas   # {{{
    surface      :: Cairo.CairoSurfaceImage{UInt32}
    pixel_width  :: Int32
    pixel_height :: Int32
    bounding_box :: CV_Rectangle{Int32} # zero-based
    user_box     :: CV_Rectangle{Int32} # user-coordinates (result of layout)
                                        # typicalle nonzero-based
    anchor_def   :: Tuple{Int32, Int32}
    attach       :: Union{Val{:north}, Val{:south}, Val{:east}, Val{:west}}
    function CV_2DAxisCanvas(user_box::CV_Rectangle{Int32}, anchor_def, attach)
        width, height = cv_width(user_box), cv_height(user_box)
        surface = cv_create_cairo_image_surface(width, height)
        self = new(
            surface, width, height,
            CV_Rectangle(height, Int32(0), Int32(0), width),
            user_box, anchor_def, attach)
        return self
    end
end

function cv_anchor(can::CV_2DAxisCanvas, anchor_name::Symbol)
    return (
        anchor_name == :default ? can.anchor_def :
        cv_anchor(can.bounding_box, anchor_name))
end

function cv_create_context(canvas::CV_2DAxisCanvas; prepare::Bool=true)
    con = CV_2DCanvasContext(canvas)
    if prepare
        ctx = con.ctx
        reset_transform(ctx)

        set_operator(ctx, Cairo.OPERATOR_SOURCE)
        set_source_rgba(ctx, 0, 0, 0, 0)
        rectangle(ctx, 0, 0, canvas.pixel_width, canvas.pixel_height)
        fill(ctx)

        set_operator(ctx, Cairo.OPERATOR_OVER)
        ubox = canvas.user_box
        translate(ctx, -ubox.left, -ubox.bottom)
    end
    return con
end

# }}}

const cv_ticks_labels_tick_style = cv_linewidth(2) → cv_color(0,0,0)
const cv_ticks_labels_label_style = cv_color(0,0,0) → 
                                    cv_fontface("cairo:monospace") →
                                    cv_fontsize(15)

function cv_ticks_labels_draw(
        canvas::CV_2DAxisCanvas, tick_length, tick_style, label_style,
        ticklabelsdata::NTuple{N, CV_TickLabelData{Float64}};
        debug::Union{Val{true}, Val{false}}=Val(false)) where {N}  # {{{

    cv_create_context(canvas) do con
        ctx = con.ctx
        ubox = canvas.user_box
        # ticks
        cv_prepare(con, tick_style)
        for td in ticklabelsdata
            if canvas.attach isa Val{:south}
                move_to(ctx, td.tick_location, 0)
                rel_line_to(ctx, 0, tick_length)
            elseif canvas.attach isa Val{:north}
                move_to(ctx, td.tick_location, ubox.top)
                rel_line_to(ctx, 0, -tick_length)
            elseif canvas.attach isa Val{:east}
                move_to(ctx, 0, td.tick_location)
                rel_line_to(ctx, tick_length, 0)
            elseif canvas.attach isa Val{:west}
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

"""
stores the maximum label sizes (height, depth, width, etc.)
"""
struct CV_TicksLabelsMetric
    max_height :: Int32
    max_depth  :: Int32
    max_width  :: Int32
end

function cv_ticks_labels_get_metric(ticklabelsdata)
    return CV_TicksLabelsMetric(
        ceil(Int32,  # max_height
            maximum(map(td -> td.text_extents.height, ticklabelsdata))),
        ceil(Int32,  # max_depth
            maximum(map(td -> td.text_extents.depth, ticklabelsdata))),
        ceil(Int32,  # max_width
            maximum(map(td -> td.text_extents.bb_width, ticklabelsdata))))
end

function cv_ticks_labels_base(tick_length, gap, tlm, attach)
    return (
        attach isa Val{:south} ? tick_length + gap + tlm.max_height  :
        attach isa Val{:north} ? tlm.max_height                      :
        attach isa Val{:east}  ? tick_length + gap                   :
        attach isa Val{:west}  ? tlm.max_width                       :
        cv_error("Unknown attach value")) :: Int32
end

function cv_set_tick_location!(ticklabelsdata, for_canvas, attach)
    for td in ticklabelsdata
        if (attach isa Val{:north}) || (attach isa Val{:south})
            td.tick_location = cv_math2pixel(for_canvas, td.math_location, 0.0)[1]
        else
            td.tick_location = cv_math2pixel(for_canvas, 0.0, td.math_location)[2]
        end
    end
    return nothing
end

function cv_get_label_xpos(td, base, attach::Union{Val{:south}, Val{:north}})
    return td.tick_location - round(Int32, cv_half(td.text_extents.bb_width))
end

function cv_get_label_xpos(td, base, attach::Val{:east})
    return base
end

function cv_get_label_xpos(td, base, attach::Val{:west})
    return base - round(Int32, td.text_extents.bb_width)
end

function cv_get_label_ypos(td, base, attach::Union{Val{:south}, Val{:north}})
    return base
end

function cv_get_label_ypos(td, base, attach::Union{Val{:east}, Val{:west}})
    # return td.tick_location + round(Int32, cv_half(td.text_extents.bb_height))
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

function cv_add_rect_for_ticks(rstore, ticklabelsdata, tick_length, gap, attach)
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
        attach isa Val{:south} ? CV_Rectangle(tick_length, min_loc,
                                              z, max_loc)                :
        attach isa Val{:north} ? CV_Rectangle(new_top, min_loc,
                                              new_top-o, max_loc)        :
        attach isa Val{:east}  ? CV_Rectangle(max_loc, z,
                                              min_loc, tick_length)      :
        attach isa Val{:west}  ? CV_Rectangle(max_loc, new_right-o,
                                              min_loc, new_right)        :
        cv_error("Unknown attach value")) :: CV_Rectangle{Int32})
    return nothing

end

function cv_add_rect_for_default_anchor(rstore, attach)
    z, o = zero(Int32), one(Int32)
    cur_top, cur_right = rstore.bounding_box.top, rstore.bounding_box.right
    cv_add_rectangle!(rstore, (
        attach isa Val{:south} ? CV_Rectangle(o, z, z, o)                   :
        attach isa Val{:north} ? CV_Rectangle(cur_top, z, cur_top-o, o)     :
        attach isa Val{:east}  ? CV_Rectangle(o, z, z, o)                   :
        attach isa Val{:west}  ? CV_Rectangle(o, cur_right-o, z, cur_right) :
        cv_error("Unknown attach value")) :: CV_Rectangle{Int32})
    return nothing
end

function cv_get_default_anchor(rstore, attach)
    z, o = zero(Int32), one(Int32)
    bb = rstore.bounding_box
    return (
        attach isa Val{:south} ? (-bb.left, z)                :
        attach isa Val{:north} ? (-bb.left, bb.top)           :
        attach isa Val{:east}  ? (z, -bb.bottom)              :
        attach isa Val{:west}  ? (bb.right, -bb.bottom)       :
        cv_error("Unknown attach value")) :: Tuple{Int32, Int32}
end

function cv_create_2daxis_canvas(for_canvas::CV_Math2DCanvas,
        ticklabels::Vararg{CV_TickLabel{Float64}, N};
        attach::Union{Val{:north}, Val{:south},
                      Val{:east}, Val{:west}}=Val{:south},
        tick_style::CV_ContextStyle=cv_ticks_labels_tick_style,
        label_style::CV_ContextStyle=cv_ticks_labels_label_style,
        tick_length::Integer=10, gap::Integer=8) where {N}

    tick_length, gap = Int32(tick_length), Int32(gap)

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

    canvas = CV_2DAxisCanvas(
        rstore.bounding_box, cv_get_default_anchor(rstore, attach), attach)
    cv_ticks_labels_draw(
        canvas, tick_length, tick_style, label_style, ticklabelsdata)
    return canvas
end

function cv_ticks_labels(
        layout::CV_Abstract2DLayout,
        for_canvas_l::CV_2DLayoutPosition{CV_Math2DCanvas, dcbT, styleT},
        ticklabels::Vararg{CV_TickLabel{Float64}, N};
        attach::Union{Val{:north}, Val{:south},
                      Val{:east}, Val{:west}}=Val{:south},
        tick_style::CV_ContextStyle=cv_ticks_labels_tick_style,
        label_style::CV_ContextStyle=cv_ticks_labels_label_style,
        tick_length::Integer=10, gap::Integer=8) where {N, dcbT, styleT}

    canvas = cv_create_2daxis_canvas(
        for_canvas_l.canvas, ticklabels...;
        attach, tick_style, label_style, tick_length)

    return cv_add_canvas!(layout, canvas, cv_anchor(canvas, :default), 
        cv_anchor(for_canvas_l, (
            attach isa Val{:south} ? :southwest   :
            attach isa Val{:north} ? :northwest   :
            attach isa Val{:east}  ? :northeast   : :northwest)))
end


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
