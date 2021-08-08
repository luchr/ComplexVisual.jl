# The goal of this visualization is to see how `f(z) = eᶻ` can be 
# approximated through `g(z) = (1 + z/n)ⁿ` as `n → ∞`. We will 
# use a slider to change the value of `n` and also place a 'test set'
# in the domain to see how it gets transformed.
using Cairo
using ComplexVisual
@ComplexVisual.import_huge

const CVG = try using ComplexVisualGtk; ComplexVisualGtk; catch nothing; end

const fontface = cv_fontface("DejaVu Sans")

# We start by creating the function to draw the axes on the left and right
function setup_axis(setup::CV_SceneSetupChain)
    label_style = cv_black → fontface → cv_fontsize(20)
    # these are the rules used to label the x-axis ticks
                                # main ticks on left, get labeled
    ticks1, ticks1h, ticks2 = "%.0f" ⇒ -6:0, 
                                # secondary ticks on left, don't get labeled
                                "" ⇒ -5.5:0.5, 
                                # ticks on right, get labeled
                                "%.0f" ⇒ -3:3
    # rules used to label the y-axis ticks
    # uses a Tuple to label specific irrational points
    ticks3 = ("-π" ⇒ -pi, "-π/2" ⇒ -pi/2, "0" ⇒ 0.0, "π/2" ⇒ pi/2, "π" ⇒ pi,)

    # main ticks are drawn slightly longer than secondary ticks on left
    app_l = CV_TickLabelAppearance(; label_style, tick_length=10)
    app_s = CV_TickLabelAppearance(; label_style, tick_length=6)

    # use the standard axis builder from `lrdomains.jl`
    return cv_setup_lr_axis(setup,
        # x-axis labels                     # y-axis labels
        (app_l ↦ ticks1, app_s ↦ ticks1h), (app_l ↦ ticks3,),
        (app_l ↦ ticks2,),                  (app_l ↦ ticks3,)
    )
end

# Now we need to create labels + style for our custom slider. We wish
# to show more detail in the slider around the first few numbers,
# and have a slider position "at infinity"
function get_slider_rulers()  # {{{
    # points where the large ticks and medium ticks are drawn
    major_values, minor_values = Float64.(10:10:50), Float64.(15:5:45)
    # all leftover integers between 1 and 50, will be drawn with small ticks
    mini_values = setdiff(setdiff(Float64.(10:1:50), minor_values), major_values)
    # These values will all be labeled
    intro_values = Float64.(1:1:9)

    # label the major values between 10 and 50, and also ∞
    major_ticks = (("%.0f" ⇒  major_values)..., "∞" ⇒ 55.0)
    # minor values do not get labeled
    minor_ticks, mini_ticks = "" ⇒ minor_values, "" ⇒ mini_values
    intro_ticks = "%.0f" ⇒ intro_values

    # at this point the style is set, using `CV_TickLabelAppearance`
    major_ruler = CV_TickLabelAppearance(; tick_length=10, 
            label_style=cv_black → fontface → cv_fontsize(20)) ↦ major_ticks
    minor_ruler = CV_TickLabelAppearance(; tick_length=7) ↦ minor_ticks
    mini_ruler = CV_TickLabelAppearance(; tick_length=4) ↦ mini_ticks
    intro_ruler = CV_TickLabelAppearance(; tick_length=4, 
            label_style=cv_black → fontface → cv_fontsize(10)) ↦ intro_ticks
    return (major_ruler, minor_ruler, mini_ruler, intro_ruler)
end # }}}

# We have the labels, so we can build the interactive slider
function create_slider(setup, slider_pos)

    # setup will be a `CV_SceneSetupChain` which has a field `layout`. 
    # For more info see `lrdomains.jl`
    layout = setup.layout

    # internal getter functions to access the layouts for the 
    # left and right portraits. Referred to as the `seen rectangles`
    can_domain_l = cv_get_can_domain_l(layout)
    can_codomain_l = cv_get_can_codomain_l(layout)

    # will be used to position ('anchor') the slider, 
    # based on the size of the portraits
    width = can_codomain_l.rectangle.right - can_domain_l.rectangle.left
    mid = cv_half(can_codomain_l.rectangle.right + can_domain_l.rectangle.left)
    bottom = min(can_domain_l.rectangle.bottom, can_codomain_l.rectangle.bottom)
    height = 15

    # now we create the basic slider object. 
    # for more info, see `slider.jl`
    slider_data = cv_create_hslider(
        width, height, 0.5, 55.5, get_slider_rulers();
        decoraction_with_layout_and_position_callback=(inner_layout, pos) ->
            cv_border(inner_layout, pos, 1))

    # this is the bounding box ('container') that contains the drawing info
    cont_slider = slider_data.slider_container
    cc_cont_slider = slider_data.container_context

    # draw the slider in our setup.layout,
    # in the center (referring to x-position),
    # 20pts above the bottom of the left-right layout (y-position)
    cont_slider_l = cv_add_canvas!(layout,
        cont_slider,
        cv_anchor(cont_slider, :slider_south, cont_slider, :south),
        (mid, bottom - Int32(20)))

    # interactive part of the slider: if the user clicks
    # to the right of the max value, snap to the rightmost 
    # slider position (labeled ∞)
    set_slider_value = z -> begin
        slider_pos.value = (z > 53) ? 55.0 : max(1.0, min(z, 50.0))
        return CV_Response(;redraw_flag=true)
    end

    # a few style decisions 
    bg_painter = cv_color(.8,.8,.8) ↦ CV_FillPainter()
    mark_painter = (cv_op_source → cv_color(0,0,1) → cv_linewidth(2)) ↦
        CV_ValueMarkPainter(slider_pos,
            0.0, imag(cont_slider.can_slider.corner_ul), false)

    # finally the slider is added to the `CV_SceneSetupChain`
    setup = cv_setup_hslider(setup, slider_data, cont_slider_l,
        bg_painter → mark_painter, set_slider_value)
    return setup
end

# Putting everything together: almost identical to the 
# 'standard' left-right setup process (see `cv_scene_lr_std` in 'lrdomains.jl')
function create_scene(trafo,
        domain, codomain, slider_pos; cut_test=nothing, gap=80,
        axis_label_style=cv_color(0,0,0) → 
                  cv_fontface("sans-serif") → cv_fontsize(20), padding=30) # {{{
    # cyclic state counter counts right-clicks
    layout = CV_StateLayout(CV_2DLayout(), CV_CyclicValue(2))
    # creates the standard left-right layout
    layout = cv_do_lr_layout(cv_add(layout, trafo, domain, codomain), gap)

    # create a basic `CV_SceneSetupChain` with a default left-right setup
    setup = cv_setup_cycle_state(CV_LRSetupChain(layout))

    # place the slider in the setup chain
    setup = create_slider(setup, slider_pos)

    # standard left-right setup, using our custom axes
    # all the functions used here are in `lrdomains.jl`
    setup = cv_setup_lr_painters(setup; cut_test)
    setup = setup_axis(setup)
    setup = cv_setup_lr_border(setup)
    padding > 0 && cv_add_padding!(setup.layout, padding)
    setup = cv_setup_domain_codomain_scene(setup)
    cv_scene_lr_start(setup)
    return setup.layout
end # }}}

# `CV_TranslateByOffset(Float64)` lets the user interact with something that
# only needs to move left and right
slider_pos = CV_TranslateByOffset(Float64)
slider_pos.value = 1.0

# There is a discontinuity in our goal function due to our use of Log
# To get a better visualization, we add the cut test
cut_func = cv_create_angle_cross_test(π, 0.0, Inf; δ=1e-2)

cut_test = (z, w) -> (slider_pos.value == round(slider_pos.value)) ?
    false : cut_func(z + slider_pos.value, w + slider_pos.value)

trafo = z -> (slider_pos.value == 55.0) ? exp(z) : 
    exp(slider_pos.value * log(1+z/slider_pos.value))
domain   = CV_Math2DCanvas(-6.5 + 3.5im, 0.5 - 3.5im, 100)
codomain = CV_Math2DCanvas(-3.5 + (pi+0.1)im, 3.5 - (pi+0.1)im, 100)

scene = create_scene(trafo, domain, codomain, slider_pos; cut_test)

# finally, run the scene!
if CVG !== nothing
    handler = CVG.cvg_visualize(scene); CVG.cvg_wait_for_destroy(handler.window)

    CVG.cvg_close(handler); CVG.cv_destroy(scene)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
