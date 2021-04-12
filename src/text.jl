macro import_text_huge()
    :(
        using ComplexVisual:
            CV_TextExtents, cv_get_text_extents,
            cv_anchor, cv_create_context, cv_text
    )
end

"""
TextExtends (including computed height and depth)
"""
struct CV_TextExtents  # {{{
    x_bearing    :: Float64
    y_bearing    :: Float64
    bb_width     :: Float64     # complete width of bounding box
    bb_height    :: Float64     # complete height of bounding box
    x_adv        :: Float64
    y_adv        :: Float64
    height       :: Float64     # height above baseline
    depth        :: Float64     # depth below baseline
end


"""
compute text extents for given string w.r.t. given cairo context.
"""
function cv_get_text_extents(
        ctx, text::AbstractString;
        use_mem=Vector{Float64}(undef, 6)::Vector{Float64})
    text_extents(ctx, text, use_mem)
    height = -use_mem[2]
    depth = use_mem[4] + use_mem[2]
    return CV_TextExtents(
        use_mem[1], use_mem[2], use_mem[3],
        use_mem[4], use_mem[5], use_mem[6],
        height, depth)
end
# }}}

"""
`CV_2DCanvas` with rendered text.
"""
struct CV_2DTextCanvas <: CV_2DCanvas # {{{
    surface         :: Cairo.CairoSurfaceImage{UInt32}
    pixel_width     :: Int32
    pixel_height    :: Int32
    bounding_box    :: CV_Rectangle{Int32} # zero-based
    baseline        :: Int32

    function CV_2DTextCanvas(width::Integer, height::Integer, baseline::Integer)
        pixel_width, pixel_height = Int32(width), Int32(height)
        surface = cv_create_cairo_image_surface(pixel_width, pixel_height)
        self = new(
            surface, pixel_width, pixel_height,
            CV_Rectangle(pixel_height, Int32(0), Int32(0), pixel_width),
            Int32(baseline))
        return self
    end
end

function cv_anchor(can::CV_2DTextCanvas, anchor_name::Symbol)
    if anchor_name === :baseline  || anchor_name === :baseline_west
        return (Int32(0), can.baseline)
    elseif anchor_name === :baseline_center
        return (cv_half(can.pixel_width), can.baseline)
    elseif anchor_name === :baseline_east
        return (can.pixel_width, can.baseline)
    else
        return cv_anchor(can.bounding_box, anchor_name)
    end
end

function cv_create_context(canvas::CV_2DTextCanvas; prepare::Bool=true)
    con = CV_2DCanvasContext(canvas)
    if prepare
        ctx = con.ctx
        reset_transform(ctx)

        set_operator(ctx, Cairo.OPERATOR_SOURCE)
        set_source_rgba(ctx, 0, 0, 0, 0)
        rectangle(ctx, 0, 0, canvas.pixel_width, canvas.pixel_height)
        fill(ctx)

        set_operator(ctx, Cairo.OPERATOR_OVER)
    end
    return con
end

"""
Create 2DCanvas with given text (rendered inside).
"""
function cv_text(text::AbstractString,
                 style::CV_ContextStyle=cv_color(0,0,0) → 
                    cv_fontface("serif") → cv_fontsize(15);
                use_temp_can=nothing,
                use_mem=Vector{Float64}(undef, 6)::Vector{Float64})
    temp_can = (use_temp_can isa Nothing) ? CV_Std2DCanvas(5, 5) : use_temp_can
    con = cv_create_context(temp_can)

    cv_prepare(con, style)
    ext = cv_get_text_extents(con.ctx, text; use_mem=use_mem)
    if ext.bb_width <= 0 || ext.bb_height <= 0
        return CV_2DTextCanvas(1, 1, 1)   # everything is empty
    end
    cv_destroy(con)
    if !(use_temp_can isa Nothing)
        cv_destroy(temp_can)
    end

    canvas = CV_2DTextCanvas(
        ceil(Int32, ext.bb_width), ceil(Int32, ext.bb_height),
        round(Int32, ext.height))
    con = cv_create_context(canvas)
    try
        cv_prepare(con, style)
        move_to(con.ctx, 0 - round(Int32, ext.x_bearing), canvas.baseline)
        show_text(con.ctx, text)
    finally
        cv_destroy(con)
    end
    return canvas
end

# }}}

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
