macro import_layout_huge()
    :(
        using ComplexVisual:
            cv_destroy,
            CV_Layout, CV_Abstract2DLayout, CV_2DLayoutWrapper, CV_2DLayout,
            CV_2DLayoutPosition, CV_2DLayoutCanvas, cv_create_context,
            cv_get_seen_boxes,
            cv_translate, cv_add_canvas!, cv_add_rectangle!, cv_add_padding!,
            cv_ensure_size!,
            cv_canvas_for_layout, cv_anchor, cv_pixel2local, cv_pixel2math,
            CV_StateLayout, cv_setup_cycle_state, cv_get_state_counter,
            CV_SceneSetupChain, CV_StdSetupChain, cv_combine
    )
end

import Base:show

# {{{ the layouts, composition-concept, macro for getter-methods

"""
A layout is able to position other objects (e.g. canvas, rectangles)
relative to already positioned objects.
"""
abstract type CV_Layout         end

"""
A 2D layout.

see also `CV_Layout`.
"""
abstract type CV_Abstract2DLayout   <: CV_Layout end

"""
That's the root for a composition "hierarchy" of immutable structs. There
are "getter"-methods to access the fields.

Why a composition "hierarchy"?

Sometimes some additional informations (often `CV_2DLayoutPosition`,
`CV_Math2DCanvas` or `CV_Std2DCanvas`) have to be stored with the layout.
In order to allow for *inferable* types (i.e. no `Vector{...}` is possible)
and to store such objects in immutable structs the composition concept is used.
If some additional informations has to be stored a "wrapper" is used and
the "original" layout is saved inside in a field called `parent_layout`.

Field access is done with (type-inferable) "getter"-methods.
"""
abstract type CV_2DLayoutWrapper <: CV_Abstract2DLayout end

"""
internal macro to (semi-)automatically create the "getter"-methods
for 2D layout (wrappers).

For the owner `getproperty` is skipped. `getfield` gets called directly.
"""
macro layout_composition_getter(field, owner_type)
    func_sym = Symbol("cv_get_", field)
    field_sym = Meta.quot(Symbol(field))
    return esc(quote
        $func_sym(al::CV_2DLayoutWrapper) = $func_sym(al.parent_layout)
        $func_sym(layout::$owner_type) = getfield(layout, $field_sym)
    end)
end

cv_destroy(l::CV_2DLayoutWrapper) = cv_destroy(l.parent_layout)

# }}}

struct CV_2DLayout  <: CV_Abstract2DLayout         # {{{
    seen_boxes      :: CV_RectangleStore{Int32}

    function CV_2DLayout()
        return new(CV_RectangleStore(Int32))
    end
end
cv_destroy(layout::CV_2DLayout) = nothing
@layout_composition_getter(seen_boxes, CV_2DLayout)

function show(io::IO, l::CV_2DLayout)
    print(io, "CV_2DLayout(seen_boxes: "); show(io, l.seen_boxes);
    print(io, ')')
    return nothing
end
# }}}

"""
`CV_2DCanvas` with size and trafo adapted to `CV_2DLayout`.
"""
struct CV_2DLayoutCanvas <: CV_2DCanvas  # {{{
    surface      :: Cairo.CairoSurfaceImage{UInt32}
    pixel_width  :: Int32
    pixel_height :: Int32
    bounding_box :: CV_Rectangle{Int32} # zero-based
    user_box     :: CV_Rectangle{Int32} # user-coordinates (result of layout)
                                        # typically nonzero-based
    function CV_2DLayoutCanvas(user_box::CV_Rectangle{Int32})
        width, height = cv_width(user_box), cv_height(user_box)
        surface = cv_create_cairo_image_surface(width, height)
        self = new(
            surface, width, height,
            CV_Rectangle(height, Int32(0), Int32(0), width),
            user_box)
        return self
    end
end

function cv_create_context(canvas::CV_2DLayoutCanvas; prepare::Bool=true)
    con = CV_2DCanvasContext(canvas)
    if prepare
        ctx = con.ctx
        reset_transform(ctx)

        set_operator(ctx, Cairo.OPERATOR_SOURCE)
        set_source_rgb(ctx, 1, 1, 1)
        rectangle(ctx, 0, 0, canvas.pixel_width, canvas.pixel_height)
        fill(ctx)
        set_operator(ctx, Cairo.OPERATOR_OVER)

        ubox = canvas.user_box
        translate(ctx, -ubox.left, -ubox.bottom)
    end
    return con
end

"""
"finalize" layout construction by building a canvas, on which all
added objects are visible.
"""
function cv_canvas_for_layout(layout::CV_Abstract2DLayout)
    bb = cv_get_seen_boxes(layout).bounding_box
    if bb.empty
        cv_error("Bounding box for Layout is empty.")
    end
    canvas = CV_2DLayoutCanvas(bb)
    return canvas
end
# }}}

"""
Destination Position/Size (a rectangle) in the layout. It's
for an optional canvas or for an optional "drawing callback".

This struct is callable: If called (with a CV_2DCanvasContext) then
(a) if a canvas was given, then this canvas is copied to its target
    position (rectangle) with style "style".
(b) if a drawing_callback was given, then the style is used and the
    drawing-callback is called.
"""
struct CV_2DLayoutPosition{canT<:Union{CV_2DCanvas, Nothing},
                           dcbT, styleT<:CV_ContextStyle}  # {{{
    rectangle   :: CV_Rectangle{Int32}
    canvas      :: canT
    drawing_cb  :: dcbT
    style       :: styleT
end

function show(io::IO, p::CV_2DLayoutPosition)
    print(io, "CV_2DLayoutPosition(rectangle: "); show(io, p.rectangle)
    print(io, ", canvas: ");                      show(io, p.canvas)
    print(io, ')')
end

function show(io::IO, m::MIME{Symbol("text/plain")}, p::CV_2DLayoutPosition)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, "CV_2DLayoutPosition(")
    print(io, indent, "rectangle: "); show(iio, p.rectangle); println(io)
    print(io, indent, "canvas: "); show(iio, p.canvas); println(io)
    print(io, outer_indent, ")")
    return nothing
end

"""
if canvas was given:
copy canvas to its target position (given in rectangle) with style "style".

otherweise call: drawing_cb.

See `CV_2DLayoutPosition`
"""
function (cl::CV_2DLayoutPosition)(cc::CV_2DCanvasContext)
    ctx = cc.ctx
    if !(cl.canvas isa Nothing)
        cv_prepare(cc, cl.style)
        rect = cl.rectangle
        set_source_surface(ctx, cl.canvas.surface, rect.left, rect.bottom)
        rectangle(ctx, rect.left, rect.bottom, cv_width(rect), cv_height(rect))
        fill(ctx)
    end
    if !(cl.drawing_cb isa Nothing)
        cv_prepare(cc, cl.style)
        cl.drawing_cb(cc, cl)
    end
    return nothing
end

# }}}

"""
use 2DLayoutPosition to compute a global pixel position `(gx, gy)` to
local/relative pixels w.r.t. the canvas' rectangle.
"""
function cv_pixel2local(canvas::CV_2DLayoutCanvas,
                        cl::CV_2DLayoutPosition, gx::Integer, gy::Integer)
    ubox = canvas.user_box
    rect = cl.rectangle
    ux, uy = Int32(gx) + ubox.left, Int32(gy) + ubox.bottom
    return (ux - rect.left, uy - rect.bottom)
end

"""
use 2DLayoutPosition (for a `CV_Math2DCanvas`) to convert a global
pixel position `(gx, gy)` coordinates in math units.
"""
function cv_pixel2math(canvas::CV_2DLayoutCanvas,
                       cl::CV_2DLayoutPosition{canT,styleT},
                       gx::Integer, gy::Integer) where {styleT,
                                                canT<:CV_Math2DCanvas}
    lx, ly = cv_pixel2local(canvas, cl, gx, gy)
    return cv_pixel2math(cl.canvas, lx, ly)
end

"""
Return anchor-point for a `CV_2DLayoutPosition`.

If there is position belongs to a canvas then its `cv_anchor` function
is used. Otherwise the anchor function of rectangle (of the position)
is used.
"""
function cv_anchor(lres::CV_2DLayoutPosition, anchor_name::Symbol)
    rect = lres.rectangle
    if lres.canvas isa Nothing
        # Fallback to anchors of the rectangle
        return cv_anchor(rect, anchor_name)
    else
        # support all anchors of the canvas
        inner = cv_anchor(lres.canvas, anchor_name)
        return (rect.left + inner[1], rect.bottom + inner[2])
    end
end

"""
build a new anchor using the x-coordinate of the `anchor1` of object `obj1`
and the y-coordinate of the `anchor2` of `obj2`.
"""
function cv_anchor(obj1, anchor1::Symbol, obj2, anchor2::Symbol)
    return (cv_anchor(obj1, anchor1)[1], cv_anchor(obj2, anchor2)[2])
end

"""
Move a position (typically a anchor) by `deltax` and `deltay`.
"""
function cv_translate(pos::Tuple{N, N}, deltax, deltay) where {N<:Number}
    return tuple(N(pos[1] + deltax), N(pos[2] + deltay))
end

const cv_add_canvas_default_style = cv_op_over

"""
add a canvas to the layout scheme. `where` describes the position
to place the canvas and `anchor` describes which part of the canvas
is located at the position `where`.

With `style` one can set the mode how the canvas is copied to the
target surface.
"""
function cv_add_canvas!(layout::CV_Abstract2DLayout,
                        canvas::CV_2DCanvas,
                        anchor::Tuple{Integer, Integer},
                        where::Tuple{Integer, Integer};
                        style::CV_ContextStyle=cv_add_canvas_default_style)
    where = (where[1] - anchor[1], where[2] - anchor[2])
    rect = cv_rect_blwh(Int32, where[2], where[1],
                               canvas.pixel_width, canvas.pixel_height)
    cv_add_rectangle!(cv_get_seen_boxes(layout), rect)
    return CV_2DLayoutPosition(rect, canvas, nothing, style)
end

const cv_add_rectangle_default_style = cv_op_over

"""
add a rectangle of given width and height to the layout scheme. `where`
describes the position to place the rectangle and `anchor` describes which
part of the rectangle is located at the position `where`.
"""
function cv_add_rectangle!(layout::CV_Abstract2DLayout,
                           width::Integer, height::Integer,
                           anchor::Tuple{Integer, Integer},
                           where::Tuple{Integer, Integer},
                           drawing_cb=nothing,
                           style=cv_add_rectangle_default_style)
    where = (where[1] - anchor[1], where[2] - anchor[2])
    rect = cv_rect_blwh(Int32, where[2], where[1], width, height)
    return cv_add_rectangle!(layout, rect, drawing_cb, style)
end


"""
add a rectangle (absolute coordinates are given in the rectangle) to the
layout scheme. The result is a `CV_2DLayoutPosition` which (when called),
calls the given drawing_callback. The drawing_callback
has the form:  `drawing_cb(cc::CV_2DCanvasContext, pos::CV_2DLayoutPosition)`
"""
function cv_add_rectangle!(layout::CV_Abstract2DLayout,
                           rect::CV_Rectangle{Int32}, drawing_cb=nothing,
                           style=cv_op_over)
    cv_add_rectangle!(cv_get_seen_boxes(layout), rect)
    return CV_2DLayoutPosition(rect, nothing, drawing_cb, style)
end

"""
add padding (with the help of cv_add_rectangle!) to the current
target layout area.
"""
function cv_add_padding!(layout::CV_Abstract2DLayout,
                         north::Integer, east::Integer=north,
                         south::Integer=north, west::Integer=east) # {{{
    o = one(Int32)
    bb = cv_get_seen_boxes(layout).bounding_box
    style = cv_op_source
    if north > 0
        cv_add_rectangle!(layout,
            CV_Rectangle(bb.bottom, bb.left,
                         bb.bottom - Int32(north), bb.left + o), nothing, style)
    end
    if south > 0
        cv_add_rectangle!(layout,
            CV_Rectangle(bb.top + Int32(south), bb.left, bb.top, bb.left + o),
            nothing, style)
    end
    if east > 0
        cv_add_rectangle!(layout,
            CV_Rectangle(bb.top, bb.right, bb.top - o, bb.right + Int32(east)),
            nothing, style)
    end
    if west > 0
        cv_add_rectangle!(layout,
            CV_Rectangle(bb.top, bb.left - Int32(west), bb.top - o, bb.left),
            nothing, style)
    end
    return nothing
end # }}}

function cv_ensure_size!(layout::CV_Abstract2DLayout,
                         minwidth::Integer, minheight::Integer) # {{{
    minwidth, minheight = Int32(minwidth), Int32(minheight)

    bb = cv_get_seen_boxes(layout).bounding_box
    missing = minwidth - cv_width(bb)
    if missing > 0
        half = cv_half(missing)
        rest = missing - half

        cv_add_rectangle!(layout,
            CV_Rectangle(bb.top, bb.left - half, bb.bottom, bb.right + rest))
    end

    bb = cv_get_seen_boxes(layout).bounding_box
    missing = minheight - cv_height(bb)
    if missing >0
        half = cv_half(missing)
        rest = missing - half
        cv_add_rectangle!(layout,
            CV_Rectangle(bb.top + half, bb.left, bb.bottom - rest, bb.right))
    end
    return nothing
end # }}}

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
"""
abstract type CV_SceneSetupChain end


"""
SetupChain with layout (type inferable) and a vector for every
callback-type where all the callback functions are stored (type inference
is lost). See `CV_SceneSetupChain` for the reasons of this tradeoff.
"""
struct CV_StdSetupChain{layoutT} <: CV_SceneSetupChain # {{{
    layout               :: layoutT
    draw_once_func       :: Vector{Any}
    update_painter_func  :: Vector{Any}
    update_state_func    :: Vector{Any}
end

function CV_StdSetupChain(layout)
    return CV_StdSetupChain(layout, Vector(), Vector(), Vector())
end

function cv_combine(old::CV_StdSetupChain;
        layout=missing, draw_once_func=missing, update_painter_func=missing,
        update_state_func=missing)
    new = ismissing(layout) ? old : CV_StdSetupChain(layout,
        old.draw_once_func, old.update_painter_func, old.update_state_func)
    !ismissing(draw_once_func) && push!(new.draw_once_func, draw_once_func)
    !ismissing(update_painter_func) && push!(new.update_painter_func, update_painter_func)
    !ismissing(update_state_func) && push!(new.update_state_func, update_state_func)
    return new
end
# }}}


"""
Layout with degree of freedoms: state_counter
"""
struct CV_StateLayout{parentT, maxV} <: CV_2DLayoutWrapper # {{{
    parent_layout   :: parentT
    state_counter   :: CV_CyclicValue{maxV}
end

@layout_composition_getter(state_counter, CV_StateLayout)

function show(io::IO, l::CV_StateLayout)
    print(io, "CV_StateLayout(state_counter: "); show(io, l.state_counter)
    print(io, ", parent_layout: ");   show(io, l.parent_layout)
    print(io, ')')
    return nothing
end

function show(io::IO, m::MIME{Symbol("text/plain")}, l::CV_StateLayout)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, "CV_StateLayout(")
    print(io, indent, "state_counter: "); show(iio, m, l.state_counter); println(io)
    print(io, indent, "parent_layout: "); show(iio, m, l.parent_layout); println(io)
    print(io, outer_indent, ')')
    return nothing
end  

function cv_setup_cycle_state(setup::CV_SceneSetupChain)
    state_counter = cv_get_state_counter(setup.layout)

    update_state_func = z -> begin
        state_counter()
        return nothing
    end
    return cv_combine(setup; update_state_func)
end

# }}}


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
