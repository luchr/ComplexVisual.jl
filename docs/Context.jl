module Context
using Printf
using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge

import Main.DocGenerator: DocSource, DocCreationEnvironment, DocContext,
        Document, substitute_marker_in_markdown, create_doc_icon, append_md

"""
# [![./Context_docicon.png]({image_from_canvas: get_doc_icon()}) Context](./Context.md)

Contexts (i.e. subtypes of `CV_Context`) are very thin wrappers for Cairo
contexts. They are used to draw/paint (typically inside canvases).

## `doc: CV_Context`

## `doc: CV_CanvasContext`

## `doc: CV_2DCanvasContext`
"""
context_intro() = nothing

function get_doc_icon()
    layout = CV_2DLayout()
    can = cv_filled_canvas(220, 220, cv_color(0, 0, 0.4))

    can_l = cv_add_canvas!(layout, can, cv_anchor(can, :center), (0, 0))

    stext = cv_text("Context", cv_white → cv_fontface("serif") → cv_fontsize(45))
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
    doc_source = DocSource("Context", @__MODULE__)
    context = DocContext(doc_env, doc_source)

    md = Markdown.MD()
    for part in (context_intro, )
        part_md = Base.Docs.doc(part)
        substitute_marker_in_markdown(context, part_md)

        append_md(md, part_md)
    end

    doc = Document(doc_source, md)
    return doc
end

end
# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
