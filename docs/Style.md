# [![./Style_docion.png](./Style_docion.png) Style](./Style.md)

Styles are used to govern the appearance of painting and drawing actions. They are used to "bundle" typical (Cairo-context) changes in order to make them reusable.

## Quick links

  * [`cv_color`](./Style.md#user-content-cv_color) ([`cv_black`](./Style.md#user-content-cv_black)  [`cv_white`](./Style.md#user-content-cv_white))
  * [`cv_linewidth`](./Style.md#user-content-cv_linewidth)
  * [`cv_antialias`](./Style.md#user-content-cv_antialias) ([`cv_antialias_best`](./Style.md#user-content-cv_antialias_best)  [`cv_antialias_none`](./Style.md#user-content-cv_antialias_none))
  * [`cv_opmode`](./Style.md#user-content-cv_opmode) ([`cv_op_source`](./Style.md#user-content-cv_op_source)  [`cv_op_over`](./Style.md#user-content-cv_op_over))
  * [`cv_fillstyle`](./Style.md#user-content-cv_fillstyle) ([`cv_fill_winding`](./Style.md#user-content-cv_fill_winding)  [`cv_fill_even_odd`](./Style.md#user-content-cv_fill_even_odd))
  * [`cv_fontface`](./Style.md#user-content-cv_fontface)  [`cv_fontsize`](./Style.md#user-content-cv_fontsize)
  * [`CV_CombiContextStyle`](./Style.md#user-content-cv_combicontextstyle)   [`→`](./Style.md#user-content--u2192)
  * [`cv_create_context`](./Style.md#user-content-cv_create_context)

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

## `cv_antialias`

`cv_antialias(antialias) = CV_ContextAntialiasStyle(antialias)`

set [Cairo's type of antialiasing](https://www.cairographics.org/manual/cairo-cairo-t.html#cairo-antialias-t).

## `cv_antialias_best`

```
CV_ContextAntialiasStyle{T} <: CV_CanvasContextStyle
    antialias      T <: Integer
```

## `cv_antialias_none`

```
CV_ContextAntialiasStyle{T} <: CV_CanvasContextStyle
    antialias      T <: Integer
```

## `cv_operatormode`

`cv_operatormode(mode) = CV_ContextOperatorStyle(mode)`

set [Cairo's compositing operator](https://www.cairographics.org/manual/cairo-cairo-t.html#cairo-operator-t).

## `cv_opmode`

`cv_opmode(mode) = CV_ContextOperatorStyle(mode)`

set [Cairo's compositing operator](https://www.cairographics.org/manual/cairo-cairo-t.html#cairo-operator-t).

## `cv_op_source`

```
CV_ContextOperatorStyle{T} <: CV_CanvasContextStyle
    opmode         T <:Integer
```

## `cv_op_over`

```
CV_ContextOperatorStyle{T} <: CV_CanvasContextStyle
    opmode         T <:Integer
```

## `cv_fillstyle`

`cv_fillstyle(style) = CV_ContextFillStyle(style)`

set [Cairo's fill rule](https://www.cairographics.org/manual/cairo-cairo-t.html#cairo-fill-rule-t).

## `cv_fill_winding`

```
CV_ContextFillStyle <: CV_CanvasContextStyle
    fillstyle        T <:Integer
```

## `cv_fill_even_odd`

```
CV_ContextFillStyle <: CV_CanvasContextStyle
    fillstyle        T <:Integer
```

## `cv_fontface`

`cv_fontface(name, slant, weight)`

select font depending on name, slant and weight.

`cv_fontface(name, [weight=Cairo.FONT_WEIGHT_NORMAL])`

select font depending on name and weight with normal slant.

## `cv_fontsize`

`cv_fontsize(size) = CV_ContextFontSize(size)`

set font size/scale.

## `CV_MathCoorStyle`

```
CV_MathCoorStyle <: CV_CanvasContextStyle
    canvas        CV_Math2DCanvas
```

Style used to change Cairo's user coordinates sucht that they represent the mathematical coordinates.


