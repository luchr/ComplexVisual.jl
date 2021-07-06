module Style
using Printf
using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge

import Main.DocGenerator: DocSource, DocCreationEnvironment, DocContext,
        Document, substitute_marker_in_markdown, create_doc_icon, append_md

"""
# [![./Style_docion.png]({image_from_canvas: get_doc_icon()}) Style](./Style.md)

Styles (i.e. subtypes of `CV_ContextStyle`) are used to govern the appearance
of painting and drawing actions. They are used to "bundle" typical
(Cairo-context) changes in order to make them reusable and easily combinable
(with `→:Tuple{T, S} where {T<:CV_ContextStyle, S<:CV_ContextStyle}`).

## Quick links

* `cv_color` (`cv_black`  `cv_white`)
* `cv_linewidth`
* `cv_antialias` (`cv_antialias_best`  `cv_antialias_none`)
* `cv_opmode` (`cv_op_source`  `cv_op_over`)
* `cv_fillstyle` (`cv_fill_winding`  `cv_fill_even_odd`)
* `cv_fontface`  `cv_fontsize`
* `CV_CombiContextStyle`   `→:Tuple{T, S} where {T<:CV_ContextStyle, S<:CV_ContextStyle}`
* `cv_create_context:Tuple{Function, CV_Canvas, Union{Nothing, CV_ContextStyle}}`

## How styles work

Before the painting and/or drawing operation(s) the function `cv_prepare` for
subtypes of `CV_ContextStyle` is called:

```
cv_prepare(context::C, style::S)
    context     C <: CV_Context          (often C <: CV_CanvasContext)
    style       S <: CV_ContextStyle     (often S <: CV_CanvasContextStyle)
```

Several styles can be combined
(with `→:Tuple{T, S} where {T<:CV_ContextStyle, S<:CV_ContextStyle}`) to
a single style:

```
new_style = cv_black → cv_linewidth(3) → cv_antialias_best
```

Styles can be attached to painters with `↦:Tuple{CV_ContextStyle, CV_Painter}`:

```
cv_color(0.7, 0.4, 0.4) ↦ CV_FillPainter()
```

Use parenthesis to combine more styles and attach them to a painter
(parens are needed because arrows are right-associative):

```
( cv_black → cv_linewidth(2) )  ↦ CV_LinePainter(...)
```

## `doc: CV_ContextStyle`

## `doc: CV_CanvasContextStyle`

"""
style_intro() = nothing

"""
## `doc: cv_create_context:Tuple{Function, CV_Canvas, Union{Nothing, CV_ContextStyle}}`
"""
help_create_context() = nothing

"""
## `doc: CV_CombiContextStyle`

## `doc: →:Tuple{T, S} where {T<:CV_ContextStyle, S<:CV_ContextStyle}`
"""
help_combi_style() = nothing

"""
## `doc: cv_color`

## `doc: cv_black`

## `doc: cv_white`
"""
help_color() = nothing

"""
## `doc: cv_linewidth`
"""
help_linewidth() = nothing

"""
## `doc: cv_antialias`

## `doc: cv_antialias_best`

## `doc: cv_antialias_none`
"""
help_antialias() = nothing

"""
## `doc: cv_operatormode`

## `doc: cv_opmode`

## `doc: cv_op_source`

## `doc: cv_op_over`
"""
help_operator() = nothing

"""
## `doc: cv_fillstyle`

## `doc: cv_fill_winding`

## `doc: cv_fill_even_odd`
"""
help_fillstyle() = nothing

"""
## `doc: cv_fontface`

## `doc: cv_fontsize`
"""
help_font() = nothing

"""
## `doc: CV_MathCoorStyle`
"""
help_coor_style() = nothing

function get_doc_icon()
    layout = CV_2DLayout()

    math_can = CV_Math2DCanvas(0.0 + 1.0im, 1.0 + 0.0im, 70)

    bg_painter = cv_white ↦ CV_FillPainter()
    line_painters = Vector{CV_StyledPainter}()
    for x in -0.5:0.2:0.9
        line_segs = [ [x+0.0im, x+0.5+1.0im ] ]
        style = cv_color(0.3, 0.3, min(0.2+0.5+x, 1.0)) → cv_linewidth(round( 5*(x+1.0) ))
        push!(line_painters, style ↦ CV_LinePainter(line_segs))
    end

    cv_create_context(math_can) do canvas_context
        cv_paint(canvas_context, bg_painter)
        for lp in line_painters
            cv_paint(canvas_context, lp)
        end
    end

    can_l = cv_add_canvas!(layout, math_can, cv_anchor(math_can, :center), (0, 0))

    stext = cv_text("Style", cv_black → cv_fontface("serif") → cv_fontsize(25))
    ptext = cv_add_canvas!(layout, stext, cv_anchor(stext, :center), (0, 0))

    can_layout = cv_canvas_for_layout(layout)
    cv_create_context(can_layout) do con_layout
        can_l(con_layout)
        ptext(con_layout)
    end

    icon = create_doc_icon(can_layout)
    return icon
end

function create_document(doc_env::DocCreationEnvironment)
    doc_source = DocSource("Style", @__MODULE__)
    context = DocContext(doc_env, doc_source)

    md = Markdown.MD()
    for part in (style_intro, help_create_context, help_combi_style,
            help_color, help_linewidth, help_antialias, help_operator,
            help_fillstyle, help_font, help_coor_style)
        part_md = Base.Docs.doc(part)
        substitute_marker_in_markdown(context, part_md)

        append_md(md, part_md)
    end

    doc = Document(doc_source, md)
    return doc
end

end
# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
