abstract type Shape end

abstract type AbstractRectangle <: Shape end

struct Rectangle <: AbstractRectangle
    corner_upper_left  :: Tuple{Float64, Float64}
    corner_lower_right :: Tuple{Float64, Float64}
end

struct GrayRectangle <: AbstractRectangle
    corner_upper_left  :: Tuple{Float64, Float64}
    corner_lower_right :: Tuple{Float64, Float64}
    gray_value         :: Float64
end

abstract type AbstractCircle end

struct Circle <: AbstractCircle
    center  :: Tuple{Float64, Float64}
    radius  :: Float64
end

struct GrayCircle <: AbstractCircle
    center     :: Tuple{Float64, Float64}
    radius     :: Float64
    gray_value :: Float64
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
