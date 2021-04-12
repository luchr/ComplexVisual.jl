# missing methods (in Cairo)
function define_missing_cairo_methods()
    if !isdefined(ComplexVisual, :get_line_width)
        @eval ComplexVisual begin
            get_line_width(ctx::CairoContext) = ccall(
                (:cairo_get_line_width, Cairo.libcairo),
                Float64, (Ptr{Nothing},), ctx.ptr)
        end
    end
end
define_missing_cairo_methods()

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
