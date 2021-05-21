using Cairo
using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

include("./TutorialHelpers.jl")


const md_context = SubstMDcontext(@__FILE__)

"""
# Layout (Positioning of graphic objects)

In order to visualize functions, phase portraits, etc. we have to place
graphical objects for the visualization. We call this: "to layout".

To make things simple we only use "fixed" layouts, i.e. after the objects
are positioned they cannot change size and/or position.

The layout process always uses rectangular regions. Because graphic objects
may be (partially) transparent (or half-transparent, etc.) the underlying
rectangles are not always visible.

At the end of the layout process (after every object has its position
and size) one typically creates a "canvas" where all the objects are
drawn/shown.

## Coordinate system

All the layout process uses the
[pixel coordinate system](./PixelCoordinates.md).

"""
layout_intro() = nothing

"""
## "Hello-world" example

Let's start with a hello-world example.

```julia
{func: hello_world_example}
```

### creating a graphic object

As a simple graphic object we use `cv_filled_canvas` to construct a
canvas with width of 100 pixels and height of 50 pixels which is totally
filled with red.

### position the object (with absolute coordinates)

Then this canvas is positioned with `cv_add_canvas!`. This method
needs to know where to place the object (here in the example the location
is `(0,0)`) and what part/anchor of the object should be at this position.
In this example the north-west corner of the rectangle (of the filled cavnas)
should be at position `(0,0)`.

see `cv_anchor` 

### layout positions

The return value of `cv_add_canvas!` (and other `cv_add_...` methods) are
"layout positions". In this example `first_object_location` is:

```
CV_2DLayoutPosition(
  rectangle: CV_Rectangle(▬0→100, 0↑50▬)
  canvas: CV_Std2DCanvas(
    surface: Ptr{Nothing} @0x0000000003671900
    pixel_width: 100
    pixel_height: 50
    bounding_box: CV_Rectangle(▬0→100, 0↑50▬)
  )
  drawing_cb: nothing
  style: CV_ContextOperatorStyle(opmode: 2)
)
```

All these layout positions are callable (they are callable structs). What
happens if they are called is explained in the next section.

### creating a layout canvas and drawing the content

With `cv_canvas_for_layout` the last smallest bounding box of all
positioned objects (in the example there is only the `first_object`)
is used to contruct a canvas of this size of the bounding box.

With `cv_create_context` a drawing context `con_layout` is constructed
and alle the layout position.

Now all layout positions can be called with such a context to draw/show their
visualization inside the layout canvas.

The output of this example is very boring:

![./LayoutTutorial_helleoworld.png]({image_from_canvas: hello_world_example()})
"""
function hello_world_example()
    layout = CV_2DLayout()

    first_object = cv_filled_canvas(100, 50, cv_color(1, 0, 0))
    first_object_location = cv_add_canvas!(layout, first_object,
        cv_anchor(first_object, :northwest), (0, 0))

    can_layout = cv_canvas_for_layout(layout)
    cv_create_context(can_layout) do con_layout
        first_object_location(con_layout)
    end

    return can_layout
end

open("./LayoutTutorial.md", "w") do fio
    for part in (layout_intro, hello_world_example)
        md = Base.Docs.doc(part)
        substitue_marker_in_markdown(md_context, md)
        write(fio, string(md))
    end
end

nothing

# cvg_create_win_for_canvas(hello_world_example(), "hello world")


# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
