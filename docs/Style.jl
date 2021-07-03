module Style
using Printf
using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge

import Main.DocGenerator: DocSource, DocCreationEnvironment, DocContext,
        Document, substitute_marker_in_markdown, create_doc_icon, append_md

"""
# Style

Styles are used to govern the appearance of painting and drawing actions.
They are used to "bundle" typical (Cairo-context) changes in order to make
them reusable.

## Quick links

`cv_color`   `cv_linewidth`
`CV_CombiContextStyle`   
`→:Tuple{T, S} where {T<:CV_ContextStyle, S<:CV_ContextStyle}`
`cv_create_context:Tuple{Function, CV_Canvas, Union{Nothing, CV_ContextStyle}}`

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

function create_document(doc_env::DocCreationEnvironment)
    doc_source = DocSource("Style", @__MODULE__)
    context = DocContext(doc_env, doc_source)

    md = Markdown.MD()
    for part in (style_intro, help_create_context, help_combi_style,
            help_color, help_linewidth)
        part_md = Base.Docs.doc(part)
        substitute_marker_in_markdown(context, part_md)

        append_md(md, part_md)
    end

    doc = Document(doc_source, md)
    return doc
end

end
# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
