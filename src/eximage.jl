macro import_eximage_huge()
    :(
        using ComplexVisual:
            cv_example_image_letter, cv_example_image_3x3
    )
end

const ex_image_letter_circle_style = cv_linewidth(2) → cv_black
const ex_image_letter_font_style = cv_fontface("cairo:monospace")
const ex_image_letter_letter_stroke_style = cv_linewidth(1) → cv_black
const ex_image_letter_letter_fill_style = cv_color(0,0,1,1)
const ex_image_letter_letter_shadow_style = cv_color(0.2, 0.2, 0.2, 0.1)

function cv_example_image_letter(;
        canvas::canvasT=CV_Math2DCanvas(-0.5 + 0.5im, 0.5 -0.5im, 200),
        letter="R",
        circle_style=ex_image_letter_circle_style,
        inner_color=(1,1,1,1), outer_color=(1,0,0,1),
        letter_font_style=ex_image_letter_font_style,
        letter_stroke_style=ex_image_letter_letter_stroke_style,
        letter_fill_style=ex_image_letter_letter_fill_style,
        letter_shadow_style=ex_image_letter_letter_shadow_style) where
        {canvasT <: CV_2DCanvas} # {{{
    width, height = canvas.pixel_width, canvas.pixel_height
    con = CV_2DCanvasContext(canvas)
    ctx = con.ctx
    scale(ctx, 1.0, -1.0)
    translate(ctx, 0.0, -height)

    save(ctx)
    set_operator(ctx, Cairo.OPERATOR_CLEAR)
    paint(ctx)
    restore(ctx)

    cv_prepare(con, circle_style)
    circle_linewidth = get_line_width(ctx)

    centerx, centery = width/2, height/2
    radius = 0.5*min(width, height) - circle_linewidth/2
 
    new_sub_path(ctx)
    arc(ctx, centerx, centery, radius, 0, 2*pi)
    pat = pattern_create_radial(centerx, centery, 2*radius/3,
                                centerx, centery, radius)
    pattern_add_color_stop_rgba(pat, 0, inner_color...)
    pattern_add_color_stop_rgba(pat, 1, outer_color...)
    set_source(ctx, pat)
    fill_preserve(ctx)

    cv_prepare(con, circle_style)
    stroke(ctx)

    destroy(pat)

    cv_prepare(con, letter_font_style)
    set_font_size(ctx, 1.5*radius)    
    ext = text_extents(ctx, letter)

    move_to(ctx, centerx, centery)
    rel_move_to(ctx, -ext[4]/2, -(ext[1]+ext[2])/2)
    rel_move_to(ctx, radius/10, radius/10)

    text_path(ctx, letter)
    cv_prepare(con, letter_shadow_style)
    fill(ctx)

    move_to(ctx, centerx, centery)
    rel_move_to(ctx, -ext[4]/2, -(ext[1]+ext[2])/2)

    text_path(ctx, letter)
    cv_prepare(con, letter_fill_style)
    fill_preserve(ctx)

    cv_prepare(con, letter_stroke_style)
    stroke(ctx)

    cv_destroy(con)
    return canvas
end # }}}

function cv_example_image_3x3() # {{{
    can = CV_Math2DCanvas(-0.5 + 0.5im, 0.5 -0.5im, 3)
    can.surface.data .= UInt32[
        0xffff0000   0xffff8000  0xffff0080
        0xff00ff00   0xff80ff00  0xff00ff80
        0xff0000ff   0xff8000ff  0xff0080ff ]
    return can
end # }}}

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
