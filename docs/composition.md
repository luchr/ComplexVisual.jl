# Composition

Here are some thoughts and experiments concering a programming pattern called *composition*.

What is this all about? All concrete types in julia can only have abstract supertypes. So there is (at the time of writing this, julia 1.6) no way to "inherit" fields/attributes to subtypes (because every abstract type is not allowed to have fields).

Let's use a (very artifical) toy example:

```julia
abstract type Shape end

struct Rectangle <: Shape
    corner_upper_left  :: Tuple{Float64, Float64}
    corner_lower_right :: Tuple{Float64, Float64}
end

struct Circle <: Shape
    center  :: Tuple{Float64, Float64}
    radius  :: Float64
end
```

## One idea to get on a wrong track

Now what happens if you want to "add" an additional field: let's say a gray value? (This is just for simplicity. Obviously it's not a good idea to combine a mathematical shape with part of its appearance. But let's stay for the sake of simplicity with this example.)

One could define a new type `GrayRectangle` and `GrayCircle`. In order to have methods that work on both types `Rectangle` and `GrayRectangle` one would add an abstract supertype (see `composition01.jl`):

```julia
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
```

Now one can define methods that only use the common fields of `GrayRectangle` and `Rectangle` and methods for gray shapes.

What happens if you want to add an new field, like a value for tranparency (often called an `alpha_value`) for each shape? Then you have a lot of possible combinations: `Circle`, `GrayCircle`, `AlphaCircle`, `GrayAlphaCircle`. And copying and pasting all the fields is tedious.

## The embrace and extend idea

Let's use another idea, where we use a new struct to save an reference to an object of the "old" type and add the fields: (see, `composition02.jl`)

```julia
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
```

Then there is a problem. How to access the `gray_value` field of

```julia
r1 = AlphaShape(GrayShape(Rectangle((0.0, 1.0), (1.0, 0.0)), 0.5), 0.9)
r2 = GrayShape(AlphaShape(Rectangle((0.0, 1.0), (1.0, 0.0)), 0.9), 0.5)
```

They are: `r1.parent.gray_value` and `r2.gray_value`. And here comes one
important part for the composition idea (in julia). If we want to keep
the data-structures as above, then we have to use getter-methods.
(see `composition03.jl`)

```julia
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
```

The idea is to let the compiler crawl up all the parents until it
reaches a parent where the field is saved directly in the struct
(using julia's dispatch algorithm).

## More compact form

For every field one has to code two methods. In order to save
keystrokes and to make this less error-prone one may use a macro:
(see `composition04.jl`)

```julia
abstract type Shape end

macro shape_getter(field, owner_type)
    func_sym = Symbol("shape_get_", field)
    return esc(quote
        $func_sym(s::Shape) = $func_sym(s.parent)
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

struct GrayShape{shapeType <: Shape} <: Shape
    parent      :: shapeType
    gray_value  :: Float64
end
@shape_getter(gray_value, GrayShape)

struct AlphaShape{shapeType <: Shape} <: Shape
    parent      :: shapeType
    alpha_value :: Float64
end
@shape_getter(alhpa_value, AlphaShape)
```


