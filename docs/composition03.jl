abstract type Shape end

struct Rectangle <: Shape
    corner_upper_left  :: Tuple{Float64, Float64}
    corner_lower_right :: Tuple{Float64, Float64}
end
shape_get_corner_upper_left(s::Shape) = shape_get_corner_upper_left(s.parent)
shape_get_corner_upper_left(r::Rectangle) = r.corner_upper_left
shape_get_corner_lower_right(s::Shape) = shape_get_corner_lower_right(s.parent)
shape_get_corner_lower_right(r::Rectangle) = r.corner_lower_right

struct Circle <: Shape
    center      :: Tuple{Float64, Float64}
    radius      :: Float64
end
shape_get_center(s::Shape) = shape_get_center(s.parent)
shape_get_center(c::Circle) = c.center
shape_get_radius(s::Shape) = shape_get_radius(s.parent)
shape_get_radius(c::Circle) = c.radius

struct GrayShape{shapeType <: Shape} <: Shape
    parent      :: shapeType
    gray_value  :: Float64
end
shape_get_gray_value(s::Shape) = shape_get_gray_value(s.parent)
shape_get_gray_value(g::GrayShape) = g.gray_value

struct AlphaShape{shapeType <: Shape} <: Shape
    parent      :: shapeType
    alpha_value :: Float64
end

shape_get_alpha_value(s::Shape) = shape_get_alpha_value(s.parent)
shape_get_alpha_value(a::AlphaShape) = a.alpha_value

r1 = AlphaShape(GrayShape(Rectangle((0.0, 1.0), (1.0, 0.0)), 0.5), 0.9)
r2 = GrayShape(AlphaShape(Rectangle((0.0, 1.0), (1.0, 0.0)), 0.9), 0.5)

println("r1: gray_value: ", shape_get_gray_value(r1))
println("r2: gray_value: ", shape_get_gray_value(r2))


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
