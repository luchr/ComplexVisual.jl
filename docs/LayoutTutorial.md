# Layout (Positioning of graphic objects)

In order to visualize functions, phase portraits, etc. we have to place graphical objects for the visualization. We call this: "to layout".

To make things simple we only use "fixed" layouts, i.e. after the objects are positioned they cannot change size and/or position.

The layout process always uses rectangular regions. Because graphic objects may be (partially) transparent (or half-transparent, etc.) the underlying rectangles are not always visible.

At the end of the layout process (after every object has its position and size) one typically creates a "canvas" where all the objects are drawn/shown.

## Coordinate system

All the layout process uses the [pixel coordinate system](./PixelCoordinates.md).
## "Hello-world" example

Let's start with a hello-world example.

```julia
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
```

### creating a graphic object

As a simple graphic object we use `cv_filled_canvas` to construct a canvas with width of 100 pixels and height of 50 pixels which is totally filled with red.

### position the object (with absolute coordinates)

Then this canvas is positioned with `cv_add_canvas!`. This method needs to know where to place the object (here in the example the location is `(0,0)`) and what part/anchor of the object should be at this position. In this example the north-west corner of the rectangle (of the filled cavnas) should be at position `(0,0)`.

see `cv_anchor` 

### layout positions

The return value of `cv_add_canvas!` (and other `cv_add_...` methods) are "layout positions". In this example `first_object_location` is:

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

All these layout positions are callable (they are callable structs). What happens if they are called is explained in the next section.

### creating a layout canvas and drawing the content

With `cv_canvas_for_layout` the smallest bounding box of all positioned objects (in the example there is only the `first_object`) is used to contruct a canvas of this size of the bounding box.

With `cv_create_context` a drawing context `con_layout` is constructed and alle the layout position.

Now all layout positions can be called with such a context to draw/show their visualization inside the layout canvas.

The output of this example is very boring:

![./LayoutTutorial_helleoworld.png](./LayoutTutorial_helleoworld.png)
## More advanced example

One can use the `cv_anchor` method on layout positions to place the next objects. This is much more convenient than computing the absolute coordinates for the positions.

There is also a `cv_translate` method to modifiy (anchor-)position (tuples) by translating them.

Here this methods can be seen in action:

```julia
function more_advanced_example()
    layout = CV_2DLayout()

    red_canvas = cv_filled_canvas(200, 200, cv_color(1, 0, 0))
    red_canvas_l = cv_add_canvas!(layout, red_canvas,
        cv_anchor(red_canvas, :center), (0, 0))

    green_canvas = cv_filled_canvas(50, 50, cv_color(0, 1, 0, 0.8))
    green_canvas_l = cv_add_canvas!(layout, green_canvas,
        cv_anchor(green_canvas, :center), cv_anchor(red_canvas_l, :east))

    blue_canvas = cv_filled_canvas(cv_width(red_canvas_l), 10, cv_color(0, 0, 1))
    blue_canvas_l = cv_add_canvas!(layout, blue_canvas,
        cv_anchor(blue_canvas, :south), 
        cv_translate(cv_anchor(red_canvas_l, :north), 0, -10))

    can_layout = cv_canvas_for_layout(layout)
    cv_create_context(can_layout) do con_layout
        red_canvas_l(con_layout)
        green_canvas_l(con_layout)
        blue_canvas_l(con_layout)
    end

    return can_layout
end
```

and thats the result:

![./LayoutTutorial_advanced.png](./LayoutTutorial_advanced.png)
