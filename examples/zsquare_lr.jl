using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

trafo = z -> z^2
domain   = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)
codomain = CV_Math2DCanvas(-4.0 + 4.0im, 4.0 - 4.0im, 50)

scene = cv_scene_lr_std(trafo, domain, codomain)

handler = cvg_visualize(scene)
cvg_wait_for_destroy(handler.window)

cv_destroy(scene)


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
