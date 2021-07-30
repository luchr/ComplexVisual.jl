# ComplexVisual

A julia package for visualizing holomorphic and meromorphic functions.

I used it for explanations in a complex analysis course in summer 2021.

## Why this package?

I wanted

* to try out some programming concepts (e.g. [composition](./docs/composition.md))
  with julia
* to have a tool for interactively showing/explaining meromorphic functions
  (see [examples](./examples#user-content-examples))
* to have fun programming in julia

## How to install this package?

There is a very thin "layer" to show the functions in a `GtkDrawingArea` in a native window (using Gtk) in an extra package [ComplexVisualGtk.jl](https://github.com/luchr/ComplexVisualGtk.jl).

This package can also be used "standalone" (without windows and interactivity) to save the visualizations as images.

```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/luchr/ComplexPortraits.jl", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/luchr/ComplexVisual.jl", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/luchr/ComplexVisualGtk.jl", rev="master"))
```

## Documentation

The layout concept, styles and painters and more are documented in the
[docs directory](./docs#user-content-overview) together with a index
of the functions/methods.

As so often, I hadn't time for more documentation. This is a open todo.

One remark: The documentation was prepared with my utility
[DocGenerator.jl](./docs/DocGenerator.jl) that I wrote, because I
wanted to have automatically generated cross references (without
an additional syntax), an easy syntax for the inclusion of doc-strings,
an easy syntax for the inclusion of parts of the source-code
and the simple generation of an index.  That escaleted quickly!


