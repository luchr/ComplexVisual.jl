abstract type Shape end

struct Rectangle <: Shape
    corner_upper_left  :: Tuple{Float64, Float64}
    corner_lower_right :: Tuple{Float64, Float64}
end

struct Circle <: Shape
    center      :: Tuple{Float64, Float64}
    radius      :: Float64
end

struct GrayShape{shapeType <: Shape} <: Shape
    parent      :: shapeType
    gray_value  :: Float64
end

struct AlphaShape{shapeType <: Shape} <: Shape
    parent      :: shapeType
    alpha_value :: Float64
end

r1 = AlphaShape(GrayShape(Rectangle((0.0, 1.0), (1.0, 0.0)), 0.5), 0.9)
r2 = GrayShape(AlphaShape(Rectangle((0.0, 1.0), (1.0, 0.0)), 0.9), 0.5)


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
