macro import_basic_huge()
    :(
        using ComplexVisual:
            CV_Error, cv_error,
            CV_TranslateByOffset, CV_MultiplyByFactor,
            CV_CyclicValue, cv_set_value!,
            cv_create_angle_cross_test, cv_half,
            CV_AttachType, cv_north, cv_south, cv_east, cv_west
     )
end

# {{{ Error Handling
struct CV_Error <: Exception
    msg :: String;
end
cv_error(messages::String...) = throw(CV_Error(join(messages)))
# }}}

# {{{ helper functions for showing concrete datatypes with their fields

"""
return fieldnames of a Datatype. Put the `parent_...` fields at the end.
"""
function cv_sorted_fieldnames(t::DataType)
    fnames = fieldnames(t)
    return tuple(
        filter(x -> !contains(string(x), "parent_"), fnames)...,
        filter(x ->  contains(string(x), "parent_"), fnames)...)
end

function cv_show_value_replacements(value)
    if value isa Cairo.CairoSurfaceImage  || value isa Cairo.CairoContext
        value = value.ptr
    end
    if value isa CV_LineSegments
        value = string(length(value)) * " CV_LineSegments"
    end
    return value
end

"""
implementation for `show(io, obj)` for ComplexVisual-objects with
`typeof(obj) isa DataType`
"""
function cv_show_impl(io::IO, obj)
    t = typeof(obj)::DataType
    print(io, string(t.name.name), '(')
    first = true
    fnames = cv_sorted_fieldnames(t)
    for name_sym in fnames
        value = getfield(obj, name_sym)
        vtype = typeof(value)
        value = cv_show_value_replacements(value)
        if !first
            print(io, ", ")
        end
        print(io, string(name_sym), ": ")
        if contains(string(vtype.name.name), '#')
            show(io, MIME("text/plain"), value)
        else
            show(io, value)
        end
        first = false
    end
    print(io, ')')
    return nothing
end

"""
implementation for `show(io, mime, obj)` for ComplexVisual-objects with
`typeof(obj) isa DataType` and where `mime` is "text/plain".
"""
function cv_show_impl(io::IO, m::MIME{Symbol("text/plain")}, obj)
    t = typeof(obj)
    outer_indent = (get(io, :cv_indent, "")::AbstractString)
    indent = outer_indent * "  "
    iio = IOContext(io, :cv_indent => indent)
    println(io, string(t.name.name), '(')
    fnames = cv_sorted_fieldnames(t)
    for name_sym in fnames
        print(io, indent, string(name_sym), ": ")
        show(iio, m, cv_show_value_replacements(getfield(obj, name_sym)))
        println(io)
    end
    print(io, outer_indent, ')')
    return nothing
end
# }}} 

# {{{ Dynamic helpers
"""
A mutable struct with one (mutable) `value` (i.e. degree of freedom).
The struct is callable. When called, the input is translated by the
given `value`.
"""
mutable struct CV_TranslateByOffset{N<:Number} # {{{
    value    :: N

    function CV_TranslateByOffset(::Type{T}) where {T<:Number}
        return new{T}(zero(T))
    end
end
function (tbp::CV_TranslateByOffset{N})(z::N) where {N}
    return z + tbp.value
end # }}}

"""
A mutable struct with one `factor` as degree of freedom.
The struct is callable. When called, the input is multiplied by
the given `factor.

If the factor is a complex number then this can be used to code
a scaling and rotation operator.
"""
mutable struct CV_MultiplyByFactor{N<:Number} # {{{
    factor   :: N
    function CV_MultiplyByFactor(::Type{T}) where {T<:Number}
        return new{T}(one(T))
    end
end
function (mbf::CV_MultiplyByFactor{N})(z::N) where {N}
    return mbf.factor * z
end
# }}}

"""
A mutable struct with an integer `value` in the interval [1, maxvalue].
The struct is callable. When called, the value is increased by 1 or 
set to 1 if maxvalue was reached.
"""
mutable struct CV_CyclicValue{maxV} # {{{
    value :: Int

    function CV_CyclicValue(maxV::Int)
        maxV < 1 && cv_error("CV_CyclicValue: maxV must be >= 1")
        return new{maxV}(1)
    end
end
function (cv::CV_CyclicValue{maxV})() where {maxV}
    cv.value = (cv.value == maxV) ? 1 : cv.value + 1
    return nothing
end

function cv_set_value!(cv::CV_CyclicValue{maxV}, new_value::Int) where {maxV}
    if !(1 ≤ new_value ≤ maxV)
        cv_error("cv_set_value: new_value must be in [1, ", string(maxV),
            "]; but found: ", string(new_value))
    end
    cv.value = new_value
    return nothing
end


# }}}

# }}}

# {{{ Helper functions
"""
creates a test, which checks if a line segment [z,w] intersects
the line segemnt [rmin*exp(iϕ), rmax*exp(iϕ)].
"""
function cv_create_angle_cross_test(ϕ::Real, rmin::Real, rmax::Real; δ=100eps())
    emϕ, rmin, rmax = exp(-Float64(ϕ)*1im), Float64(rmin), Float64(rmax)

    return (z, w) -> begin
        hz = z*emϕ
        rhz, ihz = real(hz), imag(hz)
        z == w &&  return (rmin ≤ rhz ≤ rmax) && (abs(ihz) ≤ δ)

        hw = w*emϕ
        rhw, ihw = real(hw), imag(hw)
        if (abs(ihz) ≤ δ) && (abs(ihw) ≤ δ)
            # both are very close to the cross-boundary
            return (rmin ≤ rhz ≤ rmax) || (rmin ≤ rhw ≤ rmax)
        else
            sign(ihz)*sign(ihw) != -1 && return false
            r = (rhz - rhw + rhw*ihz - rhz*ihw)/(ihz - ihw)
            return rmin ≤ r ≤ rmax
        end
    end
end

cv_half(x::N) where {N<:Integer}        =  x ÷ N(2)
cv_half(x::N) where {N<:AbstractFloat}  =  x/2

# }}}

# {{{ Directions/Locations 
const cv_north, CV_northT = Val(:north), Val{:north}
const cv_south, CV_southT = Val(:south), Val{:south}
const cv_east, CV_eastT = Val(:east), Val{:east}
const cv_west, CV_westT = Val(:west), Val{:west}
const CV_AttachType = Union{CV_northT, CV_southT, CV_eastT, CV_westT}
# }}}

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
