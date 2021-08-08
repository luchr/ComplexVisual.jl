using Colors, ColorTypes, ColorVectorSpace, Cairo, SharedArrays, ComplexVisual, ComplexVisualGtk, ComplexPortraits
@ComplexVisual.import_huge; @ComplexVisualGtk.import_huge, @ComplexPortraits.import_huge
import ComplexPortraits: portrait, cs_j
function portrait(z_upperleft, z_lowerright, f;
    no_pixels=(600,600), point_color=cs_j())
    if length(no_pixels) == 1
        no_pixels = (no_pixels[1], no_pixels[1])
    end
    width = LinRange(real(z_upperleft), real(z_lowerright), no_pixels[2])
    height = LinRange(imag(z_upperleft), imag(z_lowerright), no_pixels[1])
    out = SharedArray(zeros(RGB{Float32}, no_pixels[1], no_pixels[2]))
    @sync @distributed for i in CartesianIndices(out)
        let (x, y) = Tuple(i)
            out[i] = point_color(width[x]+height[y]*im, f(width[x]+height[y]*im))
        end
    end
    return out
end
function trafo(z; c=0.0 + 0.0im, maxabs=4, nditer=16)
    z_out, k = z, 1
    while abs(z_out) < maxabs && k < nditer
        z_out = z_out^2 + c
        k += 1
    end
    k == nditer && return 0
    return k % 360
end

struct CV_PortraitPainterWithoutCache{trafoT, CS} <: CV_2DCanvasPainter  # {{{
    trafo       :: trafoT
    colorscheme :: CS
end
function CV_PortraitPainterWithoutCache(trafo::trafoT=identity,
        colorscheme::CS=ComplexPortraits.cs_j()) where {trafoT, CS}
    return CV_PortraitPainterWithoutCache{trafoT, CS}(trafo, colorscheme)
end
import ComplexVisual: cv_paint
function cv_paint(cc::CV_2DCanvasContext{canvasT},
    portrait_painter::CV_PortraitPainterWithoutCache{CS}
    )  where {canvasT <: CV_Math2DCanvas, CS}   # {{{
    canvas = cc.canvas
    color_matrix = ComplexPortraits.portrait(
    canvas.corner_ul, canvas.corner_lr,
    portrait_painter.trafo,
    no_pixels=(canvas.pixel_height, canvas.pixel_width),
    point_color=portrait_painter.colorscheme)        
    color_argb32 = map(x -> convert(Colors.ARGB32, x).color, color_matrix) :: Matrix{UInt32}
    surface = cc.canvas.surface
    Cairo.flush(surface)
    surface.data .= color_argb32'
    Cairo.mark_dirty(surface)
    return nothing
end

function cs_circ(; colormap=hsv_colors())
    stepfct = generate_stepfct(length(colormap))
    let cm = RGB.(colormap)
      return function(z, fz)
        absfz = abs(fz)
        absfz < 1 && return RGB(0, 0, 0)
        color = cm[stepfct(1/absfz)]
        return RGB(color.r, color.g, color.b)
      end
    end
end

function trafo(z; c=0.0 + 0.0im, maxabs=4, nditer=16)
    z_out, k = z, 1
    while abs(z_out) < maxabs && k < nditer
        z_out = z_out^2 + c
        k += 1
    end
    k == nditer && return 0
    return k % 360
end

domain = CV_Math2DCanvas(-2.0+1.5im, 1.0-1.5im, 250)
codomain = CV_Math2DCanvas(-2.0+2.0im, 2.0-2.0im, 200)
action_pos = CV_TranslateByOffset(ComplexF64)
style = cv_color(1, 1, 1, 1) → cv_linewidth(3) → cv_antialias_best
cross = [[0.0+0.05im, 0.0-0.05im, 0.0+0.0im, 0.05+0.0im, -0.05+0.0im]]

lr_painters_kwargs = Dict(
    :portrait_painter_domain => CV_PortraitPainter(
        w -> trafo(0.0+0.0im; c=w, maxabs=4, nditer=32), cs_circ()
    ),
    :img_painter_domain => style ↦ CV_LinePainter(
        action_pos, cross
    ),
    :img_painter_codomain => CV_PortraitPainterWithoutCache(
        w -> trafo(
            w; c=action_pos(0.0+0.0im), maxabs=4, nditer=16
        ), 
        cs_circ()
    ), 
    :action_pos => action_pos
)

scene = cv_scene_lr_std(
    #z -> trafo(0.0+0.0im; c=z, maxabs=4, nditer=16), 
    identity,
    domain, codomain; lr_painters_kwargs
)