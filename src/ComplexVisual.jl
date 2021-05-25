"""
# ComplexVisual

A module to visualize holomorphic/meromorphic functions.

This is done by showing how sets are changed/deformed by functions
(holomorphic/meromorphic functions interpreted as transformations)
and complex phase portraits.

Often the sets (that are transformed) depend on one degree of freedom (which
may be changed by the mouse in the `ComplexVisualGtk` frontend).
"""
module ComplexVisual


using ComplexPortraits
using Colors
using Cairo
using Printf

include("monkeypatch.jl")

include("basic.jl")
include("rectangle.jl")
include("canvas.jl")
include("context.jl")
include("contextstyle.jl")
include("painter.jl")
include("eximage.jl")
include("layout.jl")
include("text.jl")
include("axis.jl")
include("decoration.jl")
include("scene.jl")
include("lrdomains.jl")
include("slider.jl")
include("winding.jl")
include("compcodomains.jl")


"""macro for importing the *huge* set of symbols."""
macro import_huge()
    quote
        @ComplexVisual.import_basic_huge
        @ComplexVisual.import_rectangle_huge
        @ComplexVisual.import_canvas_huge
        @ComplexVisual.import_context_huge
        @ComplexVisual.import_contextstyle_huge
        @ComplexVisual.import_painter_huge
        @ComplexVisual.import_eximage_huge
        @ComplexVisual.import_layout_huge
        @ComplexVisual.import_text_huge
        @ComplexVisual.import_axis_huge
        @ComplexVisual.import_decoration_huge
        @ComplexVisual.import_scene_huge
        @ComplexVisual.import_lrdomains_huge
        @ComplexVisual.import_slider_huge
        @ComplexVisual.import_winding_huge
        @ComplexVisual.import_compcodomains_huge
    end
end

end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
