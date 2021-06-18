macro import_slider_huge()
    :(
        using ComplexVisual:
            CV_SliderContainer, cv_create_hslider, cv_setup_hslider,
            cv_anchor, CV_SliderCreateData
    )
end

"""
A (Container-)Canvas with a slider (a `CV_Math2DCanvas`) inside and its rulers.
"""
struct CV_SliderContainer{ccsT, dcbT} <: CV_2DContainer # {{{
    surface        :: Cairo.CairoSurfaceImage{UInt32}
    pixel_width    :: Int32
    pixel_height   :: Int32
    bounding_box   :: CV_Rectangle{Int32} # zero-based
    user_box       :: CV_Rectangle{Int32} # user-coordinates (result of layout)
                                          # typically nonzero-based
    can_slider     :: CV_Math2DCanvas
    can_slider_l   :: CV_2DLayoutPosition # postion of can_slider inside
                                          # container
    cc_can_slider  :: ccsT
    decorator_cb   :: dcbT
end

function cv_anchor(cont::CV_SliderContainer, name::Symbol)
    name_str = string(name)
    if startswith(name_str, "slider_")
        inner_sym = Symbol(name_str[8:end])
        return cv_local2global(cont, cont.can_slider_l,
            cv_anchor(cont.can_slider, inner_sym)...)
    else
        return cv_anchor(cont.bounding_box, name)
    end
end
# }}}

struct CV_SliderCreateData{ccsT, dcbT, contextT <: CV_2DCanvasContext
                            } <: CV_CreateData
    slider_container   :: CV_SliderContainer{ccsT, dcbT}
    container_context  :: contextT
    internal_layout    :: CV_2DLayout
end

function cv_create_hslider(pixel_width::Integer, pixel_height::Integer,
        value_min::Real, value_max::Real,
        rulers::NTuple{N, CV_Ruler};
        attach::CV_AttachType=cv_south,
        decoraction_with_layout_and_position_callback=nothing) where {N}  # {{{

    if pixel_width < 0  ||  pixel_height < 0
        cv_error("pixel_width and pixel_height must be postive")
    end
    if !isfinite(value_min)  ||  !isfinite(value_max)
        cv_error("value_min and value_max must be finite")
    end
    if !(value_min < value_max)
        cv_error("value_min must be smaller than value_max")
    end
    pixel_width, pixel_height = Int32(pixel_width), Int32(pixel_height)
    value_min, value_max = Float64(value_min), Float64(value_max)
    res = pixel_width / (value_max - value_min)
    math_height = pixel_height / res

    slider_layout = CV_2DLayout()
    can_slider = CV_Math2DCanvas(
        value_min + math_height*1im, value_max + 0.0*1im, res)
    can_slider_l = cv_add_canvas!(slider_layout, can_slider, (0,0), (0,0))
    cc_can_slider = cv_create_context(can_slider)

    decorator_cb = (decoraction_with_layout_and_position_callback !== nothing) ?
        decoraction_with_layout_and_position_callback(
            slider_layout, can_slider_l) : nothing

    if N > 0
        can_axis_l = cv_ticks_labels(slider_layout, can_slider_l, attach, rulers)
    end

    bb = slider_layout.seen_boxes.bounding_box
    slider_container = CV_SliderContainer(
        cv_create_cairo_image_surface(cv_width(bb), cv_height(bb)),
        cv_width(bb), cv_height(bb),
        CV_Rectangle(cv_height(bb), Int32(0), Int32(0), cv_width(bb)),
        bb, can_slider, can_slider_l, cc_can_slider, decorator_cb)

    cc_container = cv_create_context(slider_container; fill_with=cv_color(1, 1, 1))
    if N >0 
        can_axis_l(cc_container)
    end

    return CV_SliderCreateData(slider_container, cc_container, slider_layout)
end # }}}


function cv_setup_hslider(setup::CV_SceneSetupChain,
        slider_data::CV_SliderCreateData,
        cont_l::CV_2DLayoutPosition,
        painter::CV_Painter, set_slider_value_func;
        react_to_actionpixel_update::Bool=true,
        react_to_statepixel_update::Bool=false) # {{{

    cont, cc_cont = slider_data.slider_container, slider_data.container_context

    reaction = (px, py, layout) -> begin
        resp = nothing
        can_layout = cv_get_can_layout(layout)
        cc_can_layout = cv_get_cc_can_layout(layout)
        lx, ly = cv_global2local(can_layout, cont_l, px, py)
        if 0 ≤ lx ≤ cv_width(cont_l.rectangle)  && 
                0 ≤ ly ≤ cv_height(cont_l.rectangle)
            x, y = cv_pixel2math(cont, cont.can_slider_l, lx, ly)
            resp = set_slider_value_func(x)
            cv_paint(cont.cc_can_slider, painter)
            cont.can_slider_l(cc_cont)
            cont_l(cc_can_layout)
        end
        return resp
    end

    redraw_func = layout -> begin
        cc_can_layout = cv_get_cc_can_layout(layout)
        cv_paint(cont.cc_can_slider, painter)
        cont.can_slider_l(cc_cont)
        cont_l(cc_can_layout)
        return nothing
    end

    draw_once_func = layout -> begin
        if cont.decorator_cb !== nothing
            cont.decorator_cb(cc_cont)
        end
        cv_paint(cont.cc_can_slider, painter)
        cont.can_slider_l(cc_cont)
        cc_can_layout = cv_get_cc_can_layout(layout)
        cont_l(cc_can_layout)
        return nothing
    end

    return cv_combine(setup; draw_once_func, redraw_func,
        actionpixel_update=react_to_actionpixel_update ? reaction : missing,
        statepixel_update=react_to_statepixel_update ? reaction : missing)
end # }}}


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
