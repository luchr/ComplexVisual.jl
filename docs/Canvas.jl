module Canvas
using Printf
using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge

import Main.DocGenerator: DocSource, DocCreationEnvironment, DocContext,
        Document, substitute_marker_in_markdown, create_doc_icon, append_md

"""
# [![./Canvas_docicon.png]({image_from_canvas: get_doc_icon()}) Canvas](./Canvas.md)

Canvases (i.e. subtypes of `CV_Canvas`) are thin wrappers for Cairo canvases.

## `doc: CV_Canvas`

## `doc: CV_2DCanvas`

## `doc: CV_Std2DCanvas`

## `doc: CV_Math2DCanvas`

## `doc: cv_math2pixel:Tuple{CV_Math2DCanvas, Float64, Float64}`

## `doc: cv_pixel2math:Tuple{CV_Math2DCanvas, Integer, Integer}`
"""
canvas_intro() = nothing

function get_doc_icon()
    layout = CV_2DLayout()

    can = cv_filled_canvas(30, 40, cv_white)
    can_l = cv_add_canvas!(layout, can, cv_anchor(can, :center), (0, 0))

    r_rect = cv_filled_canvas(18, 3, cv_color(1, 0, 0, 0.7))
    r_rect_l = cv_add_canvas!(layout, r_rect,
        cv_anchor(r_rect, :west),
        cv_translate(cv_anchor(can_l, :west), 3, -4))

    b_rect = cv_filled_canvas(12, 18, cv_color(0, 0, 1, 0.7))
    b_rect_l = cv_add_canvas!(layout, b_rect,
        cv_anchor(b_rect, :center),
        cv_translate(cv_anchor(can_l, :center), 7, 0))

    bg_fill = (cv_color(0, 0, 0, 0) → cv_op_over) ↦ CV_FillPainter()
    stand_canvas = CV_Math2DCanvas(-1.0 + 1.0im, 1.0 - 0.7im, 10)
    line_segs = [
        [-0.2 + 1.0im, -0.7 - 0.7im],
        [+0.2 + 1.0im, +0.7 - 0.7im],
        [0.0 + 1.0im,  0.0 - 0.7im]]

    lp_style = cv_color(0.51, 0.16, 0) → cv_linewidth(2)
    lp = lp_style ↦ CV_LinePainter(line_segs)

    cv_create_context(stand_canvas) do canvas_context
        cv_paint(canvas_context, bg_fill)
        cv_paint(canvas_context, lp)
    end
    
    stand_canvas_l = cv_add_canvas!(layout, stand_canvas,
        cv_anchor(stand_canvas, :north), cv_anchor(can_l, :south))

    stand_border = cv_border(layout, can_l, 0, 0, 2, 0; style=lp_style)
    shad_border = cv_border(layout, can_l, 2, 2, 0, 0;
        style=cv_color(0.4, 0.4, 0.4))

    cv_ensure_size!(layout, 70, 70)

    can_layout = cv_canvas_for_layout(layout)
    con_layout = cv_create_context(can_layout;
        fill_with=cv_color(0.7, 0.7, 0.7))
    can_l(con_layout)
    stand_canvas_l(con_layout)
    stand_border(con_layout)
    shad_border(con_layout)
    r_rect_l(con_layout)
    b_rect_l(con_layout)
    cv_destroy(con_layout)

    icon = create_doc_icon(can_layout)
    return icon
end

function create_document(doc_env::DocCreationEnvironment)
    doc_source = DocSource("Canvas", @__MODULE__)
    context = DocContext(doc_env, doc_source)

    md = Markdown.MD()
    for part in (canvas_intro, )
        part_md = Base.Docs.doc(part)
        substitute_marker_in_markdown(context, part_md)

        append_md(md, part_md)
    end

    doc = Document(doc_source, md)
    return doc
end

end
# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
