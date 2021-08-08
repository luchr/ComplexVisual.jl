using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

const fontface = cv_fontface("sans-serif")

function get_param_n()
    value_min, value_max = -4, 4
    slider_pos = CV_TranslateByOffset(Float64)
    slider_pos.value = value_min
    set_slider_value_func = z -> begin
        slider_pos.value = round(max(min(z, value_max), value_min); digits=2)
        return CV_Response(; redraw_flag=true)
    end
    label_style = cv_black → fontface → cv_fontsize(20)
    app = CV_TickLabelAppearance(; label_style)
    app_notick = CV_TickLabelAppearance(; tick_length=0, gap=15, label_style)
    rulers=(app ↦ ("%.1f" ⇒ value_min:1:value_max),
            app ↦ ("" ⇒ value_min+0.5:1:value_max), app_notick ↦ ("n:" ⇒ -3.5,))

    return CV_ParamWithSlider(;
        slider_pos, value_min=value_min, value_max=value_max,
        rulers, set_slider_value_func)
end

param_n = CV_TranslateByOffset(ComplexF64)

function slider_test() # ich hatte ein error bei n == 0
    return 1/(param_n.value)
end
trafo1 = z -> (z - im) / (z + im)
trafo2 = z -> (z - im) / (z + im)
linetrafo = z -> z + param_n.value
circletrafo = z -> z*slider_test() + 1.0 - 1.0im*slider_test()

codomain1 = CV_Math2DCanvas(-4.0 + 4.0im, 4.0 - 4.0im, 100)
codomain2 = CV_Math2DCanvas(-4.0 + 4.0im, 4.0 - 4.0im, 100)

label_style = cv_color(0,0,0) → fontface → cv_fontsize(20)
rulers=(CV_Ruler(cv_format_ticks("%.0f", -4.0:1.0:4.0...),
    CV_TickLabelAppearance(; label_style)),)

line = (cv_black → cv_linewidth(3)) ↦ CV_LinePainter(
    linetrafo, cv_parallel_lines(8.0im; lines=1)
)

circle = (cv_black → cv_linewidth(3)) ↦ CV_LinePainter(
    circletrafo, cv_arc_lines(0.0, 2π, (1,))
)

scene = cv_scene_comp_codomains_std((param_n, ), trafo1, trafo2,
    codomain1, codomain2; codomain1_re_rulers=rulers,
    painter1=CV_PortraitPainter(trafo1) → line,
    painter2=CV_PortraitPainter(trafo2) → circle)
cv_get_redraw_func(scene)()

handler = cvg_visualize(scene); cvg_wait_for_destroy(handler.window)

cvg_close(handler); cv_destroy(scene)
