# This is a barebones left-right setup, which can quickly be
# changed to see the phase portrait of any function. However,
# there are no cut tests
using ComplexVisual
@ComplexVisual.import_huge

const CVG = try using ComplexVisualGtk; ComplexVisualGtk; catch nothing; end

trafo = z -> z^2
domain   = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)
codomain = CV_Math2DCanvas(-4.0 + 4.0im, 4.0 - 4.0im, 50)

lr_start_kwargs = Dict(:z_start => 0.2 +0.8im)
scene = cv_scene_lr_std(trafo, domain, codomain; lr_start_kwargs)

cv_save_image(cv_get_can_layout(scene), "./zsquare_lr.png")

if CVG !== nothing
    handler = CVG.cvg_visualize(scene)
    CVG.cvg_wait_for_destroy(handler.window)

    CVG.cvg_close(handler); CVG.cv_destroy(scene)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
