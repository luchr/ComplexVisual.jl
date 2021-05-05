using Cairo
using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge
using Printf
using InteractiveUtils

function setup_star_arc_painters(setup::CV_SceneSetupChain, cut_test=nothing)

    layout = setup.layout
    multiply_pos = CV_MultiplyByFactor(ComplexF64)

    common_style = cv_opmode(Cairo.OPERATOR_OVER)  → cv_linewidth(3) →
        cv_antialias(Cairo.ANTIALIAS_BEST)
    star_painter, arc_painter = cv_star_arc_lines(
        tuple(LinRange(0.2, 1.5, 6)...), tuple(LinRange(-π/4, π/4, 6)...))
    star_painter = (common_style → cv_color(1,1,1,0.8)) ↦ star_painter
    arc_painter = (common_style → cv_color(0,0,0,0.8)) ↦ arc_painter

    PC = CV_2DDomainCodomainPaintingContext
    trafo = cv_get_trafo(layout)
    trafo_domain = multiply_pos
    trafo_codomain = w -> trafo(multiply_pos(w))

    state_counter = cv_get_state_counter(layout)
    cc_can_domain = cv_get_cc_can_domain(layout)
    cc_can_codomain = cv_get_cc_can_codomain(layout)

    dc = PC(trafo_domain, nothing, nothing)
    cc = PC(trafo_codomain, trafo_domain, cut_test)

    update_painter_func = z -> begin
        multiply_pos.factor = z
        state = state_counter.value

        if state==3 || state==5
            cv_paint(cc_can_domain, arc_painter, dc)
            cv_paint(cc_can_codomain, arc_painter, cc)
        end

        if state==4 || state==5
            cv_paint(cc_can_domain, star_painter, dc)
            cv_paint(cc_can_codomain, star_painter, cc)
        end
    end
    return cv_combine(setup; update_painter_func)
end

function setup_axis(setup::CV_SceneSetupChain)
    label_style = cv_color(0,0,0) → 
                  cv_fontface("DejaVu Sans", Cairo.FONT_WEIGHT_BOLD) → 
                  cv_fontsize(20)
    ticks1 = cv_format_ticks("%.0f", -2:2...)
    ticks2 = cv_format_ticks("%.0f", -3:3...)
    ticks3 = (CV_TickLabel(-pi/1.0, "-π"), CV_TickLabel(-pi/2, "-π/2"),
              CV_TickLabel(0.0, "0"), CV_TickLabel(pi/2, "π/2"),
              CV_TickLabel(pi/1.0, "π"))

    return cv_setup_lr_axis(setup, ticks1, ticks1, ticks2, ticks3; label_style)
end

function setup_axis_grid(setup::CV_SceneSetupChain)

    layout = setup.layout
    axis_grid_style = cv_opmode(Cairo.OPERATOR_OVER) → cv_linewidth(1) →
        cv_color(0.7, 0.7, 0.7, 0.8)
    ag_domain_painter = CV_2DAxisGridPainter(
        tuple(range(-2.0, stop=2.0, step=0.5)...),
        tuple(range(-2.0, stop=2.0, step=0.5)...))
    axis_grid_domain = axis_grid_style ↦ ag_domain_painter
    axis_grid_codomain = axis_grid_style ↦ CV_2DAxisGridPainter(
        tuple(range(-3, stop=3, step=1)...),
        tuple(range(-π, stop=π, step=π/2)...))

    cc_can_domain = cv_get_cc_can_domain(layout)
    cc_can_codomain = cv_get_cc_can_codomain(layout)
    nopc = CV_2DDomainCodomainPaintingContext(nothing, nothing, nothing)

    update_painter_func = z -> begin
        cv_paint(cc_can_domain, axis_grid_domain, nopc)
        cv_paint(cc_can_codomain, axis_grid_codomain, nopc)
        return nothing
    end
    return cv_combine(setup; update_painter_func)
end

function get_layout()
    trafo = log

    domain   = CV_Math2DCanvas(-2.5 + 2.5im, 2.5 - 2.5im, 100)
    codomain = CV_Math2DCanvas(-3.5 + (pi+0.1)im, 3.5 - (pi+0.1)im, 100)

    layout1 = CV_StateLayout(CV_2DLayout(), CV_CyclicValue(5))
    layout2 = cv_add(layout1, trafo, domain, codomain)
    return cv_do_lr_layout(layout2, 80)
end

function do_setup1(layout, cut_test)
    setup1 = cv_setup_lr_border(cv_setup_cycle_state(CV_StdSetupChain(layout)))
    setup2 = cv_setup_lr_painters(setup1; cut_test, img_painter=nothing,
        parallel_lines_painter=nothing)
    setup3 = setup_axis_grid(setup2)
    setup4 = cv_setup_lr_painters(setup3; cut_test,
        portrait_painter_domain=nothing,
        portrait_painter_codomain=nothing)
    return setup4
end

function do_setup2(setup, cut_test)
    setup1 = setup_star_arc_painters(setup, cut_test)
    setup2 = setup_axis(setup1)

    cv_add_padding!(setup2.layout, 30)
    scene = cv_setup_domain_codomain_scene(setup2)
    return scene
end

function main()
    cut_test = cv_create_angle_cross_test(pi, 0, Inf; δ=1e-2)

    layout = get_layout()
    setup = do_setup1(layout, cut_test)
    scene = do_setup2(setup, cut_test)

    cv_scene_lr_start(scene; z_start=1.0+0.0im, state_start=3)

    handler = cvg_visualize(scene.layout)
    cvg_wait_for_destroy(handler.window)

    cvg_close(handler); cv_destroy(scene.layout)
    return nothing
end

main()

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
