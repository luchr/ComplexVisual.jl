using Cairo
using ComplexVisual
@ComplexVisual.import_huge
using ComplexVisualGtk
@ComplexVisualGtk.import_huge

using Printf

"""
Approximate |z*exp(1-z)|==1 with z = r(ϕ)*exp(iϕ) for 101 values in [0,π]
```
Piecewise[{{1/E, 2*ϕ == Pi || 2*ϕ == 3*Pi}}, 
  (-ProductLog[(Abs[Cos[ϕ]]*
        Piecewise[{{1, Pi/2 <= ϕ <= (3*Pi)/2}}, -1])/E])* Sec[ϕ]]
```
"""
const curve_r_of_phi = (
    1.00000000000000000, 0.96938799932339478, 0.94031280913960984,
    0.91267447197920273, 0.88638114186065965, 0.86134829907186178,
    0.83749805315932746, 0.81475852287976240, 0.79306328346805633,
    0.77235087292502438, 0.75256435016959500, 0.73365089886863247,
    0.71556147158168498, 0.69825046956111954, 0.68167545414968103,
    0.66579688623349311, 0.65057789065218041, 0.63598404285018716,
    0.62198317538372242, 0.60854520218380338, 0.59564195872407880,
    0.58324705645795586, 0.57133575007763025, 0.55988481631183171,
    0.54887244312274892, 0.53827812828850114, 0.52808258646807237,
    0.51826766394286338, 0.50881626031469696, 0.49971225651573406,
    0.49094044855261233, 0.48248648646631564, 0.47433681804178095,
    0.46647863684787701, 0.45889983422986405, 0.45158895491338878,
    0.44453515591202428, 0.43772816845980179, 0.43115826271651143,
    0.42481621501712971, 0.41869327745787858, 0.41278114963040691,
    0.40707195233265375, 0.40155820310031468, 0.39623279341667475,
    0.39108896747105881, 0.38612030234742765, 0.38132068953484406,
    0.37668431766076138, 0.37220565635644773, 0.36787944117144232,
    0.36370065946082444, 0.35966453717533229, 0.35576652649006006,
    0.35200229421264355, 0.34836771091656781, 0.34485884074953856,
    0.34147193187079335, 0.33820340747482355, 0.33504985736226709,
    0.33200803002174285, 0.32907482518915661, 0.32624728685353880,
    0.32352259668079724, 0.32089806782890166, 0.31837113912997935,
    0.31593936961660664, 0.31360043337124438, 0.31135211467929895,
    0.30919230346770490, 0.30711899101223196, 0.30513026589792689,
    0.30322431021821778, 0.30139939599924305, 0.29965388183692661,
    0.29798620973521020, 0.29639490213468041, 0.29487855912159646,
    0.29343585580803966, 0.29206553987457226, 0.29076642926741500,
    0.28953741004273363, 0.28837743435116807, 0.28728551855624701,
    0.28626074148080829, 0.28530224277599438, 0.28440922140781493,
    0.28358093425666686, 0.28281669482557941, 0.28211587205330827,
    0.28147788922874187, 0.28090222300340517, 0.28038840249915426,
    0.27993600850844928, 0.27954467278487599, 0.27921407742185853,
    0.27894395431776862, 0.27873408472589181, 0.27858429888795920,
    0.27849447575019571, 0.27846454276107380)

function get_curve()
    ϕ1 = LinRange(0, π, 101)
    ϕ2 = -ϕ1[end-1:-1:2]
    r1, r2 = curve_r_of_phi, curve_r_of_phi[end-1:-1:2]
    line_seg = [collect(r1).*exp.(1im*collect(ϕ1))...,
                collect(r2).*exp.(1im*collect(ϕ2))...]
    return CV_2DCanvasLinePainter([line_seg], true)
end

const fontface = cv_fontface("sans-serif")

function show_comparison(n, save=false)
    param_n = CV_TranslateByOffset(Int)
    param_n.value = n

    function trafo2(z)
        n = param_n.value
        z = z * n
        result = big(1.0)
        for k in 1:n
          result += big(z)^k/factorial(big(k))
        end
        return ComplexF64(result)
    end

    trafo1 = z -> exp(z*param_n.value)

    codomain1 = CV_Math2DCanvas(-0.5 + 1.0im, 1.5 - 1.0im, 200)
    codomain2 = CV_Math2DCanvas(-0.5 + 1.0im, 1.5 - 1.0im, 200)

    label_style = cv_black → fontface → cv_fontsize(20)
    nstyle = cv_black → fontface → cv_fontsize(40)
    nrulers=(
        CV_TickLabelAppearance(; label_style) ↦ ("%.0f" ⇒ 0.0:1.0),
        CV_TickLabelAppearance(; label_style=nstyle, tick_length=0) ↦
            (("n = " * string(n)) ⇒ 1.2,))
    rulers=(
        CV_TickLabelAppearance(; label_style) ↦ ("%.0f" ⇒ 0.0:1.0),)

    curve = (cv_black → cv_linewidth(3)) ↦ get_curve()

    scene = cv_scene_comp_codomains_std(tuple(), trafo1, trafo2,
        codomain1, codomain2; codomain1_re_rulers=rulers,
        codomain1_im_rulers=rulers,
        codomain2_re_rulers=rulers,
        codomain2_im_rulers=nrulers,
        painter1=CV_Math2DCanvasPortraitPainter(trafo1) → curve,
        painter2=CV_Math2DCanvasPortraitPainter(trafo2) → curve)
    cv_get_redraw_func(scene)()

    if save
        write_to_png(cv_get_can_layout(scene).surface,
            @sprintf("ExpSeriesRescaled_%03i.png", n))
    else
        handler = cvg_visualize(scene)
        cvg_wait_for_destroy(handler.window)

        cvg_close(handler);
    end
    cv_destroy(scene)
end

for n in (1, 5, 10, 30, 60, 80, 100)
    println("n = ", n)
    show_comparison(n, true)
end

# vim:syn=julia:cc=79:fdm=marker:sw=4:ts=4:
