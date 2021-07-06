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


