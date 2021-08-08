# Tutorials

## Arctan

The first visualization tutorial goes through the basic concepts of `ComplexVisual.jl`. The goal of the visualization is to see how a 'test set' gets transformed by the analytic continuation of `Arctan`.

[![Arctan.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Arctan.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Arctan.mp4?raw=true "Movie")

Source: [Arctan.jl](./Arctan.jl)

## `z^2`

This is a barebones version of the first tutorial, which can be quickly changed to fit whatever set function you wish to visualize.

[![zsquare_lr.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/zsquare_lr.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/zsquare_lr.mp4?raw=true "Movie")

Source: [zsquare_lr.jl](./zsquare_lr.jl)

## ArctanSeries

The second tutorial goes through how to build a slider. We use this to compare the `Arctan` function to its truncated Taylor series at z=0. The size of the sum can be changed with the slider. 

[![ArctanSeries.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/ArctanSeries.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/ArctanSeries.mp4?raw=true "Movie")

Source: [ArctanSeries.jl](./ArctanSeries.jl)

## Visualizing Exp with approximation

We can now add the slider and 'test set' together to build a more complicated model. The goal is to see how `exp(z)` can be approximated through `(1 + z/n) ^ n`. To do this, we build our own custom slider that has a 'snap to infinity' option. 

[![Exp01.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Exp01.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Exp01.mp4?raw=true "Movie")

Source: [Exp01.jl](./Exp01.jl)

## Mandelbrot Set

Our goal is to generate an image of the mandelbrot set, as well as interactive images of Julia sets. To do this, we need to build custom painter functions and colorschemes. 

[![Mandelbrot.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Mandelbrot.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Mandelbrot.mp4?raw=true "Movie")

# Examples

## Winding numbers

[![Winding01.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Winding01.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Winding01.mp4?raw=true "Movie")

Source: [Winding01.jl](./Winding01.jl)

## Exp

[![Exp02.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Exp02.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Exp02.mp4?raw=true "Movie")

Source: [Exp02.jl](./Exp02.jl)

## Rescaled truncated Exp-Series

Visualizing `exp(z*n)` vs. truncated series of `exp(z*n)` with n terms.

![n=1](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/ExpSeriesRescaled_001.png)
![n=10](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/ExpSeriesRescaled_010.png)

![n=30](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/ExpSeriesRescaled_030.png)
![n=80](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/ExpSeriesRescaled_080.png)

Source: [ExpSeriesRescaled.jl](./ExpSeriesRescaled.jl)

## Visualizing Log with approximation

Visualization of `(z^(1/n) - 1)*n`.

[![Log01.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Log01.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Log01.mp4?raw=true "Movie")

Source: [Log01.jl](./Log01.jl)

## Log

[![Log02.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Log02.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Log02.mp4?raw=true "Movie")

Source: [Log02.jl](./Log02.jl)

## Log(1+z)

Truncated Taylor series at z=0 of `Log(1+z)`

[![Log1pSeries.mp4](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Log1pSeries.png)](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Log1pSeries.mp4?raw=true "Movie")

Source: [Log1pSeries.jl](./Log1pSeries.jl)

## Axis

How to style ticks and axis.

![Axis01](https://github.com/luchr/ComplexVisualMedia/blob/main/examples/Axis01.png)

Source: [Axis01.jl](./Axis01.jl)
