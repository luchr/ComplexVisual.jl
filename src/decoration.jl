macro import_decoration_huge()
    :(
        using ComplexVisual:
            cv_border, cv_fill_rectangle_cb, cv_fill_circle_cb,
            cv_filled_canvas
    )
end

"""
create border(-callback) for a givven `CV_2DLayoutPosition`, adds
the border rectangle to the layout and recturns the `CV_2DLayoutPosition`
for this border decoration.

The parameter north, east, south, west define the border thickness.
"""
function cv_border(layout::CV_Abstract2DLayout, for_position::CV_2DLayoutPosition,
        north::Integer=2, east::Integer=north, south::Integer=north,
        west::Integer=east; gap_north::Integer=0, gap_east::Integer=gap_north,
        gap_south::Integer=gap_north, gap_west::Integer=gap_east,
        style=cv_color(0,0,0)) # {{{

    rect = for_position.rectangle
    inner_rect = CV_Rectangle(
        rect.top + Int32(gap_south), rect.left - Int32(gap_west),
        rect.bottom - Int32(gap_north), rect.right + Int32(gap_east))
    outer_rect = CV_Rectangle(
        inner_rect.top + Int32(south), inner_rect.left - Int32(west),
        inner_rect.bottom - Int32(north), inner_rect.right + Int32(east))
    drawing_cb =  (cc, pos) -> begin
        set_fill_type(cc.ctx, Cairo.CAIRO_FILL_RULE_EVEN_ODD)
        rectangle(cc.ctx, outer_rect.left, outer_rect.bottom,
            cv_width(outer_rect), cv_height(outer_rect))
        rectangle(cc.ctx, inner_rect.left, inner_rect.bottom,
            cv_width(inner_rect), cv_height(inner_rect))
        fill(cc.ctx)
        return nothing
    end
    return cv_add_rectangle!(layout, outer_rect, drawing_cb, style)
end # }}}


"""
drawing callback (e.g. for `cv_add_rectangle!`) which fills the rectangle.

Typically used only for debugging purposes or for explaining something.
"""
function cv_fill_rectangle_cb(cc, pos)     # {{{
    rect = pos.rectangle
    rectangle(cc.ctx, rect.left, rect.bottom,
              cv_width(rect), cv_height(rect))
    fill(cc.ctx)
    return nothing
end   # }}}

"""
drawing callback (e.g. for `cv_add_rectangle!`) which fills the inscribed
circle.

Typically used only for debugging purposes or for explaining something.
"""
function cv_fill_circle_cb(cc, pos)  # {{{
    rect = pos.rectangle
    half_width, half_height = cv_half(cv_width(rect)), cv_half(cv_height(rect))
    new_sub_path(cc.ctx)
    arc(cc.ctx,
        rect.left + half_width,
        rect.bottom + half_height,
        min(half_width, half_height), 0.0, 2*pi)
    fill(cc.ctx)
    return nothing
end    # }}}

"""
CV_Std2DCanvas filled with the given style.

Typically used only for debugging.
"""
function cv_filled_canvas(width::Integer, height::Integer,
                          style::CV_ContextStyle) # {{{
    canvas = CV_Std2DCanvas(width, height)
    cv_create_context(canvas, style) do con
        rectangle(con.ctx, 0, 0, width, height)
        fill(con.ctx)
    end
    return canvas
end # }}}


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
