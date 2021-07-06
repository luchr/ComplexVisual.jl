"""
# DocGenerator

This is an "experimental" generator for the Markdown documentation.

"experimental" because some (a lot) of undocumented Julia methods are used.

## Why a generator?

Because I want to support (or I want to have)

* (automatically generated) cross references (without an additional syntax)
* inclusion of functions doc-string into the documentation (with an easy
  syntax)
* generation of an index

## How?

There are 3 main ingredients

* where something is documented (in the end), that's a `DocRef`
* what is documented, that's a `ObjSpecification`
* the relationship of "where-is-what" (i.e. what objects are documented where)
  thats `refs` inside `DocCreationEnvironment`

"""
module DocGenerator

using Base.Docs
using Printf
using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge()

"""
all "registerted" doc-Modules producing some documentation file(s).

Registration at the bottom of this file.
"""
const doc_modules = Vector{Module}()

"""
Source of Documentation.
"""
struct DocSource
    filename   :: AbstractString  # without path and without suffix
    doc_module :: Module          # Module which created the documentation
end


"""
Reference to a point/anchor in the (generated) documentation.
"""
struct DocRef
    source   :: DocSource
    anchor   :: AbstractString
end

"""
Specifies an object (which will be documented). `sig` is a signature
in order to identify a special method if `obj_sym` is the symbol for
a function.
"""
struct ObjSpecification
    mod      :: Module
    obj_sym  :: Symbol
    sig      :: Type
end

"""
Regex for how objects can be specified: `[Module.]Name[:Signature]`.
"""
const re_parse_obj_specification = r"""
    ^\s*                      # maybe space(s)
    (                         # group 1: optional: the module
      ([^\s]+)                # group 2: module name
      \.                      # followed by dot
    )? 
    ([^\s]+)                  # group 3: object/symbol name
    (                         # group 4: optional: the signature
      :\s*                    # colon (with maybe space(s))
      (                       # group 5: signature
        Union(.*)  |          # Starting with Union or
        Tuple(.*)             # Starting with Tuple
      )
    )?
    \s*$                      # maybe space(s) to the end
    """x

function parse_obj_specification(str::AbstractString;
        default_module::Module=ComplexVisual,
        default_sig::Type=Union{})
    match_obj = match(re_parse_obj_specification, str)
    if match_obj === nothing
        error("Cannot parse object specification: " * str)
    end
    return ObjSpecification(
        match_obj[2] === nothing ?
            default_module :
            getproperty(@__MODULE__, Symbol(match_obj[2]))::Module,
        Symbol(match_obj[3]),
        match_obj[5] === nothing ?
            default_sig :
            eval(Meta.parse(match_obj[5]))::Type)
end

"""
saves data for generating documents.

Gathers all the `DocRef` for object specifications.
"""
struct DocCreationEnvironment
    refs :: Dict{Module, Dict{Symbol, Dict{Type, Vector{DocRef}}}}
end
DocCreationEnvironment() = DocCreationEnvironment(Dict{Module,
    Dict{Symbol, Dict{Type, Vector{DocRef}}}}())

"""
context while generating the documentation.
"""
struct DocContext
    env      :: DocCreationEnvironment
    source   :: DocSource               # current source
end

"""
A produced (Markdown) document.
"""
struct Document
    source     :: DocSource
    markdown   :: Markdown.MD
end

# Helper functions {{{

eval_in_context(context::DocContext) = context.source.doc_module.eval

"""
```
extract_lines(filename, start_re, stop_re; include_start_stop=true)

filename             AbstractString
start_re             Regexp
stop_re              Regexp
include_start_stop   Bool
```

extract some lines of a file.
"""
function extract_lines(filename::AbstractString, start_re::Regex, stop_re::Regex;
        include_start_stop=true) # {{{
    inside_flag = false
    found_lines = Vector{AbstractString}()
    open(filename, "r") do fio
        while !eof(fio)
            line = readline(fio)

            if match(start_re, line) !== nothing
                if include_start_stop
                    push!(found_lines, line)
                end
                inside_flag = true
            elseif inside_flag && match(stop_re, line) !== nothing
                if include_start_stop
                    push!(found_lines, line)
                end
                inside_flag = false
            elseif inside_flag
                push!(found_lines, line)
            end
        end
    end
    return found_lines
end # }}}


"""
```
extract_lines(doc_context, start_re, stop_re; include_start_stop=true)

doc_context          DocContext
start_re             Regexp
stop_re              Regexp
include_start_stop   Bool
```

extract some lines of a file.
"""

function extract_lines(doc_context::DocContext, start_re::Regex, stop_re::Regex;
        include_start_stop=true)
    filename = doc_context.source.filename * ".jl"
    return extract_lines(filename, start_re, stop_re; include_start_stop)
end

"""
append to Markdown other Markdown-elements (and strip off `MD`s).
"""
function append_md(where_to_append, what_to_append)
    while what_to_append isa Markdown.MD  &&
            length(what_to_append.content) == 1
        what_to_append = what_to_append.content[1]
    end
    if what_to_append isa Markdown.MD
        push!(where_to_append.content, what_to_append.content...)
    else
        push!(where_to_append.content, what_to_append)
    end
    return nothing
end

# }}}

# Methods for refs in DocCreationEnvironment {{{
"""
returns `Vector{DocRef}` for the given object specification or `nothing`
if no `DocRef` can be found.

if `sig === UnionAll` then all the `DocRef` for every saved signature
are put in the result vector.
"""
function get_doc_refs(env::DocCreationEnvironment,
        mod::Module, sym::Symbol, sig::Type)  # {{{
    refs = env.refs
    sym_dict = get(refs, mod, nothing)
    if sym_dict === nothing
        return nothing
    end
    sig_dict = get(sym_dict, sym, nothing)
    if sig_dict === nothing
        return nothing
    end
    if sig === UnionAll
        docref_vec = Vector{DocRef}()
        append!(docref_vec, values(sig_dict)...)
        return docref_vec
    end
    docref_vec = get(sig_dict, sig, nothing)
    return docref_vec
end  # }}}

function get_doc_refs(env::DocCreationEnvironment, obj::ObjSpecification)
    return get_doc_refs(env, obj.mod, obj.obj_sym, obj.sig)
end

"""
appends the `doc_ref` to the refs of the specified object specification.
"""
function append_doc_ref(env::DocCreationEnvironment,
        mod::Module, sym::Symbol, sig::Type, doc_ref::DocRef)   # {{{
    refs = env.refs
    if !haskey(refs, mod)
        refs[mod] = Dict{Symbol, Dict{Type, Vector{DocRef} } }()
    end
    sym_dict = refs[mod]
    if !haskey(sym_dict, sym)
        sym_dict[sym] = Dict{Type, Vector{DocRef}}()
    end
    sig_dict = sym_dict[sym]
    if !haskey(sig_dict, sig)
        sig_dict[sig] = Vector{DocRef}()
    end
    push!(sig_dict[sig], doc_ref)
    return nothing
end # }}}
function append_doc_ref(env::DocCreationEnvironment,
        obj::ObjSpecification, doc_ref::DocRef)
    return append_doc_ref(env, obj.mod, obj.obj_sym, obj.sig, doc_ref)
end
# }}}

# Anchors {{{
"""
test if a `DocRef` is already saved in the `refs` in the DocCreationEnvironment.
"""
function has_docref(context::DocContext, search_ref::DocRef) # {{{
    refs = context.env.refs
    for doc_module in keys(refs)
        for sym in keys(refs[doc_module])
            for docref_vec in values(refs[doc_module][sym])
                if findfirst(
                    doc_ref -> doc_ref == search_ref, docref_vec) !== nothing
                    return true
                end
            end
        end
    end
    return false
end # }}}

"""
try to guess the anchor name which github's flavored markdown will use if
this content is used (again) in this context (as anchor).

Takes into account if there were already anchors for the same content and
use the "-1", "-2", ... suffixes used.
"""
function get_anchor_name(context::DocContext,
        content::AbstractString, prefix::AbstractString="user-content-") # {{{
    name = lowercase(content)                #  ⎫ only a rough approximation 
    name = replace(name, r"[^\w\- ]" => "")  #  ⎬ what github/gitlab are
    name = replace(name, " " => "-")         #  ⎭ doing

    refs = context.env.refs
    result = prefix * name
    if result != ""
        base, next_index = result, 1
        while true
            try_ref = DocRef(context.source, result)
            !has_docref(context, try_ref) && break
            result = base * "-" * string(next_index)
            next_index += 1
        end
    end
    return result
end # }}}

doc_ref_to_linktarget(ref::DocRef) = @sprintf(
    "./%s.md#%s", ref.source.filename, ref.anchor)

doc_ref_to_markdownlink(ref::DocRef, name) =
    Markdown.Link(Markdown.Code(String(name)), doc_ref_to_linktarget(ref))
# }}}

# Functions to extract Markdown subparts {{{

const MD_has_content = Union{Markdown.Paragraph, Markdown.BlockQuote,
        Markdown.Admonition, Markdown.MD}
const MD_has_items = Union{Markdown.List}
const MD_has_rows = Union{Markdown.Table}
const MD_has_subparts = Union{MD_has_content, MD_has_items, MD_has_rows}

get_subparts(md) = []
get_subparts(md::MD_has_content) = md.content
get_subparts(md::MD_has_items) = md.items
get_subparts(md::MD_has_rows) = md.rows
# }}}

# Subst `{func: name_of_function}`  {{{
const re_substitute_code_func = r"^\s*\{func:\s*([^\s}]+)\s*\}"

"""
look for `Markdown.Code` with content "{func: name_of_function}"
and replace the content with the acutal code of the function.
"""
substitute_code_func(context::DocContext, md) = nothing
function substitute_code_func(context::DocContext, v::Vector)
    for part in v
        substitute_code_func(context, part)
    end
    return nothing
end
substitute_code_func(context::DocContext, md::MD_has_subparts) = 
    substitute_code_func(context, get_subparts(md))
function substitute_code_func(context::DocContext, md::Markdown.Code)
    match_obj = match(re_substitute_code_func, md.code)
    if match_obj !== nothing
        start = Regex("^function "*match_obj.captures[1])
        stop = r"^end"
        func_lines = extract_lines(context, start, stop)
        md.code = join(func_lines, "\n")
    end
    return nothing
end
# }}}

# Subst `{image_from_canvas: expression}` {{{
const re_substitute_canvas_image = r"^\s*\{image_from_canvas:\s*([^\s}]+)\s*\}"

"""
look for `Markdown.Image` with `url` of the form 

```
  {image_from_canvas: expression}
```

Then

* execute expression (expect a canvas)
* create a png (with the content of the canvas) and save it unter the
  alt-tag-name
* replace the url with the name of the created png.
"""
substitute_canvas_image(context::DocContext, md) = nothing
function substitute_canvas_image(context::DocContext, v::Vector)
    for part in v
        substitute_canvas_image(context, part)
    end
    return nothing
end
substitute_canvas_image(context::DocContext, md::MD_has_subparts) = 
    substitute_canvas_image(context, get_subparts(md))
substitute_canvas_image(context::DocContext, md::Union{
    Markdown.Header, Markdown.Link}) =
    substitute_canvas_image(context, md.text)

function substitute_canvas_image(context::DocContext, md::Markdown.Image)
    match_obj = match(re_substitute_canvas_image, md.url)
    if match_obj !== nothing
        to_eval = Meta.parse(match_obj.captures[1])
        img_file = md.alt
        println("  producing image ", img_file, " for ", to_eval)
        canvas = eval_in_context(context)(to_eval) :: CV_2DCanvas
        write_to_png(canvas.surface, img_file)
        md.url = img_file
    end
    return nothing
end
# }}}

# Subst Paragraphs of the form `[inline](<name>)` {{{
"""
look for Paragraphs which have exactly one link of the form
`[inline](<object specification>)`.

Then replace the whole paragraph with the Markdown documentation of the
specified object.
"""
get_inline_replacement_for(context::DocContext, md) = nothing
function get_inline_replacement_for(context::DocContext,
        md::Markdown.Paragraph)
    if length(md.content) == 1 && md.content[1] isa Markdown.Link
        link = md.content[1]
        if link.text isa Vector && length(link.text) == 1 &&
                link.text[1] == "inline"
            obj_spec = parse_obj_specification(link.url; default_sig=UnionAll)

            if obj_spec.sig !== UnionAll
                # special signature is given
                binding = Base.Docs.Binding(obj_spec.mod, obj_spec.obj_sym)
                doc_md = doc(binding, obj_spec.sig)
            else
                # all docs that can be found for this symbol
                doc_md = doc(getproperty(obj_spec.mod, obj_spec.obj_sym))
            end
            if doc_md === nothing
                error("Cannot find doc for " * link.url)
            end
            return doc_md.content
        end
    end
    return nothing
end
substitute_inline_markdown(context::DocContext, md) = nothing
function substitute_inline_markdown(context::DocContext, v::Vector)
    index = 1
    while index <= length(v)
        part = v[index]
        replacement = get_inline_replacement_for(context, part)
        if replacement !== nothing
            deleteat!(v, index)
            for elem in reverse(replacement)
                insert!(v, index, elem)
            end
            continue
        end
        substitute_inline_markdown(context, part)
        index += 1
    end
    return nothing
end
substitute_inline_markdown(context::DocContext, md::MD_has_subparts) =
    substitute_inline_markdown(context, get_subparts(md))
# }}}

# Extend Headers of the form `doc: <obj specification>` with object documentation {{{
"""
rewrite header content (by appending the code-points in "U+..."-notation)
if needed. This is needed if no anchor-name could be deduced.

An example where this is needed if the content of the headline is `"⇒"`.
"""
function rewrite_header(context::DocContext, content)
    result = content
    if get_anchor_name(context, result, "") == ""
        # Need to rewrite it (a litte bit)
        result *= " ("
        for (index, character) in enumerate(content)
            if index != 1
                result *= ' '
            end
            result *= "U+" * uppercase(string(
                codepoint(character), base=16, pad=4))
        end
        result *= ')'
    end
    return result
end


const re_substitute_doc = r"^\s*doc:(.*)$"
substitute_obj_header(context::DocContext, md) = nothing
function substitute_obj_header(context::DocContext, v::Vector)
    index = 1
    while index <= length(v)
        part = v[index]
        if part isa Markdown.Header  &&  part.text isa Vector  && 
                length(part.text) == 1  && part.text[1] isa Markdown.Code
            code_md = part.text[1]
            match_obj = match(re_substitute_doc, code_md.code)
            if match_obj !== nothing
                obj_spec = parse_obj_specification(match_obj[1])
                content = String(obj_spec.obj_sym)

                # rewrite (if there is no nice anchor)
                content_in_header = rewrite_header(context, content)
                code_md.code = content_in_header

                doc_ref = DocRef(context.source,
                    get_anchor_name(context, content_in_header))
                append_doc_ref(context.env, obj_spec, doc_ref)

                sub_md = Markdown.parse("[inline](" * match_obj[1] * ")")
                substitute_marker_in_markdown(context, sub_md)

                for elem in reverse(sub_md.content)
                    insert!(v, index+1, elem)
                end
            end
        end
        substitute_obj_header(context, part)
        index += 1
    end
    return nothing
end
substitute_obj_header(context::DocContext, md::MD_has_subparts) =
    substitute_obj_header(context, get_subparts(md))
# }}}

# Subst Code-Cross-References {{{
substitute_code_ref(context::DocContext, md) = nothing
function substitute_code_ref(context::DocContext, v::Vector)
    index = 1
    while index <= length(v)
        part = v[index]
        if part isa Markdown.Code
            obj_spec = nothing
            try
                obj_spec = parse_obj_specification(part.code; default_sig=UnionAll)
            catch
            end
            if obj_spec !== nothing
                rendered = render_ref(context.env, obj_spec; error_if_not_found=false)
                if rendered !== nothing
                    deleteat!(v, index)
                    for elem in reverse(rendered.content)
                        insert!(v, index, elem)
                    end
                end
            end
        end
        substitute_code_ref(context, part)
        index += 1
    end
end
substitute_code_ref(context::DocContext, md::MD_has_subparts) =
    substitute_code_ref(context, get_subparts(md))
# }}}

"""
replace some "markers" inside markdown with actual code from
the file here. This is done to make sure the code in the documentation
is exactly the same code as the one used in the example functions.
"""
function substitute_marker_in_markdown(context::DocContext, md)
    substitute_code_func(context, md)
    substitute_canvas_image(context, md)
    substitute_inline_markdown(context, md)
    substitute_obj_header(context, md)
    return nothing
end

# Fadeout {{{
"""
```
create_fadeout_surface(w, h, dist=30)

w     Integer           width
h     Integer           height
dist  Integer           distance to boundary where to decrease alpha
```

creates a surface where the alpha component is decreased (to 0) near
the boundary.
"""
function create_fadeout_surface(w::Integer, h::Integer, dist::Integer=30)
    w, h, dist = Int32(w), Int32(h), Int32(dist)
    if 2*dist > w || 2*dist > h
        cv_error("d too large: 2*dist > w  or 2*dist > h")
    end
    canvas = CV_Std2DCanvas(w, h)
    Cairo.flush(canvas.surface)
    data = canvas.surface.data
    for x = 1:dist
        p1 = (dist-x)^2
        data[x    , dist+1:h-dist] .= p1
        data[w-x+1, dist+1:h-dist] .= p1
        for y = 1:dist
            p2 = (dist-y)^2
            data[x, y] = data[x, h-y+1] = 
            data[w-x+1, y] = data[w-x+1, h-y+1] = UInt32(p1 + p2)
        end
    end
    for y = 1:dist
        p2 = (dist-y)^2
        data[dist+1:w-dist, y] .= p2
        data[dist+1:w-dist, h-y+1] .= p2
    end
    data[dist+1:w-dist, dist+1:h-dist] .= 0x0

    # normalize
    data[:] .= round.(UInt32, 
        255*(
            1.0 .- max.(min.(Float64.(data[:])/((dist-3)^2), 1.0), 0.0)
            )) .<< 24
 
    Cairo.mark_dirty(canvas.surface)
    return canvas
end

"""
default fadeout canvas for `create_doc_icon`.
"""
const cv_default_fadeout_canvas = create_fadeout_surface(70, 70, 20)

"""
```
create_doc_icon(src_canvas, src_rect=src_canvas.bounding_box,
                fadeout_canvas=cv_default_fadeout_canvas)

src_canvas      CV_2DCanvas         canvas with the source image
src_rect        CV_Rectangle{Int32} rectangle to use for icon
fadeout_canvas  CV_2DCanvas         canvas used for fadeout effect
```

creates a canvas with an "icon" for the documentation. The size of the
icon is determined by the size of the `fadeout_canvas`. The `src_rect`
is scaled to the icon size.
"""
function create_doc_icon(
        src_canvas::CV_2DCanvas,
        src_rect::CV_Rectangle{Int32}=src_canvas.bounding_box,
        fadeout_canvas::CV_2DCanvas=cv_default_fadeout_canvas)  # {{{

    w, h = fadeout_canvas.pixel_width, fadeout_canvas.pixel_height
    icon = CV_Std2DCanvas(w, h)

    sw, sh = cv_width(src_rect), cv_height(src_rect)
    cv_create_context(icon) do con
        ctx = con.ctx

        set_operator(ctx, Cairo.OPERATOR_SOURCE)
        set_source_rgb(ctx, 1, 1, 1)
        rectangle(ctx, 0, 0, w, h)
        fill_preserve(ctx)

        pat = CairoPattern(src_canvas.surface)
        pattern_set_filter(pat, Cairo.FILTER_BEST)
        pat_mat = CairoMatrix(sw/w, 0, 0, sh/h, src_rect.left, src_rect.bottom)
        set_matrix(pat, pat_mat)
        set_source(ctx, pat)
        set_operator(ctx, Cairo.OPERATOR_OVER)
        fill_preserve(ctx)
        
        set_source(ctx, fadeout_canvas.surface)
        set_operator(ctx, Cairo.OPERATOR_DEST_IN)
        fill(ctx)
    end

    return icon
end # }}}


# }}}

# Write short descritions for arguments of methods {{{

mutable struct StringIO
    buffer     :: String
    indent     :: Vector{AbstractString}
    max_width  :: Int
    cur_width  :: Int
end

function StringIO(max_width::Integer, cur_indent::AbstractString="")
    indent = [cur_indent]
    return StringIO("", indent, Int(max_width), 0)
end

function append_newline(sio::StringIO)
    sio.buffer *= "\n" * sio.indent[end]
    sio.cur_width = textwidth(sio.indent[end])
    return sio
end

function push_indent(sio::StringIO, new_indent::AbstractString)
    push!(sio.indent, new_indent)
    return sio
end

function pop_indent(sio::StringIO)
    if length(sio.indent) > 1
        pop!(sio.indent)
    end
    return sio
end

function append_nc(sio::StringIO, to_append::AbstractString)
    sio.buffer *= to_append
    sio.cur_width += textwidth(to_append)
    return sio
end

function append(sio::StringIO, to_append::AbstractString,
        sep_if_fits=""::AbstractString, sep_for_newline=""::AbstractString)
    inline = sep_if_fits * to_append
    inline_width = textwidth(inline)
    if inline_width + sio.cur_width >= sio.max_width
        append_newline(append_nc(sio, sep_for_newline))
        inline = to_append
        inline_width = textwidth(inline)
    end
    append_nc(sio, inline)
    return sio
end


"""
Highly experimental

I use it to get a first version of a function description for the docstring.

Many undocumented methods from Base are used
"""
function get_arg_description(m::Method; indent="")
    args = Base.arg_decl_parts(m)[2]     # args[1]: function itself

    result = StringIO(79, indent)
    append_newline(append_nc(result, "```"))
    header = indent * args[1][2] * '('
    push_indent(result, repeat(' ', textwidth(header)))
    append(result, header)

    isfirst = true
    for arg in args[2:end]
        append(result, arg[1], isfirst ? "" : ", ", isfirst ? "" : ",")
        isfirst = false
    end

    kwargs = Base.kwarg_decl(m)
    if !isempty(kwargs)
        append_newline(append(result, ";"))
        isfirst = true
        for arg in kwargs
            append(result, String(arg), isfirst ? "" : ", ", isfirst ? "" : ",")
            isfirst = false
        end
    end
    pop_indent(result)
    append_newline(append_newline(append(result, ")")))

    max_arg_width = length(args) > 1 ? 
        maximum(map(arg -> textwidth(arg[1]), args[2:end])) : 4
    max_type_width = length(args) > 1 ?
        maximum(map(arg -> textwidth(arg[2]), args[2:end])) : 4

    arg_fmt = @sprintf("%%-%is", max_arg_width)
    pad_arg = @eval str -> @sprintf($arg_fmt, str)

    type_fmt = @sprintf("%%-%is", max_type_width)
    pad_type = @eval str -> @sprintf($type_fmt, str)

    for arg in args[2:end]
        append_nc(result, Base.invokelatest(pad_arg ,arg[1]))
        append_nc(result, "   ")
        append_nc(result, Base.invokelatest(pad_type, arg[2]))
        append_newline(result)
    end
    append_newline(append_nc(result, "```"))

    return result.buffer
end

function get_arg_description(something)
    result = ""
    for method in methods(something)
        result *= get_arg_description(method)
        result *= "\n\n"
    end
    return result
end

function list_all_sigs(something)
    for m in methods(something)
        println(tuple(m.sig.types[2:end]...))
    end
end
# }}}

# write Markdown files {{{
"""
write Markdown-files for all Documents.
"""
function write_markdown_documentations(documents::Vector{Document})
    for document in documents
        filename = document.source.filename * ".md"
        open(filename, "w") do fio
            write(fio, string(document.markdown))
            write(fio, "\n\n")
        end
    end
end
# }}}

const re_find_cv_start = r"^(cv|CV)_"

function isless_ignore_cv(sym1::Symbol, sym2::Symbol)
    name1 = replace(lowercase(String(sym1)), re_find_cv_start => "")
    name2 = replace(lowercase(String(sym2)), re_find_cv_start => "")
    return isless(name1, name2)
end

function render_ref(doc_env::DocCreationEnvironment,
        obj_spec::ObjSpecification; error_if_not_found::Bool=true) # {{{
    ref_vec = get_doc_refs(doc_env, obj_spec)
    if ref_vec === nothing
        if error_if_not_found
            error("Cannot find ", obj_spec)
        else
            return nothing
        end
    end

    sym_name = String(obj_spec.obj_sym)
    parts = []
    if length(ref_vec) == 1
        push!(parts, doc_ref_to_markdownlink(ref_vec[1], sym_name))
    else
        push!(parts, Markdown.Code(sym_name))
        push!(parts, " (")
        first = true
        for ref in ref_vec
            if first
                first = false
            else
                push!(parts, ", ")
            end
            push!(parts, doc_ref_to_markdownlink(ref, ref.source.filename))
        end
        push!(parts, ")")
    end
    return Markdown.Paragraph(parts)
end # }}}

function create_letter_list(doc_env::DocCreationEnvironment)
    letter_list = Dict{AbstractChar, Markdown.List}()
    refs = doc_env.refs

    sym_vec = Vector{Symbol}()  # all the symbols (that are documented)
    for sym_dict in values(refs)
        push!(sym_vec, keys(sym_dict)...)
    end
    sort!(sym_vec; lt=isless_ignore_cv)

    for entry in sym_vec
        entry_name = String(entry)
        fchar = first(replace(uppercase(entry_name), re_find_cv_start => ""))
        if !isletter(fchar)
            fchar = '…'
        end
        if !haskey(letter_list, fchar)
            letter_list[fchar] = Markdown.List()
        end

        para = Markdown.Paragraph(Vector{Any}([Markdown.Code(entry_name)]))
        push!(letter_list[fchar].items, para)
    end
    return letter_list
end

function create_index(doc_env::DocCreationEnvironment)
    doc_source = DocSource("Index", @__MODULE__)
    context = DocContext(doc_env, doc_source)

    header = Markdown.Header{1}("Index")

    letter_list = create_letter_list(doc_env)

    md = Markdown.MD(header)
    for fchar in sort(collect(keys(letter_list)))
        hdl = "" * fchar
        md = Markdown.MD(md, Markdown.Header{2}(hdl), letter_list[fchar])
    end

    return md
end

function create_overview(doc_env::DocCreationEnvironment,
        docs::Vector{Document})

    header = Markdown.Header{1}("Overview")

    list = Markdown.List()
    for doc in docs
        content = doc.markdown.content
        if length(content) > 0 && content[1] isa Markdown.Header
            para = Markdown.Paragraph(content[1].text)
            push!(list.items, para)
        end
    end

    return Markdown.MD(header, list)
end

function create_readme(doc_env::DocCreationEnvironment,
        docs::Vector{Document})

    doc_source = DocSource("README", @__MODULE__)

    md = Markdown.MD([create_overview(doc_env, docs), create_index(doc_env)])
    return Document(doc_source, md)
end

function create_documents()
    doc_env = DocCreationEnvironment()

    documents = Vector{Document}()
    for mod in doc_modules
        println("generating markdown for ", mod)
        push!(documents, mod.create_document(doc_env))
    end
    println("generating markdown for Readme")
    push!(documents, create_readme(doc_env, documents))

    # Cross-Ref
    println("inserting cross references")
    context = DocContext(doc_env, DocSource("cross-refs", @__MODULE__))
    for doc in documents
        substitute_code_ref(context, doc.markdown)
    end

    write_markdown_documentations(documents)
    return nothing
end


for filename in (
    "./Context.jl",
    "./Style.jl", "./Painter.jl",
    "./PixelCoordinates.jl", "./LayoutTutorial.jl", "./Axis.jl")
    push!(doc_modules, include(filename))
end

# create_documents()

end


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
