using Markdown

"""
extract some lines of a file.
"""
function extract_lines(filename, start_re::Regex, stop_re::Regex;
        include_start_stop=true)
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
end

struct SubstMDcontext
    filename :: AbstractString
end

const re_substitute_code_func = r"^\s*\{func:\s*([^\s}]+)\s*\}"

"""
look for `Markdown.Code` with content "{func: name_of_function}"
and replace the content with the acutal code of the function.
"""
substitute_code_func(context::SubstMDcontext, md) = nothing
function substitute_code_func(context::SubstMDcontext, md::Markdown.MD)
    for part in md.content
        substitute_code_func(context, part)
    end
    return nothing
end
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


const re_substitute_canvas_image = r"^\s*\{image_from_canvas:\s*([^\s}]+)\s*\}"


"""
look für `Markdown.Image` with `url` of the form 

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
function substitute_canvas_image(context::SubstMDcontext,
        md::Union{Markdown.MD, Markdown.Paragraph})
    for part in md.content
        substitute_canvas_image(context, part)
    end
    return nothing
end

function substitute_canvas_image(context::SubstMDcontext, md::Markdown.Image)
    match_obj = match(re_substitute_canvas_image, md.url)
    if match_obj !== nothing
        canvas = eval(Meta.parse(match_obj.captures[1])) :: CV_2DCanvas
        write_to_png(canvas.surface, md.alt)
        md.url = md.alt
    end
    return nothing
end

"""
replace some "markers" inside markdown with actual code from
the file here. This is done to make sure the code in the documentation
is exactly the same code as the one used in the example functions.
"""
function substitute_marker_in_markdown(context::SubstMDcontext, md)
    substitute_code_func(context, md)
    substitute_canvas_image(context, md)
    return nothing
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:

