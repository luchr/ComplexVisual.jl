using Cairo
using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

const fontface = cv_fontface("sans-serif")

function get_param_n()
    value_min, value_max = 1, 19
    slider_pos = CV_TranslateByOffset(Int)
    slider_pos.value = value_min
    set_slider_value_func = z -> begin
        slider_pos.value = round(UInt, max(min(z, value_max), value_min))
        return CV_Response(; redraw_flag=true)
    end
    label_style = cv_black → fontface → cv_fontsize(20)
    rulers=(CV_TickLabelAppearance(; label_style) ↦
                ("%.0f" ⇒ value_min:2:value_max),
            CV_Ruler("" ⇒  value_min+1:2:value_max),
            CV_TickLabelAppearance(; tick_length=0, gap=15, label_style) ↦
                (("n:" ⇒ 0.5),))

    return CV_ParamWithSlider(;
        slider_pos, value_min=value_min-0.1, value_max=value_max+0.1,
        rulers, set_slider_value_func)
end

param_n = get_param_n()

trafo1 = z -> 1/(1-z)
trafo2 = z -> abs(z) < 1 ?
    sum(k -> z^k, param_n.slider_pos.value:-1:1; init=1.0) : 
    sum(k -> z^k, 1:param_n.slider_pos.value; init=1.0)

label_style = cv_black → fontface → cv_fontsize(20)
rulers=(CV_TickLabelAppearance(; label_style) ↦ ("%.0f" ⇒ [-1.0, 0.0, 1.0]),)
codomain1  = CV_Math2DCanvas(-1.5 + 1.5im, 1.5 - 1.5im, 150)
codomain2  = CV_Math2DCanvas(-1.5 + 1.5im, 1.5 - 1.5im, 150)

circle = (cv_black → cv_linewidth(3)) ↦ CV_2DCanvasLinePainter(
    cv_arc_lines(0.0, 2π, (1.0,)))

scene = cv_scene_comp_codomains_std((param_n, ), trafo1, trafo2,
    codomain1, codomain2; codomain1_re_rulers=rulers,
    painter1=CV_Math2DCanvasPortraitPainter(trafo1) → circle,
    painter2=CV_Math2DCanvasPortraitPainter(trafo2) → circle)
cv_get_redraw_func(scene)()

handler = cvg_visualize(scene)
cvg_wait_for_destroy(handler.window)

cvg_close(handler); cv_destroy(scene)

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
