module DocGenerator

using Base.Docs
using Printf
using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge()

"""
A (Markdown) document together with all the symbols (types, functions, 
structs, etc.) that are explained inside the document.
"""
struct Document
    basename            :: AbstractString
    markdown            :: Markdown.MD
    anchors_for_symbols :: Dict{Symbol, AbstractString}
end

"""
Context for Markdown substitutions.
"""
struct SubstMDcontext
    filename :: AbstractString
    eval     :: Function
end


# Helper functions {{{


"""
```
extract_lines(filename, start_re, stop_re; include_start_stop=true)

start_re             Regexp
stop_re              Regexp
include_start_stop   Bool
```

extract some lines of a file.
"""
function extract_lines(filename, start_re::Regex, stop_re::Regex;
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

# }}}

# Functions to extract Markdown subparts {{{

const MD_has_content = Union{Markdown.Paragraph, Markdown.BlockQuote,
        Markdown.Admonition, Markdown.MD}
const MD_has_items = Union{Markdown.List}
const MD_has_subparts = Union{MD_has_content, MD_has_items}

get_subparts(md) = []
get_subparts(md::MD_has_content) = md.content
get_subparts(md::MD_has_items) = md.items
# }}}

# Subst `{func: name_of_function}`  {{{
const re_substitute_code_func = r"^\s*\{func:\s*([^\s}]+)\s*\}"

"""
look for `Markdown.Code` with content "{func: name_of_function}"
and replace the content with the acutal code of the function.
"""
substitute_code_func(context::SubstMDcontext, md) = nothing
function substitute_code_func(context::SubstMDcontext, v::Vector)
    for part in v
        substitute_code_func(context, part)
    end
    return nothing
end
substitute_code_func(context::SubstMDcontext, md::MD_has_subparts) = 
    substitute_code_func(context, get_subparts(md))
function substitute_code_func(context::SubstMDcontext, md::Markdown.Code)
    match_obj = match(re_substitute_code_func, md.code)
    if match_obj !== nothing
        start = Regex("^function "*match_obj.captures[1])
        stop = r"^end"
        func_lines = extract_lines(context.filename, start, stop)
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
substitute_canvas_image(context::SubstMDcontext, md) = nothing
function substitute_canvas_image(context::SubstMDcontext, v::Vector)
    for part in v
        substitute_canvas_image(context, part)
    end
    return nothing
end
substitute_canvas_image(context::SubstMDcontext, md::MD_has_subparts) = 
    substitute_canvas_image(context, get_subparts(md))

function substitute_canvas_image(context::SubstMDcontext, md::Markdown.Image)
    match_obj = match(re_substitute_canvas_image, md.url)
    if match_obj !== nothing
        canvas = context.eval(Meta.parse(match_obj.captures[1])) :: CV_2DCanvas
        write_to_png(canvas.surface, md.alt)
        md.url = md.alt
    end
    return nothing
end
# }}}

# Subst Paragraphs of the form `[inline](<name>)` {{{
"""
look für Paragraphs which have exactly one link of the form `[inline](<name>)`.

Then replace the whole paragraph with the Markdown documentation of `<name>`.
"""
get_inline_replacement_for(context::SubstMDcontext, md) = nothing
function get_inline_replacement_for(context::SubstMDcontext,
        md::Markdown.Paragraph)
    if length(md.content) == 1 && md.content[1] isa Markdown.Link
        link = md.content[1]
        if link.text isa Vector && length(link.text) == 1 &&
                link.text[1] == "inline"
            doc_md = doc(getproperty(ComplexVisual, Symbol(link.url)))
            return doc_md.content
        end
    end
    return nothing
end
substitute_inline_markdown(context::SubstMDcontext, md) = nothing
function substitute_inline_markdown(context::SubstMDcontext, v::Vector)
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
substitute_inline_markdown(context::SubstMDcontext, md::MD_has_subparts) =
    substitute_inline_markdown(context, get_subparts(md))
# }}}

# Extend Headers of the form `doc: <name>` with object documentation {{{
const re_substitute_doc = r"^\s*doc:\s*([^\s]+)\s*$"
substitute_obj_header(context::SubstMDcontext, md) = nothing
function substitute_obj_header(context::SubstMDcontext, v::Vector)
    index = 1
    while index <= length(v)
        part = v[index]
        if part isa Markdown.Header  &&  part.text isa Vector  && 
                length(part.text) == 1  && part.text[1] isa Markdown.Code
            code_md = part.text[1]
            match_obj = match(re_substitute_doc, code_md.code)
            if match_obj !== nothing
                func_name = match_obj.captures[1]
                code_md.code = func_name

                sub_md = Markdown.parse("[inline](" * func_name * ")")
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
substitute_obj_header(context::SubstMDcontext, md::MD_has_subparts) =
    substitute_obj_header(context, get_subparts(md))
# }}}

"""
replace some "markers" inside markdown with actual code from
the file here. This is done to make sure the code in the documentation
is exactly the same code as the one used in the example functions.
"""
function substitute_marker_in_markdown(context::SubstMDcontext, md)
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

    max_arg_width = maximum(map(arg -> textwidth(arg[1]), args[2:end]))
    max_type_width = maximum(map(arg -> textwidth(arg[2]), args[2:end]))

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

get_arg_description(f::Function) = get_arg_description(first(methods(f)))

function list_all_sigs(f::Function)
    for m in methods(f)
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
        open(@sprintf("./%s.md", document.basename), "w") do fio
            write(fio, string(document.markdown))
            write(fio, "\n\n")
        end
    end
end
# }}}


documents = Vector{Document}()

# for filename in ("./PixelCoordinates.jl", "./LayoutTutorial.jl",
#                  "./Axis.jl")
for filename in ("./Axis.jl", )
    println("generating markdown: ", filename)
    mod = include(filename)
    push!(documents, mod.create_document())
end

write_markdown_documentations(documents)


end


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
