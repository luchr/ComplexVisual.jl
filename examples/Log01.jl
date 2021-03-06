using ComplexVisual
@ComplexVisual.import_huge

const CVG = try using ComplexVisualGtk; ComplexVisualGtk; catch nothing; end

const fontface = cv_fontface("DejaVu Sans")

function setup_axis(setup::CV_SceneSetupChain)
    label_style = cv_black → fontface → cv_fontsize(20)
    ticks1  = "%.0f" ⇒ -2:2
    ticks1h =     "" ⇒ -2.5:2.5
    ticks2  = "%.0f" ⇒ -3:3
    ticks3 = ("-π" ⇒ -pi, "-π/2" ⇒ -pi/2, "0" ⇒ 0.0, "π/2" ⇒ pi/2, "π" ⇒ pi,)

    app_l = CV_TickLabelAppearance(; label_style, tick_length=10)
    app_s = CV_TickLabelAppearance(; label_style, tick_length=6)
    return cv_setup_lr_axis(setup,
        (app_l ↦ ticks1, app_s ↦ ticks1h,), (app_l ↦ ticks1, app_s ↦ ticks1h,),
        (app_l ↦ ticks2,), (app_l ↦ ticks3,))
end

function setup_star_arc_painters(setup::CV_SceneSetupChain, cut_test=nothing)
    layout = setup.layout
    multiply_pos = CV_MultiplyByFactor(ComplexF64)

    trafo = cv_get_trafo(layout)
    trafo_domain = multiply_pos
    trafo_codomain = w -> trafo(multiply_pos(w))

    common_style = cv_op_over  → cv_linewidth(3) → cv_antialias_best
    star_style = common_style → cv_color(1,1,1,0.8)
    arc_style = common_style → cv_color(0,0,0,0.8)
    star_lines, arc_lines = cv_star_arc_lines(
        tuple(LinRange(0.2, 1.5, 6)...), tuple(LinRange(-π/4, π/4, 6)...))
    CLP = CV_LinePainter
    star_painter_domain   = star_style ↦ CLP(trafo_domain,   star_lines)
    arc_painter_domain    = arc_style  ↦ CLP(trafo_domain,   arc_lines )
    star_painter_codomain = star_style ↦ CLP(trafo_codomain, star_lines, false,
        trafo_domain, cut_test)
    arc_painter_codomain  = arc_style  ↦ CLP(trafo_codomain, arc_lines, false,
        trafo_domain, cut_test)

    state_counter = cv_get_state_counter(layout)
    cc_can_domain = cv_get_cc_can_domain(layout)
    cc_can_codomain = cv_get_cc_can_codomain(layout)

    update_painter_func = z -> begin
        multiply_pos.factor = z
        state = state_counter.value

        if state == 2
            cv_paint(cc_can_domain, arc_painter_domain)
            cv_paint(cc_can_codomain, arc_painter_codomain)
            cv_paint(cc_can_domain, star_painter_domain)
            cv_paint(cc_can_codomain, star_painter_codomain)
        end
        return nothing
    end

    redraw_func = layout -> begin
        update_painter_func(multiply_pos.factor)
        return nothing
    end
    return cv_combine(setup; update_painter_func, redraw_func)
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
            label_style=cv_black → fontface → cv_fontsize(20)))
    minor_ruler = CV_Ruler(minor_ticks, CV_TickLabelAppearance(; tick_length=7))
    mini_ruler = CV_Ruler(mini_ticks, CV_TickLabelAppearance(; tick_length=4))
    intro_ruler = CV_Ruler(intro_ticks,
        CV_TickLabelAppearance(; tick_length=4, 
            label_style=cv_black → fontface → cv_fontsize(10)))
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

    bg_painter = cv_color(.8,.8,.8) ↦ CV_FillPainter()
    mark_painter = (cv_op_source → cv_color(0,0,1) → cv_linewidth(2)) ↦
        CV_ValueMarkPainter(slider_pos,
            0.0, imag(cont_slider.can_slider.corner_ul), false)

    setup = cv_setup_hslider(setup, slider_data, cont_slider_l,
        bg_painter → mark_painter, set_slider_value)
    return setup
end

function create_scene(trafo,
        domain, codomain, slider_pos; cut_test=nothing, gap=80,
        axis_label_style=cv_black → fontface → cv_fontsize(20), padding=30) # {{{
    layout = CV_StateLayout(CV_2DLayout(), CV_CyclicValue(2))
    layout = cv_do_lr_layout(cv_add(layout, trafo, domain, codomain), gap)

    setup = cv_setup_cycle_state(CV_LRSetupChain(layout))
    setup = create_slider(setup, slider_pos)
    setup = cv_setup_lr_painters(setup; cut_test,
        parallel_lines_painter_domain=nothing,
        parallel_lines_painter_codomain=nothing)
    setup = setup_star_arc_painters(setup, cut_test)
    setup = setup_axis(setup)
    setup = cv_setup_lr_border(setup)
    padding > 0 && cv_add_padding!(setup.layout, padding)
    setup = cv_setup_domain_codomain_scene(setup)
    cv_scene_lr_start(setup)
    return setup.layout
end # }}}

slider_pos = CV_TranslateByOffset(Float64)
slider_pos.value = 1.2

cut_func = cv_create_angle_cross_test(π, 0.0, Inf; δ=1e-2)

cut_test = (z, w) -> (slider_pos.value == 1.0) ? false : cut_func(z, w)

trafo = z -> (slider_pos.value == 55.0) ? log(z) : 
    slider_pos.value * expm1(log(z)/slider_pos.value)
domain   = CV_Math2DCanvas(-2.5 + 2.5im, 2.5 - 2.5im, 100)
codomain = CV_Math2DCanvas(-3.5 + (pi+0.1)im, 3.5 - (pi+0.1)im, 100)

scene = create_scene(trafo, domain, codomain, slider_pos; cut_test)

cv_save_image(cv_get_can_layout(scene), "./Log01.png")

if CVG !== nothing
    handler = CVG.cvg_visualize(scene)
    CVG.cvg_wait_for_destroy(handler.window)

    CVG.cvg_close(handler); CVG.cv_destroy(scene)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:


