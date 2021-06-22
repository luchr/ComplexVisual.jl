module Painter
using Printf
using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge

import Main.DocGenerator: DocSource, DocCreationEnvironment, DocContext,
        Document, substitute_marker_in_markdown, create_doc_icon, append_md

"""
# [![./Painter_docicon.png]({image_from_canvas: get_doc_icon()}) Painter](./Painter.md)

Painters have the ability to "draw"/"paint" something inside objects
with math coordinate systems (e.g. `CV_Math2DCanvas`).

## Quick links

|  "area" painters     |    curve  painters    |      other painters   |
|:---------------------|:----------------------|:----------------------|
| ![./Painter_fillpainter_icon.png]({image_from_canvas: create_icon(example_fill_painter())}) `CV_FillPainter`             | ![./Painter_linepainter_icon.png]({image_from_canvas: create_icon(example_line_painter())}) `CV_LinePainter`    | ![./Painter_markpainter_icon.png]({image_from_canvas: create_icon(example_mark_painter())}) `CV_ValueMarkPainter` |
| ![./Painter_portraitpainter_icon.png]({image_from_canvas: create_icon(example_portrait_painter())}) `CV_PortraitPainter` | ![./Painter_dirpainter_icon.png]({image_from_canvas: create_icon(example_dir_painter())}) `CV_DirectionPainter` | ![./Painter_gridpainter_icon.png]({image_from_canvas: create_icon(example_grid_painter())}) `CV_GridPainter`      |

`CV_CombiPainter`    `CV_StyledPainter`

"""
painter_intro() = nothing

"""
## `doc: CV_FillPainter`

## Example for `CV_FillPainter`

![./Painter_fillpainter.png]({image_from_canvas: example_fill_painter()})

```julia
{func: example_fill_painter}
```
"""
help_fill_painter() = nothing

function example_fill_painter()
    math_canvas = CV_Math2DCanvas(0.0 + 1.0im, 1.0 + 0.0im, 220)

    fill_painter = CV_FillPainter()
    styled_painter = cv_color(0.7, 0.4, 0.4) ↦ fill_painter
    
    cv_create_context(math_canvas) do canvas_context
        cv_paint(canvas_context, styled_painter)
    end

    return math_canvas
end

"""
## `doc: CV_ValueMarkPainter`

## Example for `CV_ValueMarkPainter`

![./Painter_markpainter.png]({image_from_canvas: example_mark_painter()})

```julia
{func: example_mark_painter}
```
"""
help_mark_painter() = nothing

function example_mark_painter()
    math_canvas = CV_Math2DCanvas(0.0 + 1.0im, 1.0 + 0.0im, 220)

    x_pos, y_pos = CV_TranslateByOffset(Float64), CV_TranslateByOffset(Float64)
    x_pos.value, y_pos.value = 0.7, 0.3

    bg_fill = cv_white ↦ CV_FillPainter()  # for background
    grid_style = cv_color(0.8, 0.8, 0.8) → cv_linewidth(1)
    grid = grid_style ↦ CV_GridPainter(0.0:0.1:1.0, 0.0:0.1:1.0)
    horiz_mark = CV_ValueMarkPainter(x_pos, 0.5, 0.1, true)
    vert_mark = CV_ValueMarkPainter(y_pos, 0.2, 0.1, false)

    h_painter = (cv_color(1,0,0) → cv_linewidth(2)) ↦ horiz_mark
    v_painter = (cv_color(0,1,0) → cv_linewidth(2)) ↦ vert_mark

    cv_create_context(math_canvas) do canvas_context
        cv_paint(canvas_context, bg_fill)
        cv_paint(canvas_context, grid)
        cv_paint(canvas_context, h_painter)
        cv_paint(canvas_context, v_painter)
    end

    return math_canvas
end

"""
## `doc: CV_GridPainter`

## Example for `CV_GridPainter`

![./Painter_gridpainter.png]({image_from_canvas: example_grid_painter()})

```julia
{func: example_grid_painter}
```
"""
help_grid_painter() = nothing

function example_grid_painter()
    math_canvas = CV_Math2DCanvas(0.0 + 1.0im, 1.0 + 0.0im, 220)

    bg_fill = cv_white ↦ CV_FillPainter()  # for background

    style1 = cv_color(0.7, 0.3, 0.3) → cv_linewidth(2)
    grid1 = style1 ↦ CV_GridPainter(0.0:0.2:1.0, 0.0:0.2:1.0)

    style2 = cv_color(0.3, 0.7, 0.3) → cv_linewidth(1)
    grid2 = style2 ↦ CV_GridPainter(0.1:0.2:0.9, 0.1:0.2:0.9)

    cv_create_context(math_canvas) do canvas_context
        cv_paint(canvas_context, bg_fill)
        cv_paint(canvas_context, grid2)
        cv_paint(canvas_context, grid1)
    end

    return math_canvas
end

"""
## `doc: CV_LinePainter`

## Example for `CV_LinePainter`

![./Painter_linepainter.png]({image_from_canvas: example_line_painter()})

```julia
{func: example_line_painter}
```
"""
help_line_painter() = nothing

function example_line_painter()
    math_canvas = CV_Math2DCanvas(-1.0 + 1.0im, 1.0 + -1.0im, 110)
    bg_fill = cv_white ↦ CV_FillPainter()  # for background

    grid_style = cv_color(0.7, 0.7, 0.7) → cv_linewidth(1)
    grid = grid_style ↦ CV_GridPainter(-1.0:0.2:1.0, -1.0:0.2:1.0)

    segment = [0.2im + exp(ϕ*2im)*ϕ/7 for ϕ in LinRange(0, 2*π, 200)]
    style = cv_color(0, 0, 1) → cv_linewidth(2)

    seg_painter = style ↦ CV_LinePainter([segment])

    cv_create_context(math_canvas) do canvas_context
        cv_paint(canvas_context, bg_fill)
        cv_paint(canvas_context, grid)
        cv_paint(canvas_context, seg_painter)
    end

    return math_canvas
end

"""
## `doc: CV_DirectionPainter`

## Example for `CV_DirectionPainter`

![./Painter_dirpainter.png]({image_from_canvas: example_dir_painter()})

```julia
{func: example_dir_painter}
```
"""
help_dir_painter() = nothing

function example_dir_painter()
    math_canvas = CV_Math2DCanvas(-1.0 + 1.0im, 1.0 + -1.0im, 110)
    bg_fill = cv_white ↦ CV_FillPainter()  # for background

    grid_style = cv_color(0.7, 0.7, 0.7) → cv_linewidth(1)
    grid = grid_style ↦ CV_GridPainter(-1.0:0.2:1.0, -1.0:0.2:1.0)

    segment = [0.2im + exp(ϕ*2im)*ϕ/7 for ϕ in LinRange(0, 2*π, 200)]
    style = cv_color(0.8, 0.8, 1) → cv_linewidth(1)  # light blue for curve
    seg_painter = style ↦ CV_LinePainter([segment])

    dir_style = cv_color(0.9, 0, 0)
    dir_painter = dir_style ↦ CV_DirectionPainter(identity,
        [segment]; every_len=0.5, arrow=0.1*exp(1im*π*8/9))

    cv_create_context(math_canvas) do canvas_context
        cv_paint(canvas_context, bg_fill)
        cv_paint(canvas_context, grid)
        cv_paint(canvas_context, seg_painter)
        cv_paint(canvas_context, dir_painter)
    end

    return math_canvas
end

"""
## `doc: CV_PortraitPainter`

## Example for `CV_PortraitPainter`

![./Painter_portraitpainter.png]({image_from_canvas: example_portrait_painter()})

```julia
{func: example_portrait_painter}
```
"""
help_portrait_painter() = nothing

function example_portrait_painter()
    math_canvas = CV_Math2DCanvas(0.0 + 1.0im, 1.0 + 0.0im, 220)

    trafo = z -> (z - 0.6 - 0.2im)^2 + 0.15*exp(z)
    painter = CV_PortraitPainter(trafo)

    cv_create_context(math_canvas) do canvas_context
        cv_paint(canvas_context, painter)
    end

    return math_canvas
end

"""
## `doc: CV_CombiPainter`

## `doc: →:Tuple{T, S} where {T<:CV_Painter, S<:CV_Painter}`
"""
help_combi_painter() = nothing

"""
## `doc: CV_StyledPainter`

## `doc: ↦:Tuple{CV_ContextStyle, CV_Painter}`
"""
help_styled_painter() = nothing

create_icon(can) = create_doc_icon(can, cv_rect_blwh(Int32, 50, 70, 70, 70))

function get_doc_icon()
    math_canvas = CV_Math2DCanvas(0.0 + 1.0im, 1.0 + 0.0im, 220)

    trafo = z -> (z - 0.6 - 0.2im)^2 + 0.15*exp(z)
    ppainter = CV_PortraitPainter(trafo)

    arc_base = cv_arc_lines(-π, π/2, (0.4,))
    arc = [arc_base[1] .+ 0.4 .+ 0.6im]

    arc_style = cv_white → cv_linewidth(4)
    arc_painter = arc_style ↦ CV_LinePainter(arc)
    dir_painter = arc_style ↦ CV_DirectionPainter(identity, arc;
        every_len=0.5, arrow=0.15*exp(1im*π*8/9))

    cv_create_context(math_canvas) do canvas_context
        cv_paint(canvas_context, ppainter)
        cv_paint(canvas_context, arc_painter)
        cv_paint(canvas_context, dir_painter)
    end

    icon = create_doc_icon(math_canvas, cv_rect_blwh(Int32, 10, 10, 200, 200))
    return icon
end

function create_document(doc_env::DocCreationEnvironment)
    doc_source = DocSource("Painter", @__MODULE__)
    context = DocContext(doc_env, doc_source)

    md = Markdown.MD()
    for part in (painter_intro, help_fill_painter, help_mark_painter,
            help_grid_painter, help_line_painter, help_dir_painter,
            help_portrait_painter, help_combi_painter, help_styled_painter)
        part_md = Base.Docs.doc(part)
        substitute_marker_in_markdown(context, part_md)

        append_md(md, part_md)
    end

    doc = Document(doc_source, md)
    return doc
end

end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
