using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge


cut_test1 = cv_create_angle_cross_test(+π/2, 1.0, Inf; δ=1e-2)
cut_test2 = cv_create_angle_cross_test(-π/2, 1.0, Inf; δ=1e-2)

cut_test = (w,z) -> cut_test1(w, z) || cut_test2(w, z)

trafo = z -> log((1+z*1im)/(1-z*1im))/(2im)
domain   = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)
codomain = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)

scene = cv_scene_lr_std(trafo, domain, codomain; cut_test)

handler = cvg_visualize(scene)
cvg_wait_for_destroy(handler.window)

cvg_close(handler); cv_destroy(scene)

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
