# In this visualization we wish to Generate an image of the Mandelbrot
# set, and interactive images of Julia sets. To do this, we will need
# to create our own painter function and colorscheme.
using Cairo, Colors, ColorTypes
using ComplexVisual; @ComplexVisual.import_huge
using ComplexVisualGtk; @ComplexVisualGtk.import_huge
using ComplexPortraits; @ComplexPortraits.import_huge

# We first need a painter function that redraws a portrait
# every time the action position changes. There are simply
# too many pixel options to cache every drawn image
struct CV_PortraitPainterWithoutCache{trafoT, CS} <: CV_2DCanvasPainter  # {{{
    trafo       :: trafoT
    colorscheme :: CS
end
function CV_PortraitPainterWithoutCache(trafo::trafoT=identity,
        colorscheme::CS=ComplexPortraits.cs_j()) where {trafoT, CS}
    return CV_PortraitPainterWithoutCache{trafoT, CS}(trafo, colorscheme)
end

# CV_PortraitPainterWithoutCache performs the same painting
# function as CV_PortraitPainter. See `painter.jl` for the original
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
    color_argb32 = map(color_matrix) do x
        convert(Colors.ARGB32, x).color
    end :: Matrix{UInt32}
    surface = cc.canvas.surface
    Cairo.flush(surface)
    surface.data .= color_argb32'
    Cairo.mark_dirty(surface)
    return nothing
end

# This is our approximation function for the Mandelbrot and Julia
# sets. Our goal is to see if the function `f(z) = z^2 + c` stays
# bounded after infinitely many iterations `f ∘ f ∘ ... ∘ f (z)`.
# Since we can't do infinite iterations, we use a finite number of 
# iterations and a finite bounding circle. If 
# `|fⁿᵈⁱᵗᵉʳ(z)| < maxabs`, we assume it will stay bounded. 
function trafo(z; c=0.0 + 0.0im, maxabs=4, nditer=16)
    k = 1
    while abs(z) < maxabs && k < nditer
        z = z^2 + c
        k += 1
    end
    k == nditer && return 0
    return k % 360
end

# Now we need a custom colorscheme to paint each number 
# of iterations a different color
function cs_circ(; colormap=hsv_colors())
    stepfct = generate_stepfct(length(colormap))
    let cm = RGB.(colormap)
      return function(z, fz)
        fz < 1 && return RGB(0, 0, 0)
        color = cm[stepfct(1/fz)]
        return RGB(color.r, color.g, color.b)
      end
    end
end

# We set up the standard left-right layout now
domain = CV_Math2DCanvas(-2.0+1.5im, 1.0-1.5im, 250)
codomain = CV_Math2DCanvas(-2.0+2.0im, 2.0-2.0im, 200)
action_pos = CV_TranslateByOffset(ComplexF64)
style = cv_color(1, 1, 1, 1) → cv_linewidth(3) → cv_antialias_best
cross = [[0.0+0.05im, 0.0-0.05im, 0.0+0.0im, 0.05+0.0im, -0.05+0.0im]]

# `:portrait_painter_domain` draws a custom phase portrait once 
# at the beginning of the visualization on the left (domain) side.
# 
# `:img_painter_domain`, `:img_painter_codomain` are options to 
# change the interactive set that gets drawn on mouseclick. On the
# left side, we wish to show a small reticle to indicate where the 
# user clicks. On the right side we draw the corresponding Julia set.
lr_painters_kwargs = Dict(
    :portrait_painter_domain => CV_PortraitPainter(
        w -> trafo(0.0+0.0im; c=w, maxabs=4, nditer=32), cs_circ()
    ),
    :img_painter_domain => style ↦ CV_LinePainter(
        action_pos, cross
    ),
    :img_painter_codomain => CV_PortraitPainterWithoutCache(
        w -> trafo(w; c=action_pos(0.0+0.0im), maxabs=4, nditer=16), 
        cs_circ()
    ), 
    :action_pos => action_pos
)

# Finally, we can see our work!
scene = cv_scene_lr_std(identity, domain, codomain; lr_painters_kwargs)
handler = cvg_visualize(scene); cvg_wait_for_destroy(handler.window)
cvg_close(handler); cv_destroy(scene)
