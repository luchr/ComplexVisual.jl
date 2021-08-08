# In our fist example, we will build a basic left-right
# visualization using the standard layout options,
# to see how a 'test set' gets transformed by the 
# anayltic continuation of `Arctan`.
using ComplexVisual
@ComplexVisual.import_huge

# Test if user has `ComplexVisualGtk` installed. It is 
# possible to use `ComplexVisual` as a standalone package,
# though the interactive mode is not possible
const CVG = try using ComplexVisualGtk; ComplexVisualGtk; catch nothing; end

# If the goal function has a discontinuity, it is 
# recommended to add a `cut_test`. This helps in visualization 
cut_test1 = cv_create_angle_cross_test(+π/2, 1.0, Inf; δ=1e-2)
cut_test2 = cv_create_angle_cross_test(-π/2, 1.0, Inf; δ=1e-2)

cut_test = (w,z) -> cut_test1(w, z) || cut_test2(w, z)

# Our transformation is the complex definition of Arctan 
trafo = z -> log((1+z*1im)/(1-z*1im))/(2im)

# We now set up our layout
domain   = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)
codomain = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)

# The `lr_painters_kwargs` gives options to change the shape,
# style, colors, etc. of the interactive parts. 
# Similarly, `lr_start_kwargs` has options to change how the 
# interactive parts start. See `lrdomains.jl` for details.
# Change `:z_start` if you want to save different pictures
lr_start_kwargs = Dict(:z_start => 0.2 +0.8im)
scene = cv_scene_lr_std(trafo, domain, codomain; cut_test, lr_start_kwargs)

# `scene` is a CV_SceneSetupChain, which can be used to
# interact.
# `cv_get_can_layout` is an internal getter-function. 
# It serves to get `scene.layout`, which is all that
# we need to create a `png` image.
cv_save_image(cv_get_can_layout(scene), "./Arctan.png")

# will not do anything unless ComplexVisualGtk is installed
if CVG !== nothing
    handler = CVG.cvg_visualize(scene)
    CVG.cvg_wait_for_destroy(handler.window)

    CVG.cvg_close(handler); CVG.cv_destroy(scene)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
