macro import_compcodomains_huge()
    :(
        using ComplexVisual:
            cv_destroy,
            CV_CompareCodomainParts,
            cv_get_trafo1, cv_get_trafo2,
            cv_get_can_codomain1, cv_get_can_codomain2,
            cv_get_cc_can_codomain1, cv_get_cc_can_codomain2,
            cv_add,
            CV_CodomainsPosLayout, CV_ParamWithSlider,
            cv_do_comp_codomains_layout,
            cv_setup_comp_codomains_axis, cv_setup_comp_codomains_painters,
            cv_setup_comp_codomains_border, cv_setup_comp_codomains_scene,
            cv_setup_comp_slider_cb, cv_setup_comp_sliders,
            cv_scene_comp_codomains_std
    )
end

"""
Saves two codomains (and their contexts) together with two trafos in (the)
layout.
"""
struct CV_CompareCodomainParts{parentT<:CV_Abstract2DLayout,
        trafo1T, trafo2T, codomain1T, codomain2T,
        ccc1T, ccc2T} <: CV_2DLayoutWrapper   # {{{
    parent_layout   :: parentT
    trafo1          :: trafo1T
    trafo2          :: trafo2T
    can_codomain1   :: codomain1T
    can_codomain2   :: codomain2T
    cc_can_codomain1:: ccc1T
    cc_can_codomain2:: ccc2T
end

@layout_composition_getter(trafo1,           CV_CompareCodomainParts)
@layout_composition_getter(trafo2,           CV_CompareCodomainParts)
@layout_composition_getter(can_codomain1,    CV_CompareCodomainParts)
@layout_composition_getter(can_codomain2,    CV_CompareCodomainParts)
@layout_composition_getter(cc_can_codomain1, CV_CompareCodomainParts)
@layout_composition_getter(cc_can_codomain2, CV_CompareCodomainParts)

function cv_destroy(l::CV_CompareCodomainParts)
    cv_destroy(l.cc_can_codomain1)
    cv_destroy(l.cc_can_codomain2)
    cv_destroy(l.can_codomain1)
    cv_destroy(l.can_codomain2)
    cv_destroy(l.parent_layout)
    return nothing
end

"""
convenience function to combine domain and codomain (and their contexts)
together with a trafo to (the) layout.
"""
function cv_add(layout::CV_Abstract2DLayout,
        trafo1, trafo2,
        can_codomain1::codomain1T=CV_Math2DCanvas(-2.0+2.0im, 2.0-2.0im, 50),
        can_codomain2::codomain2T=CV_Math2DCanvas(-2.0+2.0im, 2.0-2.0im, 50),
        cc_can_codomain1::CV_CanvasContext=cv_create_context(can_codomain1),
        cc_can_codomain2::CV_CanvasContext=cv_create_context(can_codomain2)
        ) where {codomain1T<:CV_Canvas, codomain2T<:CV_Canvas}
    return CV_CompareCodomainParts(
        layout, trafo1, trafo2, can_codomain1, can_codomain2,
        cc_can_codomain1, cc_can_codomain2)
end
# }}}


"""
A layout with both codomains positioned.
"""
struct CV_CodomainsPosLayout{parentT<:CV_Abstract2DLayout,
        can1T, dcb1T, style1T, can2T, dcb2T, style2T} <: CV_2DLayoutWrapper # {{{
    parent_layout       :: parentT
    can_codomain1_l     :: CV_2DLayoutPosition{can1T, dcb1T, style1T}
    can_codomain2_l     :: CV_2DLayoutPosition{can2T, dcb2T, style2T}
end

@layout_composition_getter(can_codomain1_l,    CV_CodomainsPosLayout)
@layout_composition_getter(can_codomain2_l,    CV_CodomainsPosLayout)
# }}}


"""
All informations for a dynamic parameter (represented by a slider)
"""
struct CV_ParamWithSlider{posT, N, funcT, setupT} # {{{
    slider_pos             :: posT
    value_min              :: Real
    value_max              :: Real
    rulers                 :: NTuple{N, CV_Ruler}
    set_slider_value_func  :: funcT
    gap_below              :: Integer
    setup_cb               :: setupT
end

function CV_ParamWithSlider(;
        slider_pos=CV_TranslateByOffset(Float64),
        value_min=0.0, value_max=1.0,
        rulers=(CV_Ruler(cv_format_ticks("%.1f", 0.0:0.5:1.0...)),),
        set_slider_value_func=nothing,
        gap_below=40, setup_cb=cv_setup_comp_slider_cb)
    return CV_ParamWithSlider(slider_pos, value_min, value_max, rulers,
        set_slider_value_func, gap_below, setup_cb)
end # }}}


"""
Do a left-right layout of the two codomains with a gap between.
"""
function cv_do_comp_codomains_layout(layout::CV_Abstract2DLayout,
        gap_domains::Integer=50) # {{{
    can_codomain1 = cv_get_can_codomain1(layout)
    can_codomain2 = cv_get_can_codomain2(layout)
    can_codomain1_l = cv_add_canvas!(layout, can_codomain1,
        cv_anchor(can_codomain1, :northwest), (0, 0))
    can_codomain2_l = cv_add_canvas!(layout, can_codomain2,
        cv_anchor(can_codomain2, :west),
        cv_translate(cv_anchor(can_codomain1_l, :east), gap_domains, 0))

    return CV_CodomainsPosLayout(layout, can_codomain1_l, can_codomain2_l)
end # }}}


"""
setup rulers for codomains.
"""
function cv_setup_comp_codomains_axis(setup::CV_SceneSetupChain,
        codomain1_re_rulers::NTuple{A, CV_Ruler},
        codomain1_im_rulers::NTuple{B, CV_Ruler}=codomain1_re_rulers,
        codomain2_re_rulers::NTuple{C, CV_Ruler}=codomain1_re_rulers,
        codomain2_im_rulers::NTuple{D, CV_Ruler}=codomain1_im_rulers
        ) where {A, B, C, D}   # {{{
    layout = setup.layout
    can_codomain1_l = cv_get_can_codomain1_l(layout)
    can_codomain2_l = cv_get_can_codomain2_l(layout)

    codomain1_re_axis = cv_ticks_labels(layout, can_codomain1_l,
        cv_south, codomain1_re_rulers)
    codomain1_im_axis = cv_ticks_labels(layout, can_codomain1_l,
        cv_west, codomain1_im_rulers)
    codomain2_re_axis = cv_ticks_labels(layout, can_codomain2_l,
        cv_south, codomain2_re_rulers)
    codomain2_im_axis = cv_ticks_labels(layout, can_codomain2_l,
        cv_west, codomain2_im_rulers)

    draw_once_func = future_layout -> begin
        cc_can_layout = cv_get_cc_can_layout(future_layout)
        codomain1_re_axis(cc_can_layout)
        codomain1_im_axis(cc_can_layout)
        codomain2_re_axis(cc_can_layout)
        codomain2_im_axis(cc_can_layout)
        return nothing
    end
    return cv_combine(setup; draw_once_func)
end # }}}


function cv_setup_comp_codomains_painters(setup::CV_SceneSetupChain,
        painter1_trafo, painter1_notrafo,
        painter2_trafo, painter2_notrafo) # {{{

    layout = setup.layout
    trafo1, trafo2 = cv_get_trafo1(layout), cv_get_trafo2(layout)

    cc_can_codomain1 = cv_get_cc_can_codomain1(layout)
    cc_can_codomain2 = cv_get_cc_can_codomain2(layout)

    p1pc = CV_2DDomainCodomainPaintingContext(trafo1, nothing, nothing)
    p2pc = CV_2DDomainCodomainPaintingContext(trafo2, nothing, nothing)

    ec = CV_2DDomainCodomainPaintingContext(identity, nothing, nothing)

    redraw_func = layout -> begin
        if painter1_trafo !== nothing
            cv_clear_cache(painter1_trafo)
            cv_paint(cc_can_codomain1, painter1_trafo, p1pc)
        end
        if painter1_notrafo !== nothing
            cv_clear_cache(painter1_notrafo)
            cv_paint(cc_can_codomain1, painter1_notrafo, ec)
        end
        if painter2_trafo !== nothing
            cv_clear_cache(painter2_trafo)
            cv_paint(cc_can_codomain2, painter2_trafo, p2pc)
        end
        if painter2_notrafo !== nothing
            cv_clear_cache(painter2_notrafo)
            cv_paint(cc_can_codomain2, painter2_notrafo, ec)
        end
        return nothing
    end

    return cv_combine(setup; redraw_func)
end  # }}}

"""
creates borders for the two codomains.
"""
function cv_setup_comp_codomains_border(setup::CV_SceneSetupChain;
        width::Integer=2, style=cv_black) # {{{
    layout = setup.layout
    codomain1_border = cv_border(layout, cv_get_can_codomain1_l(layout), width;
        style)
    codomain2_border = cv_border(layout, cv_get_can_codomain2_l(layout), width;
        style)

    draw_once_func = future_layout -> begin
        cc_can_layout = cv_get_cc_can_layout(future_layout)
        codomain1_border(cc_can_layout)
        codomain2_border(cc_can_layout)
        return nothing
    end

    return cv_combine(setup; draw_once_func)
end # }}}

"""
create scene for codomains with sliders.
"""
function cv_setup_comp_codomains_scene(setup::CV_SceneSetupChain)  # {{{
    layout = setup.layout
    can_codomain1_l = cv_get_can_codomain1_l(layout)
    can_codomain2_l = cv_get_can_codomain2_l(layout)

    redraw_func = future_layout -> begin
        cc_can_layout = cv_get_cc_can_layout(future_layout)
        can_codomain1_l(cc_can_layout)
        can_codomain2_l(cc_can_layout)
        return nothing
    end

    setup = cv_combine(setup; redraw_func)
    return cv_setup_2dminimal_scene(setup)
end # }}}

"""
creates default slider with `width` centered at `mid` and starting at `bottom`
with a value-mark painter.
"""
function cv_setup_comp_slider_cb(setup, param::CV_ParamWithSlider,
        width::Int32, mid::Int32, bottom::Int32) # {{{

    layout = setup.layout

    slider_data = cv_create_hslider(width, 20,
        param.value_min, param.value_max, param.rulers; attach=cv_north,
        decoraction_with_layout_and_position_callback=(inner_layout, pos) ->
            cv_border(inner_layout, pos, 1))
    
    slider_container = slider_data.slider_container
    slider_l = cv_add_canvas!(layout,
        slider_container,
        cv_anchor(slider_container, :slider_south, slider_container, :south),
        (mid, bottom - Int32(param.gap_below)))

    if param.set_slider_value_func === nothing
        set_slider_value_func = z -> begin
            slider_pos.value = max(min(z, value_max), value_min)
            return CV_Response(; redraw_flag=true)
        end
    else
        set_slider_value_func = param.set_slider_value_func
    end

    bg_painter = cv_color(.8, .8, .8) ↦ CV_2DCanvasFillPainter()
    mark_painter = (cv_op_source → cv_color(0, 0, 1) → cv_linewidth(2)) ↦
        CV_2DValueMarkPainter(param.slider_pos, 0.0, 
            imag(slider_container.can_slider.corner_ul), false)

    setup = cv_setup_hslider(setup, slider_data, slider_l,
        bg_painter → mark_painter, set_slider_value_func)
    return setup, slider_l.rectangle.bottom
end  # }}}

"""
setup sliders for parameters
"""
function cv_setup_comp_sliders(setup,
        params::NTuple{N, CV_ParamWithSlider}) where {N}  # {{{

    layout = setup.layout
    can_codomain1_l = cv_get_can_codomain1_l(layout)
    can_codomain2_l = cv_get_can_codomain2_l(layout)

    r1, r2 = can_codomain1_l.rectangle, can_codomain2_l.rectangle
    width, mid = r2.right - r1.left, cv_half(r2.right + r1.left)
    bottom = min(r1.bottom, r2.bottom)

    for param in params[N:-1:1]
        setup, bottom = param.setup_cb(setup, param, width, mid, bottom)
    end
    return setup
end # }}}


"""
creates "standard" scene with two codomains in left-right layout and a 
slider (north).
"""
function cv_scene_comp_codomains_std(
        params::NTuple{N, CV_ParamWithSlider}, trafo1, trafo2,
        codomain1, codomain2;
        gap_domains::Integer=80, padding=30,
        codomain1_re_rulers::NTuple{A, CV_Ruler},
        codomain1_im_rulers::NTuple{B, CV_Ruler}=codomain1_re_rulers,
        codomain2_re_rulers::NTuple{C, CV_Ruler}=codomain1_re_rulers,
        codomain2_im_rulers::NTuple{D, CV_Ruler}=codomain1_im_rulers,
        painter1_trafo = CV_Math2DCanvasPortraitPainter(),
        painter2_trafo = CV_Math2DCanvasPortraitPainter(),
        painter1_notrafo = nothing,
        painter2_notrafo = nothing) where {A, B, C, D, N} # {{{

    layout = CV_2DLayout()
    layout = cv_add(layout, trafo1, trafo2, codomain1, codomain2)
    layout = cv_do_comp_codomains_layout(layout, gap_domains)

    setup = CV_MinimalSetupChain(layout)
    setup = cv_setup_comp_codomains_painters(setup,
        painter1_trafo, painter1_notrafo, painter2_trafo, painter2_notrafo)
    setup = cv_setup_comp_codomains_axis(setup,
        codomain1_re_rulers, codomain1_im_rulers,
        codomain2_re_rulers, codomain2_im_rulers)
    setup = cv_setup_comp_codomains_border(setup)
    setup = cv_setup_comp_sliders(setup, params)
    padding > 0 && cv_add_padding!(setup.layout, padding)

    setup = cv_setup_comp_codomains_scene(setup)
    return setup.layout
end # }}}

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
