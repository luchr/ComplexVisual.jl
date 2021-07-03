# Style

Styles are used to govern the appearance of painting and drawing actions. They are used to "bundle" typical (Cairo-context) changes in order to make them reusable.

## Quick links

[`cv_color`](./Style.md#user-content-cv_color)   [`cv_linewidth`](./Style.md#user-content-cv_linewidth) [`CV_CombiContextStyle`](./Style.md#user-content-cv_combicontextstyle)    [`→`](./Style.md#user-content--u2192) [`cv_create_context`](./Style.md#user-content-cv_create_context)

## `cv_create_context`

```
cv_create_context(do_func, canvas, [style=nothing]; prepare=true)
    do_func       Function
    canvas        CV_Canvas
    style         Union{Nothing, CV_ContextStyle}
    prepare       Bool
```

call [`cv_create_context`](./Style.md#user-content-cv_create_context) for `canvas`, execute `do_func` and destroy the context afterwards.

## `CV_CombiContextStyle`

```
CV_CombiContextStyle{T, S} <: CV_ContextStyle
    style1     T <: CV_ContextStyle
    style2     S <: CV_ContextStyle
```

combines to styles to a new style.

## `→ (U+2192)`

`→(style1, style2) = CV_CombiContextStyle(style1, style2)`

## `cv_color`

```
cv_color(red, green, blue[, alpha=1.0])
    red     Real
    green   Real
    blue    Real
    alpha   Real
```

## `cv_black`

```
CV_ContextColorStyle <: CV_CanvasContextStyle 
    red       Float64
    green     Float64
    blue      Float64
    alpha     Float64
```

sets stroke and fill to constant red, green, blue color (with alpha-value).

## `cv_white`

```
CV_ContextColorStyle <: CV_CanvasContextStyle 
    red       Float64
    green     Float64
    blue      Float64
    alpha     Float64
```

sets stroke and fill to constant red, green, blue color (with alpha-value).

## `cv_linewidth`

`cv_linewidth(width) = CV_ContextLineWidthStyle(Float64(width))`

set line width.


