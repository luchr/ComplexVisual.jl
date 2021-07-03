macro import_contextstyle_huge()
    :(
        using ComplexVisual:
            CV_ContextStyle, cv_create_context, CV_CanvasContextStyle,
            CV_CombiContextStyle, cv_prepare, →,
            CV_ContextColorStyle, cv_color, cv_black, cv_white,
            CV_ContextLineWidthStyle, cv_linewidth,
            CV_ContextAntialiasStyle, cv_antialias,
            cv_antialias_best, cv_antialias_none,
            CV_ContextOperatorStyle, cv_operatormode, cv_opmode,
            cv_op_source, cv_op_over,
            CV_ContextFillStyle, cv_fillstyle, 
            CV_ContextFontFaceStyle, cv_fontface,
            CV_ContextFontSize, cv_fontsize,
            CV_MathCoorStyle
    )
end

import Base:show

"""
`CV_ContextStyle`: such a style has inpact on the following painting
operators.
"""
abstract type CV_ContextStyle end

"""
`CV_CanvasContextStyle`: a `CV_ContextStyle` for canvases.
"""
abstract type CV_CanvasContextStyle <: CV_ContextStyle end

show(io::IO, s::CV_ContextStyle) = cv_show_impl(io, s)


"""
```
cv_create_context(do_func, canvas, [style=nothing]; prepare=true)
    do_func       Function
    canvas        CV_Canvas
    style         Union{Nothing, CV_ContextStyle}
    prepare       Bool
```

call `cv_create_context` for `canvas`, execute `do_func` and destroy
the context afterwards.
"""
function cv_create_context(do_func::Function, canvas::CV_Canvas,
                           style::Union{Nothing, CV_ContextStyle}=nothing;
                           prepare::Bool=true)
    con = cv_create_context(canvas; prepare=prepare)
    if style isa CV_ContextStyle
        cv_prepare(con, style)
    end
    try
        do_func(con)
    finally
        cv_destroy(con)
    end
    return nothing
end


"""
```
CV_CombiContextStyle{T, S} <: CV_ContextStyle
    style1     T <: CV_ContextStyle
    style2     S <: CV_ContextStyle
```

combines to styles to a new style.
"""
struct CV_CombiContextStyle{T<:CV_ContextStyle,
                            S<:CV_ContextStyle} <: CV_ContextStyle # {{{
    style1 :: T
    style2 :: S
end

show(io::IO, m::MIME{Symbol("text/plain")}, s::CV_CombiContextStyle) =
    cv_show_impl(io, m, s)

function cv_prepare(con::CV_Context, cstyle::CV_CombiContextStyle{T,S}) where {T,S}
    cv_prepare(con, cstyle.style1)
    cv_prepare(con, cstyle.style2)
    return nothing
end


"""
`→(style1, style2) = CV_CombiContextStyle(style1, style2)`
"""
function →(style1::T, style2::S) where {T<:CV_ContextStyle, S<:CV_ContextStyle}
  return CV_CombiContextStyle(style1, style2)
end

# }}}

"""
```
CV_ContextColorStyle <: CV_CanvasContextStyle 
    red       Float64
    green     Float64
    blue      Float64
    alpha     Float64
```

sets stroke and fill to constant red, green, blue color (with alpha-value).
"""
struct CV_ContextColorStyle <: CV_CanvasContextStyle  # {{{
    red   :: Float64
    green :: Float64
    blue  :: Float64
    alpha :: Float64
end

"""
```
cv_color(red, green, blue[, alpha=1.0])
    red     Real
    green   Real
    blue    Real
    alpha   Real
```
"""
cv_color(red::Real, green::Real, blue::Real, alpha::Real=1.0) =
    CV_ContextColorStyle(
        convert(Float64, red),
        convert(Float64, green),
        convert(Float64, blue),
        convert(Float64, alpha))

function cv_prepare(cc::CV_CanvasContext, style::CV_ContextColorStyle)
    set_source_rgba(cc.ctx, style.red, style.green, style.blue, style.alpha)
    return nothing
end 

"""
`cv_black`: black color
"""
const cv_black = cv_color(0, 0, 0)

"""
`cv_white`: white color
"""
const cv_white = cv_color(1, 1, 1)

# }}}

"""
```
CV_ContextLineWidthStyle <: CV_CanvasContextStyle
    width     Float64
```
"""
struct CV_ContextLineWidthStyle <: CV_CanvasContextStyle # {{{
    width :: Float64
end

"""
`cv_linewidth(width) = CV_ContextLineWidthStyle(Float64(width))`

set line width.
"""
cv_linewidth(width::Real) = CV_ContextLineWidthStyle(Float64(width))

function cv_prepare(cc::CV_CanvasContext, style::CV_ContextLineWidthStyle)
    set_line_width(cc.ctx, style.width)
    return nothing
end
# }}}

struct CV_ContextAntialiasStyle{T<:Integer} <: CV_CanvasContextStyle # {{{
    antialias :: T
end
cv_antialias(antialias) = CV_ContextAntialiasStyle(antialias)
function cv_prepare(cc::CV_CanvasContext, style::CV_ContextAntialiasStyle)
    set_antialias(cc.ctx, style.antialias)
    return nothing
end

const cv_antialias_best = cv_antialias(Cairo.ANTIALIAS_BEST)
const cv_antialias_none = cv_antialias(Cairo.ANTIALIAS_NONE)
# }}}

struct CV_ContextOperatorStyle{T<:Integer} <: CV_CanvasContextStyle # {{{
    opmode :: T
end
cv_operatormode(mode::Integer) = CV_ContextOperatorStyle(mode)
cv_opmode(mode::Integer) = CV_ContextOperatorStyle(mode)

const cv_op_source = CV_ContextOperatorStyle(Cairo.OPERATOR_SOURCE)
const cv_op_over = CV_ContextOperatorStyle(Cairo.OPERATOR_OVER)

function cv_prepare(cc::CV_CanvasContext, style::CV_ContextOperatorStyle)
    set_operator(cc.ctx, style.opmode)
    return nothing
end
# }}}

struct CV_ContextFillStyle{T<:Integer} <: CV_CanvasContextStyle   # {{{
    fillstyle :: T
end
cv_fillstyle(style) = CV_ContextFillStyle(style)
function cv_prepare(cc::CV_CanvasContext, style::CV_ContextFillStyle)
    set_fill_type(cc.ctx, style.fillstyle)
  return nothing
end 
# }}}

struct CV_ContextFontFaceStyle{sT<:Integer,
                               wT<:Integer} <: CV_CanvasContextStyle # {{{
    name   :: AbstractString
    slant  :: sT
    weight :: wT
end
cv_fontface(name::AbstractString, slant::sT,
            weight::wT) where {sT<:Integer, wT<:Integer} =
    CV_ContextFontFaceStyle(name, slant, weight)
cv_fontface(name::AbstractString, weight::wT) where {wT<:Integer} =
    cv_fontface(name, Cairo.FONT_SLANT_NORMAL, weight)
cv_fontface(name::AbstractString) = cv_fontface(name, Cairo.FONT_WEIGHT_NORMAL)
function cv_prepare(cc::CV_CanvasContext, style::CV_ContextFontFaceStyle)
    select_font_face(cc.ctx, style.name, style.slant, style.weight)
    return nothing
end
# }}}

struct CV_ContextFontSize{T<:Real} <: CV_CanvasContextStyle # {{{
    size    :: T
end
cv_fontsize(size::T) where {T<:Real} = CV_ContextFontSize(size)
function cv_prepare(cc::CV_CanvasContext, style::CV_ContextFontSize)
    set_font_size(cc.ctx, style.size)
    return nothing
end
# }}}

struct CV_MathCoorStyle <: CV_CanvasContextStyle  # {{{
    canvas :: CV_Math2DCanvas
end
function cv_prepare(cc::CV_CanvasContext, style::CV_MathCoorStyle)
    canvas = style.canvas
    ctx = cc.ctx
    scale(ctx, canvas.resolution, -canvas.resolution)
    translate(ctx, -real(canvas.corner_ul), -imag(canvas.corner_ul))
    return nothing
end
# }}}

# }}}

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
