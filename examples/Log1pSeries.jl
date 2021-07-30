using ComplexVisual
@ComplexVisual.import_huge

const CVG = try using ComplexVisualGtk; ComplexVisualGtk; catch nothing; end

const fontface = cv_fontface("sans-serif")

function get_param_n()
    value_min, value_max = 1, 29
    slider_pos = CV_TranslateByOffset(Int)
    slider_pos.value = 3
    set_slider_value_func = z -> begin
        slider_pos.value = round(UInt, max(min(z, value_max), value_min))
        return CV_Response(; redraw_flag=true)
    end
    label_style = cv_black → fontface → cv_fontsize(20)
    rulers=(CV_TickLabelAppearance(; label_style) ↦
                ("%.0f" ⇒ value_min:2:value_max),
            CV_Ruler("" ⇒ value_min+1:2:value_max),
            CV_TickLabelAppearance(; tick_length=0, gap=15, label_style) ↦
                (("n:" ⇒ 0.2),))

    return CV_ParamWithSlider(;
        slider_pos, value_min=value_min-0.1, value_max=value_max+0.1,
        rulers, set_slider_value_func)
end

param_n = get_param_n()

function trafo2(z)
    n = param_n.slider_pos.value
    result = 0.0
    for k in 1:n
      result += (isodd(k) ? +1 : -1)*(z^k)/k
    end
    return result
end

trafo1 = z -> log1p(z)

codomain1 = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)
codomain2 = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)

label_style = cv_color(0,0,0) → cv_fontface("sans-serif") → cv_fontsize(20)
rulers=(CV_Ruler(cv_format_ticks("%.0f", -2.0:1.0:2.0...),
    CV_TickLabelAppearance(; label_style)),)

circle = (cv_black → cv_linewidth(3)) ↦ CV_LinePainter(
    cv_arc_lines(0.0, 2π, (1.0,)))

scene = cv_scene_comp_codomains_std((param_n, ), trafo1, trafo2,
    codomain1, codomain2; codomain1_re_rulers=rulers,
    painter1=CV_PortraitPainter(trafo1) → circle,
    painter2=CV_PortraitPainter(trafo2) → circle)
cv_get_redraw_func(scene)()

cv_save_image(cv_get_can_layout(scene), "./Log1pSeries.png")

if CVG !== nothing
    handler = CVG.cvg_visualize(scene)
    CVG.cvg_wait_for_destroy(handler.window)

    CVG.cvg_close(handler); CVG.cv_destroy(scene)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
