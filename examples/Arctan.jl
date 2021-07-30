using ComplexVisual
@ComplexVisual.import_huge

const CVG = try using ComplexVisualGtk; ComplexVisualGtk; catch nothing; end

cut_test1 = cv_create_angle_cross_test(+π/2, 1.0, Inf; δ=1e-2)
cut_test2 = cv_create_angle_cross_test(-π/2, 1.0, Inf; δ=1e-2)

cut_test = (w,z) -> cut_test1(w, z) || cut_test2(w, z)

trafo = z -> log((1+z*1im)/(1-z*1im))/(2im)
domain   = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)
codomain = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)

lr_start_kwargs = Dict(:z_start => 0.2 +0.8im)
scene = cv_scene_lr_std(trafo, domain, codomain; cut_test, lr_start_kwargs)

cv_save_image(cv_get_can_layout(scene), "./Arctan.png")

if CVG !== nothing
    handler = CVG.cvg_visualize(scene)
    CVG.cvg_wait_for_destroy(handler.window)

    CVG.cvg_close(handler); CVG.cv_destroy(scene)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
