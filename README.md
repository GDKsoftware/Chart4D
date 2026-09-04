<img src="assets/chart4d-mark-64.png" width="48" alt="Chart4D">

# Chart4D

Publication-ready editorial charts for Delphi, VCL and FireMonkey.

Chart4D draws charts the way a newsroom publishes them: a strong left-aligned title, a light
horizontal grid, no chart junk, direct labelling, and a footer with the source. One consistent
style out of the box, every part of it overridable.

Zero dependencies, RTL only in the core, in the style of the GDK -4D library family.

<!-- badges -->
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Latest version](https://img.shields.io/github/v/tag/GDKsoftware/Chart4D?label=version&color=blue)](https://github.com/GDKsoftware/Chart4D/tags)
[![Delphi 12+](https://img.shields.io/badge/Delphi-12%2B-e62329.svg)](https://www.embarcadero.com/products/delphi)
[![Tests passing](https://img.shields.io/badge/tests-passing-1f6feb.svg)](Tests)
![VCL and FMX](https://img.shields.io/badge/frameworks-VCL%20%7C%20FMX-1f6feb.svg)
![Zero dependencies](https://img.shields.io/badge/dependencies-none-1f6feb.svg)

<p align="center">
  <img src="docs/images/multi-line.png" alt="Life expectancy in three countries, as a multi-line chart" width="49%">
  <img src="docs/images/dot-plot.png" alt="Life expectancy in ten countries, as a dot plot" width="49%">
</p>

## Why Chart4D

Most charting components give you every option and leave the design to you. The result is
usually a chart that looks like a spreadsheet: a boxed plot area, a heavy grid in both
directions, a legend in a corner, values you have to look up on an axis.

Chart4D starts from the other end. The default output is the chart a newspaper graphics desk
would publish: title and subtitle top left, a light horizontal grid only, series labelled at the
line end instead of in a legend, and a footer with the source. You supply the data and the
words; the layout, the label placement and the colours are already decided, and every one of
those decisions can be overridden when you disagree.

The core is plain Object Pascal on the RTL and does not know about VCL or FMX. The two controls
are thin adapters over one shared renderer, so a chart renders pixel-for-pixel the same on both
frameworks and exports to PNG the same way. Delphi 12 Athens and Delphi 13, MIT licensed.

## Quick start

```pascal
uses
  Chart4D.Types,
  Chart4D.Style,
  Chart4D.VCL;

var Chart := TChart4D.Create(Self);
Chart.Parent := Self;
Chart.Align := alClient;

Chart.Plot.Kind := TChartKind.Bar;
Chart.Plot.Orientation := TChartOrientation.Horizontal;
Chart.Plot.Title := 'Almost everyone is online';
Chart.Plot.Subtitle := 'Share of the population using the internet, 2020';
Chart.Plot.Source := 'Source: World Bank';
Chart.Plot.Categories := ['Sweden', 'Spain', 'Belgium', 'Netherlands'];
Chart.Plot.AddSeries('2020', [94.5, 93.2, 91.5, 91.3]);

Chart.SaveToPng('online.png');
```

The FireMonkey control has the same API. Use `Chart4D.FMX` instead of `Chart4D.VCL` and
nothing else changes, because both are thin adapters over one shared renderer.

## Chart kinds

| Kind | What it is for |
|---|---|
| `Line` | A measure over time, one or more series |
| `Area` | A quantity accumulating, rather than a level being measured |
| `Bar` | Ranking and comparison, for values with a meaningful zero |
| `GroupedBar` | Two or three measures per category, side by side |
| `StackedBar` | Parts of a whole, absolute or normalised to 100% |
| `Histogram` | The shape of a distribution, binned for you |
| `DotPlot` | Comparison where zero is not informative, so bars would mislead |
| `Dumbbell` | Change between two moments, one row per category |
| `Range` | The span between a low and a high value |
| `Arrow` | The same change, with its direction as the subject |
| `Scatter` | Two continuous measures against each other, with optional bubble sizing |
| `Pie` | Parts of one whole, for a handful of segments |
| `Donut` | A pie with room for a total in the middle |

<table>
<tr>
<td><img src="docs/images/bar-horizontal.png" alt="Horizontal bar chart"></td>
<td><img src="docs/images/dot-plot.png" alt="Dot plot"></td>
</tr>
<tr>
<td><img src="docs/images/stacked-bar-proportions.png" alt="Stacked bar chart"></td>
<td><img src="docs/images/dumbbell.png" alt="Dumbbell chart"></td>
</tr>
<tr>
<td><img src="docs/images/scatter-bubble.png" alt="Scatter plot with bubble sizing"></td>
<td><img src="docs/images/donut.png" alt="Donut chart"></td>
</tr>
<tr>
<td><img src="docs/images/histogram.png" alt="Histogram"></td>
<td><img src="docs/images/uncertainty-band.png" alt="Line chart with an uncertainty band"></td>
</tr>
</table>

## Labelling and emphasis

Direct labelling is what makes this style readable, so it is built in rather than left to you.

```pascal
Plot.ValueLabels := TValueLabelMode.Extremes;  // None, All, FirstAndLast, Extremes
```

![Value labels](docs/images/value-labels-extremes.png)

Labels are placed automatically, moved inside the plot when they would cover an axis label,
and skipped when they would collide with a label already drawn. The result is deterministic,
so a chart looks the same on every run.

To argue one point while still showing context, mute everything except one series:

```pascal
Plot.HighlightedSeriesIndex := 4;
```

![Series highlighting](docs/images/series-highlighting.png)

A series with an explicitly set colour keeps it, so a deliberate choice always survives.

## Axes

```pascal
var YAxis := Plot.YAxis;
YAxis.MinValue := 0;                             // NaN for automatic
YAxis.Breaks := [0, 50, 100];                    // empty for automatic
YAxis.BreakLabels := ['none', 'half', 'all'];    // one label per break; empty to format the breaks
YAxis.UseThousandSeparator := True;              // 40,000 instead of 40000
YAxis.LabelSuffix := '%';
YAxis.SuffixOnLastOnly := True;                  // the unit on the last label only
YAxis.LocaleName := 'nl-NL';                     // 40.000 for a Dutch audience
YAxis.Scale := TAxisScaleKind.Logarithmic;
Plot.YAxis := YAxis;

var XAxis := Plot.XAxis;
XAxis.DateMode := TAxisDateMode.Auto;            // days, months, quarters or years
Plot.XAxis := XAxis;
```

Numbers use the invariant convention unless `LocaleName` says otherwise, so output stays
reproducible in tests until you decide it should follow a reader instead.

For a horizontal chart the value axis is still `YAxis`. The orientation swaps where the axes
are drawn, not what they mean.

## Annotations and context

```pascal
Plot.AddTextAnnotation(5, 72.5, '+17.3 years', ChartDarkRed, TTextAlignH.Center);
Plot.AddHorizontalLine(80, ChartLightGrey, True);
Plot.AddHorizontalRangeOverlay(78, 80, TAlphaColor($30990000));
Plot.AddArrow(1990, 60, 1995, 45);
```

A range band takes its bounds from data instead of the axis, for confidence intervals,
forecast ranges or a real spread:

```pascal
const Band = Plot.AddRangeBandSeries('Male to female', Years, Men, Women);
Band.Color := TAlphaColor($3013A0C1);
```

## Interaction

Both controls hit-test the chart on mouse move, highlight the nearest data point and draw a
tooltip. It is on by default.

```pascal
Chart.ShowTooltips := True;
Chart.OnDataPointHover := HandleHover;

procedure TFormMain.HandleHover(Sender: TObject; const Info: TChartHitInfo);
begin
  if Info.HasHit then
    Caption := Format('%s: %s', [Info.CategoryLabel,
                                 TAxisScale.FormatValue(Info.Value, False)]);
end;
```

`SaveToPng` never draws a tooltip, so an export is always clean.

## Export

```pascal
Chart.SaveToPng('chart.png');            // 640x450 by default
Chart.SaveToPng('large.png', 1280, 900);
```

The publication footer is part of the export: the source text on the left, an optional logo on
the right, separated from the chart by a full-width rule.

```pascal
Plot.Source := 'Source: World Bank';
Plot.LogoFilePath := 'logo.png';
```

The logo is scaled to fit the footer height and aligned right. Both demos set it to
`assets\chart4d-mark-64.png`, so you can see what it looks like without wiring anything up.

## Style

`TChartStyle.Default` holds the editorial style: Helvetica, or Arial on Windows, a 28 pixel
bold title, a 22 pixel subtitle, 18 pixel legend and axis text in `#222222`, gridlines on the
value axis only in `#cbcbcb`, and no axis titles, ticks or axis lines. Sizes are pixels at the
640x450 reference size and scale with `ScaleFactor`.

```pascal
var Style := Plot.Style;
Style.TitleFontSize := 32;
Style.ShowGridlines := False;
Style.ScaleFactor := 2.0;
Plot.Style := Style;
```

The palette:

```pascal
ChartBlue         = $FF1380A1;
ChartOrange       = $FFFAAB18;
ChartDarkRed      = $FF990000;
ChartGreen        = $FF588300;
ChartBaselineGrey = $FF333333;
ChartLightGrey    = $FFDDDDDD;
```

## Installation

Open the runtime packages under `packages\RAD Studio 13.0\` or `packages\RAD Studio 12.0\`,
whichever matches your IDE, and build `Chart4D_R` for the core, then `Chart4D_VCL_R` or
`Chart4D_FMX_R` for the framework you use.

Or add `Source\` plus `Source\VCL\` or `Source\FMX\` to your project search path. Controls are
created at runtime; there is no design-time registration yet.

## Demos

`Examples\VCL` and `Examples\FMX` both run every example in the catalogue, with the
explanation and the code that produces it beside the chart. They share
`Examples\Common\Chart4DDemo.Catalog.pas`, so the fragment on screen and the chart next to it
always come from the same source.

Build them with `Build.bat` in the repository root, which also builds the packages and runs
the tests. The script picks the newest installed Delphi; set `CHART4D_STUDIO` to `23.0` or
`37.0` to force Delphi 12 or Delphi 13.

All demo data is published World Bank World Development Indicators data, except the
electricity mix, which is Ember data via Our World in Data.

## Verification

`Build.bat` builds the three packages, runs the DUnitX suite and builds both demos. Everything
compiles with zero warnings and zero hints.

Four console tools under `Tools\` go further:

| Tool | What it checks |
|---|---|
| `CoreCheck` | Every core unit compiles and every scenario renders |
| `VclCheck` | The GDI+ adapter renders, exports and reports hover |
| `FmxCheck` | The same for FMX, plus every chart kind drawing real pixels |
| `Gallery` | Renders the whole catalogue to PNG for visual inspection |

`FmxCheck` and `VclCheck` drive the control's own mouse handling, so the chain from a mouse
move through the hit test to the repaint is covered, not just the geometry behind it.

## Status

Version 1.0.0. See `SPEC.md` for the design contract and [CONTRIBUTING.md](CONTRIBUTING.md)
for how to build, test and submit a change.

## License

Chart4D is released under the [MIT License](LICENSE).

Copyright (c) 2026 GDK Software

## Commercial Support

Chart4D is MIT licensed, so it is free to use. For companies we offer a support and
maintenance contract, including sponsored development of the features you need. Get in touch
at [gdksoftware.com/contact-us](https://gdksoftware.com/contact-us), or open an issue.

## About GDK Software

Chart4D is developed by [GDK Software](https://gdksoftware.com), a software company building
Delphi developer tools, MCP integrations, and enterprise Delphi applications.
