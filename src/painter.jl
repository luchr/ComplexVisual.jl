macro import_painter_huge()
    :(
        using ComplexVisual:
                CV_Painter, cv_paint, CV_CanvasPainter, CV_2DCanvasPainter,
                CV_FillPainter, CV_ValueMarkPainter,
                CV_DiskPainter,
                CV_GridPainter, CV_LineSegment, CV_LineSegments,
                CV_LinePainter, CV_DirectionPainter,
                CV_PortraitPainter, cv_clear_cache,
                CV_CombiPainter, →, CV_StyledPainter, ↦, 
                CV_Math2DCanvasPainter,
                cv_parallel_lines, cv_arc_lines, cv_star_lines,
                cv_star_arc_lines
    )
end

import Base:show

"""
`CV_Painter`: Instances of this type can paint inside objects with math
coordinate systems (e.g. `CV_Math2DCanvas`).
"""
abstract type CV_Painter end

show(io::IO, p::CV_Painter) = cv_show_impl(io, p)

"""
`CV_CanvasPainter`: Instances of this type can paint inside canvases with
math coordinate systems (e.g. `CV_Math2DCanvas`).
"""
abstract type CV_CanvasPainter <: CV_Painter end

"""
`CV_2DCanvasPainter`: Instances of this type can paint inside 2D canvases
with math coordinate systems (e.g. `CV_Math2DCanvas`).
"""
abstract type CV_2DCanvasPainter <: CV_CanvasPainter end

cv_clear_cache(canvas_painter::CV_2DCanvasPainter) = nothing

"""
```
CV_FillPainter <: CV_2DCanvasPainter
    no fields
```

A painter filling the complete canvas.

A `CV_ContextStyle` is typically used to govern the appearance of
the filling operation.
"""
struct CV_FillPainter <: CV_2DCanvasPainter # {{{
end

"""
```
cv_paint(cc, fill_painter)
    cc            CV_2DCanvasContext
    fill_painter  CV_FillPainter
```

fill the complete (math) canvas.
"""
function cv_paint(cc::CV_2DCanvasContext, fill_painter::CV_FillPainter)
    canvas = cc.canvas
    rectangle(cc.ctx,
        real(canvas.corner_ul), imag(canvas.corner_lr),
        real(canvas.corner_lr) - real(canvas.corner_ul),
        imag(canvas.corner_ul) - imag(canvas.corner_lr))
    fill(cc.ctx)
    return nothing
end
# }}}

"""
```
CV_ValueMarkPainter{N<:Number}
    where     CV_TranslateByOffset{N}
    start     Float64
    len       Float64
    vertical  Bool
```

A painter drawing a vertical line-segment
`(where, start)` to `(where, start + len)` (in the math coordinate system).
Here the `where` is the where-value of a `CV_TranslateByOffset`.
If `vertical` is `true` then the real- and imag-coordinates are
swapped for drawing.

This painter is typically used for Sliders to mark the current
slider position.
"""
struct CV_ValueMarkPainter{N<:Number} <: CV_2DCanvasPainter # {{{
    where     :: CV_TranslateByOffset{N}
    start     :: Float64
    len       :: Float64
    vertical  :: Bool

    function CV_ValueMarkPainter(where::CV_TranslateByOffset{N},
            start::Real, len::Real, vertical::Bool=true) where {N<:Number}
        return new{N}(where, Float64(start), Float64(len), vertical)
    end
end

"""
```
cv_paint(cc, mark_painter)
    cc              CV_2DCanvasContext
    mark_painter    CV_ValueMarkPainter
```

draw a horitzonal or vertical mark to the painter's `where` position.
"""
function cv_paint(cc::CV_2DCanvasContext, mark_painter::CV_ValueMarkPainter)
    canvas, ctx = cc.canvas, cc.ctx
    if mark_painter.vertical
        move_to(ctx, mark_painter.start, mark_painter.where.value)
        rel_line_to(ctx, mark_painter.len, 0)
    else
        move_to(ctx, mark_painter.where.value, mark_painter.start)
        rel_line_to(ctx, 0, mark_painter.len)
    end
    stroke(ctx)
    return nothing
end
# }}}

"""
```
CV_GridPainter <: CV_2DCanvasPainter
    reals   Vector{Float64}
    imags   Vector{Float64}
```

A painter for drawing horizontal and vertical grid lines.
"""
struct CV_GridPainter <: CV_2DCanvasPainter  # {{{
    reals   :: Vector{Float64}
    imags   :: Vector{Float64}
end

"""
`CV_GridPainter(reals, imags)`

```
reals    Union{NTuple{N, Real}, AbstractVector{Float64}}
imags    Union{NTuple{M, Real}, AbstractVector{Float64}}
```

construct grid for given real- and imag-values.
"""
function CV_GridPainter(
        reals::Union{NTuple{N, Real}, AbstractVector{Float64}},
        imags::Union{NTuple{M, Real}, AbstractVector{Float64}}) where {M, N}
    return CV_GridPainter(
        [Float64(x) for x in reals],
        [Float64(y) for y in imags])
end

show(io::IO, m::MIME{Symbol("text/plain")}, gp::CV_GridPainter) =
    cv_show_impl(io, m, gp)


"""
```
cv_paint(cc, grid_painter)
    cc              CV_2DCanvasContext
    grid_painter    CV_GridPainter
```

draw horizontal and vertical grid lines.
"""
function cv_paint(cc::CV_2DCanvasContext, grid_painter::CV_GridPainter) # {{{
    canvas, ctx = cc.canvas, cc.ctx
    left, right = real(canvas.corner_ul), real(canvas.corner_lr)
    top, bottom = imag(canvas.corner_ul), imag(canvas.corner_lr)
    for x in grid_painter.reals
        move_to(ctx, x, bottom)
        line_to(ctx, x, top)
        stroke(ctx)
    end
    for y in grid_painter.imags
        move_to(ctx, left, y)
        line_to(ctx, right, y)
        stroke(ctx)
    end
    return nothing
end # }}}
# }}}

"""
`CV_LineSegment`: list/vector of points in complex plane.
"""
const CV_LineSegment = Vector{Complex{Float64}}

"""
`CV_LineSegments`: list/vector of `CV_LineSegment`
"""
const CV_LineSegments = Vector{CV_LineSegment}

"""
```
CV_LinePainter{dtrafoT, strafoT, scutT} <: CV_2DCanvasPainter
    dst_trafo           dtrafoT
    segments            CV_LineSegments
    auto_close_path     Bool
    src_trafo           strafoT
    src_cut_test        scutT
```

Painting `CV_LineSegments` as curves.

All the points of the line segments are transformed according to `dst_trafo`.

The preimage of the line segments are transformed by `src_trafo` (unless
`src_trafo === nothing`) and afterwards they are checked with `src_cut_test`
(unless `src_cut_test === nothing`) if the line-segment needs to be "cut"
(i.e. the line is interrupted there).
"""
struct CV_LinePainter{dtrafoT, strafoT, scutT} <: CV_2DCanvasPainter # {{{
    dst_trafo       :: dtrafoT
    segments        :: CV_LineSegments
    auto_close_path :: Bool
    src_trafo       :: strafoT
    src_cut_test    :: scutT
end

"""
```
CV_LinePainter(dst_trafo, segments, auto_close_path=false)
    dst_trafo
    segments           CV_LineSegments
    auto_close_path    Bool
```

with `src_trafo` and `src_cut_test` both `nothing`.
"""
function CV_LinePainter(dst_trafo, segments::CV_LineSegments,
        auto_close_path::Bool=false)
    return CV_LinePainter(dst_trafo, segments, auto_close_path,
        nothing, nothing)
end

"""
```
CV_LinePainter(segments, auto_close_path=false)
    segments           CV_LineSegments
    auto_close_path    Bool
```

`dst_trafo = identity` and with `src_trafo` and `src_cut_test` both `nothing`.
"""
CV_LinePainter(segments::CV_LineSegments, auto_close_path::Bool=false) = 
    CV_LinePainter(identity, segments, auto_close_path)

"""
```
cv_paint(cc, line_painter)
    cc            CV_2DCanvasContext,
    line_painter  CV_LinePainter{dtrafoT, Nothing, Nothing}
```

paint line segments without cut-test.
"""
function cv_paint(cc::CV_2DCanvasContext,
        line_painter::CV_LinePainter{dtrafoT,
                Nothing, Nothing}) where {dtrafoT}  # {{{
    dst_trafo = line_painter.dst_trafo
    ctx = cc.ctx
    for segment in line_painter.segments
        value = dst_trafo(segment[1])
        move_to(ctx, real(value), imag(value))
        for point in segment[2:end]
            value = dst_trafo(point)
            line_to(ctx, real(value), imag(value))
        end
        if line_painter.auto_close_path
            close_path(ctx)
        end
        stroke(ctx)
    end
    return nothing
end # }}}

"""
```
cv_paint(cc, line_painter)
    cc            CV_2DCanvasContext,
    line_painter  CV_LinePainter{dtrafoT, strafoT, scutT})
```

paint line segments with cut-test.
"""
function cv_paint(cc::CV_2DCanvasContext,
        line_painter::CV_LinePainter{dtrafoT,
                strafoT, scutT}) where {dtrafoT, strafoT, scutT}  # {{{

    ctx, trafo = cc.ctx, line_painter.dst_trafo
    src_trafo, cut_test = line_painter.src_trafo, line_painter.src_cut_test

    for segment in line_painter.segments
        from_point, from_value = src_trafo(segment[1]), trafo(segment[1])
        first, cut = true, false
        for point in segment
            to_point, to_value = src_trafo(point), trafo(point)
            if cut_test(from_point, to_point)
                first, cut = true, true
                from_point, from_value = to_point, to_value
            else
                if first
                    move_to(ctx, real(to_value), imag(to_value))
                    first = false
                else
                    line_to(ctx, real(to_value), imag(to_value))
                    from_point, from_value = to_point, to_value
                end
            end
        end
        line_painter.auto_close_path && !cut && close_path(ctx)
        stroke(ctx)
    end

    return nothing
end # }}}
# }}}


"""
```
CV_DiskPainter{dtrafoT} <: CV_2DCanvasPainter
    dst_trafo           dtrafoT
    segments           CV_LineSegments
    radius             Float64
```

Paint disks (filled circles) at the given points.
"""
struct CV_DiskPainter{dtrafoT} <: CV_2DCanvasPainter  # {{{
    dst_trafo       :: dtrafoT
    segments        :: CV_LineSegments
    radius          :: Float64
end


"""
```
CV_DiskPainter(segments, radius=0.1)
    segments           CV_LineSegments
    radius
```
"""
function CV_DiskPainter(segments::CV_LineSegments, radius=0.1)
    return CV_DiskPainter(identity, segments, radius)
end

function cv_paint(cc::CV_2DCanvasContext,
        disk_painter::CV_DiskPainter{dtrafoT}) where {dtrafoT} # {{{
    trafo, radius = disk_painter.dst_trafo, disk_painter.radius
    ctx = cc.ctx
    for segment in disk_painter.segments
        for point in segment
            wvalue = trafo(point)

            move_to(ctx, real(wvalue), imag(wvalue))
            arc(ctx, real(wvalue), imag(wvalue), radius, 0.0, 2*π)
            fill(ctx)
        end
    end
    return nothing
end # }}}

# }}}

"""
```
CV_DirectionPainter{trafoT} <: CV_2DCanvasPainter
    trafo              trafoT
    segments           CV_LineSegments
    auto_close_path    Bool
    every_len          Float64
    pre_gap            Float64
    arrow              ComplexF64
```

Paint triangles (along a curve) to indicate the direction of a curve.
"""
struct CV_DirectionPainter{trafoT} <: CV_2DCanvasPainter # {{{
    trafo           :: trafoT
    segments        :: CV_LineSegments
    auto_close_path :: Bool
    every_len       :: Float64
    pre_gap         :: Float64
    arrow           :: ComplexF64
end

"""
```
CV_DirectionPainter(trafo, segments, auto_close_path=false; 
        every_len=2.0, pre_gap=0.0, arrow=0.3*exp(1im*π*8/9)) 
    trafo   
    segments          CV_LineSegments
    auto_close_path   Bool
    every_len         Real
    pre_gap           Real
    arrow             ComplexF64
```

The `arrow` parameter describes the shape of the triangle:

```
      arrow
        *   ^
        |\\  │
        |░\\ │
        |░░\\│
    ────|░░░┼────>
        |░░/│
        |░/ │
        |/  │
        *   │
     conj(arrow)
```

Moves along the curve. Places after `every_len` a arrow/triangle showing in
the direction of the curve. `pre_gap` can be used to prohibit a
triangle at the beginning (with length `pre_gap`).
"""
CV_DirectionPainter(trafo, segments::CV_LineSegments,
        auto_close_path::Bool=false; 
        every_len::Real=2.0, pre_gap::Real=0.0,
        arrow::ComplexF64=0.3*exp(1im*π*8/9)) =
    CV_DirectionPainter(trafo, segments, auto_close_path,
        Float64(every_len), Float64(pre_gap), ComplexF64(arrow))

"""
```
cv_paint(cc, ldirp)
    cc       CV_2DCanvasContext,
    ldirp    CV_DirectionPainter
```

paint traingle/arrows along the curve.
"""
function cv_paint(cc::CV_2DCanvasContext,
        ldirp::CV_DirectionPainter) # {{{
    ctx, trafo, arrow = cc.ctx, ldirp.trafo, ldirp.arrow

    needed_len = ldirp.pre_gap + ldirp.every_len
    for segment in ldirp.segments
        wold = trafo(segment[1])
        for point in segment[2:end]
            wnew = trafo(point)
            wdiff = wnew - wold
            needed_len -= abs(wdiff)
            if needed_len ≤ 0
                needed_len = ldirp.every_len

                zcenter = wold + 0.5*wdiff
                move_to(ctx, real(zcenter), imag(zcenter))

                wnorm = wdiff/abs(wdiff)

                z = zcenter + arrow * wnorm
                line_to(ctx, real(z), imag(z))
                
                z = zcenter + conj(arrow) * wnorm
                line_to(ctx, real(z), imag(z))

                close_path(ctx)
                fill(ctx)
            end
            wold = wnew
        end
    end
    return nothing
end # }}}
# }}}


"""
```
CV_Math2DCanvasPainterCache 
    last_canvas
    last_data
    last_color_matrix    Matrix{UInt32}
```

A cache for caching the color of every pixel in a (math) canvas.
`last_canvas` and `last_data` is used to save the dependencies for
the pixel colors in order to make recomputations possible if something
changes.
"""
mutable struct CV_Math2DCanvasPainterCache # {{{
    last_canvas
    last_data
    last_color_matrix :: Matrix{UInt32}
end

"""
`CV_Math2DCanvasPainterCache()`

init cache.
"""
CV_Math2DCanvasPainterCache() = CV_Math2DCanvasPainterCache(
    nothing, nothing, zeros(UInt32, 1, 1))

"""
```
cv_is_in_cache(cache, canvas, data)
    cache    CV_Math2DCanvasPainterCache
    canvas
    data
```

checks if the cache contains color values "matching" to `canvas` and `data`.
"""
cv_is_in_cache(cache::CV_Math2DCanvasPainterCache, canvas, data) = (
    cache.last_canvas === canvas && cache.last_data === data)
# }}}

"""
```
CV_PortraitPainter{CS}
    trafo           trafoT
    colorscheme     CS
    cache_flag      Bool
    cache           CV_Math2DCanvasPainterCache    
```

Fill math coordinate system with phase portrait.

For `colorscheme`, please see the package `ComplexPortraits`.

"""
struct CV_PortraitPainter{trafoT, CS} <: CV_2DCanvasPainter  # {{{
    trafo       :: trafoT
    colorscheme :: CS
    cache_flag  :: Bool
    cache       :: CV_Math2DCanvasPainterCache    
end

"""
```
CV_PortraitPainter([trafo=identity, [colorscheme=ComplexPortraits.cs_j(),
                                    [cache_flag=true]]])
    trafo         trafoT
    colorscheme   CS
    cache_flag    Bool
```
"""
function CV_PortraitPainter(trafo::trafoT=identity,
        colorscheme::CS=ComplexPortraits.cs_j(),
        cache_flag::Bool=true) where {trafoT, CS}
    return CV_PortraitPainter{trafoT, CS}(trafo, colorscheme, cache_flag,
        CV_Math2DCanvasPainterCache())
end

"""
```
cv_clear_cache(pp)
    pp    CV_PortraitPainter
```

invalidates the cache (by setting `last_canvas=noting`.
"""
function cv_clear_cache(pp::CV_PortraitPainter)
    if pp.cache_flag
        pp.cache.last_canvas = nothing
    end
    return nothing
end

"""
```
cv_paint(cc, portrait_painter)
    cc                   CV_2DCanvasContext
    portrait_painter     CV_PortraitPainter
```

fill the whole (math) canvas with the phase portrait.
"""
function cv_paint(cc::CV_2DCanvasContext{canvasT},
                  portrait_painter::CV_PortraitPainter{CS}
                  )  where {canvasT <: CV_Math2DCanvas, CS}   # {{{
    canvas = cc.canvas
    cache = portrait_painter.cache
    if portrait_painter.cache_flag && cv_is_in_cache(cache, canvas, nothing)
        color_argb32 = cache.last_color_matrix        
    else
        color_matrix = ComplexPortraits.portrait(
            canvas.corner_ul, canvas.corner_lr,
            portrait_painter.trafo,
            no_pixels=(canvas.pixel_height, canvas.pixel_width),
            point_color=portrait_painter.colorscheme)        
        color_argb32 = map(x -> convert(Colors.ARGB32, x).color, color_matrix) :: Matrix{UInt32}
        if portrait_painter.cache_flag
            cache.last_canvas, cache.last_data = canvas, nothing
            cache.last_color_matrix = color_argb32
        end
    end
    surface = cc.canvas.surface
    Cairo.flush(surface)
    surface.data .= color_argb32'
    Cairo.mark_dirty(surface)
    return nothing
end # }}}
# }}}


"""
```
CV_CombiPainter{T<:CV_Painter, S<:CV_Painter}
    painter1   T
    painter2   S
```

combines two painters.
"""
struct CV_CombiPainter{T<:CV_Painter, S<:CV_Painter} <: CV_Painter # {{{
    painter1 :: T
    painter2 :: S
end

function cv_clear_cache(cpainter::CV_CombiPainter)
    cv_clear_cache(cpainter.painter1)
    cv_clear_cache(cpainter.painter2)
    return nothing
end

function cv_paint(cc::CV_Context, cpainter::CV_CombiPainter)
    cv_paint(cc, cpainter.painter1)
    cv_paint(cc, cpainter.painter2)
    return nothing
end

"""
`→(painter1, painter2)  = CV_CombiPainter(painter1, painter2)`
"""
function →(painter1::T, painter2::S) where {T<:CV_Painter, S<:CV_Painter}
  return CV_CombiPainter(painter1, painter2)
end

"""
`→(nothing, painter2)  = painter2`
"""
→(painter1::Nothing, painter2::S) where {S<:CV_Painter} = painter2

"""
`→(painter1, nothing)  = painter1`
"""
→(painter1::T, painter2::Nothing) where {T<:CV_Painter} = painter1


show(io::IO, m::MIME{Symbol("text/plain")}, p::CV_CombiPainter) =
    cv_show_impl(io, m, p)

# }}}


"""
```
CV_StyledPainter{styleT<:CV_ContextStyle, painterT<:CV_Painter}
    style       styleT
    painter     painterT
```

Painter with Style :-)

This is *the* way to govern the appearance (color, thickness, etc.)
of the painting operations of a painter.
"""
struct CV_StyledPainter{styleT<:CV_ContextStyle,
                        painterT<:CV_Painter} <: CV_Painter   # {{{
    style    :: styleT
    painter  :: painterT
end

"""
`↦(style, painter) = CV_StyledPainter(style, painter)`
"""
↦(style::CV_ContextStyle, painter::CV_Painter) = CV_StyledPainter(
    style, painter)

show(io::IO, m::MIME{Symbol("text/plain")}, p::CV_StyledPainter) =
    cv_show_impl(io, m, p)

function cv_clear_cache(spainter::CV_StyledPainter)
    cv_clear_cache(spainter.painter)
    return nothing
end

function cv_paint(cc::CV_CanvasContext, styled_painter::CV_StyledPainter)
    cv_prepare(cc, styled_painter.style)
    cv_paint(cc, styled_painter.painter)
    return nothing
end # }}}

"""
```
CV_Math2DCanvasPainter <: CV_2DCanvasPainter
    dst_trafo       dtrafoT
    canvas          canvasT <: CV_Math2DCanvas
    src_trafo       strafoT
    src_cut_test    scutT
```
paint transformed (by `dst_trafo`) canvas in coordinate system.

The preimage of the pixel (of the canvas) are transformed by `src_trafo`
(unless `src_trafo === nothing`) and afterwards they are checked with
`src_cut_test` (unless `src_cut_test === nothing`) if the pixels
needs to be "cut" (i.e. left out).
"""
struct CV_Math2DCanvasPainter{dtrafoT, canvasT<:CV_Math2DCanvas,
                              strafoT, scutT} <: CV_2DCanvasPainter # {{{
    dst_trafo       :: dtrafoT
    canvas          :: canvasT
    src_trafo       :: strafoT
    src_cut_test    :: scutT
end

CV_Math2DCanvasPainter(trafo, canvas::CV_Math2DCanvas) =
    CV_Math2DCanvasPainter(trafo, canvas, nothing, nothing)

CV_Math2DCanvasPainter(canvas::CV_Math2DCanvas) =
    CV_Math2DCanvasPainter(identity, canvas)

show(io::IO, m::MIME{Symbol("text/plain")}, p::CV_Math2DCanvasPainter) =
    cv_show_impl(io, m, p)

"""
```
cv_paint(cc, canvas_painter)
    cc                CV_2DCanvasContext{canvasT <: CV_Math2DCanvas}
    canvas_painter    CV_Math2DCanvasPainter{dtrafoT, canvasT,
                            Nothing, Nothing})
```

Implementation without cut-test
"""
function cv_paint(cc::CV_2DCanvasContext{canvasT},
        canvas_painter::CV_Math2DCanvasPainter{dtrafoT, canvasT,
            Nothing, Nothing}) where {canvasT <: CV_Math2DCanvas, dtrafoT} # {{{
    ctx, trafo = cc.ctx, canvas_painter.dst_trafo
    canvas = canvas_painter.canvas
    width, height = canvas.pixel_width, canvas.pixel_height
    wh, hh = width/2, height/2
    punit = 1/canvas.resolution    # units per pxiel (at canvas)

    # missing optimization for:  trafo isa CV_TranslateByOffset
    data = canvas.surface.data
    for row in range(1, height; step=1)
        yb = (row-1-hh)*punit
        yt = yb + punit
        for col in range(1, width; step=1)
            color = ARGB32(data[col, row], Val{true})
            set_source_rgba(ctx,
                red(color), green(color), blue(color), alpha(color))

            xl = (col-1-wh)*punit 
            xr = xl + punit

            z = trafo(xl + yb*1im) :: Complex{Float64}
            move_to(ctx, real(z), imag(z))

            z = trafo(xr + yb*1im) :: Complex{Float64}
            line_to(ctx, real(z), imag(z))

            z = trafo(xr + yt*1im) :: Complex{Float64}
            line_to(ctx, real(z), imag(z))

            z = trafo(xl + yt*1im) :: Complex{Float64}
            line_to(ctx, real(z), imag(z))

            close_path(ctx)
            fill(ctx)
        end
    end
    return nothing
end  # }}}

"""
```
cv_paint(cc, canvas_painter)
    cc                CV_2DCanvasContext{canvasT <: CV_Math2DCanvas}
    canvas_painter    CV_Math2DCanvasPainter{dtrafoT, canvasT,
                            strafoT, scut})
```

Implementation with cut-test
"""
function cv_paint(cc::CV_2DCanvasContext{canvasT},
        canvas_painter::CV_Math2DCanvasPainter{dtrafoT, canvasT,
            strafoT, scutT}) where {canvasT <: CV_Math2DCanvas, dtrafoT,
                strafoT, scutT} # {{{
    ctx, trafo, canvas  = cc.ctx, canvas_painter.dst_trafo, canvas_painter.canvas
    src_trafo, cut_test = canvas_painter.src_trafo, canvas_painter.src_cut_test
    width, height = canvas.pixel_width, canvas.pixel_height
    wh, hh = width/2, height/2
    punit = 1/canvas.resolution    # units per pxiel (at canvas)

    # missing optimization for:  trafo isa CV_TranslateByOffset
    data = canvas.surface.data
    for row in range(1, height; step=1)
        yb = (row-1-hh)*punit
        yt = yb + punit
        for col in range(1, width; step=1)
            xl = (col-1-wh)*punit 
            xr = xl + punit

            w1 = trafo(xl + yb*1im) :: Complex{Float64}
            z1 = src_trafo(xl + yb*1im) :: Complex{Float64}

            w2 = trafo(xr + yb*1im) :: Complex{Float64}
            z2 = src_trafo(xr + yb*1im) :: Complex{Float64}

            w3 = trafo(xr + yt*1im) :: Complex{Float64}
            z3 = src_trafo(xr + yt*1im) :: Complex{Float64}

            w4 = trafo(xl + yt*1im) :: Complex{Float64}
            z4 = src_trafo(xl + yt*1im) :: Complex{Float64}

            if !cut_test(z1, z2) && !cut_test(z2, z3) &&
                    !cut_test(z3, z4) && !cut_test(z4, z1)
                color = ARGB32(data[col, row], Val{true})
                set_source_rgba(ctx,
                    red(color), green(color), blue(color), alpha(color))
                move_to(ctx, real(w1), imag(w1))
                line_to(ctx, real(w2), imag(w2))
                line_to(ctx, real(w3), imag(w3))
                line_to(ctx, real(w4), imag(w4))
                close_path(ctx)
                fill(ctx)
            end
        end
    end
    return nothing
end # }}}
# }}}


"""
```
cv_parallel_lines(direction;  width=1.0, lines=5, segments=120)
    direction   ComplexF64    direction for lines
    width       Real          space/width the lines cover
    lines       Integer       number of lines
    segments    Integer       how many segments per line
```

returns the `CV_LineSegments`.
"""
function cv_parallel_lines(direction::ComplexF64;
                           width::Real=1.0, lines::Integer=5,
                           segments::Integer=120)  # {{{
    width = Float64(width)
    if !isfinite(direction)
        cv_error("direction must be finite; direction = ", direction)
    end
    len = abs(direction)
    if len == 0
        cv_error("direction must not be 0")
    end
    if !isfinite(width)
        cv_error("width must be finite; width = ", width)
    end
    if !(width > 0)
        cv_error("width must be positive; width = ", width)
    end
    if !(lines > 0)
        cv_error("lines must be positive; lines = ", lines)
    end
    if !(segments > 0)
        cv_error("segments must be positive; segments = ", segments)
    end
    
    perp_dir = 1im*direction/len
    perp_parts = (lines == 1) ? (0.0:0.0) : range(-0.5*width, stop=0.5*width, length=lines)
    
    line_segs = CV_LineSegments()
    seg_parts = collect(0:segments) / segments
    for perp_part in perp_parts
        push!(line_segs, (perp_part*perp_dir - direction/2) .+ (seg_parts .* direction))
    end
    return line_segs
end # }}}

"""
```
cv_arc_lines(ϕ_start, ϕ_end, radii; segments=120)
    ϕ_start    Real                start angle
    ϕ_end      Real                end angle
    radii      NTuple{N, Real}     radii for the arcs
    segments   Integer             how many segments per line
```

create a `CV_LineSegments` with arcs starting at the angle `ϕ_start`
and ending at the angle `ϕ_end`. In `radii` one can give radii at which
the lines are created.
"""
function cv_arc_lines(ϕ_start::Real, ϕ_end::Real, radii::NTuple{N, Real};
                      segments::Integer=120) where {N} # {{{
    ϕ_start, ϕ_end = Float64(ϕ_start), Float64(ϕ_end)

    arc = exp.(1im .* range(ϕ_start, stop=ϕ_end, length=1+segments))
    line_segs = [Float64(radius) * arc for radius in radii]
    return line_segs
end # }}}

"""
```
cv_star_lines(r_start, r_end, angles; segments=120) 
    r_start     Real                start radius
    r_end       Real                end radius
    angles      NTuple{N, Real}     lines at this angles
    segments    Integer             how many segments per line
```
create a `CV_LineSegments` with star lines starting the radius `r_start`
and ending at the radius `r_end`. In `angles` one can give angles at
which the lines are created.
"""
function cv_star_lines(r_start::Real, r_end::Real, angles::NTuple{N, Real};
                       segments::Integer=120) where {N}  # {{{
    r_start, r_end = Float64(r_start), Float64(r_end)

    line = collect(range(r_start, stop=r_end, length=1+segments))

    line_segs = [exp(1im*Float64(ϕ)) * line for ϕ in angles]
    return line_segs
end # }}}

"""
```
cv_star_arc_lines(radii, angle; star_segments=120, arc_segments=120) 
    radii           NTuple{N, Real}
    angles          NTuple{M, Real};
    star_segments   Integer
    arc_segments    Integer
```

combination of `cv_star_lines` and `cv_arc_lines`.
"""
function cv_star_arc_lines(radii::NTuple{N, Real}, angles::NTuple{M, Real};
                star_segments::Integer=120,
                arc_segments::Integer=120) where {M, N}
    r_start, r_end = minimum(radii), maximum(radii)
    ϕ_start, ϕ_end = minimum(angles), maximum(angles)

    return (cv_star_lines(r_start, r_end, angles; segments=star_segments),
            cv_arc_lines(ϕ_start, ϕ_end, radii; segments=arc_segments))
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
