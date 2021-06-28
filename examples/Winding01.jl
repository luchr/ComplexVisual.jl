using Cairo
using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

function get_axis_rulers()
    label_style = cv_black → cv_fontface("sans-serif") → cv_fontsize(20)

    ticks1, ticks1h = "%.0f" ⇒ -4:4, "" ⇒ -4.5:4.5

    app_l = CV_TickLabelAppearance(; label_style, tick_length=10)
    app_s = CV_TickLabelAppearance(; label_style, tick_length=6)

    return (app_l ↦ ticks1, app_s ↦ ticks1h,)
end

function create_colorbar(setup, can_codomain_l, winding_painter) # {{{
    layout = setup.layout
    width = cv_width(can_codomain_l.rectangle)
    mid = cv_half(can_codomain_l.rectangle.right + can_codomain_l.rectangle.left)
    bottom = can_codomain_l.rectangle.bottom
    height = 30

    colorbar_data = cv_create_winding_colorbar(width, height,
        winding_painter, -2, 5)
    cont_colorbar = colorbar_data.colorbar_container
    cont_colorbar_l = cv_add_canvas!(layout,
        cont_colorbar,
        cv_anchor(cont_colorbar, :slider_south, cont_colorbar, :south),
        (mid, bottom - Int32(20)))

    return cv_setup_winding_colorbar(setup, colorbar_data, cont_colorbar_l)
end # }}}

function create_scene(trafo, can_codomain, curve_painter; padding=30) # {{{
    layout = CV_StateLayout(CV_2DLayout(), CV_CyclicValue(2))

    can_codomain_l = cv_add_canvas!(layout, can_codomain, (0, 0), (0, 0))

    cc_can_codomain = cv_create_context(can_codomain)

    rulers = get_axis_rulers()
    codomain_re_axis = cv_ticks_labels(layout, can_codomain_l, cv_south, rulers)
    codomain_im_axis = cv_ticks_labels(layout, can_codomain_l, cv_west, rulers)
    codomain_border = cv_border(layout, can_codomain_l, 2)

    fill_painter = CV_FillPainter()
    styled_fill_painter = cv_color(1,1,1) ↦ fill_painter

    wind_painter = CV_WindingPainter(trafo, curve_painter.segments)

    style = cv_color(0,0,1) → cv_linewidth(4) → cv_antialias(Cairo.ANTIALIAS_BEST)
    styled_curve_painter = style ↦ curve_painter

    dir_painter = CV_DirectionPainter(trafo,
        curve_painter.segments, true; every_len=3)
    dir_style = cv_color(0,0,1) → cv_op_source
    styled_dir_painter = dir_style ↦ dir_painter

    setup = CV_MinimalSetupChain(layout)

    actionpixel_update = (px, py, future_layout) -> begin
        cc_can_layout = cv_get_cc_can_layout(future_layout)
        cv_paint(cc_can_codomain, styled_fill_painter)
        cv_paint(cc_can_codomain, wind_painter)
        cv_paint(cc_can_codomain, styled_curve_painter)
        cv_paint(cc_can_codomain, styled_dir_painter)
        can_codomain_l(cc_can_layout)
        return nothing
    end

    draw_once_func = future_layout -> begin
        cc_can_layout = cv_get_cc_can_layout(future_layout)
        codomain_re_axis(cc_can_layout)
        codomain_im_axis(cc_can_layout)
        codomain_border(cc_can_layout)
        return nothing
    end
    setup = cv_combine(setup; draw_once_func, actionpixel_update)

    setup = create_colorbar(setup, can_codomain_l, wind_painter)
    padding > 0 && cv_add_padding!(setup.layout, padding)
    setup = cv_setup_2dminimal_scene(setup)
    setup.layout.actionpixel_update(Int32(0), Int32(0))
    setup.layout.redraw_func()
    return setup.layout
end # }}}


function create_curve()
    phi = collect(LinRange(0.0, 2*pi, 700))[1:end-1]
    curve = 2.0*exp.(1im.*phi)
    return [curve,] :: CV_LineSegments
end

trafo = z -> sin(z^2)/10 - 5/z
codomain = CV_Math2DCanvas(-5.0 + 5.0im, 5.0 - 5.0im, 80)
curve_painter = CV_LinePainter(trafo, create_curve(), true)

scene = create_scene(trafo, codomain, curve_painter)

handler = cvg_visualize(scene)
cvg_wait_for_destroy(handler.window)

cvg_close(handler); cv_destroy(scene)

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:


