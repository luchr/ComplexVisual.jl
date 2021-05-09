macro import_lrdomains_huge()
    :(
        using ComplexVisual:
            cv_destroy,
            CV_DomainCodomainLayout, 
            cv_get_trafo, cv_get_can_domain, cv_get_can_codomain,
            cv_get_cc_can_domain, cv_get_cc_can_codomain,
            cv_add, 
            CV_DomainPosLayout, CV_CodomainPosLayout,
            cv_get_can_domain_l, cv_get_can_codomain_l,
            cv_do_lr_layout,
            CV_DomainCodomainScene,
            cv_get_can_layout, cv_get_cc_can_layout,
            cv_get_update_math_domains, cv_get_actionpixel_update,
            cv_get_statepixel_update,
            cv_setup_can_layout_drawing_cb,
            cv_setup_domain_codomain_scene,
            cv_setup_lr_axis, cv_setup_lr_painters, cv_setup_lr_border,
            cv_scene_lr_start, cv_scene_lr_std,
            CV_LRSetupChain, cv_combine
    )
end

import Base:show


"""
SetupChain with layout (type inferable) and a vector for every
callback-type where all the callback functions are stored (type inference
is lost). See `CV_SceneSetupChain` for the reasons of this tradeoff.
"""
struct CV_LRSetupChain{layoutT} <: CV_SceneSetupChain # {{{
    layout               :: layoutT
    draw_once_func       :: Vector{Any}
    actionpixel_update   :: Vector{Any}
    statepixel_update    :: Vector{Any}
    update_painter_func  :: Vector{Any}
    update_state_func    :: Vector{Any}
end

function CV_LRSetupChain(layout)
    return CV_LRSetupChain(layout, Vector(), Vector(), Vector(), 
        Vector(), Vector())
end

function cv_combine(old::CV_LRSetupChain;
        layout=missing, draw_once_func=missing, update_painter_func=missing,
        update_state_func=missing, actionpixel_update=missing,
        statepixel_update=missing)
    new = ismissing(layout) ? old : CV_LRSetupChain(layout,
        old.draw_once_func, old.actionpixel_update, old.statepixel_update,
        old.update_painter_func, old.update_state_func)
    !ismissing(draw_once_func) && push!(new.draw_once_func, draw_once_func)
    !ismissing(actionpixel_update) && push!(new.actionpixel_update, actionpixel_update)
    !ismissing(statepixel_update) && push!(new.statepixel_update, statepixel_update)
    !ismissing(update_painter_func) && push!(new.update_painter_func, update_painter_func)
    !ismissing(update_state_func) && push!(new.update_state_func, update_state_func)
    return new
end
# }}}



"""
Saves domain and codomain (and their contexts) together with a trafo in
(the) layout.
"""
struct CV_DomainCodomainLayout{parentT<:CV_Abstract2DLayout,
                    trafoT, domainT<:CV_Canvas, codomainT<:CV_Canvas,
                    ccdT, cccT} <: CV_2DLayoutWrapper  # {{{
    parent_layout   :: parentT
    trafo           :: trafoT
    can_domain      :: domainT
    can_codomain    :: codomainT
    cc_can_domain   :: ccdT
    cc_can_codomain :: cccT
end

@layout_composition_getter(trafo,           CV_DomainCodomainLayout)
@layout_composition_getter(can_domain,      CV_DomainCodomainLayout)
@layout_composition_getter(can_codomain,    CV_DomainCodomainLayout)
@layout_composition_getter(cc_can_domain,   CV_DomainCodomainLayout)
@layout_composition_getter(cc_can_codomain, CV_DomainCodomainLayout)

function cv_destroy(l::CV_DomainCodomainLayout)
    cv_destroy(l.cc_can_domain)
    cv_destroy(l.cc_can_codomain)
    cv_destroy(l.can_domain)
    cv_destroy(l.can_codomain)
    cv_destroy(l.parent_layout)
    return nothing
end

function show(io::IO, l::CV_DomainCodomainLayout)
    fio = IOContext(io, :compact => true)
    print(io, "CV_DomainCodomainLayout(trafo: "); show(fio, l.trafo)
    print(io, ", can_domain: ");                  show(io, l.can_domain)
    print(io, ", can_codomain: ");                show(io, l.can_codomain)
    print(io, ", parent_layout: ");               show(io, l.parent_layout)
    print(io, ')')
    return nothing
end

function show(io::IO, m::MIME{Symbol("text/plain")}, l::CV_DomainCodomainLayout)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent, :compact => true)
    println(io, "CV_DomainCodomainLayout(")
    print(io, indent, "trafo: "); show(iio, m, l.trafo); println(io)
    print(io, indent, "can_domain: "); show(iio, m, l.can_domain); println(io)
    print(io, indent, "can_codomain: "); show(iio, m, l.can_codomain); println(io)
    print(io, indent, "parent_layout: "); show(iio, m, l.parent_layout); println(io)
    print(io, outer_indent, ')')
    return nothing
end

"""
convenience function to combine domain and codomain (and their contexts)
together with a trafo to (the) layout.
"""
function cv_add(layout::CV_Abstract2DLayout, trafo,
        can_domain::domainT=CV_Math2DCanvas(-2.0+2.0im, 2.0-2.0im, 50),
        can_codomain::codomainT=CV_Math2DCanvas(-2.0+2.0im, 2.0-2.0im, 50),
        cc_can_domain::CV_CanvasContext=cv_create_context(can_domain),
        cc_can_codomain::CV_CanvasContext=cv_create_context(can_codomain)
        ) where {domainT<:CV_Canvas, codomainT<:CV_Canvas}

    return CV_DomainCodomainLayout(
        layout, trafo, can_domain, can_codomain, 
        cc_can_domain, cc_can_codomain)
end

# }}}

"""
A `CV_DomainPosLayout` with domain positioned.
"""
struct CV_DomainPosLayout{parentT<:CV_Abstract2DLayout, canT, dcbT, styleT
                          } <: CV_2DLayoutWrapper    # {{{
    parent_layout   :: parentT
    can_domain_l    :: CV_2DLayoutPosition{canT, dcbT, styleT}
end

@layout_composition_getter(can_domain_l, CV_DomainPosLayout)

function show(io::IO, l::CV_DomainPosLayout)
    print(io, "CV_DomainPosLayout(can_domain_l: ")
    show(io, l.can_domain_l)
    print(io, ", parent_layout: ")
    show(io, l.parent_layout)
    return nothing
end

function show(io::IO, m::MIME{Symbol("text/plain")}, l::CV_DomainPosLayout)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, "CV_DomainPosLayout(")
    print(io, indent, "can_domain_l: "); show(iio, m, l.can_domain_l); println(io)
    print(io, indent, "parent_layout: "); show(iio, m, l.parent_layout); println(io)
    print(io, outer_indent, ')')
    return nothing
end

# }}}

"""
A `CV_CodomainPosLayout` with codomain positioned.
"""
struct CV_CodomainPosLayout{parentT<:CV_Abstract2DLayout,canT, dcbT, styleT
                            } <: CV_2DLayoutWrapper   # {{{
    parent_layout   :: parentT
    can_codomain_l  :: CV_2DLayoutPosition{canT, dcbT, styleT}
end

@layout_composition_getter(can_codomain_l, CV_CodomainPosLayout)

function show(io::IO, l::CV_CodomainPosLayout)
    print(io, "CV_CodomainPosLayout(can_codomain_l: ")
    show(io, l.can_codomain_l)
    print(io, ", parent_layout: ")
    show(io, l.parent_layout)
    return nothing
end

function show(io::IO, m::MIME{Symbol("text/plain")}, l::CV_CodomainPosLayout)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, "CV_CodomainPosLayout(")
    print(io, indent, "can_codomain_l: "); show(iio, m, l.can_codomain_l); println(io)
    print(io, indent, "parent_layout: "); show(iio, m, l.parent_layout); println(io)
    print(io, outer_indent, ")")
    return nothing
end   # }}}

"""
Do a left-right layout of domain and codomain canvas with a gap between.
"""
function cv_do_lr_layout(layout::CV_Abstract2DLayout, gap::Integer=50) # {{{
    can_domain = cv_get_can_domain(layout)
    can_codomain = cv_get_can_codomain(layout)
    can_domain_l = cv_add_canvas!(layout, can_domain,
        cv_anchor(can_domain, :northwest), (0, 0))
    can_codomain_l = cv_add_canvas!(layout, can_codomain,
        cv_anchor(can_codomain, :west),
        cv_translate(cv_anchor(can_domain_l, :east), gap, 0))
    return CV_CodomainPosLayout(
        CV_DomainPosLayout(layout, can_domain_l), can_codomain_l)
end # }}}

"""
Scene with domain and codomain painter update and domain pixel2coor.
"""
struct CV_DomainCodomainScene{parentT, ccclT, apuT, spuT,
                              umdT} <: CV_2DLayoutWrapper # {{{
    parent_layout            :: parentT
    can_layout               :: CV_2DLayoutCanvas
    cc_can_layout            :: ccclT
    actionpixel_update       :: apuT
    statepixel_update        :: spuT
    update_math_domains      :: umdT
end

@layout_composition_getter(can_layout,              CV_DomainCodomainScene)
@layout_composition_getter(cc_can_layout,           CV_DomainCodomainScene)
@layout_composition_getter(actionpixel_update,      CV_DomainCodomainScene)
@layout_composition_getter(statepixel_update,       CV_DomainCodomainScene)
@layout_composition_getter(update_math_domains,     CV_DomainCodomainScene)

function cv_destroy(scene::CV_DomainCodomainScene)
    cv_destroy(scene.cc_can_layout)
    cv_destroy(scene.can_layout)
    cv_destroy(scene.parent_layout)
    return nothing
end

function show(io::IO, s::CV_DomainCodomainScene)
    print(io, "CV_DomainCodomainScene(can_layout: "); show(io, s.can_layout)
    print(io, ", parent_layout: "); show(io, s.parent_layout)
    print(io, ')')
    return nothing
end

function show(io::IO, m::MIME{Symbol("text/plain")}, s::CV_DomainCodomainScene)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, "CV_DomainCodomainScene(")
    print(io, indent, "can_layout: "); show(iio, m, s.can_layout); println(io)
    print(io, indent, "parent_layout: "); show(iio, m, s.parent_layout); println(io)
    print(io, outer_indent, ')')
    return nothing
end

"""
create scene for given scene setup.
"""
function cv_setup_domain_codomain_scene(setup::CV_SceneSetupChain)
    layout = setup.layout

    can_domain_l = cv_get_can_domain_l(layout)
    can_codomain_l = cv_get_can_codomain_l(layout)

    can_layout = cv_canvas_for_layout(layout)
    cc_can_layout = cv_create_context(can_layout)

    update_math_domains = (z) -> begin
        for func in setup.update_painter_func
            func(z)
        end
        can_domain_l(cc_can_layout)
        can_codomain_l(cc_can_layout)
        return nothing
    end

    actionpixel_update = (px, py) -> begin
        canvas = can_domain_l.canvas
        lx, ly = cv_global2local(can_layout, can_domain_l, px, py)
        if (lx < 0) || (ly < 0) ||
              (lx > canvas.pixel_width) || (ly > canvas.pixel_height)
            return nothing
        end
        x, y = cv_pixel2math(canvas, lx, ly)
        update_math_domains(x + y*1im)
        return nothing
    end

    statepixel_update = (px, py) -> begin
        canvas = can_domain_l.canvas
        lx, ly = cv_global2local(can_layout, can_domain_l, px, py)
        if (lx < 0) || (ly < 0) ||
              (lx > canvas.pixel_width) || (ly > canvas.pixel_height)
            return nothing
        end
        x, y = cv_pixel2math(canvas, lx, ly)
        for func in setup.update_state_func
            func(x + y*1im)
        end
        return nothing
    end

    scene_actionpixel_update = (px, py) -> begin
        for func in setup.actionpixel_update
            func(px, py)
        end
        actionpixel_update(px, py)
    end
    scene_statepixel_update = (px, py) -> begin
        for func in setup.statepixel_update
            func(px, py)
        end
        statepixel_update(px, py)
    end

    new_layout = CV_DomainCodomainScene(
        layout, can_layout, cc_can_layout,
        scene_actionpixel_update, scene_statepixel_update,
        update_math_domains)
    return cv_combine(setup; layout=new_layout)
end
# }}}

function cv_setup_can_layout_drawing_cb(setup::CV_SceneSetupChain, drawing_cb)
    draw_once_func = layout -> begin
        drawing_cb(cv_get_cc_can_layout(layout))
        return nothing
    end
    return cv_combine(setup; draw_once_func)
end

function cv_setup_lr_axis(setup::CV_SceneSetupChain,
        domain_re_ruler::CV_Ruler, domain_im_ruler::CV_Ruler,
        codomain_re_ruler::CV_Ruler, codomain_im_ruler::CV_Ruler) # {{{
    return cv_setup_lr_axis(setup,
        (domain_re_ruler, ), (domain_im_ruler, ),
        (codomain_re_ruler, ), (codomain_im_ruler, ))
end # }}}

function cv_setup_lr_axis(setup::CV_SceneSetupChain,
        domain_re_rulers::NTuple{A, CV_Ruler},
        domain_im_rulers::NTuple{B, CV_Ruler},
        codomain_re_rulers::NTuple{C, CV_Ruler},
        codomain_im_rulers::NTuple{D, CV_Ruler}) where {A, B, C, D} # {{{

    layout = setup.layout
    can_domain_l = cv_get_can_domain_l(layout)
    can_codomain_l = cv_get_can_codomain_l(layout)

    domain_re_axis = cv_ticks_labels(layout, can_domain_l,
        cv_south, domain_re_rulers)
    domain_im_axis = cv_ticks_labels(layout, can_domain_l,
        cv_west, domain_im_rulers)
    codomain_re_axis = cv_ticks_labels(layout, can_codomain_l,
        cv_south, codomain_re_rulers)
    codomain_im_axis = cv_ticks_labels(layout, can_codomain_l,
        cv_west, codomain_im_rulers)

    draw_once_func = future_layout -> begin
        cc_can_layout = cv_get_cc_can_layout(future_layout)
        domain_re_axis(cc_can_layout)
        domain_im_axis(cc_can_layout)
        codomain_re_axis(cc_can_layout)
        codomain_im_axis(cc_can_layout)
        return nothing
    end
    return cv_combine(setup; draw_once_func)
end  # }}}

function cv_setup_lr_axis(setup::CV_SceneSetupChain;
        label_style::CV_ContextStyle = cv_color(0,0,0) → 
                cv_fontface("serif") → cv_fontsize(20)) where {A, B, C, D} # {{{

    layout = setup.layout
    get_range_mean = (a, b) -> (
        range(ceil(Int64, a); stop=floor(Int64, b)), a+0.5*(b-a))
    function format_ticks(a, b)
        ra = range(ceil(Int64, a); stop=floor(Int64, b))
        mean = a+0.5*(b-a)
        return isempty(ra) ? cv_format_ticks("%.2f", mean) :
                             cv_format_ticks("%.0f", ra...)
    end

    can_domain = cv_get_can_domain(layout)
    can_codomain = cv_get_can_codomain(layout)

    domain_re_ticks = format_ticks(
        real(can_domain.corner_ul), real(can_domain.corner_lr))
    domain_im_ticks = format_ticks(
        imag(can_domain.corner_lr), imag(can_domain.corner_ul))
    codomain_re_ticks = format_ticks(
        real(can_codomain.corner_ul), real(can_codomain.corner_lr))
    codomain_im_ticks = format_ticks(
        imag(can_codomain.corner_lr), imag(can_codomain.corner_ul))
    app = CV_TickLabelAppearance(; label_style)

    return cv_setup_lr_axis(setup,
        CV_Ruler(domain_re_ticks, app), CV_Ruler(domain_im_ticks, app),
        CV_Ruler(codomain_re_ticks, app), CV_Ruler(codomain_im_ticks, app))
end  # }}}


function cv_setup_lr_painters(setup::CV_SceneSetupChain,
        cut_test, img_painter,
        portrait_painter_domain, portrait_painter_codomain,
        parallel_lines_painter) # {{{

    layout = setup.layout
    translate_pos = CV_TranslateByOffset(ComplexF64)
    state_counter = cv_get_state_counter(layout)
    trafo = cv_get_trafo(layout)
    trafo_translate = w -> trafo(translate_pos(w))

    cc_can_domain = cv_get_cc_can_domain(layout)
    cc_can_codomain = cv_get_cc_can_codomain(layout)

    ppdc = CV_2DDomainCodomainPaintingContext(trafo, nothing, nothing)
    ppcc = CV_2DDomainCodomainPaintingContext(identity, nothing, nothing)

    gpdc = CV_2DDomainCodomainPaintingContext(translate_pos, nothing, nothing)
    gpcc = CV_2DDomainCodomainPaintingContext(trafo_translate, translate_pos, cut_test)

    update_painter_func = z -> begin
        translate_pos.value = z

        if portrait_painter_domain !== nothing
            cv_paint(cc_can_domain, portrait_painter_domain, ppdc)
        end
        if portrait_painter_codomain !== nothing
            cv_paint(cc_can_codomain, portrait_painter_codomain, ppcc)
        end

        if state_counter.value == 1
            if img_painter !== nothing
                cv_paint(cc_can_domain, img_painter, gpdc)
                cv_paint(cc_can_codomain, img_painter, gpcc)
            end
        elseif state_counter.value == 2
            if parallel_lines_painter !== nothing
                cv_paint(cc_can_domain, parallel_lines_painter, gpdc)
                cv_paint(cc_can_codomain, parallel_lines_painter, gpcc)
            end
        end
        return nothing
    end

    return cv_combine(setup; update_painter_func)
end # }}}

const cv_setup_lr_painters_default_phs = cv_op_source → 
                cv_antialias(Cairo.ANTIALIAS_BEST) →
                cv_linewidth(3) → cv_color(0,0,0)
const cv_setup_lr_painters_default_vhs = cv_op_source → 
                cv_antialias(Cairo.ANTIALIAS_BEST) →
                cv_linewidth(3) → cv_color(1,1,1)
const cv_setup_lr_painters_default_hlines = cv_parallel_lines(1.0+0.0im)
const cv_setup_lr_painters_default_vlines = cv_parallel_lines(0.0+1.0im)
const cv_setup_lr_painters_default_imgps = cv_op_over → 
                     cv_antialias(Cairo.ANTIALIAS_NONE)

"""
convenience function for `cv_setup_lr_painters` with all
arguments as keyword arguments.

Because julia functions do *not* specialize on keyword parameters, we
need to call `cv_create_scene_with_lr_painters` with positional parameters,
because we need type inference there!
"""
function cv_setup_lr_painters(setup::CV_SceneSetupChain;
        cut_test=nothing,
        canvas_test_img=cv_example_image_letter(),
        img_painter_style=cv_setup_lr_painters_default_imgps,
        img_painter=missing,
        portrait_painter_domain=CV_Math2DCanvasPortraitPainter(),
        portrait_painter_codomain=CV_Math2DCanvasPortraitPainter(),
        parallel_hlines_style=cv_setup_lr_painters_default_phs,
        parallel_vlines_style=cv_setup_lr_painters_default_vhs,
        parallel_hlines=cv_setup_lr_painters_default_hlines,
        parallel_vlines=cv_setup_lr_painters_default_vlines,
        parallel_lines_painter=missing) # {{{
    ip = (canvas_test_img === nothing || ismissing(img_painter)) ? (
        img_painter_style ↦ CV_Math2DCanvasPainter(canvas_test_img)) : 
        img_painter
    plp = ismissing(parallel_lines_painter) ? (
        (parallel_hlines_style ↦ parallel_hlines) →
        (parallel_vlines_style ↦ parallel_vlines)) : parallel_lines_painter
    return cv_setup_lr_painters(
        setup, cut_test, ip,
        portrait_painter_domain, portrait_painter_codomain, plp)

end # }}}

"""
creates borders for the domain and codomain canvas.
"""
function cv_setup_lr_border(setup::CV_SceneSetupChain; width::Integer=2,
        style=cv_color(0,0,0))
    layout = setup.layout
    domain_border = cv_border(layout, cv_get_can_domain_l(layout), width;
        style)
    codomain_border = cv_border(layout, cv_get_can_codomain_l(layout), width;
        style)

    draw_once_func = future_layout -> begin
        cc_can_layout = cv_get_cc_can_layout(future_layout)
        domain_border(cc_can_layout)
        codomain_border(cc_can_layout)
        return nothing
    end

    return cv_combine(setup; draw_once_func)
end

function cv_scene_lr_start(scene::CV_SceneSetupChain;
        z_start::Union{ComplexF64, Missing}=missing,
        state_start::Union{Int, Missing}=missing) # {{{
    
    layout = scene.layout
    z = 0.0+0.0im
    if ismissing(z_start)
        can_codomain = cv_get_can_codomain(layout)
        z = (can_codomain.corner_ul + can_codomain.corner_lr)/2 
    else
        z = z_start :: ComplexF64
    end
    if !ismissing(state_start)
        cv_set_value!(cv_get_state_counter(layout), state_start)
    end
    cv_get_update_math_domains(layout)(z)
    for func in scene.draw_once_func
        func(scene.layout)
    end
    return nothing
end # }}}

"""
creates "standard" scene with domain and codomain in a left-right layout.
"""
function cv_scene_lr_std(trafo,
        domain, codomain; cut_test=nothing, gap=80,
        axis_label_style=cv_color(0,0,0) → 
                  cv_fontface("sans-serif", Cairo.FONT_WEIGHT_BOLD) → 
                  cv_fontsize(20), padding=30) # {{{
    layout = CV_StateLayout(CV_2DLayout(), CV_CyclicValue(2))
    layout = cv_do_lr_layout(cv_add(layout, trafo, domain, codomain), gap)

    setup = cv_setup_cycle_state(CV_LRSetupChain(layout))
    setup = cv_setup_lr_painters(setup; cut_test)
    setup = cv_setup_lr_axis(setup; label_style=axis_label_style)
    setup = cv_setup_lr_border(setup)
    padding > 0 && cv_add_padding!(setup.layout, padding)
    setup = cv_setup_domain_codomain_scene(setup)
    cv_scene_lr_start(setup)
    return setup.layout
end # }}}


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
