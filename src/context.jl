macro import_context_huge()
    :(
        using ComplexVisual:
            CV_Context, CV_CanvasContext,
            cv_destroy, CV_2DCanvasContext
    )
end

import Base:show

"""
`CV_Context`: object (with styles, etc.) used for drawing/painting.
"""
abstract type CV_Context end

"""
```
abstract CV_CanvasContext  <: CV_Context
    # required fields
    # canvas  (subtype of CV_Canvas)
    # ctx     (CairoContext)
```

A context for a canvas.
"""
abstract type CV_CanvasContext  <: CV_Context
    # required fields
    # canvas  (subtype of CV_Canvas)
    # ctx     (CairoContext)
end

show(io::IO, cc::CV_CanvasContext) = cv_show_impl(io, cc)
show(io::IO, m::MIME{Symbol("text/plain")}, cc::CV_CanvasContext) =
    cv_show_impl(io, m, cc)

"""
`cv_destroy(canvas_context)`

destroeys Cairo context (inside).
"""
function cv_destroy(cc::canvasT) where {canvasT<:CV_CanvasContext}
    destroy(cc.ctx)
    return nothing
end

"""
```
CV_2DCanvasContext{canvasT} <: CV_CanvasContext
    canvas     canvasT         <:CV_2DCanvas
    ctx        CairoContext
```

Context for two-dimensional painting/drawing in the `canvas`. This
wrapper is mainly used to have the type of `canvas` as a parametric type.
"""
struct CV_2DCanvasContext{canvasT<:CV_2DCanvas} <: CV_CanvasContext
    canvas :: canvasT
    ctx    :: CairoContext

    function CV_2DCanvasContext(canvas::T) where {T<:CV_2DCanvas}
        ctx = CairoContext(canvas.surface)
        return new{T}(canvas, ctx)
    end
end


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:

