# [![./Context_docicon.png](./Context_docicon.png) Context](./Context.md)

Contexts (i.e. subtypes of [`CV_Context`](./Context.md#user-content-cv_context)) are very thin wrappers for Cairo contexts. They are used to draw/paint (typically inside canvases).

## `CV_Context`

[`CV_Context`](./Context.md#user-content-cv_context): object (with styles, etc.) used for drawing/painting.

## `CV_CanvasContext`

```
abstract CV_CanvasContext  <: CV_Context
    # required fields
    # canvas  (subtype of CV_Canvas)
    # ctx     (CairoContext)
```

A context for a canvas.

## `CV_2DCanvasContext`

```
CV_2DCanvasContext{canvasT} <: CV_CanvasContext
    canvas     canvasT         <:CV_2DCanvas
    ctx        CairoContext
```

Context for two-dimensional painting/drawing in the `canvas`. This wrapper is mainly used to have the type of `canvas` as a parametric type.

## `cv_create_context`

```
cv_create_context(canvas; prepare=true)
    canvas    CV_2DCanvas
    prepare   Bool
```

Create Context for 2DCanvas. If `prepare` is `true` then (depending on the concrete CV_2DCanvas subtype) special preperations or initializations for the context are done.

```
cv_create_context(canvas; prepare=true)
    canvas       CV_Math2DCanvas
    prepare      Bool
```

create context for Math2DCanvas. If `prepare` is `true` the the context's user coordinate system is the mathematical coordinate system of the Math2DCanvas. See also [`CV_MathCoorStyle`](./Style.md#user-content-cv_mathcoorstyle).

```
cv_create_context(do_func, canvas, [style=nothing]; prepare=true)
    do_func       Function
    canvas        CV_Canvas
    style         Union{Nothing, CV_ContextStyle}
    prepare       Bool
```

call `cv_create_context` ([`Style`](./Style.md#user-content-cv_create_context), [`Context`](./Context.md#user-content-cv_create_context)) ([`Style`](./Style.md#user-content-cv_create_context), [`Context`](./Context.md#user-content-cv_create_context)) for `canvas`, execute `do_func` and destroy the context afterwards.


