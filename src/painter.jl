macro import_painter_huge()
    :(
        using ComplexVisual:
                CV_PaintingContext, CV_EmptyPaintingContext,
                CV_2DDomainCodomainPaintingContext,
                CV_Painter, cv_paint, CV_CanvasPainter, CV_2DCanvasPainter,
                CV_2DCanvasFillPainter, CV_2DValueMarkPainter, 
                CV_2DAxisGridPainter, CV_LineSegment, CV_LineSegments,
                CV_2DCanvasLinePainter, CV_2DCanvasLineDirectionPainter,
                CV_2DCanvasLineDirectionPainterContext,
                cv_line_direction_context,
                CV_Math2DCanvasPortraitPainter, cv_clear_cache,
                CV_CombiPainter, →, CV_StyledPainter, ↦, 
                CV_Math2DCanvasPainter,
                cv_parallel_lines, cv_arc_lines, cv_star_lines,
                cv_star_arc_lines
    )
end

import Base:show

"""
Abstract supertype for combining informations about the painting (mathematical
transformations, etc.)
"""
abstract type CV_PaintingContext end

"""
Empty painting context.
"""
struct CV_EmptyPaintingContext <: CV_PaintingContext
end

"""
Painting Context describing the transformation `trafo` an
optional source transformation (if `trafo` describes the transformation
in the domain, then `src_trafo` describes the transformation in the
codomain).
Optionally there is a `src_cut_test` function which may be used
by the painter to see if there is a singularity on a line segment.
"""
struct CV_2DDomainCodomainPaintingContext{
        trafoT, src_trafoT, src_cutT} <: CV_PaintingContext
    trafo         :: trafoT
    src_trafo     :: src_trafoT
    src_cut_test  :: src_cutT
end


"""
Instances of this type can paint inside objects with math coordinate
systems (e.g. `CV_Math2DCanvas`).
"""
abstract type CV_Painter end

show(io::IO, p::CV_Painter) = cv_show_impl(io, p)

"""
Instances of this type can paint inside canvases with math coordinate
systems (e.g. `CV_Math2DCanvas`).
"""
abstract type CV_CanvasPainter <: CV_Painter end

"""
Instances of this type can paint inside 2D canvases with math coordinate
systems (e.g. `CV_Math2DCanvas`).
"""
abstract type CV_2DCanvasPainter <: CV_CanvasPainter end

"""
A painter filling  the complete canvas.
"""
struct CV_2DCanvasFillPainter <: CV_2DCanvasPainter # {{{
end

function cv_paint(cc::CV_2DCanvasContext, fill_painter::CV_2DCanvasFillPainter,
                  pc::CV_PaintingContext)
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
A painter drawing a vertical line-segment `(offset, start)` to
`(offset, start + len)` (in the math coordinate system). Here 
the `offset` is the offset-value of a `CV_TranslateByOffset`.

If `vertical` is `true` then the real- and imag-coordinates are
swapped for drawing.
"""
struct CV_2DValueMarkPainter{N<:Number} <: CV_2DCanvasPainter # {{{
    where     :: CV_TranslateByOffset{N}
    start     :: Float64
    len       :: Float64
    vertical  :: Bool
end

function cv_paint(cc::CV_2DCanvasContext, mark_painter::CV_2DValueMarkPainter,
                  pc::CV_PaintingContext)
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
A painter drawing axis grid lines.

Hence this painter ignores the PaintingContext.
"""
struct CV_2DAxisGridPainter <: CV_2DCanvasPainter  # {{{
    reals   :: Vector{Float64}
    imags   :: Vector{Float64}

end

function CV_2DAxisGridPainter(reals::NTuple{N, Real},
                              imags::NTuple{M, Real}) where {M, N}
    return CV_2DAxisGridPainter(
        [Float64(x) for x in reals],
        [Float64(y) for y in imags])
end

show(io::IO, m::MIME{Symbol("text/plain")}, gp::CV_2DAxisGridPainter) =
    cv_show_impl(io, m, gp)

function cv_paint(cc::CV_2DCanvasContext, grid_painter::CV_2DAxisGridPainter,
                  pc::CV_PaintingContext)
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
end
# }}}

const CV_LineSegment = Vector{Complex{Float64}}
const CV_LineSegments = Vector{CV_LineSegment}

struct CV_2DCanvasLinePainter <: CV_2DCanvasPainter # {{{
    segments        :: CV_LineSegments
    auto_close_path :: Bool
end
CV_2DCanvasLinePainter(segments::CV_LineSegments) = CV_2DCanvasLinePainter(
    segments, false)

"""
Implementation without cut-test
"""
function cv_paint_line_painter(
        cc::CV_2DCanvasContext, line_painter::CV_2DCanvasLinePainter, trafo)

    ctx = cc.ctx
    for segment in line_painter.segments
        value = trafo(segment[1])
        move_to(ctx, real(value), imag(value))
        for point in segment[2:end]
            value = trafo(point)
            line_to(ctx, real(value), imag(value))
        end
        if line_painter.auto_close_path
            close_path(ctx)
        end
        stroke(ctx)
    end
    return nothing
end

"""
Implementation with cut-test
"""
function cv_paint_line_painter(
        cc::CV_2DCanvasContext, line_painter::CV_2DCanvasLinePainter,
        pc::CV_2DDomainCodomainPaintingContext)

    ctx, trafo, src_trafo = cc.ctx, pc.trafo, pc.src_trafo
    cut_test = pc.src_cut_test

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
end

function cv_paint(cc::CV_2DCanvasContext,
                  line_painter::CV_2DCanvasLinePainter,
                  pc::CV_2DDomainCodomainPaintingContext{trafoT,
                        src_trafoT, src_cutT}) where {trafoT,
                            src_trafoT <: Nothing, src_cutT <: Nothing}
    return cv_paint_line_painter(cc, line_painter, pc.trafo)
end

function cv_paint(cc::CV_2DCanvasContext,
                  line_painter::CV_2DCanvasLinePainter,
                  pc::CV_2DDomainCodomainPaintingContext{trafoT,
                        src_trafoT, src_cutT}) where {trafoT,
                            src_trafoT <: Nothing, src_cutT}
    return cv_paint_line_painter(cc, line_painter, pc.trafo)
end

function cv_paint(cc::CV_2DCanvasContext,
                  line_painter::CV_2DCanvasLinePainter,
                  pc::CV_2DDomainCodomainPaintingContext{trafoT,
                        src_trafoT, src_cutT}) where {trafoT,
                            src_trafoT, src_cutT <: Nothing}
    return cv_paint_line_painter(cc, line_painter, pc.trafo)
end

function cv_paint(cc::CV_2DCanvasContext,
                  line_painter::CV_2DCanvasLinePainter,
                  pc::CV_2DDomainCodomainPaintingContext{trafoT,
                        src_trafoT, src_cutT}) where {trafoT,
                            src_trafoT, src_cutT}
    return cv_paint_line_painter(cc, line_painter, pc)
end

# }}}


"""
Painting Context for `CV_2DCanvasLineDirectionPainter`.

Description of the appearance of the arrow pointers und where to place them.
"""
struct CV_2DCanvasLineDirectionPainterContext{trafoT} <: CV_PaintingContext
    trafo         :: trafoT
    every_len     :: Float64
    pre_gap       :: Float64
    arrow         :: ComplexF64
end

function cv_line_direction_context(trafo;
        every_len=2.0, pre_gap=0.0, arrow=0.3*exp(1im*π*8/9))
    return CV_2DCanvasLineDirectionPainterContext(trafo, Float64(every_len),
        Float64(pre_gap), ComplexF64(arrow))
end

struct CV_2DCanvasLineDirectionPainter <: CV_2DCanvasPainter # {{{
    segments        :: CV_LineSegments
    auto_close_path :: Bool
end

function cv_paint(cc::CV_2DCanvasContext,
        ldirp::CV_2DCanvasLineDirectionPainter,
        pc::CV_2DCanvasLineDirectionPainterContext)
    ctx, trafo, arrow = cc.ctx, pc.trafo, pc.arrow

    needed_len = pc.pre_gap + pc.every_len
    for segment in ldirp.segments
        wold = trafo(segment[1])
        for point in segment[2:end]
            wnew = trafo(point)
            wdiff = wnew - wold
            needed_len -= abs(wdiff)
            if needed_len ≤ 0
                needed_len = pc.every_len

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
end
# }}}

mutable struct CV_Math2DCanvasPainterCache # {{{
    last_canvas
    last_pc
    last_color_matrix :: Matrix{UInt32}
end
CV_Math2DCanvasPainterCache() = CV_Math2DCanvasPainterCache(
    nothing, nothing, zeros(UInt32, 1, 1))
cv_is_in_cache(cache::CV_Math2DCanvasPainterCache, canvas, pc) = (
    cache.last_canvas === canvas && cache.last_pc === pc
)

struct CV_Math2DCanvasPortraitPainter{CS} <: CV_2DCanvasPainter
    colorscheme :: CS
    cache_flag  :: Bool
    cache       :: CV_Math2DCanvasPainterCache    
    function CV_Math2DCanvasPortraitPainter(colorscheme::CS,
                                            cache_flag::Bool) where {CS}
        return new{CS}(colorscheme, cache_flag,
                       CV_Math2DCanvasPainterCache())
    end
end
CV_Math2DCanvasPortraitPainter() = CV_Math2DCanvasPortraitPainter(
    ComplexPortraits.cs_j(), true)

function cv_clear_cache(pp::CV_Math2DCanvasPortraitPainter)
    if pp.cache_flag
        pp.cache.last_canvas = nothing
    end
    return nothing
end

function cv_paint(cc::CV_2DCanvasContext{canvasT},
                  portrait_painter::CV_Math2DCanvasPortraitPainter{CS},
                  pc::CV_PaintingContext)  where {canvasT <: CV_Math2DCanvas, CS}
    canvas = cc.canvas
    cache = portrait_painter.cache
    if portrait_painter.cache_flag && cv_is_in_cache(cache, canvas, pc)
        color_argb32 = cache.last_color_matrix        
    else
        color_matrix = ComplexPortraits.portrait(
            canvas.corner_ul, canvas.corner_lr,
            pc.trafo,
            no_pixels=(canvas.pixel_height, canvas.pixel_width),
            point_color=portrait_painter.colorscheme)        
        color_argb32 = map(x -> convert(Colors.ARGB32, x).color, color_matrix) :: Matrix{UInt32}
        if portrait_painter.cache_flag
            cache.last_canvas = canvas
            cache.last_pc = pc
            cache.last_color_matrix = color_argb32
        end
    end
    surface = cc.canvas.surface
    Cairo.flush(surface)
    surface.data .= color_argb32'
    Cairo.mark_dirty(surface)
    return nothing
end # }}}

struct CV_CombiPainter{T<:CV_Painter, S<:CV_Painter} <: CV_Painter # {{{
    painter1 :: T
    painter2 :: S
end

function cv_paint(cc::CV_Context,
                  cpainter::CV_CombiPainter, pc::CV_PaintingContext)
    cv_paint(cc, cpainter.painter1, pc)
    cv_paint(cc, cpainter.painter2, pc)
    return nothing
end

function →(painter1::T, painter2::S) where {T<:CV_Painter, S<:CV_Painter}
  return CV_CombiPainter(painter1, painter2)
end

show(io::IO, m::MIME{Symbol("text/plain")}, p::CV_CombiPainter) =
    cv_show_impl(io, m, p)

# }}}

struct CV_StyledPainter{styleT<:CV_ContextStyle,
                        painterT<:CV_Painter} <: CV_Painter   # {{{
    style    :: styleT
    painter  :: painterT
end
↦(style::CV_ContextStyle, painter::CV_Painter) = CV_StyledPainter(
    style, painter)

show(io::IO, m::MIME{Symbol("text/plain")}, p::CV_StyledPainter) =
    cv_show_impl(io, m, p)

function cv_paint(cc::CV_CanvasContext,
                  styled_painter::CV_StyledPainter,
                  pc::CV_PaintingContext)
    cv_prepare(cc, styled_painter.style)
    cv_paint(cc, styled_painter.painter, pc)
    return nothing
end # }}}

struct CV_Math2DCanvasPainter{T<:CV_Math2DCanvas} <: CV_2DCanvasPainter # {{{
    canvas :: T
end

show(io::IO, m::MIME{Symbol("text/plain")}, p::CV_Math2DCanvasPainter) =
    cv_show_impl(io, m, p)

"""
Implementation without cut-test
"""
function cv_paint_2dmathcanvaspainter(cc::CV_2DCanvasContext{canvasT},
                  canvas_painter::CV_Math2DCanvasPainter{CS},
                  trafo)  where {canvasT <: CV_Math2DCanvas, CS}
    ctx = cc.ctx
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
end 

"""
Implementation with cut-test
"""
function cv_paint_2dmathcanvaspainter(cc::CV_2DCanvasContext{canvasT},
                  canvas_painter::CV_Math2DCanvasPainter{CS},
                  pc::CV_2DDomainCodomainPaintingContext)  where {
                    canvasT <: CV_Math2DCanvas, CS}
    ctx, trafo, canvas  = cc.ctx, pc.trafo, canvas_painter.canvas
    src_trafo, cut_test = pc.src_trafo, pc.src_cut_test
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
end

function cv_paint(cc::CV_2DCanvasContext{canvasT},
                  canvas_painter::CV_Math2DCanvasPainter{CS},
                  pc::CV_2DDomainCodomainPaintingContext{trafoT,
                        src_trafoT, src_cutT})  where {
                        canvasT <: CV_Math2DCanvas, CS, trafoT,
                        src_trafoT <: Nothing, src_cutT <: Nothing}
    return cv_paint_2dmathcanvaspainter(cc, canvas_painter, pc.trafo)
end

function cv_paint(cc::CV_2DCanvasContext{canvasT},
                  canvas_painter::CV_Math2DCanvasPainter{CS},
                  pc::CV_2DDomainCodomainPaintingContext{trafoT,
                        src_trafoT, src_cutT})  where {
                        canvasT <: CV_Math2DCanvas, CS, trafoT,
                        src_trafoT <: Nothing, src_cutT}
    return cv_paint_2dmathcanvaspainter(cc, canvas_painter, pc.trafo)
end

function cv_paint(cc::CV_2DCanvasContext{canvasT},
                  canvas_painter::CV_Math2DCanvasPainter{CS},
                  pc::CV_2DDomainCodomainPaintingContext{trafoT,
                        src_trafoT, src_cutT})  where {
                        canvasT <: CV_Math2DCanvas, CS, trafoT,
                        src_trafoT, src_cutT <: Nothing}
    return cv_paint_2dmathcanvaspainter(cc, canvas_painter, pc.trafo)
end

function cv_paint(cc::CV_2DCanvasContext{canvasT},
                  canvas_painter::CV_Math2DCanvasPainter{CS},
                  pc::CV_2DDomainCodomainPaintingContext{trafoT,
                        src_trafoT, src_cutT})  where {
                        canvasT <: CV_Math2DCanvas, CS, trafoT,
                        src_trafoT, src_cutT}
    return cv_paint_2dmathcanvaspainter(cc, canvas_painter, pc)
end
# }}}


function cv_parallel_lines(direction::Complex{Float64};
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
    return CV_2DCanvasLinePainter(line_segs)
end # }}}

"""
create a CV_2DCanvasLinePainter with arcs starting at the angle `ϕ_start`
and ending at the angle `ϕ_end`. In `radii` one can give radii at which
the lines are created.
"""
function cv_arc_lines(ϕ_start::Real, ϕ_end::Real, radii::NTuple{N, Real};
                      segments::Integer=120,
                      auto_close_path::Bool=false) where {N} # {{{
    ϕ_start, ϕ_end = Float64(ϕ_start), Float64(ϕ_end)

    arc = exp.(1im .* range(ϕ_start, stop=ϕ_end, length=1+segments))
    line_segs = [Float64(radius) * arc for radius in radii]
    return CV_2DCanvasLinePainter(line_segs, auto_close_path)
end # }}}

"""
create a CV_2DCanvasLinePainter with star lines starting the radius `r_start`
and ending at the radius `r_end`. In `angles` one can give angles at
which the lines are created.
"""
function cv_star_lines(r_start::Real, r_end::Real, angles::NTuple{N, Real};
                       segments::Integer=120,
                       auto_close_path::Bool=false) where {N}  # {{{
    r_start, r_end = Float64(r_start), Float64(r_end)

    line = collect(range(r_start, stop=r_end, length=1+segments))

    line_segs = [exp(1im*Float64(ϕ)) * line for ϕ in angles]
    return CV_2DCanvasLinePainter(line_segs, auto_close_path)
end # }}}

"""
create star-lines and arc-lines matching together.
"""
function cv_star_arc_lines(radii::NTuple{N, Real}, angles::NTuple{M, Real};
                star_segments::Integer=120, arc_segments::Integer=120,
                auto_close_arcs::Bool=false) where {M, N}
    r_start, r_end = minimum(radii), maximum(radii)
    ϕ_start, ϕ_end = minimum(angles), maximum(angles)

    return (cv_star_lines(r_start, r_end, angles; segments=star_segments),
            cv_arc_lines(ϕ_start, ϕ_end, radii; segments=arc_segments,
                         auto_close_path=auto_close_arcs))
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
