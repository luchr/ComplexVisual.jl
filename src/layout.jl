macro import_layout_huge()
    :(
        using ComplexVisual:
            cv_destroy,
            CV_Layout, CV_Abstract2DLayout, CV_2DLayoutWrapper,
            CV_2DContainer, CV_2DLayout,
            CV_Framed2DLayout, CV_MinimalFramed2DLayout,
            CV_2DLayoutPosition, CV_2DLayoutCanvas, cv_create_context,
            cv_get_seen_boxes,
            cv_translate, cv_add_canvas!, cv_add_rectangle!, cv_add_padding!,
            cv_ensure_size!,
            cv_canvas_for_layout, cv_anchor, cv_global2local, cv_local2global,
            cv_pixel2math,
            CV_StateLayout, cv_get_state_counter,
            CV_SceneSetupChain, CV_2DScene
    )
end

import Base:show

# {{{ the layouts, composition-concept, macro for getter-methods

"""
A layout is able to position other objects (e.g. canvas, rectangles)
relative to already positioned objects.

Typically a layout "grows" (in the size) with new objects. Even additional
information may be stored in a layout, see `CV_2DLayoutWrapper`.

At some time a layout gets "framed", see `CV_Framed2DLayout`. At this time
such a layout has a `can_layout`  and `cc_can_layout` field.

At the ende a layout becomes a "scene", see `CV_2DScene`. At this time
there are some callback-functions for interaction available as fields.
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
A Layout which supports the fields `can_layout` and `cc_can_layout`.
At this time the size of the layout cannot grow anymore (because the canvas
is already allocated).
"""
abstract type CV_Framed2DLayout <: CV_2DLayoutWrapper
    # can_layout      :: CV_2DLayoutCanvas
    # cc_can_layout
end

"""
internal macro to (semi-)automatically create the "getter"-methods
for 2D layout (wrappers).

For the owner `getproperty` is skipped. `getfield` gets called directly.
"""
macro layout_composition_getter(field, owner_type)
    func_sym = Symbol("cv_get_", field)
    func_quote = Meta.quot(func_sym)
    field_sym = Meta.quot(Symbol(field))
    return esc(quote
        if !isdefined(ComplexVisual, $func_quote)
            $func_sym(al::CV_2DLayoutWrapper) = $func_sym(al.parent_layout)
        end
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

function show(io::IO, l::CV_Framed2DLayout)
    t = typeof(l)
    print(io, t, "(can_layout: "); show(io, cv_get_can_layout(l));
    print(io, ')')
    return nothing
end

function show(io::IO, m::MIME{Symbol("text/plain")}, s::CV_Framed2DLayout)
    t = typeof(s)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, t, '(')
    print(io, indent, "can_layout: "); show(iio, m, cv_get_can_layout(s)); println(io)
    print(io, indent, "parent_layout: "); show(iio, m, s.parent_layout); println(io)
    print(io, outer_indent, ')')
    return nothing
end

# }}}

struct CV_MinimalFramed2DLayout{parentT,
            canT <: CV_2DCanvas, cccT} <: CV_Framed2DLayout # {{{
    parent_layout   :: parentT
    can_layout      :: canT
    cc_can_layout   :: cccT
end

@layout_composition_getter(can_layout,    CV_MinimalFramed2DLayout)
@layout_composition_getter(cc_can_layout, CV_MinimalFramed2DLayout)

function cv_destroy(layout::CV_MinimalFramed2DLayout)
    cv_destroy(layout.cc_can_layout)
    cv_destroy(layout.can_layout)
    cv_destroy(layout.parent_layout)
    return nothing
end
# }}}

"""
A container with a `bounding_box` and `user_box` (pixel-)coordinates.
"""
abstract type  CV_2DContainer   <: CV_2DCanvas end

"""
`CV_2DCanvas` with size and trafo adapted to `CV_2DLayout`.
"""
struct CV_2DLayoutCanvas{afT} <: CV_2DContainer  # {{{
    surface      :: Cairo.CairoSurfaceImage{UInt32}
    pixel_width  :: Int32
    pixel_height :: Int32
    bounding_box :: CV_Rectangle{Int32} # zero-based
    user_box     :: CV_Rectangle{Int32} # user-coordinates (result of layout)
                                        # typically nonzero-based
    anchor_func  :: afT
    function CV_2DLayoutCanvas(user_box::CV_Rectangle{Int32},
            anchor_func=(can, name) -> cv_anchor(can.bounding_box, name))
        width, height = cv_width(user_box), cv_height(user_box)
        surface = cv_create_cairo_image_surface(width, height)
        self = new{typeof(anchor_func)}(
            surface, width, height,
            CV_Rectangle(height, Int32(0), Int32(0), width),
            user_box, anchor_func)
        return self
    end
end

function cv_anchor(can::CV_2DLayoutCanvas, anchor_name::Symbol)
    return can.anchor_func(can, anchor_name) :: Tuple{Int32, Int32}
end

function cv_create_context(canvas::CV_2DContainer; prepare::Bool=true,
        fill_with::CV_ContextStyle=cv_color(1,1,1))
    con = CV_2DCanvasContext(canvas)
    if prepare
        ctx = con.ctx
        reset_transform(ctx)

        set_operator(ctx, Cairo.OPERATOR_SOURCE)
        cv_prepare(con, fill_with)
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
function cv_canvas_for_layout(layout::CV_Abstract2DLayout,
        anchor_func=(can, name) -> cv_anchor(can.bounding_box, name))
    bb = cv_get_seen_boxes(layout).bounding_box
    if bb.empty
        cv_error("Bounding box for Layout is empty.")
    end
    canvas = CV_2DLayoutCanvas(bb, anchor_func)
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
use 2DLayoutPosition to transform a global pixel position `(gx, gy)` to
local/relative pixels w.r.t. the positon's coordinates.
"""
function cv_global2local(canvas::CV_2DContainer,
                        cl::CV_2DLayoutPosition, gx::Integer, gy::Integer)
    ubox = canvas.user_box
    rect = cl.rectangle
    ux, uy = Int32(gx) + ubox.left, Int32(gy) + ubox.bottom
    return (ux - rect.left, uy - rect.bottom)
end

"""
use 2DLayoutPosition to transform a local pixel position `(lx, ly)`
w.r.t. the positon's coordinates to global pixels.

This is the opposite of `cv_global2local`.
"""
function cv_local2global(canvas::CV_2DContainer,
                         cl::CV_2DLayoutPosition, lx::Integer, ly::Integer)
    ubox = canvas.user_box
    rect = cl.rectangle
    ux, uy = Int32(lx) + rect.left, Int32(ly) + rect.bottom
    return (ux - ubox.left, uy - ubox.bottom)
end

"""
use 2DLayoutPosition (for a `CV_Math2DCanvas`) to convert a global
pixel position `(gx, gy)` coordinates in math units.
"""
function cv_pixel2math(canvas::CV_2DContainer,
                       cl::CV_2DLayoutPosition{canT,styleT},
                       gx::Integer, gy::Integer) where {styleT,
                                                canT<:CV_Math2DCanvas}
    lx, ly = cv_global2local(canvas, cl, gx, gy)
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


# }}}


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
