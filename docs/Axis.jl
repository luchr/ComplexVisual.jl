module Axis

using Printf
using Markdown
using Cairo
using ComplexVisual
@ComplexVisual.import_huge

import Main.DocGenerator: DocSource, DocCreationEnvironment, DocContext,
        Document, substitute_marker_in_markdown, create_doc_icon

"""
# Axes

## Names

Let's start with some vocabulary

* ![./Axis_ticks.png]({image_from_canvas: vocab_tick()})
  tick: A marker for a mathematical coordinate
* ![./Axis_ticklabels.png]({image_from_canvas: vocab_ticklabel()})
  tick label: A text below a tick (may be the empty string, i.e. no text)
* ![./Axis_ruler.png]({image_from_canvas: vocab_ruler()})
  ruler: several ticks (with optional tick labels) and information about
  styling
* ![./Axis_axis.png]({image_from_canvas: vocab_axis()})
  axis: several rulers
"""
axes_intro() = nothing

"""
## Tick labels

### `doc: CV_TickLabel`

### `doc: cv_format_ticks`
"""
help_ticklabel() = nothing



function vocab_basic(format_string="", app=CV_TickLabelAppearance())
    layout = CV_2DLayout()

    math_canvas = CV_Math2DCanvas(0.0 +1.0im, 8.0 + 0.0im, 30)

    ticks = cv_format_ticks(format_string, 0.0:1.0:8.0...)
    rulers = (CV_Ruler(ticks, app), )

    axis_canvas = cv_create_2daxis_canvas(math_canvas, cv_south, rulers)
    axis_canvas_l = cv_add_canvas!(layout, axis_canvas, (0,0), (0,0))

    cv_add_padding!(layout, 5)
    can_layout = cv_canvas_for_layout(layout)
    cv_create_context(can_layout) do con_layout
        axis_canvas_l(con_layout)
    end

    return can_layout
end

vocab_tick() = vocab_basic("", CV_TickLabelAppearance())
vocab_ticklabel() = vocab_basic("%.0f", CV_TickLabelAppearance())
vocab_ruler() = vocab_basic("%.0f", CV_TickLabelAppearance(;
    tick_style=cv_color(0,0,.5) → cv_linewidth(2),
    label_style=cv_color(0,.5,0) → cv_fontface("serif") → cv_fontsize(15)))

function vocab_axis()
    layout = CV_2DLayout()

    math_canvas = CV_Math2DCanvas(0.0 +1.0im, 8.0 + 0.0im, 30)

    loc1 = 0.0:2.0:8.0
    ticks1 = cv_format_ticks("%0.f", loc1...)
    app1 = CV_TickLabelAppearance(;
        tick_style=cv_color(0,0,.5) → cv_linewidth(2),
        label_style=cv_color(0,.5,0) → cv_fontface("serif") → cv_fontsize(15))
    
    loc2 = 1.0:2.0:7.0
    ticks2 = cv_format_ticks("", loc2...)
    app2 = CV_TickLabelAppearance(; tick_length=7)

    loc3 = setdiff(setdiff(0.0:0.25:8.0, loc1), loc2)
    ticks3 = cv_format_ticks("", loc3...)
    app3 = CV_TickLabelAppearance(; tick_length=4)

    rulers = (CV_Ruler(ticks1, app1), CV_Ruler(ticks2, app2), 
              CV_Ruler(ticks3, app3), )

    axis_canvas = cv_create_2daxis_canvas(math_canvas, cv_south, rulers)
    axis_canvas_l = cv_add_canvas!(layout, axis_canvas, (0,0), (0,0))

    cv_add_padding!(layout, 5)
    can_layout = cv_canvas_for_layout(layout)
    cv_create_context(can_layout) do con_layout
        axis_canvas_l(con_layout)
    end

    return can_layout
end

function example_inches_cm()
    layout = CV_2DLayout()

    math_canvas = CV_Math2DCanvas(0.0 +0.0im, 1.0 - 8.0im, 60)

    in_unit = 2.54
    col_cm, col_in  = cv_color(0, 0, 0.5), cv_color(0, 0.5, 0)

    app1(col) = CV_TickLabelAppearance(; tick_length=30, gap=7,
        tick_style=col → cv_linewidth(2),
        label_style=col → cv_fontface("serif") → cv_fontsize(15))
    app2(col) = CV_TickLabelAppearance(; tick_length=15,
        tick_style=col → cv_linewidth(2),
        label_style=col → cv_fontface("serif") → cv_fontsize(15))
    app3(col) = CV_TickLabelAppearance(; tick_length=9,
        tick_style=col → cv_linewidth(2),
        label_style=col → cv_fontface("serif") → cv_fontsize(10))
    app4(col) = CV_TickLabelAppearance(;
        tick_length=0, gap=5,
        tick_style=col → cv_linewidth(2),
        label_style=col → cv_fontface("serif") → cv_fontsize(15))

    loc1 = 0.0:1.0:8.0
    ticks1 = cv_format_ticks("%0.f", loc1...)

    loc2 = 0.5:1.0:7.5
    ticks2 = cv_format_ticks("", loc2...)

    loc3 = setdiff(setdiff(0.0:0.1:8.0, loc1), loc2)
    ticks3 = cv_format_ticks("", loc3...)

    ticks4 = (CV_TickLabel(8.5, "cm"),)

    rulers1 = (
        CV_Ruler(ticks1, app1(col_cm)), CV_Ruler(ticks2, app2(col_cm)),
        CV_Ruler(ticks3, app3(col_cm)), CV_Ruler(ticks4, app4(col_cm)),)
    axis1_canvas = cv_create_2daxis_canvas(math_canvas, cv_west, rulers1)

    loc1 = 0.0:1.0:3.0
    ticks1 = tuple(
        map( v -> CV_TickLabel(v*in_unit, @sprintf("%0.f", v)), loc1)...)

    loc2 = setdiff(0.0:0.5:2.5, loc1)
    ticks2 = tuple(map(v -> CV_TickLabel(v*in_unit, "½"), loc2)...)

    loc3 = setdiff(setdiff(0.0:0.25:3.0, loc1), loc2)
    ticks3 = tuple(map(e -> CV_TickLabel(e[2]*in_unit,
            isodd(e[1]) ? "¼" : "¾"), enumerate(loc3))...)

    ticks4 = (CV_TickLabel(8.5, "inch"),)

    rulers2 = (
        CV_Ruler(ticks1, app1(col_in)), CV_Ruler(ticks2, app2(col_in)),
        CV_Ruler(ticks3, app3(col_in)), CV_Ruler(ticks4, app4(col_in)),)
    axis2_canvas = cv_create_2daxis_canvas(math_canvas, cv_east, rulers2)

    axis1_canvas_l = cv_add_canvas!(layout, axis1_canvas,
        cv_anchor(axis1_canvas, :default), (0,0))
    axis2_canvas_l = cv_add_canvas!(layout, axis2_canvas,
        cv_anchor(axis2_canvas, :default), (0,0))

    cv_add_padding!(layout, 10)

    can_layout = cv_canvas_for_layout(layout)
    cv_create_context(can_layout) do con_layout
        axis1_canvas_l(con_layout)
        axis2_canvas_l(con_layout)
    end

    return can_layout
end

function create_document(doc_env::DocCreationEnvironment)
    doc_source = DocSource("Axis", @__MODULE__)
    context = DocContext(doc_env, doc_source)

    md = Markdown.MD()
    for part in (axes_intro, help_ticklabel)
        part_md = Base.Docs.doc(part)
        substitute_marker_in_markdown(context, part_md)
        md = Markdown.MD(md, part_md)
    end

    doc = Document(doc_source, md)
    return doc
end

end



# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
