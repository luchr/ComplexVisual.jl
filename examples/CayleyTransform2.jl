using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

trafo = z -> (z - im) / (z + im)

domain = CV_Math2DCanvas(-4.0 + 4.0im, 4.0 - 4.0im, 100)
codomain = CV_Math2DCanvas(-4.0 + 4.0im, 4.0 - 4.0im, 100)


action_pos = CV_TranslateByOffset(ComplexF64)

vline = cv_parallel_lines(0.0+7.0im; lines=2, segments=400)

style = cv_black → cv_linewidth(4) → cv_antialias_best

lr_painters_kwargs = Dict(
    :parallel_lines_painter_domain => style ↦ CV_LinePainter(
        action_pos, vline),
    :parallel_lines_painter_codomain => style ↦ CV_LinePainter(
        w -> trafo(action_pos(w)), vline),
    :action_pos => action_pos
)

scene = cv_scene_lr_std(trafo, domain, codomain; lr_painters_kwargs)

handler = cvg_visualize(scene); cvg_wait_for_destroy(handler.window)

cvg_close(handler); cv_destroy(scene)
