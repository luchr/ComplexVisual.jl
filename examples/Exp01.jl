using Cairo
using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

function setup_axis(setup::CV_SceneSetupChain)
    label_style = cv_color(0,0,0) → 
                  cv_fontface("DejaVu Sans", Cairo.FONT_WEIGHT_BOLD) → 
                  cv_fontsize(20)
    ticks1 = cv_format_ticks("%.0f", -6:0...)
    ticks1h = cv_format_ticks("", -5.5:1.0:0.5...)
    ticks2 = cv_format_ticks("%.0f", -3:3...)
    ticks3 = (CV_TickLabel(-pi/1.0, "-π"), CV_TickLabel(-pi/2, "-π/2"),
              CV_TickLabel(0.0, "0"), CV_TickLabel(pi/2, "π/2"),
              CV_TickLabel(pi/1.0, "π"))

    app_l = CV_TickLabelAppearance(; label_style, tick_length=10)
    app_s = CV_TickLabelAppearance(; label_style, tick_length=6)
    return cv_setup_lr_axis(setup,
        (CV_Ruler(ticks1, app_l), CV_Ruler(ticks1h, app_s)),
        (CV_Ruler(ticks3, app_l), ),
        (CV_Ruler(ticks2, app_l), ), (CV_Ruler(ticks3, app_l), ))
end

function get_slider_rulers()  # {{{
    major_values = Float64.(10:10:50)
    minor_values = Float64.(15:5:45)
    mini_values = setdiff(setdiff(Float64.(10:1:50), minor_values), major_values)
    
    intro_values = Float64.(1:1:9)

    major_ticks = (cv_format_ticks("%.0f", major_values...)..., 
        CV_TickLabel(55.0, "∞"))
    minor_ticks = cv_format_ticks("", minor_values...)
    mini_ticks = cv_format_ticks("", mini_values...)
    intro_ticks = cv_format_ticks("%.0f", intro_values...)

    major_ruler = CV_Ruler(major_ticks,
        CV_TickLabelAppearance(; tick_length=10, 
            label_style=cv_color(0,0,0) → 
                cv_fontface("DejaVu Sans") → cv_fontsize(20)))
    minor_ruler = CV_Ruler(minor_ticks, CV_TickLabelAppearance(; tick_length=7))
    mini_ruler = CV_Ruler(mini_ticks, CV_TickLabelAppearance(; tick_length=4))
    intro_ruler = CV_Ruler(intro_ticks,
        CV_TickLabelAppearance(; tick_length=4, 
            label_style=cv_color(0,0,0) → 
                cv_fontface("DejaVu Sans") → cv_fontsize(10)))
    return (major_ruler, minor_ruler, mini_ruler, intro_ruler)
end # }}}

function create_slider(setup, slider_pos)
    layout = setup.layout
    can_domain_l = cv_get_can_domain_l(layout)
    can_codomain_l = cv_get_can_codomain_l(layout)
    width = can_codomain_l.rectangle.right - can_domain_l.rectangle.left
    mid = cv_half(can_codomain_l.rectangle.right + can_domain_l.rectangle.left)
    bottom = min(can_domain_l.rectangle.bottom, can_codomain_l.rectangle.bottom)
    height = 15

    slider_data = cv_create_hslider(
        width, height, 0.5, 55.5, get_slider_rulers();
        decoraction_with_layout_and_position_callback=(inner_layout, pos) ->
            cv_border(inner_layout, pos, 1))

    cont_slider = slider_data.slider_container
    cc_cont_slider = slider_data.container_context
    cont_slider_l = cv_add_canvas!(layout,
        cont_slider,
        cv_anchor(cont_slider, :slider_south, cont_slider, :south),
        (mid, bottom - Int32(20)))

    set_slider_value = z -> begin
        slider_pos.value = (z > 53) ? 55.0 : max(1.0, min(z, 50.0))
        return CV_Response(;redraw_flag=true)
    end

    bg_painter = cv_color(.8,.8,.8) ↦ CV_2DCanvasFillPainter()
    mark_painter = (cv_op_source → cv_color(0,0,1) → cv_linewidth(2)) ↦
        CV_2DValueMarkPainter(slider_pos,
            0.0, imag(cont_slider.can_slider.corner_ul), false)

    setup = cv_setup_hslider(setup, slider_data, cont_slider_l,
        bg_painter → mark_painter, set_slider_value)
    return setup
end

function create_scene(trafo,
        domain, codomain, slider_pos; cut_test=nothing, gap=80,
        axis_label_style=cv_color(0,0,0) → 
                  cv_fontface("sans-serif") → cv_fontsize(20), padding=30) # {{{
    layout = CV_StateLayout(CV_2DLayout(), CV_CyclicValue(2))
    layout = cv_do_lr_layout(cv_add(layout, trafo, domain, codomain), gap)

    setup = cv_setup_cycle_state(CV_LRSetupChain(layout))
    setup = create_slider(setup, slider_pos)
    setup = cv_setup_lr_painters(setup; cut_test)
    setup = setup_axis(setup)
    setup = cv_setup_lr_border(setup)
    padding > 0 && cv_add_padding!(setup.layout, padding)
    setup = cv_setup_domain_codomain_scene(setup)
    cv_scene_lr_start(setup)
    return setup.layout
end # }}}

slider_pos = CV_TranslateByOffset(Float64)
slider_pos.value = 1.0

cut_func = cv_create_angle_cross_test(π, 0.0, Inf; δ=1e-2)

cut_test = (z, w) -> (slider_pos.value == round(slider_pos.value)) ?
    false : cut_func(z + slider_pos.value, w + slider_pos.value)

trafo = z -> (slider_pos.value == 55.0) ? exp(z) : 
    exp(slider_pos.value * log(1+z/slider_pos.value))
domain   = CV_Math2DCanvas(-6.5 + 3.5im, 0.5 - 3.5im, 100)
codomain = CV_Math2DCanvas(-3.5 + (pi+0.1)im, 3.5 - (pi+0.1)im, 100)

scene = create_scene(trafo, domain, codomain, slider_pos; cut_test)

handler = cvg_visualize(scene)
cvg_wait_for_destroy(handler.window)

cvg_close(handler); cv_destroy(scene)

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:


