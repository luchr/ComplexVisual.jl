# ComplexVisual

A julia package for visualizing holomorphic and meromorphic functions.

This is work in progress for the months May &ndash; July 2021. Aim: more examples, more documentation, etc.

## Why this package?

I want 

* to try out some programming concepts (e.g. composition) with julia
* to have a tool for (interactively) showing/explaining meromorphic functions
* to have fun programming in julia

## How to install this package?

There is a very thin "layer" to show the functions in a GtkDrawingArea in a native window (using Gtk) in an extra package `ComplexVisualGtk`.

This package can also be used "standalone" (without windows and interactivity) to save the visualizations as images.

```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/luchr/ComplexPortraits.jl", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/luchr/ComplexVisual.jl", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/luchr/ComplexGtk.jl", rev="master"))
```

## First exmaples

### `z ↦ z²`

[Source-code](./examples/zsquare_lr.jl)

[![zsquare_lr.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/zsquare_lr.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/zsquare_lr.mp4?raw=true "Movie")

### `z ↦ Log(z)`

[Source-code](./examples/Log02.jl)

[![Log02.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/Log02.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/Log02.mp4?raw=true "Movie")


