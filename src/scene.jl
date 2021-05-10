macro import_scene_huge()
    :(
        using ComplexVisual:
            CV_SceneSetupChain, CV_2DScene,
            CV_MinimalSetupChain, CV_2DMinimalScene,
            cv_setup_2dminimal_scene,
            cv_setup_cycle_state
    )
end

import Base: show

"""
Scene construction with a chain idea.

## What is a Scene?

A scene is layout together with all the callbacks/functions to update/draw all
relevant parts. Often painters depends on "degrees of freedom" that change.
[The change of such degrees of freedom may be triggered by a mouse or other
"events".]

Scenes are constructed step-by-step. If an new painter is "added" to the
scene, there must be a possibility to ensure, that also this new painter
is called if the degrees of freedom changed.

Here is, where a `CV_SceneSetupChain` helps.

## How does this work?

All callback functions are gathered in vectors. This is the point where
the type information about the callback functions are completely lost.
For the return value (which is always `nothing`) this is not a problem.
For the call this is a tradeoff: If elements of such a vector are
called then this are purely "runtime"-calls (i.e. what to call, with
what types, etc. is determined at runtime). That's the negative part.
The positive part: Julia doesn't need to do the type-book-keeping (which
is rather tough if e.g. types informations should not be lost and all
these methods are nested: meaning every new method calls the old one first;
because every call is typically are closure with a lot of types;
preserving the type-info with this way would result in an unbearable
compile-time).

If a new part (e.g. a painter) changes the layout then a new
`CV_SceneSetupChain` is built (with the new layout). This is very important,
because for the (nested) layouts all type informations are preserved (also
in the `CV_SceneSetupChain`). So the painter calls (which use parts of
the layout) can make use of this type informations.

All the given callback functions are appended to the callback vectors.

Required fields:
* `layout`
* `draw_once_func`:      callbacks that a called after the layout is fixed
                         and a Layout-Canvas was constructed.
                         Argument: last layout
* `actionpixel_update`:  callbacks that are called after "the main action"
                         occured (e.g. mouse dragged).
                         Arguments: pixel_x, pixel_y (both w.r.t. Layout Canvas)
* `statepixel_update`:   callbacks that are called after the
                         "state-change action" occured.
                         Arguments: pixel_x, pixel_y (both w.r.t. Layout Canvas)
* `redraw_func`:         callbacks that are called after a redraw
                         is triggered (e.g. because some trafo-parameters have
                         changed; typically all painters react and clear their
                         caches and recompute their paintings)
"""
abstract type CV_SceneSetupChain end


"""
A minimalistic `CV_SceneSetupChain`.
"""
struct CV_MinimalSetupChain{layoutT} <: CV_SceneSetupChain # {{{
    layout               :: layoutT
    draw_once_func       :: Vector{Any}
    actionpixel_update   :: Vector{Any}
    statepixel_update    :: Vector{Any}
    redraw_func          :: Vector{Any}
end

function CV_MinimalSetupChain(layout)
    return CV_MinimalSetupChain(layout, Vector(), Vector(), Vector(), Vector())
end

"""
"update" a scene-setup by new layout and/or by adding callback-functions.
"""
function cv_combine(old::CV_MinimalSetupChain;
        layout=missing, draw_once_func=missing,
        actionpixel_update=missing, statepixel_update=missing,
        redraw_func=missing)
    new = ismissing(layout) ? old : CV_MinimalSetupChain(layout,
        old.draw_once_func, old.actionpixel_update, old.statepixel_update)
    !ismissing(draw_once_func) && push!(new.draw_once_func, draw_once_func)
    !ismissing(actionpixel_update) && push!(new.actionpixel_update, actionpixel_update)
    !ismissing(statepixel_update) && push!(new.statepixel_update, statepixel_update)
    !ismissing(redraw_func) && push!(new.redraw_func, redraw_func)
    return new
end

# }}}


"""
A scene is a framed layout which has everything to be shown and to be used
interactively.

A `CV_2DScene` must support:
`cv_get_actionpixel_update`, `cv_get_statepixel_update`,
`cv`get_redraw_func`
"""
abstract type CV_2DScene <: CV_Framed2DLayout
    # actionpixel_update
    # statepixel_update
    # redraw_func
end


"""
A minimalistic `CV_2DScene`.
"""
struct CV_2DMinimalScene{parentT, apuT, spuT, rfT} <: CV_2DScene    # {{{
    parent_layout            :: parentT
    actionpixel_update       :: apuT
    statepixel_update        :: spuT
    redraw_func              :: rfT
end

@layout_composition_getter(actionpixel_update,      CV_2DMinimalScene)
@layout_composition_getter(statepixel_update,       CV_2DMinimalScene)
@layout_composition_getter(redraw_func,             CV_2DMinimalScene)


function cv_setup_2dminimal_scene(setup::CV_SceneSetupChain)
    can_layout = cv_canvas_for_layout(setup.layout)
    cc_can_layout = cv_create_context(can_layout)
    layout = CV_MinimalFramed2DLayout(setup.layout, can_layout, cc_can_layout)

    scene_actionpixel_update = (px, py) -> begin
        for func in setup.actionpixel_update
            func(px, py, layout)
        end
        return nothing
    end

    scene_statepixel_update = (px, py) -> begin
        for func in setup.statepixel_update
            func(px, py, layout)
        end
        return nothing
    end

    scene_redraw_func = () -> begin
        for func in setup.redraw_func
            func(layout)
        end
        return nothing
    end

    scene = CV_2DMinimalScene(layout,
        scene_actionpixel_update, scene_statepixel_update,
        scene_redraw_func)
    for func in setup.draw_once_func
        func(scene)
    end

    return cv_combine(setup; layout=scene)
end


# }}}


function cv_setup_cycle_state(setup::CV_SceneSetupChain)
    state_counter = cv_get_state_counter(setup.layout)

    update_state_func = z -> begin
        state_counter()
        return nothing
    end
    return cv_combine(setup; update_state_func)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
