macro import_canvas_huge()
    :(
        using ComplexVisual:
            CV_Canvas, CV_2DCanvas, cv_create_context, cv_save_image,
            cv_destroy, CV_Std2DCanvas, CV_Math2DCanvas,
            cv_pixel2math, cv_math2pixel
    )
end

import Base:show

"""
`CV_Canvas`: something where you can draw and paint.
"""
abstract type CV_Canvas  end

"""
```
CV_2DCanvas <: CV_Canvas
    # required fields:
    # surface       (CairoSurface)
    # pixel_width   (convert(Int32, surface.width))
    # pixel_height  (convert(Int32, surface.height))
    # bounding_box  (CV_Rectangle{Int32})  bottom=0, left=0 (i.e. zero-based)
```

a thin wrapper around a `CairoSurface` (where `pixel_width` and `pixel_height`
are `Int32`, instead of `Floats`) for twodimensional painting and drawing
operations.

There are canvases with "only" pixel coorindates (like `CV_Std2DCanvas`)
and there are canvases which also have a mathematical coordinate
system (like `CV_Math2DCanvas`).
"""
abstract type CV_2DCanvas <: CV_Canvas    # {{{
    # required fields:
    # surface       (CairoSurface)
    # pixel_width   (convert(Int32, surface.width))
    # pixel_height  (convert(Int32, surface.height))
    # bounding_box  (CV_Rectangle{Int32})  bottom=0, left=0 (i.e. zero-based)
end

show(io::IO, canvas::CV_2DCanvas) = cv_show_impl(io, canvas)
show(io::IO, m::MIME{Symbol("text/plain")}, canvas::CV_2DCanvas) =
    cv_show_impl(io, m, canvas)

function cv_destroy(can::CV_2DCanvas)
    destroy(can.surface)
    return nothing
end 

function cv_anchor(can::CV_2DCanvas, anchor_name::Symbol)
    return cv_anchor(can.bounding_box, anchor_name)
end

"""
```
cv_create_context(canvas; prepare=true)
    canvas    CV_2DCanvas
    prepare   Bool
```

Create Context for 2DCanvas. If `prepare` is `true` then
(depending on the concrete CV_2DCanvas subtype) special preperations
or initializations for the context are done.
"""
function cv_create_context(canvas::CV_2DCanvas; prepare::Bool=true)
    return CV_2DCanvasContext(canvas)
end

# }}}

"""
```
cv_create_cairo_image_surface(width, height)
    width     Integer
    height    Integer
```
Use ARGB32 image surface with pixel matrix stored in julia.
"""
function cv_create_cairo_image_surface(width::Integer, height::Integer)
    return CairoImageSurface(
        zeros(UInt32, width, height),
        Cairo.FORMAT_ARGB32; flipxy=false)
end

"""
```
cv_save_image(canvas, filename)
    canvas      CV_2DCanvas
    filename    AbstractString
```

save content of canvas as a png image.
"""
function cv_save_image(canvas::CV_2DCanvas, filename::AbstractString)
    write_to_png(canvas.surface, filename)
    return nothing
end

"""
```
CV_Std2DCanvas <: CV_2DCanvas 
    surface          Cairo.CairoSurfaceImage{UInt32}
    pixel_width      Int32
    pixel_height     Int32
    bounding_box     CV_Rectangle{Int32}
```

A twodimensional canvas with a `CairoSurfaceImage` (ARGB32 format).
"""
struct CV_Std2DCanvas <: CV_2DCanvas  # {{{
    surface      :: Cairo.CairoSurfaceImage{UInt32}
    pixel_width  :: Int32
    pixel_height :: Int32
    bounding_box :: CV_Rectangle{Int32}

    function CV_Std2DCanvas(pixel_width::Integer, pixel_height::Integer)
        width = convert(Int32, pixel_width)
        height = convert(Int32, pixel_height)
        surface = cv_create_cairo_image_surface(width, height)
        self = new(
            surface, width, height, 
            CV_Rectangle(height, Int32(0), Int32(0), width))
        return self
    end
end # }}}

"""
```
CV_Math2DCanvas <: CV_2DCanvas
    corner_ul       Complex{Float64}  # (math.) coordinates of upper left corner
    corner_lr       Complex{Float64}  # (math.) coordinates of lower right corner
    resolution      Float64           # Pixels per (math.) unit
    surface         Cairo.CairoSurfaceImage{UInt32}
    pixel_width     Int32
    pixel_height    Int32
    bounding_box    CV_Rectangle{Int32}
```

A twodimensional canvas with a `CairoSurfaceImage` (ARGB32 format) where
the user coordinates represent a mathmatical coordinate system.
With the two methods `cv_math2pixel` and `cv_pixel2math` one can
transform math coordinates to pixel coordinates and vice versa.
See also: `CV_MathCoorStyle`.
"""
struct CV_Math2DCanvas <: CV_2DCanvas # {{{
    corner_ul    :: Complex{Float64}; # (math.) coordinates of upper left corner
    corner_lr    :: Complex{Float64}; # (math.) coordinates of lower right corner
    resolution   :: Float64;          # Pixels per (math.) unit
    surface      :: Cairo.CairoSurfaceImage{UInt32}
    pixel_width  :: Int32
    pixel_height :: Int32
    bounding_box :: CV_Rectangle{Int32}

    function CV_Math2DCanvas(
            corner_ul::Complex{Float64}, corner_lr::Complex{Float64},
            resolution=100.0::Float64)    # {{{
        if (!isfinite(resolution))
            cv_error("resolution must be finite; resolution = ", resolution)
        end
        if (!(resolution > 0))
            cv_error("resolution must be positive; resolution = ", resolution)
        end
        if (!isfinite(corner_ul) || !isfinite(corner_lr))
            cv_error(
                "corner_ul and corner_lr must be finite",
                "; corner_ul = ", corner_ul,
                "; corner_lr = ", corner_lr)
        end
        if (!(real(corner_ul) < real(corner_lr)))
            cv_error(
                "requirement: real(corner_ul) < real(corner_lr)",
                "; corner_ul = ", corner_ul,
                "; corner_lr = ", corner_lr)
        end
        if (!(imag(corner_ul) > imag(corner_lr)))
            cv_error(
                "requirement: imag(corner_ul) > imag(corner_lr)",
                "; corner_ul = ", corner_ul,
                "; corner_lr = ", corner_lr)
        end
        math_width = real(corner_lr) - real(corner_ul)
        math_height = imag(corner_ul) - imag(corner_lr)
        pixel_width = floor(Int32, math_width*resolution)
        pixel_height = floor(Int32, math_height*resolution)
        if (pixel_width == 0 || pixel_height == 0)
            cv_error(
                "resolution too small; image width or height would be 0",
                "; math_width = ", math_width,
                "; math_height = ", math_height,
                "; pixel_width = ", pixel_width,
                "; pixel_height = ", pixel_height)
        end
        surface = CairoImageSurface(
            zeros(UInt32, pixel_width, pixel_height),
            Cairo.FORMAT_ARGB32; flipxy=false)
        self = new(
            corner_ul, corner_lr, resolution, surface,
            pixel_width, pixel_height,
            CV_Rectangle(pixel_height, Int32(0), Int32(0), pixel_width))
        return self
    end  # }}}
end

function show(io::IO, canvas::CV_Math2DCanvas)
    t = typeof(canvas)
    print(io, string(t.name.name), "(⌜")
    show(io, canvas.corner_ul)
    print(io, ", ")
    show(io, canvas.corner_lr)
    print(io, "⌟, res=")
    show(io, canvas.resolution)
    print(io, ", ")
    show(io, canvas.bounding_box)
    print(io, ')')
    return nothing
end

show(io::IO, m::MIME{Symbol("text/plain")}, canvas::CV_Math2DCanvas) =
    show(io, canvas)

"""
```
cv_math2pixel(canvas, mx, my) :: Tuple{Int32, Int32}
    canvas      CV_Math2DCanvas
    mx          Float64
    my          Float64
```

convert math coordinates `(mx, my)` to pixel coordinates.
"""
function cv_math2pixel(canvas::CV_Math2DCanvas, mx::Float64, my::Float64)
    res = canvas.resolution
    return (
        round(Int32, (mx - real(canvas.corner_ul))*res),
        round(Int32, -(my - imag(canvas.corner_ul))*res))
end

"""
```
cv_pixel2math(canvas, px, py::Integer) :: Tuple{Float64, Float64}
    canvas    CV_Math2DCanvas
    px        Integer
    pyi       Integer
```

convert pixel coordinates `(px, py)` to math coordinates.
"""
function cv_pixel2math(canvas::CV_Math2DCanvas, px::Integer, py::Integer)
    res = canvas.resolution
    return (
        real(canvas.corner_ul) + px/res,
        imag(canvas.corner_ul) - py/res)
end

"""
```
cv_create_context(canvas; prepare=true)
    canvas       CV_Math2DCanvas
    prepare      Bool
```
create context for Math2DCanvas. If `prepare` is `true` the
the context's user coordinate system is the mathematical coordinate
system of the Math2DCanvas. See also `CV_MathCoorStyle`.
"""
function cv_create_context(canvas::CV_Math2DCanvas; prepare::Bool=true)
    con = CV_2DCanvasContext(canvas)
    if prepare
        cv_prepare(con, CV_MathCoorStyle(canvas))
    end
    return con
end

# }}}


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:

