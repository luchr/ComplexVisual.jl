using Cairo
using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

const fontface = cv_fontface("sans-serif")

function create_scene(trafo,
        domain, codomain; cut_test=nothing, gap=80,
        axis_label_style=cv_black → fontface → cv_fontsize(20), padding=30) # {{{
    layout = CV_StateLayout(CV_2DLayout(), CV_CyclicValue(2))
    layout = cv_do_lr_layout(cv_add(layout, trafo, domain, codomain), gap)

    setup = cv_setup_cycle_state(CV_LRSetupChain(layout))
    setup = cv_setup_lr_painters(setup; cut_test,
        parallel_hlines_style=cv_op_source → cv_antialias_best →
            cv_linewidth(3) → cv_black,
        parallel_vlines_style=cv_op_source → cv_antialias_best →
            cv_linewidth(3) → cv_white,
        parallel_hlines=cv_parallel_lines(2.0+0.0im),
        parallel_vlines= cv_parallel_lines(0.0+2.0im))
    setup = cv_setup_lr_axis(setup; label_style=axis_label_style)
    setup = cv_setup_lr_border(setup)
    padding > 0 && cv_add_padding!(setup.layout, padding)
    setup = cv_setup_domain_codomain_scene(setup)
    cv_scene_lr_start(setup)
    return setup.layout
end

trafo = exp
domain   = CV_Math2DCanvas(-4.0 + 4.0im, 4.0 - 4.0im, 50)
codomain = CV_Math2DCanvas(-4.0 + 4.0im, 4.0 - 4.0im, 50)

scene = create_scene(trafo, domain, codomain)

handler = cvg_visualize(scene)
cvg_wait_for_destroy(handler.window)

cvg_close(handler); cv_destroy(scene)

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
