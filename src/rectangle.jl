macro import_rectangle_huge()
    :(
        using ComplexVisual:
            CV_Rectangle, cv_rect_blwh, cv_width, cv_height, cv_is_inside,
            cv_anchor, cv_intersect, CV_RectangleStore, cv_add_rectangle!,
            cv_find_first_nonempty_intersection, cv_compute_bounding_box
    )
end

import Base:show


"""
A rectangle with non-positive width and/or non-positive height is considered as "empty".

A rectangle is always given/specified by the coordinates of the upper-left and lower-right corner.
"""
struct CV_Rectangle{N<:Number}
    top    :: N
    left   :: N
    bottom :: N
    right  :: N
    empty  :: Bool

    function CV_Rectangle(top::T, left::T, bottom::T, right::T) where {T<:Number}
        if !(isfinite(top) && isfinite(left) && isfinite(bottom) && isfinite(right))
            cv_error(
                "Only finite values are supported",
                "; top = ", top, "; left = ", left, "; bottom = ", bottom, "; right = ", right)
        end
        empty = (left >= right) || (bottom >= top)
        return new{T}(top, left, bottom, right, empty)
    end
end

"""
creates rectangle (with given number type) with the data:
bottom, left, width, height.
"""
function cv_rect_blwh(::Type{T},
        bottom::Real, left::Real, width::Real, height::Real) where {T<:Real}
    return CV_Rectangle(T(bottom + height), T(left), T(bottom), T(left + width))
end
function CV_Rectangle(type::Type{T}) where {T<:Number}
    null = zero(T)
    return CV_Rectangle(null, null, null, null)
end
function CV_Rectangle(width::T, height::T) where {T<:Number}
    return cv_rect_blwh(T, zero(T), zero(T), width, height)
end
function CV_Rectangle(type::Type{T}, width::Real, height::Real) where {T<:Number}
    return cv_rect_blwh(T, zero(T), zero(T), T(width), T(height))
end

function show(io::IO, rect::CV_Rectangle) # {{{
    char = rect.empty ? '▭' : '▬'
    print(io, char);
    show(io, rect.left);   print(io, '→'); show(io, rect.right)
    print(io, ", ")
    show(io, rect.bottom); print(io, '↑'); show(io, rect.top)
    print(io, char)
    return nothing
end

function show(io::IO, ::MIME{Symbol("text/plain")}, rect::CV_Rectangle)
    compact = get(io, :compact, false) :: Bool
    if !compact
        print(io, "CV_Rectangle(")
    end
    show(io, rect)
    if !compact
        print(io, ")")
    end
    return nothing
end # }}}

cv_width(rect::CV_Rectangle) = rect.right - rect.left
cv_height(rect::CV_Rectangle) = rect.top - rect.bottom

function cv_is_inside(rect::CV_Rectangle{N}, x::N, y::N) where {N}
    return (rect.left ≤ x ≤ rect.right) && (rect.bottom ≤ y ≤ rect.top)
end

"""
return anchor for a rectangle. 

Coor-system

     ┌─────────>
     │   north/bottom
     │  w┌───┐e
     │  e│   │a
     │  s│   │s
     │  t└───┘t
     v   south/top

Supported anchors (for a rectangle) are:
```
:north        :south        :east    :west    :center    
:northeast    :southeast    
:southwest    :northwest    
```
"""
function cv_anchor(r::CV_Rectangle{N},
                   anchor_name::Symbol) where {N<:Number}
    return (
        anchor_name == :north     ? (cv_half(r.left + r.right), r.bottom)  :
        anchor_name == :south     ? (cv_half(r.left + r.right), r.top)     :
        anchor_name == :east      ? (r.right, cv_half(r.top + r.bottom))   :
        anchor_name == :west      ? (r.left, cv_half(r.top + r.bottom))    :
        anchor_name == :northeast ? (r.right, r.bottom)                    :
        anchor_name == :southeast ? (r.right, r.top)                       :
        anchor_name == :southwest ? (r.left, r.top)                        :
        anchor_name == :northwest ? (r.left, r.bottom)                     :
        anchor_name == :center    ? (cv_half(r.left + r.right),
                                      cv_half(r.top + r.bottom))           :
        cv_error("Unknown anchor_name: ", string(anchor_name))) :: Tuple{N, N}
end


"""
return rectangle with intersection of rectA and rectB.

If already rectA and/or rectB is empty then an empty rectangle is returned.
"""
function cv_intersect(rectA::CV_Rectangle{N}, rectB::CV_Rectangle{N}) where {N<:Number}
    if rectA.empty
        return rectA
    end
    if rectB.empty
        return rectB
    end
    # Non-empty case
    top = min(rectA.top, rectB.top)
    left = max(rectA. left, rectB.left)
    bottom = max(rectA.bottom, rectB.bottom)
    right = min(rectA.right, rectB.right)
    return CV_Rectangle(top, left, bottom, right)
end

"""
This helper is used to get the smallest bounding box for rectangles and for intersection tests.
No painting/drawing is done.
"""
mutable struct CV_RectangleStore{N<:Number}
    rectangles    :: Vector{CV_Rectangle{N}}
    bounding_box  :: CV_Rectangle{N}
    
    function CV_RectangleStore(type::Type{T}) where {T<:Number}
        rectangles = Vector{CV_Rectangle{T}}()
        bounding_box = CV_Rectangle(type)
        return new{T}(rectangles, bounding_box)
    end
end

function show(io::IO, store::CV_RectangleStore{N}) where {N} # {{{
    print(io, "CV_RectangleStore")
    print(io, "(bb: ")
    show(io, store.bounding_box)
    no_rect = length(store.rectangles)
    print(io, ", #", no_rect)
    print(io, ')')
    return nothing
end

function show(io::IO, mime::MIME{Symbol("text/plain")},
              store::CV_RectangleStore{N}) where {N}
    print(io, "CV_RectangleStore{")
    show(io, N)
    print(io, "}(bounding_box: ")
    show(io, mime, store.bounding_box)
    print(io, "; with ")
    no_rect = length(store.rectangles)
    print(io, no_rect, " rectangle")
    if no_rect != 1
        print(io, 's')
    end
    print(io, ')')
    return nothing
end # }}}

"""
Internal method for bonding_box update with new/last rectangle in rectangles.
"""
function cv_update_bounding_box!(store::CV_RectangleStore{N}) where {N<:Number}
    rect = store.rectangles[end]
    bb = store.bounding_box
    if bb.empty
        store.bounding_box = rect
    else
        top = max(rect.top, bb.top)
        left = min(rect.left, bb.left)
        bottom = min(rect.bottom, bb.bottom)
        right = max(rect.right, bb.right)
        store.bounding_box = CV_Rectangle(top, left, bottom, right)
    end
    return nothing
end

"""
add rectangle to store and update bounding box.
"""
function cv_add_rectangle!(store::CV_RectangleStore{N}, rect::CV_Rectangle{N}) where {N<:Number}

    if rect.empty
        cv_error("Only non-empty rectangles can be added.")
    end
    push!(store.rectangles, rect)
    cv_update_bounding_box!(store)
    return nothing
end

"""
find first non-empty intersection. If all intersections are empty then an empty rectangle is returned.
"""
function cv_find_first_nonempty_intersection(
            store::CV_RectangleStore{N}, rect::CV_Rectangle{N}) where {N<:Number}
    last_intersection = CV_Rectangle(zero(N), zero(N), zero(N), zero(N))
    if !(rect.empty)
        for test_rect in store.rectangles
            result = cv_intersect(rect, test_rect)
            if !(result.empty)
                last_intersection = result
                break
            end
        end
    end
    return last_intersection
end

function cv_compute_bounding_box(rects::CV_Rectangle{N}...) where {N}
    store = CV_RectangleStore(N)
    for rect in rects
        cv_add_rectangle!(store, rect)
    end
    return store.bounding_box
end


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
