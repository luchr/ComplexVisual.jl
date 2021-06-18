module PixelCoordinates

using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge

import Main.DocGenerator: DocSource, DocCreationEnvironment, DocContext,
        Document, substitute_marker_in_markdown, create_doc_icon, append_md

"""
Use a `CV_Math2DCanvas`, an axis grid painter and  ad-hoc painting with
Cairo to show/simulate a zoomed/enlarged `CV_Std2DCanvas` pixel canvas .
"""
function visualize_pixelcanvas(layout)
    res = 70
    can = CV_Math2DCanvas(0.0 + 0.0im + 1.0*(-1.0 + 1.0im)/res,
                          6.0 - 6.0im + 1.0*( 1.0 - 1.0im)/res, res)
    can_l = cv_add_canvas!(layout, can, (0,0), (0,0))
    grid_painter = CV_2DAxisGridPainter(0:6, -6:0)
    grid_style = cv_color(0.7, 0.7, 0.7) → cv_op_source → cv_linewidth(1)
    cv_create_context(can) do con
        set_operator(con.ctx, Cairo.OPERATOR_SOURCE)
        
        set_source_rgb(con.ctx, 0, 0.7, 0)
        rectangle(con.ctx, 1, -5,  4,  2)
        fill(con.ctx)

        set_source_rgb(con.ctx, 0.7, 0, 0)
        rectangle(con.ctx, 2, -1,  1,  1)
        fill(con.ctx)

        cv_paint(con, grid_style ↦ grid_painter)
    end
    return can, can_l
end

"""
show axis for "pixel-coordinate" system.
"""
function create_axis(layout, can_l)
    arr = Vector{CV_2DLayoutPosition}()

    label_style = cv_black → cv_fontface("sans-serif") → cv_fontsize(15)
    app = CV_TickLabelAppearance(; label_style, tick_length=10)

    ticks = tuple(map(f -> CV_TickLabel(f, string(Int(-f))), 0.0:-1.0:-6.0)...)
    push!(arr, cv_ticks_labels(layout, can_l, cv_west, (CV_Ruler(ticks, app),)))
    push!(arr, cv_ticks_labels(layout, can_l, cv_east, (CV_Ruler(ticks, app),)))

    ticks = cv_format_ticks("%.0f", 0.0:1.0:6.0...)
    push!(arr, cv_ticks_labels(layout, can_l, cv_north, (CV_Ruler(ticks, app),)))
    push!(arr, cv_ticks_labels(layout, can_l, cv_south, (CV_Ruler(ticks, app),)))

    return arr
end

"""
# [![./PixelCoordinates_docicon.png]({image_from_canvas: get_doc_icon()}) Pixel Coordinates](./PixelCoordinates.md)

## Axes directions and integer coordinates

For the layout process and for low level painting operations (typically using
Cairo) pixel coordinates are used. Let's have a look at the pixel
coordinate system.

![./PixelCoordinates01.png]({image_from_canvas: explain_pixel_coordinates()})

The horizontal axis points from west to east and the vertical axis
points from north to south. Integer coordinates, e.g. `(2,0)`, are located
at the zero-width "gap" between pixels.

In the figure above, the red pixel is described by the rectangle
with the two corners `(2,0)` and `(3,1)`.

## "left", "right", "top" and "bottom"

So far the words "left", "right", "top" and "bottom" were avoided. Because
a `CV_Rectangle` is defined by the "top left" and "bottom right" corner, we
have to define them.

In the horizontal direction we say "x1 is left of x2" (or "x2 is right of x1")
if `x1 < x2`.

In the vertical direction we say "y1 is below y2" (or "y2 is above y1")
if `y1 < y2`.

With this definition in mind (together with the north to south direction
of the vertical axis) to "top left" corner of the red pixel is `(2,1)` and
the "bottom right" corner of the red pixel is `(3,0)`.

## Examples with `CV_Rectangle`

There more ways to describe a rectangle. The constructor for `CV_Rectangle`
and `cv_rect_blwh` which have the form [with `{T<:Real}`]

```julia
    CV_Rectangle(top::T, left::T, bottom::T, right::T)
    cv_rect_blwh(::Type{T}, bottom, left, width, height)
```

So the red and green rectangles in the example above can be constructed with

```julia
rect_red1 = CV_Rectangle(1, 2, 0, 3)
rect_red2 = cv_rect_blwh(Int, 0, 2, 1, 1)

rect_green1 = CV_Rectangle(5, 1, 3, 5)
rect_green2 = cv_rect_blwh(Int, 3, 1, 4, 2)
```
"""
function explain_pixel_coordinates()
    layout = CV_2DLayout()


    can, can_l = visualize_pixelcanvas(layout)
    all_axis = create_axis(layout, can_l)

    cv_add_padding!(layout, 15)
    can_layout = cv_canvas_for_layout(layout)
    cv_create_context(can_layout) do con
        can_l(con)
        for axis in all_axis
            axis(con)
        end
    end

    return can_layout
end

function get_doc_icon()
    src_canvas = explain_pixel_coordinates()
    icon = create_doc_icon(src_canvas, cv_rect_blwh(Int32, 0, 80, 200, 200))
    return icon
end

function create_document(doc_env::DocCreationEnvironment)
    doc_source = DocSource("PixelCoordinates", @__MODULE__)
    context = DocContext(doc_env, doc_source)
    
    md = Markdown.MD()
    for part in (explain_pixel_coordinates, )
        part_md = Base.Docs.doc(part)
        substitute_marker_in_markdown(context, part_md)

        append_md(md, part_md)
    end

    doc = Document(doc_source, md)
    return doc
end

end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
