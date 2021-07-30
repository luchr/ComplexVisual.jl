using ComplexVisual
@ComplexVisual.import_huge

const fontface = cv_fontface("sans-serif")

function axis1(layout, can_math_l, attach)
    t1, t2 = collect(-2:2), collect(-1.5:1.0:1.5)
    t3 = setdiff(setdiff(collect(-2:0.1:2), t1), t2)

    ticks, ticksh, tickss = "%.0f" ⇒ t1, "%.1f" ⇒ t2, "" ⇒ t3

    app = CV_TickLabelAppearance(; tick_length=10,
        label_style=cv_color(0, 0, 1) → fontface → cv_fontsize(20))
    apph = CV_TickLabelAppearance(; tick_length=6,
        label_style=cv_color(.4, .4, 0) → fontface → cv_fontsize(10))
    apps = CV_TickLabelAppearance(; tick_length=3)
    return cv_ticks_labels(layout, can_math_l, attach,
        (app ↦ ticks, apph ↦ ticksh, apps ↦ tickss))
end

function main()
    layout = CV_2DLayout()

    can_math = CV_Math2DCanvas(-2.0 + 2.0im, 2.0 - 2.0im, 100)
    can_math_l = cv_add_canvas!(layout, can_math,
        cv_anchor(can_math, :center), (0,0))
    cc_can_math = cv_create_context(can_math)

    a1_l = axis1(layout, can_math_l, cv_south)
    a2_l = axis1(layout, can_math_l, cv_north)
    a3_l = axis1(layout, can_math_l, cv_east)
    a4_l = axis1(layout, can_math_l, cv_west)

    cv_add_padding!(layout, 30)

    fill_red = cv_color(0.7,0.1,0.1) ↦ CV_FillPainter()

    can_layout = cv_canvas_for_layout(layout)
    cc_can_layout = cv_create_context(can_layout)

    cv_paint(cc_can_math, fill_red)
    can_math_l(cc_can_layout)
    a1_l(cc_can_layout)
    a2_l(cc_can_layout)
    a3_l(cc_can_layout)
    a4_l(cc_can_layout)

    cv_save_image(can_layout, "./Axis01.png")
end

main()

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
