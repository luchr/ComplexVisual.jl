abstract type Shape end

abstract type ShapeWithParent <: Shape end

macro shape_getter(field, owner_type)
    func_sym = Symbol("shape_get_", field)
    return esc(quote
        $func_sym(s::ShapeWithParent) = $func_sym(s.parent)
        $func_sym(s::$owner_type) = s.$field
    end)
end

struct Rectangle <: Shape
    corner_upper_left  :: Tuple{Float64, Float64}
    corner_lower_right :: Tuple{Float64, Float64}
end
@shape_getter(corner_upper_left, Rectangle)
@shape_getter(corner_lower_right, Rectangle)

struct Circle <: Shape
    center      :: Tuple{Float64, Float64}
    radius      :: Float64
end
@shape_getter(center, Circle)
@shape_getter(radius, Circle)

struct GrayShape{shapeType <: Shape} <: ShapeWithParent
    parent      :: shapeType
    gray_value  :: Float64
end
@shape_getter(gray_value, GrayShape)

struct AlphaShape{shapeType <: Shape} <: ShapeWithParent
    parent      :: shapeType
    alpha_value :: Float64
end
@shape_getter(alhpa_value, AlphaShape)

r1 = AlphaShape(GrayShape(Rectangle((0.0, 1.0), (1.0, 0.0)), 0.5), 0.9)
r2 = GrayShape(AlphaShape(Rectangle((0.0, 1.0), (1.0, 0.0)), 0.9), 0.5)

println("r1: gray_value: ", shape_get_gray_value(r1))
println("r2: gray_value: ", shape_get_gray_value(r2))


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
