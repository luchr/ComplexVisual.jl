# In our second example, we will compare the `Arctan` function
# to various partial sums of its power series. To do this,
# we will make a slider to compare the phase portraits,
# and allow the user to interactively choose the size of the sum.
using ComplexVisual
@ComplexVisual.import_huge

const CVG = try using ComplexVisualGtk; ComplexVisualGtk; catch nothing; end

const fontface = cv_fontface("sans-serif")

# Build our slider
function get_param_n()
    value_min, value_max = 1, 19
    # Our slider position only moves in integer-length steps
    slider_pos = CV_TranslateByOffset(Int)
    # Our starting slider position is 4
    slider_pos.value = 4
    set_slider_value_func = z -> begin
        slider_pos.value = round(UInt, max(min(z, value_max), value_min))
        return CV_Response(; redraw_flag=true)
    end
    # The next 4 lines are used to style the slider
    label_style = cv_black → fontface → cv_fontsize(20)
    app = CV_TickLabelAppearance(; label_style)
    app_notick = CV_TickLabelAppearance(; tick_length=0, gap=15, label_style)
    # Odd values between 1 and 19 are labeled
    rulers=(app ↦ ("%.0f" ⇒ value_min:2:value_max),
            # Even values are not labeled           # Set the label 'n' to the slider left
            app ↦ ("" ⇒ value_min+1:2:value_max), app_notick ↦ ("n:" ⇒ 0.5,))

    return CV_ParamWithSlider(;
        slider_pos, value_min=value_min-0.1, value_max=value_max+0.1,
        rulers, set_slider_value_func)
end

# creates the slider object. The slider position
# can be gotten by `param_n.slider_pos.value`
param_n = get_param_n()

# Power series for the Arctan function
function trafo2(z)
    n = param_n.slider_pos.value
    result = 0.0
    for k in 1:(n÷2)
      result += (isodd(k) ? +1 : -1)*z^(2*k-1)
    end
    return result
end

trafo1 = z -> log((1+z*1im)/(1-z*1im))/(2im)

codomain1 = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)
codomain2 = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)

# Create custom axis ruler for the (codomain) portraits
label_style = cv_color(0,0,0) → fontface → cv_fontsize(20)
rulers=(CV_Ruler(cv_format_ticks("%.0f", -2.0:1.0:2.0...),
    CV_TickLabelAppearance(; label_style)),)

circle = (cv_black → cv_linewidth(3)) ↦ CV_LinePainter(
    cv_arc_lines(0.0, 2π, (1.0,)))

# Now we build the scene. We use `cv_scene_comp_codomains_std`
# to create a 'standard' left-right layout with slider(s) above
scene = cv_scene_comp_codomains_std((param_n, ), trafo1, trafo2,
    codomain1, codomain2; codomain1_re_rulers=rulers,
    painter1=CV_PortraitPainter(trafo1) → circle,
    painter2=CV_PortraitPainter(trafo2) → circle)
cv_get_redraw_func(scene)()

cv_save_image(cv_get_can_layout(scene), "./ArctanSeries.png")

if CVG !== nothing
    handler = CVG.cvg_visualize(scene)
    CVG.cvg_wait_for_destroy(handler.window)

    CVG.cvg_close(handler); CVG.cv_destroy(scene)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
