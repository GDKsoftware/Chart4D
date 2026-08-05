# Chart4D Specification

Chart4D is a zero-dependency Delphi library that produces publication-ready,
editorial-style charts for both VCL and FireMonkey: clean typography, a light horizontal
grid, direct labelling, and a publication footer with source text and an optional logo.

This document is the authoritative design contract. Implementations must match the public
APIs declared here exactly. Section 8 gives the source conventions they are written to.

## 1. Scope (v1)

Thirteen chart kinds: line (single and multiple series), area, bar, grouped bar,
stacked bar (absolute and proportional), histogram, dot plot, dumbbell, range, arrow,
scatter (with optional bubble sizing), pie and donut. One built-in visual style
(`TChartStyle.Default`) with user-overridable properties. Annotations (text labels,
segments, arrows, reference lines, shaded range overlays) and uncertainty/range band
series. Value labels with deterministic placement (4.12) and series highlighting (4.13).
Legend control. Axis label formatting, including locale-aware formatting (4.14),
logarithmic value axes (4.15) and date axes (4.16). PNG export
with publication finishing: left-aligned title/subtitle, footer with source text (left),
a full-width separator line above the footer, and an optional logo (right). Default
export size 640x450 pixels. Hover interaction on both controls: nearest data point
highlighting with an in-chart tooltip (see 4.11), on by default.

Out of scope for v1: facets/small multiples, zoom/pan, 3D, design-time component
registration (runtime creation only), animation.

## 2. Repository layout

```
Chart4D/
├── Source/                      Core, RTL-only (no platform-specific APIs)
│   ├── Chart4D.Types.pas
│   ├── Chart4D.Consts.pas
│   ├── Chart4D.Style.pas
│   ├── Chart4D.Series.pas
│   ├── Chart4D.Axis.pas
│   ├── Chart4D.Canvas.Interfaces.pas
│   ├── Chart4D.Plot.pas
│   ├── Chart4D.Renderer.pas
│   ├── Chart4D.Tooltip.pas      Hit-testing and the hover tooltip (4.11)
│   ├── Chart4D.Hover.pas        Hover state shared by both controls (4.11)
│   ├── VCL/
│   │   └── Chart4D.VCL.pas      GDI+ canvas, TChart4D control, PNG export
│   └── FMX/
│       └── Chart4D.FMX.pas      FMX canvas, TChart4D control, PNG export
├── packages/RAD Studio 13.0/
│   ├── Chart4D_R.dpk/.dproj         requires rtl
│   ├── Chart4D_VCL_R.dpk/.dproj     requires rtl, vcl, Chart4D_R
│   └── Chart4D_FMX_R.dpk/.dproj     requires rtl, fmx, Chart4D_R
├── Tests/                       DUnitX console project + build.bat
├── Examples/
│   ├── Common/                  Chart4DDemo.Catalog.pas, shared by both demos
│   ├── VCL/                     Chart4DDemoVcl.dpr
│   └── FMX/                     Chart4DDemoFmx.dpr
├── Tools/
│   ├── CoreCheck/               Console .dpr that uses every core unit (compile check)
│   ├── VclCheck/                Renders and exports through the VCL adapter, plus tooltip
│   ├── FmxCheck/                Same for FMX, plus series-pixel checks on the paint path
│   └── Gallery/                 Renders every chart kind to PNG for visual inspection
├── assets/                      Chart4D.ico and the mark, plus the .rc/.res that embeds it
├── docs/images/                 Rendered charts used by README.md
├── Build.bat                    Builds packages, tests, demos
└── SPEC.md, README.md, LICENSE, GDK.Chart4D.dspec
```

Dependency rules: core units use only `System.*`. `Chart4D.VCL.pas` additionally uses
`Vcl.*`/`Winapi.*`; `Chart4D.FMX.pas` additionally uses `FMX.*`. Nothing in core may
reference an adapter.

## 3. Default editorial style

All colors are `TAlphaColor` ($AARRGGBB). Sizes are pixels at the 640x450 reference size,
multiplied by `TChartStyle.ScaleFactor` when rendering.

| Element | Value |
|---|---|
| Title | bold, 28, $FF222222 |
| Subtitle | regular, 22, $FF222222, 9 px margin above and below |
| Legend text | 18, $FF222222, no legend title, top position, left aligned |
| Axis text | 18, $FF222222; no axis titles, no tick marks, no axis lines |
| X-axis labels | 5 px margin above, 10 px below the labels |
| Gridlines | value-axis only, $FFCBCBCB, width 1; none on the category axis |
| Baseline at value 0 | $FF333333, width 2 (drawn when 0 is inside the value range) |
| Background | $FFFFFFFF |
| Footer (source) | 16, $FF555555, bottom left; separator line $FF222222 width 1 above the footer area |
| Tooltip | white box, border $FFCBCBCB width 1, text 16 $FF222222, 8 px padding; highlight circle radius 5 in the series color |
| Series line width | 3 |
| Font | 'Helvetica'; on Windows 'Arial' (`{$IFDEF MSWINDOWS}`) |
| Value labels | text `AxisFontSize`/`TextColor`, white background box (3 px padding), same convention as `TextLabel` annotations (see 4.12) |
| Series highlight (muted series) | drawn in `ChartLightGrey` (see 4.13) |
| Scatter point radius | 4 (uniform, used when a series has no per-point `Sizes`; see 4.19) |
| Bubble radius range | 4 to 24, area-proportional (`Sqrt` scaling), domain shared across the whole plot (see 4.19) |
| Donut inner radius | 0.6 &times; outer radius (see 4.24) |

The last four rows are carried by `TChartStyle` fields: `ScatterPointRadius: Single` (4),
`MinBubbleRadius: Single` (4), `MaxBubbleRadius: Single` (24), `DonutInnerRadiusFactor: Single` (0.6). See 4.3.

Palette constants in `Chart4D.Style.pas`:

```pascal
const
  ChartBlue         = TAlphaColor($FF1380A1);
  ChartOrange       = TAlphaColor($FFFAAB18);
  ChartDarkRed      = TAlphaColor($FF990000);
  ChartGreen        = TAlphaColor($FF588300);
  ChartTextDark     = TAlphaColor($FF222222);
  ChartTextMuted    = TAlphaColor($FF555555);
  ChartBaselineGrey = TAlphaColor($FF333333);
  ChartGridGrey     = TAlphaColor($FFCBCBCB);
  ChartLightGrey    = TAlphaColor($FFDDDDDD);

  DefaultPalette: array[0..5] of TAlphaColor =
    (ChartBlue, ChartOrange, ChartDarkRed, ChartGreen, ChartBaselineGrey, ChartLightGrey);
```

## 4. Public API contracts

Signatures below are normative. Add `/// <summary>` docs; private helpers are free.

### 4.1 Chart4D.Types.pas

```pascal
{$SCOPEDENUMS ON}
type
  TChartKind = (Line, Bar, GroupedBar, StackedBar, Dumbbell, Histogram, Area,
               Scatter, DotPlot, Range, Arrow, Pie, Donut);
  TChartOrientation = (Vertical, Horizontal);
  TStackMode = (Values, Proportions);
  TLegendPosition = (None, Top, Right, Bottom, Left);
  TAnnotationKind = (TextLabel, Segment, Arrow, HorizontalLine, VerticalLine,
                     HorizontalRangeOverlay, VerticalRangeOverlay);
  TTextAlignH = (Left, Center, Right);
  TTextAlignV = (Top, Middle, Bottom);

  TChartAnnotation = record
    Kind: TAnnotationKind;
    X, Y, X2, Y2: Double;
    Text: string;
    Color: TAlphaColor;
    FontSize: Single;
    LineWidth: Single;
    Dashed: Boolean;
    AlignH: TTextAlignH;
  end;

  EChart4DException = class(Exception);

  TChartKindTraits = record
    /// <summary>
    /// Whether the kind draws as wedges of a circle and therefore has no axes, no
    /// gridlines and no baseline at all.
    /// </summary>
    class function IsCircular(const Kind: TChartKind): Boolean; static;

    /// <summary>
    /// Whether the kind plots against a continuous X axis built from
    /// <c>TChartSeries.XValues</c>, rather than against discrete categories.
    /// </summary>
    class function UsesContinuousX(const Kind: TChartKind): Boolean; static;

    /// <summary>
    /// Whether the kind reads <c>TChartSeries.EndValues</c> as the second end of every
    /// data point, so those values count towards the value range as well.
    /// </summary>
    class function HasEndValues(const Kind: TChartKind): Boolean; static;

    /// <summary>
    /// Whether the kind draws marks that grow from a zero baseline, which forces zero
    /// into the value range even when no data point is near it.
    /// </summary>
    class function IncludesZeroBaseline(const Kind: TChartKind): Boolean; static;

    /// <summary>
    /// Whether the kind's marks encode a position rather than a length from a baseline.
    /// Such a scale gets headroom below the data as well as above it, because its lowest
    /// mark would otherwise sit on the plot edge.
    /// </summary>
    class function MarksPositionNotBaseline(const Kind: TChartKind): Boolean; static;
  end;
```

Annotation coordinates are in data space. For category charts the category axis
coordinate is the 0-based category index as `Double`. `Pie`/`Donut` charts have no
axes to define a data space, so annotations there use a coordinate space of their own:
X is still the 0-based category index, and Y is a fraction of the plot height, 0 at
the bottom edge and 1 at the top (4.23). `FontSize`/`LineWidth` value 0
means "use style default". `TextLabel` annotations are drawn with a white background
rectangle behind the text so they stay readable on top of series.

`TChartKindTraits` is the single authority on the per-kind facts that more than one
part of the library has to agree on; every site that needs one of these answers asks
this record rather than keeping its own `Kind in [...]` set.

Bubble charts are not a separate `TChartKind`: a `Scatter` series with a non-empty
`Sizes` array (4.4) is a bubble series. A dedicated kind would duplicate every scatter
code path (axis computation, hit map, legend) for a difference that is really a
per-series data fact, not a chart-kind fact; see 4.19.

`TAnnotationKind`'s `HorizontalRangeOverlay` is a filled band between `Y` and `Y2`,
spanning the full plot width; `VerticalRangeOverlay` is a filled band between `X` and
`X2`, spanning the full plot height; see 4.18. Both reuse the `X2`/`Y2` fields that
`Segment`/`Arrow` also read, so `TChartAnnotation` needs no extra field for them.

### 4.2 Chart4D.Consts.pas

`resourcestring` error messages (English) and:

```pascal
const
  DefaultExportWidth  = 640;
  DefaultExportHeight = 450;
```

The `resourcestring` entries for the capabilities in 4.12 to 4.24:

```pascal
resourcestring
  SSeriesSizeCountMismatch = 'Series "%s" has %d value(s) but %d size(s)';
  SLogAxisRequiresPositiveValues = 'Logarithmic value axis requires every value to be greater than 0, got %g';
  SPairedValueCountMismatch = '%s series has %d start value(s) but %d end value(s)';
  SBandValueCountMismatch = 'Band series "%s" has %d low value(s) but %d high value(s)';
  SPieRequiresSingleSeries = 'Pie/Donut charts require exactly one series, got %d';
  SPieValuesMustBeNonNegative = 'Pie/Donut values must not be negative, got %g';
```

### 4.3 Chart4D.Style.pas

```pascal
type
  TChartStyle = record
    FontName: string;
    TitleFontSize: Single;      // 28
    SubtitleFontSize: Single;   // 22
    LegendFontSize: Single;     // 18
    AxisFontSize: Single;       // 18
    CaptionFontSize: Single;    // 16
    TitleColor: TAlphaColor;    // ChartTextDark
    TextColor: TAlphaColor;     // ChartTextDark
    MutedTextColor: TAlphaColor;// ChartTextMuted
    BackgroundColor: TAlphaColor;
    GridColor: TAlphaColor;
    BaselineColor: TAlphaColor;
    ShowGridlines: Boolean;     // True: gridlines on the value axis
    ShowBaseline: Boolean;      // True
    GridLineWidth: Single;      // 1
    BaselineWidth: Single;      // 2
    SeriesLineWidth: Single;    // 3
    ScaleFactor: Single;        // 1.0
    ScatterPointRadius: Single;      // 4, see 4.19
    MinBubbleRadius: Single;         // 4, see 4.19
    MaxBubbleRadius: Single;         // 24, see 4.19
    DonutInnerRadiusFactor: Single;  // 0.6, see 4.24
    class function Default: TChartStyle; static;
  end;
```

### 4.4 Chart4D.Series.pas

```pascal
type
  TChartSeries = class
  public
    constructor Create(const Name: string);
    property Name: string read ... write ...;
    property Color: TAlphaColor read ... write ...;   // 0 = auto from palette
    property Values: TArray<Double> read ... write ...;
    property XValues: TArray<Double> read ... write ...;   // Line/Area/Scatter only
    property EndValues: TArray<Double> read ... write ...; // Dumbbell/Range/Arrow/range bands
    property Sizes: TArray<Double> read ... write ...;     // Scatter only; empty = uniform radius
    property IsRangeBand: Boolean read ... write ...;      // Line/Area only; default False
  end;
```

`XValues` covers `Scatter` (4.19) as well, which reuses the same continuous-X point
shape as `Line`. `EndValues` covers `Range` (4.21) and `Arrow` (4.22) as well, which
reuse the same low/high pair shape as `Dumbbell`; a range-band series (4.17) also reads
it as its high bound. `Sizes`, when non-empty, must have the
same length as `Values`; it turns a `Scatter` series into a bubble series (4.19).
`IsRangeBand`, when `True` on a series of a `Line`/`Area` plot, marks it as an uncertainty
band: `Values` is the low bound and `EndValues` the high bound at each point, drawn as a
shaded region rather than a line (4.17). The defaults (`nil`/`False`) leave a plain
series untouched by either capability.

### 4.5 Chart4D.Axis.pas

```pascal
type
  TAxisOptions = record
    MinValue: Double;              // NaN = automatic
    MaxValue: Double;              // NaN = automatic
    Breaks: TArray<Double>;        // empty = automatic (NiceBreaks)
    BreakLabels: TArray<string>;   // empty = automatic (BuildLabels)
    UseThousandSeparator: Boolean; // default False
    LabelSuffix: string;           // e.g. '%' or ' years'
    SuffixOnLastOnly: Boolean;     // default True ("90 years" on the last break only)
    Visible: Boolean;              // default True (axis text)
    Scale: TAxisScaleKind;         // default Linear; see 4.15
    LogBase: Double;               // default 10; see 4.15
    DateMode: TAxisDateMode;       // default None; see 4.16
    LocaleName: string;            // default ''; '' = invariant; see 4.14
    class function Default: TAxisOptions; static;
  end;

  TAxisScale = class
  public
    class function NiceBreaks(const MinValue, MaxValue: Double;
                              const TargetCount: Integer = 5): TArray<Double>; static;
    class function FormatValue(const Value: Double;
                               const UseThousandSeparator: Boolean): string; overload; static;
    class function FormatValue(const Value: Double; const UseThousandSeparator: Boolean;
                               const LocaleName: string): string; overload; static;
    class function BuildLabels(const Breaks: TArray<Double>;
                               const Options: TAxisOptions): TArray<string>; static;
    class function LogBreaks(const MinValue, MaxValue: Double;
                             const LogBase: Double = 10): TArray<Double>; static;
    class function ResolveDateMode(const MinValue, MaxValue: Double;
                                   const Mode: TAxisDateMode): TAxisDateMode; static;
    class function DateBreaks(const MinValue, MaxValue: Double;
                              const Mode: TAxisDateMode): TArray<Double>; static;
    class function FormatDateValue(const Value: Double; const Mode: TAxisDateMode;
                                   const LocaleName: string = ''): string; static;
  end;

  TLinearMapper = record
    DataMin: Double;
    DataMax: Double;
    PixelMin: Single;
    PixelMax: Single;
    Inverted: Boolean;
    class function Create(const DataMin, DataMax: Double;
                          const PixelMin, PixelMax: Single;
                          const Inverted: Boolean): TLinearMapper; static;
    function Map(const Value: Double): Single;
  end;
```

`Chart4D.Axis.pas` uses `Chart4D.Types` for `TAxisScaleKind` (4.15) and
`TAxisDateMode` (4.16); both are declared in `Chart4D.Types.pas` alongside the other
`{$SCOPEDENUMS ON}` enums, not in this unit. Setting both `Scale = Logarithmic` and
`DateMode <> None` on the same axis is not supported; behavior in that combination is
undefined, and callers must treat the two as mutually exclusive per axis.

`NiceBreaks` algorithm (nice numbers, inclusive-inside breaks):

1. Guard: if `MinValue = MaxValue`, treat range as `[MinValue - 1, MaxValue + 1]`.
2. `RawStep := (MaxValue - MinValue) / (TargetCount - 1)`.
3. `Magnitude := Power(10, Floor(Log10(RawStep)))`; `Normalized := RawStep / Magnitude`.
4. `NiceFactor`: `< 1.5 → 1`, `< 3 → 2`, `< 7 → 5`, otherwise `10`. `Step := NiceFactor * Magnitude`.
5. Breaks run from `Ceil(MinValue / Step) * Step` up to `Floor(MaxValue / Step) * Step`
   inclusive, stepping by `Step` (all breaks lie inside `[MinValue, MaxValue]`).

Examples (used in tests): `NiceBreaks(0, 85)` = `[0, 20, 40, 60, 80]`;
`NiceBreaks(1952, 2007)` = `[1960, 1970, 1980, 1990, 2000]`; `NiceBreaks(0, 1, 5)` =
`[0, 0.2, 0.4, 0.6, 0.8, 1.0]`.

`FormatValue`: invariant decimal separator `.`; thousand separator `,` (fixed English
convention, not locale dependent, so output is reproducible). Trailing decimal zeros
removed (`5.0 → '5'`).

`BuildLabels`: when `Options.DateMode <> TAxisDateMode.None` (4.16), every break is
formatted with `FormatDateValue(Break, Mode, Options.LocaleName)` instead of the rules
below, where `Mode` is the concrete date mode resolved once from the data range before
the breaks were placed (4.16), never a second resolution from the break span; and
`LabelSuffix`/`UseThousandSeparator` are ignored. Otherwise: format every break with `FormatValue`
(the 3-argument overload when `Options.LocaleName <> ''`, otherwise the 2-argument
invariant overload); when `LabelSuffix <> ''` append it to the last break only when
`SuffixOnLastOnly`, otherwise to every break. When `BreakLabels` is non-empty it wins
entirely, before either of the above.

`FormatValue(Value, UseThousandSeparator, LocaleName)`: identical to the 2-argument
overload except it formats with `TFormatSettings.Create(LocaleName)` instead of
`TFormatSettings.Invariant`, and trims trailing decimal zeros using that locale's own
`DecimalSeparator`/`ThousandSeparator` rather than the fixed `.`/`,`. The 2-argument
overload's behavior, and its use as the default everywhere `LocaleName` is `''`, is
unchanged, so every existing caller and test keeps its exact invariant output; locale
formatting is strictly opt-in per axis (4.14).

`TLinearMapper.Map`: linear interpolation of `Value` from `[DataMin, DataMax]` to
`[PixelMin, PixelMax]`; when `Inverted`, to `[PixelMax, PixelMin]` (screen Y axis).
`TLinearMapper` itself is unchanged by the logarithmic axis (4.15): the renderer feeds it
`LogN(LogBase, Value)` instead of `Value`, and log-space bounds instead of data-space
bounds, when the axis is logarithmic; the mapper does not know it is operating in log
space.

### 4.6 Chart4D.Canvas.Interfaces.pas

```pascal
type
  TChartTextStyle = record
    FontName: string;
    Size: Single;
    Bold: Boolean;
    Color: TAlphaColor;
    class function Create(const FontName: string; const Size: Single;
                          const Bold: Boolean; const Color: TAlphaColor): TChartTextStyle; static;
  end;

  IChartCanvas = interface
    ['{...new GUID...}']
    procedure FillBackground(const Width, Height: Single; const Color: TAlphaColor);
    procedure DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                       const StrokeWidth: Single; const Dashed: Boolean);
    procedure DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                           const StrokeWidth: Single);
    procedure FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
    procedure FillRect(const Bounds: TRectF; const Color: TAlphaColor);
    procedure FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
    procedure DrawText(const X, Y: Single; const Text: string;
                       const TextStyle: TChartTextStyle;
                       const AlignH: TTextAlignH; const AlignV: TTextAlignV);
    function MeasureText(const Text: string;
                         const TextStyle: TChartTextStyle): TSizeF;
    procedure DrawImage(const FilePath: string; const Bounds: TRectF);
  end;
```

`DrawText` anchors at `(X, Y)` according to the alignment (e.g. `AlignH = Left`,
`AlignV = Top` means `(X, Y)` is the top-left of the text box). `DrawImage` scales the
image uniformly (aspect fit) inside `Bounds`, right-aligned within it.

### 4.7 Chart4D.Plot.pas

```pascal
type
  TChartPlot = class
  public
    constructor Create;
    destructor Destroy; override;

    function AddSeries(const Name: string): TChartSeries; overload;
    function AddSeries(const Name: string; const Values: TArray<Double>): TChartSeries; overload;
    function AddLineSeries(const Name: string;
                           const XValues, YValues: TArray<Double>): TChartSeries;
    function AddRangeBandSeries(const Name: string;
                                const XValues, LowValues, HighValues: TArray<Double>): TChartSeries;
    function AddDumbbellSeries(const StartValues, EndValues: TArray<Double>): TChartSeries;
    function AddRangeSeries(const Name: string;
                            const LowValues, HighValues: TArray<Double>): TChartSeries;
    function AddArrowSeries(const Name: string;
                            const StartValues, EndValues: TArray<Double>): TChartSeries;
    procedure SetHistogramData(const Values: TArray<Double>; const BinWidth: Double);
    procedure ClearSeries;

    procedure AddTextAnnotation(const X, Y: Double; const Text: string;
                                const Color: TAlphaColor; const AlignH: TTextAlignH = TTextAlignH.Left);
    procedure AddSegment(const X1, Y1, X2, Y2: Double);
    procedure AddArrow(const X1, Y1, X2, Y2: Double);
    procedure AddHorizontalLine(const Y: Double; const Color: TAlphaColor;
                                const Dashed: Boolean = False);
    procedure AddVerticalLine(const X: Double; const Color: TAlphaColor;
                              const Dashed: Boolean = False);
    procedure AddHorizontalRangeOverlay(const Y1, Y2: Double; const Color: TAlphaColor);
    procedure AddVerticalRangeOverlay(const X1, X2: Double; const Color: TAlphaColor);
    procedure ClearAnnotations;

    function SeriesColor(const Index: Integer): TAlphaColor;
    function CategoryColor(const Index: Integer): TAlphaColor;

    property Kind: TChartKind ...;
    property Title: string ...;
    property Subtitle: string ...;
    property Source: string ...;            // footer text, e.g. 'Source: World Bank'
    property LogoFilePath: string ...;      // optional footer logo (PNG)
    property Categories: TArray<string> ...;
    property Series: TObjectList<TChartSeries> read ...;   // owned
    property Style: TChartStyle ...;
    property XAxis: TAxisOptions ...;
    property YAxis: TAxisOptions ...;
    property Orientation: TChartOrientation ...;  // default Vertical
    property StackMode: TStackMode ...;           // default Values
    property LegendPosition: TLegendPosition ...; // default Top
    property LegendReversed: Boolean ...;
    property Annotations: TArray<TChartAnnotation> read ...;
    property ValueLabels: TValueLabelMode ...;         // default None; see 4.12
    property HighlightedSeriesIndex: Integer ...;      // default -1; see 4.13
    property DonutCenterText: string ...;              // default ''; Donut only, see 4.24
    property OnChanged: TNotifyEvent ...;
  end;
```

Behavior:

- `SeriesColor(Index)`: when `HighlightedSeriesIndex` is `-1` (default) or out of range,
  the series' own `Color` when non-zero, otherwise
  `DefaultPalette[Index mod Length(DefaultPalette)]`. When `HighlightedSeriesIndex` is a
  valid series index, `SeriesColor(HighlightedSeriesIndex)` still resolves as above, and
  `SeriesColor` of every other index returns `ChartLightGrey` instead; see 4.13.
- `CategoryColor(Index)`: `DefaultPalette[Index mod Length(DefaultPalette)]`, always;
  categories have no per-category color override. Used by `Pie`/`Donut` (4.23, 4.24),
  which color by category rather than by series.
- `AddDumbbellSeries` sets `Kind := Dumbbell` and `Orientation := Horizontal` and fills
  `Values`/`EndValues` of a single series. `AddRangeSeries` and `AddArrowSeries` do the
  same for `Kind := Range` (4.21) and `Kind := Arrow` (4.22) respectively, and additionally
  take a `Name`, since (unlike `Dumbbell`) a named single series is useful and does not
  conflict with anything existing.
- `AddRangeBandSeries` appends (does not clear) a series with `XValues`, `Values :=
  LowValues`, `EndValues := HighValues`, and `IsRangeBand := True`, exactly like
  `AddLineSeries` otherwise. It does not set `Kind`; the band renders as a shaded region
  only when the plot's `Kind` is `Line` or `Area` (4.17), matching the existing convention
  that `AddLineSeries` does not set `Kind` either.
- `AddHorizontalRangeOverlay`/`AddVerticalRangeOverlay` append a
  `HorizontalRangeOverlay`/`VerticalRangeOverlay` annotation using `Y`/`Y2` or `X`/`X2`
  respectively (4.18); `Color` is drawn exactly as given, with no alpha adjustment, so a
  translucent wash requires the caller to pass a `TAlphaColor` with a non-`$FF` alpha
  channel, the same as every other `Color` parameter in this unit.
- `SetHistogramData` sets `Kind := Histogram`, bins values (bin `k` covers
  `[k*BinWidth, (k+1)*BinWidth)`, `k = Floor(Value / BinWidth)`; empty bins between the
  first and last used bin get count 0), fills `Categories` with the lower bin bounds
  formatted with `TAxisScale.FormatValue`, and one series with the counts.
- `DotPlot` (4.20) and `Pie`/`Donut` (4.23, 4.24) need no new `TChartPlot` method: a dot
  plot is `Categories` plus one or more ordinary `AddSeries` calls, exactly like `Bar`/
  `GroupedBar`, distinguished only by `Kind`; a pie/donut is `Categories` plus exactly one
  `AddSeries` call.
- Every mutator fires `OnChanged` (controls repaint on it).
- Guard clauses raise `EChart4DException` on invalid input (e.g. `BinWidth <= 0`,
  empty histogram data, mismatching array lengths at render time).

### 4.8 Chart4D.Renderer.pas

```pascal
type
  TChartRenderer = class
  public
    class procedure Render(const Plot: TChartPlot; const Canvas: IChartCanvas;
                           const Width, Height: Single);
  end;
```

Layout (top to bottom; all sizes scaled by `Style.ScaleFactor`; outer margin 16 on all
sides):

1. Background fill.
2. Title (bold, left-aligned at outer margin), when non-empty. Wrapped onto as many lines
   as needed when wider than the space between the outer margins: `WrapTextLines` measures
   each candidate line with `IChartCanvas.MeasureText` and breaks on word boundaries, adding
   one word at a time until the next word would not fit, at which point that word starts a
   new line. A single word wider than the available width is not split and is left to overflow,
   since breaking a word gives an unreadable result and this is a caller-content problem
   not a layout defect. Each line advances by the same line
   height, `IChartCanvas.MeasureText('Xg', TextStyle).Height`, a fixed per-font-size value
   rather than each line's own measured height, so a wrapped block has even line spacing
   regardless of which lines happen to contain descenders (the same fixed-sample precedent
   `Chart4D.Tooltip.pas` already uses for its own multi-line text). This is a pure layout
   change: the plot area top is pushed down by the extra line height whenever a title or
   subtitle wraps, since `PerformLayout` already threads the returned bottom of the title/
   subtitle block into the content rect it hands to the plot area.
3. Subtitle with 9 px margin above and below, when non-empty, wrapped exactly like the title
   and sharing the same `WrapTextLines`/line-height rule, using its own font size.
4. Legend when `LegendPosition = Top` and more than one named series: a horizontal
   left-aligned row of items (14x14 color swatch, 6 px gap, series name, 24 px between
   items), wrapping to extra rows when needed. `LegendReversed` reverses item order.
   Positions Right/Bottom/Left: vertical or bottom variants (simple implementations
   acceptable); `None` hides the legend. Legend items come from `BuildSeriesLegendItems`,
   one item per named series; for `Pie`/`Donut`, `BuildCategoryLegendItems` builds one
   item per category (`Categories[i]`/`CategoryColor(i)`) instead, since those kinds
   always have exactly one series (4.23); the "more than one item"
   condition to show the legend still applies, there counting categories.
5. Plot area: from below the legend (12 px gap) down to the category/axis labels and
   the footer. Left inset = widest value-axis label + 8 px. Right inset = half the
   width of the last horizontal-axis label, so that label is never clipped at the
   right edge. For `Pie`/`Donut` (4.23, 4.24), which have no axes at all, both insets and
   the bottom axis label height are always 0: `ComputeLeftInset`, `ComputeRightInset`,
   and `ComputeBottomAxisLabelHeight` return 0 when `Kind in [Pie, Donut]`, before their
   normal axis-visibility checks.
6. Footer, only when `Source <> ''` or `LogoFilePath <> ''`: at the very bottom, height
   `2.2 * CaptionFontSize`, a full-width separator line ($FF222222, width 1) at its top,
   source text left (CaptionFontSize, MutedTextColor, vertically centered), logo
   right (aspect fit into the footer height).

Value axis: compute data min/max over all series appropriate for the kind. For `Bar`,
`GroupedBar`, `StackedBar`, `Histogram` and `Area` the range always includes 0
(`TChartKindTraits.IncludesZeroBaseline`, 4.1). `Line`,
`Scatter`, `DotPlot`, `Range`, `Arrow` and `Dumbbell` never force 0 into range
(4.19, 4.20, 4.21, 4.22); `Range` and `Arrow` compute their range the same
way as `Dumbbell`, as the min/max across both `Values` and `EndValues` of the
single series. Stacked uses per-category sums, with separate positive and negative sums
per category so a mixed-sign stack reserves room on both sides of the baseline;
`StackMode.Proportions` normalizes each
category to 1.0 with fixed breaks `[0, 0.25, 0.5, 0.75, 1]` labelled `0%..100%`. Add 4%
headroom above the data maximum; for the kinds that mark a position rather than a length
from a zero baseline, `Line`, `Dumbbell`, `Range`, `Arrow`, `Scatter` and `DotPlot`
(`TChartKindTraits.MarksPositionNotBaseline`, 4.1), also
add 4% headroom below the data minimum whenever `YAxis.MinValue` is automatic, regardless
of sign. `Bar`, `GroupedBar`, `StackedBar`, `Histogram`
and `Area` keep their zero baseline and stay out of this rule. Manual
`MinValue`/`MaxValue`/`Breaks` in the axis options override all of this,
as does a logarithmic scale, which replaces headroom entirely (4.15). Gridlines are drawn
per break across the plot area on the value axis; the baseline at value 0 on top of them
(never drawn for a logarithmic axis, since 0 cannot be in its range; see 4.15). `Pie`/
`Donut` have no value axis and skip this whole computation, and skip `DrawAxisLabels`,
`DrawGrid` and `DrawValueLabels` (4.12) entirely: see 4.23. Category axis: a label is
centered under (or left of, when `Orientation = Horizontal`) its band, but is drawn only
when it fits beside its neighbours: `TChartRenderJob.SelectedCategoryLabelIndices` walks
categories left to right (top to bottom when horizontal), always keeps index 0, and keeps
a later index only when the distance to the last kept label (`(Index - LastKept) *
CategoryBand`) is at least the average of the two labels' measured extents (`IChartCanvas.
MeasureText` on the actual label text and the actual `AxisTextStyle`; width for a vertical
chart, height for a horizontal one, since a horizontal chart stacks its category labels one
per row down the left edge, where height, not width, is the scarce dimension). The last
category is then kept too whenever it does not collide with the last label the walk kept,
so the first and last category stay labelled whenever they fit, anchoring the axis. This
is deterministic (the same categories, band and font always select the same indices) and
applies to every kind that draws a discrete category axis, including `Histogram`; there is
no separate fixed-count thinning rule anywhere, since a measured fit is strictly more
accurate than a fixed count and a second thinning rule alongside it would just be
duplicate logic that could drift out of
sync. For `Line`, `Area` and `Scatter` the X axis uses `NiceBreaks` over the X range
(`TChartKindTraits.UsesContinuousX`, 4.1), or, when `XAxis.DateMode <>
None`, a date-aware axis instead (4.16); a continuous X axis draws every break's label
unthinned, since `NiceBreaks`/`DateBreaks` already keep to roughly 5-8 breaks by
construction.

`Orientation = Horizontal` swaps the roles of the axes: categories run top to bottom,
values run left to right, gridlines become vertical.

Series drawing per kind (band = plot width / category count):

- `Line`: one polyline per series, `SeriesLineWidth`.
- `Area`: polygon from the line down to the baseline, series color; polyline on top.
- `Bar`: one bar per category, width 0.7 * band, centered.
- `GroupedBar`: bars of the series side by side inside 0.7 * band (dodge).
- `StackedBar`: segments stacked in series order, positive segments accumulating away
  from the baseline on one side and negative segments on the other (diverging stacking,
  with separate positive and negative running totals per category); `LegendReversed`
  only affects the legend, not stacking order.
- `Histogram`: like `Bar` but bar width = band minus a 1 px gap on each side; its category
  labels are thinned by the same measured-fit rule as every other discrete category axis,
  described just above.
- `Dumbbell`: per category a connector line (ChartLightGrey, width 3) from `Values[i]`
  to `EndValues[i]` with a circle (radius 5) at each end: start = ChartOrange,
  end = ChartBlue.
- `Scatter`: see 4.19. One filled circle per point, no connecting line; radius is
  `ScatterPointRadius` when the series' `Sizes` is empty, otherwise area-proportional
  between `MinBubbleRadius` and `MaxBubbleRadius` (a bubble series).
- `DotPlot`: see 4.20. One filled circle per category per series, all series sharing the
  same category position (no dodge offset), radius `ScatterPointRadius`.
- `Range`: see 4.21. One filled rectangle per category from `Values[i]` to `EndValues[i]`,
  width `0.7 * band`, like `Bar`.
- `Arrow`: see 4.22. One line with an arrowhead per category from `Values[i]` to
  `EndValues[i]`, reusing the shared `TChartArrowPainter` helper.
- `Pie`, `Donut`: no category/value axis and no band; see 4.23 and 4.24.

Value labels (4.12) draw next, above the series but below annotations, when
`ValueLabels <> None`; not drawn for `Pie`/`Donut`, which label their segments
unconditionally instead (4.23). Annotations render last, above series and value labels,
mapped through the same mappers, except `HorizontalRangeOverlay`/`VerticalRangeOverlay`
(4.18), which render immediately after axis labels and before gridlines, so they sit
behind the grid and the series rather than on top of them; `DrawAnnotation`'s dispatch
excludes these two kinds (already drawn) when it runs the remaining annotations.
`HorizontalLine`/`VerticalLine`/`HorizontalRangeOverlay`/`VerticalRangeOverlay` span the
full plot area.

The renderer must not mutate the plot. A plot with no series draws just the background
and produces an empty hit map: painting a control before its data arrives is a normal
state and never raises. Once a series is present, the renderer validates the input up
front and raises `EChart4DException` with a clear message for mismatched lengths
(categories vs values), a series without values, a NaN value, a reversed manual axis
range (`MinValue` above `MaxValue`), a `LogBase` not greater than 1, and a manual
`MinValue`/`MaxValue` that is not strictly positive on a logarithmic axis.

### 4.9 Chart4D.VCL.pas (Source\VCL)

```pascal
type
  TGdiPlusChartCanvas = class(TInterfacedObject, IChartCanvas)
  public
    constructor Create(const Graphics: TGPGraphics);
    // implements every IChartCanvas method with antialiasing enabled
  end;

  TChart4D = class(TGraphicControl)
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SaveToPng(const FilePath: string;
                        const Width: Integer = DefaultExportWidth;
                        const Height: Integer = DefaultExportHeight);
    property Plot: TChartPlot read ...;   // owned
  published
    property Align;
    property Anchors;
    property Visible;
  end;
```

Implementation notes: `SmoothingModeAntiAlias`, `TextRenderingHintAntiAliasGridFit`;
fonts created with `UnitPixel` so style sizes are pixels. `TAlphaColor` maps 1:1 to the
GDI+ ARGB color value. `SaveToPng` renders into a `TGPBitmap` and saves with the PNG
encoder CLSID; it raises `EChart4DException` when the plot has no series to export,
whereas painting an empty control does not (4.8). Control repaints (`Invalidate`) via `Plot.OnChanged`. Default control
size 640x450. GDI+ startup/shutdown is handled by `Winapi.GDIPOBJ`.

### 4.10 Chart4D.FMX.pas (Source\FMX)

```pascal
type
  TFmxChartCanvas = class(TInterfacedObject, IChartCanvas)
  public
    constructor Create(const Canvas: FMX.Graphics.TCanvas);
  end;

  TChart4D = class(TControl)
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SaveToPng(const FilePath: string;
                        const Width: Integer = DefaultExportWidth;
                        const Height: Integer = DefaultExportHeight);
    property Plot: TChartPlot read ...;
  end;
```

Text via `TTextLayout` (reliable measuring); `SaveToPng` via an offscreen
`FMX.Graphics.TBitmap` (`BeginScene`/`EndScene`, `SaveToFile`), raising the same
no-series `EChart4DException` as the VCL control. Repaint via
`Plot.OnChanged` calling `Repaint`.

### 4.11 Hover interaction (tooltips)

Hover interaction lives in the core units `Chart4D.Tooltip.pas` and `Chart4D.Hover.pas`
plus the declarations below in existing units.

In `Chart4D.Types.pas`:

```pascal
type
  TChartHitInfo = record
    HasHit: Boolean;
    SeriesIndex: Integer;
    PointIndex: Integer;
    SeriesName: string;
    CategoryLabel: string;   // category label, or formatted X value for Line/Area
    Value: Double;
    AnchorX: Single;         // pixel anchor of the data point / bar
    AnchorY: Single;
    Color: TAlphaColor;      // resolved series color
  end;

  TChartHitTarget = record
    Bounds: TRectF;          // hit rectangle (bars, stack segments)
    Center: TPointF;         // hit center (line points, dumbbell dots)
    Radius: Single;          // > 0: circular target, Bounds ignored
    Info: TChartHitInfo;
  end;
```

In `Chart4D.Renderer.pas` (the map-less `Render` overload delegates to this one with a
discarded map):

```pascal
class procedure Render(const Plot: TChartPlot; const Canvas: IChartCanvas;
                       const Width, Height: Single;
                       out HitMap: TArray<TChartHitTarget>); overload;
```

The hit map contains one target per data point: circular targets (radius 12) for
`Line`/`Area` points and dumbbell dots, rectangular targets for bars, grouped bars,
stack segments and histogram bins. `Info.CategoryLabel` holds the category text (or
the formatted X value for Line/Area); `Info.Color` the resolved series color.

`Chart4D.Tooltip.pas`:

```pascal
type
  TChartTooltip = class
  public
    class function FindTarget(const HitMap: TArray<TChartHitTarget>;
                              const X, Y: Single; out Info: TChartHitInfo): Boolean; static;
    class procedure Draw(const Canvas: IChartCanvas; const Style: TChartStyle;
                         const Info: TChartHitInfo;
                         const Width, Height: Single;
                         const LocaleName: string = ''); static;
  end;
```

`Draw`'s trailing `LocaleName` parameter defaults to `''` (invariant). When non-empty it
is used to format `Info.Value` in
`BuildLines` via the 3-argument `TAxisScale.FormatValue` overload (4.14) instead of the
invariant one; callers pass the hovered axis' `LocaleName` (typically `Plot.YAxis
.LocaleName`). `TChartHitTarget` carries sector fields for `Pie`/`Donut` hit-testing, and
`TChartTooltip`'s private `TargetContainsPoint` has a branch for them; both are
specified in 4.23, the section that introduces sectors, rather than here.

`FindTarget` returns the target whose center/rect is closest to `(X, Y)` among those
containing the point (circular: distance <= radius; rect: point inside). `Draw`
renders a highlight circle (radius 5, `Info.Color`) at the anchor and a tooltip box
per the section 3 style: text `'<SeriesName>'` on the first line (omitted when the
series has no name) and `'<CategoryLabel>: <formatted Value>'` on the second,
positioned 12 px above the anchor, clamped inside the chart bounds, background white,
border $FFCBCBCB.

Both controls (`Chart4D.VCL.pas`, `Chart4D.FMX.pas`):

- Public property `ShowTooltips: Boolean` (default True) and event
  `OnDataPointHover: TChartHoverEvent` (`procedure(Sender: TObject; const Info: TChartHitInfo) of object`,
  declared in `Chart4D.Types.pas`; fired when the hovered target changes, also with
  `HasHit = False` when the pointer leaves all targets).
- The control stores the hit map produced during `Paint` and hit-tests it on mouse
  move (no re-layout per move). When the hovered target changes it repaints; the
  paint pass draws the tooltip last via `TChartTooltip.Draw`.
- Mouse leave clears the hover state and repaints.
- `SaveToPng` never draws tooltips.
- Both controls hold that state in a `TChartHoverState` (`Chart4D.Hover.pas`), which owns
  the hit map, the hovered point, and the rule for whether a pointer move changed it.
  `MoveTo` and `Leave` return whether anything changed, which is the only moment a control
  fires `OnDataPointHover` and repaints. The rule lives in the RTL-only core so the VCL and
  FMX controls cannot drift apart on it; only `Invalidate` versus `Repaint` differs.
- Both core units are part of `Chart4D_R.dpk`/`.dproj`.

### 4.12 Value labels

In `Chart4D.Types.pas`:

```pascal
{$SCOPEDENUMS ON}
type
  TValueLabelMode = (None, All, FirstAndLast, Extremes);
{$SCOPEDENUMS OFF}
```

`TChartPlot` carries `property ValueLabels: TValueLabelMode` (4.7),
default `None`. `None` draws no value labels, so the capability is
purely opt-in per plot.

Value labels are drawn from the same anchor points as the hit map (built during
`DrawSeries`), as a `DrawValueLabels` step that runs after `DrawSeries` and before
`DrawAnnotations` (4.8), skipped entirely when `ValueLabels = None` or `Kind in [Pie,
Donut]` (which label their segments unconditionally instead, 4.23).

**Grouping.** A "group" is the unit `FirstAndLast`/`Extremes` select within: one group per
series for `Line`, `Area`, `Scatter`/bubble, `GroupedBar`, `StackedBar`, `DotPlot`; one
group (the single series) for `Bar`, `Histogram`; two groups, "Start" and "End", for
`Dumbbell`/`Range` (all start-of-connector points across categories, and all
end-of-connector points across categories); one group, "End", for `Arrow` (only the
arrowhead points are ever candidates, never the start points; see placement below). A
range-band series (4.17) is not a group at all and never receives value labels: a band
draws a shaded region, not marks, so it has no points to label. This
grouping exists only to decide which points are candidates; it does not read or change
`TChartHitInfo.SeriesIndex`.

**Selection**, within each group, ordered by the group's own point/category index:

- `All`: every point in the group.
- `FirstAndLast`: the first and last point in the group.
- `Extremes`: the point with the minimum `Value` and the point with the maximum `Value`
  in the group; when several points tie for a minimum or maximum, the first one in index
  order is kept and the later ties are dropped, so the result is always exactly zero, one,
  or two points per group, deterministically.

**Placement**, at the reference scale (offsets scaled by `ScaleFactor`), text formatted as
`TAxisScale.FormatValue(Value, YAxis.UseThousandSeparator) + YAxis.LabelSuffix` (always
appended, unlike axis break labels, since each value label stands alone):

- `Line`, `Area`, `Scatter`/bubble, `DotPlot`: centered on the point, offset 8 px away from
  the plot in the fixed direction for the chart's orientation (up when `Vertical`, right
  when `Horizontal`); the offset direction does not depend on the point's own value.
- `Bar`, `GroupedBar`, `Histogram`, and each `StackedBar` segment: centered on the value
  edge opposite the baseline (the bar/segment top when `Vertical`, its right edge when
  `Horizontal`), offset 8 px further away from the baseline pixel
  (`FValueMapper.Map(0)`) along the value axis; `StackedBar` uses the segment's own
  `RawValue` (matching `Info.Value` for that segment's hit target), not the cumulative
  total.
- `Dumbbell`, `Range`: one label per end, offset 8 px further away from the other end
  along the value axis (i.e. the "Start" label moves further from "End", and vice versa).
- `Arrow`: one label at the end (arrowhead) point only, offset 8 px further along the
  arrow's own direction, beyond the arrowhead.

Every label is drawn with the same white background rectangle and 3 px padding as a
`TextLabel` annotation (4.1), text in `AxisFontSize`/`TextColor`.

**Deterministic overlap avoidance.** Candidates across every group are generated in a
single fixed order: outer loop over series index as stored in `Plot.Series` (or, for
`Dumbbell`/`Range`, "Start" group before "End" group), inner loop over category/point
index, exactly the order `DrawSeries` already iterates in. For each candidate in that
order: compute its background rectangle at the placement above; clamp it into the value
label bounds defined below; if the clamped rectangle intersects
(`TRectF.IntersectsWith`) the rectangle of any label already drawn earlier in this pass,
skip this candidate entirely (it is not drawn, and not shifted further); otherwise draw it
and add its clamped rectangle to the "already drawn" list for the rest of the pass. This is
a first-come-first-served rule over a fixed order, so it needs no randomization or
iteration and always yields the same result for the same input; it is also exactly the rule
`Pie`/`Donut` reuse for segment labels (4.23), in category order. It only considers other
value labels drawn in the same pass, not pre-existing manual annotations, which are drawn
afterward and are the caller's own responsibility to place.

**Value label bounds.** The margin-adjusted chart bounds used by
`TChartLabelPlacer.ClampShift` for
`TextLabel` annotations, narrowed to the plot area on each edge that carries
axis labels: the left edge when the left-edge axis is visible, the bottom edge when the
bottom-edge axis is visible (which edge that is follows `Orientation`, exactly as
`ComputeLeftInset` and `ComputeBottomAxisLabelHeight` already determine it). A value label
therefore never covers an axis break or category label; it is moved inside the plot area
instead. It is never dropped for overlapping an axis label, because an axis label is
secondary furniture and a value label is the subject of the chart. `Pie` and `Donut` have
no axis labels, so no narrowing applies to their segment labels and the plain
margin-adjusted bounds are used.

### 4.13 Series highlighting

No dedicated type. `TChartPlot` carries `property HighlightedSeriesIndex: Integer`,
default `-1` (declared in 4.7), and `SeriesColor` behaves as specified in 4.7: at `-1`
(default) or an out-of-range index, the plain palette resolution applies. Setting
`HighlightedSeriesIndex` fires `OnChanged` like every other mutator.

Because the legend (`BuildSeriesLegendItems`, 4.8) and every series-drawing routine
resolve their color through `SeriesColor`, highlighting needs no other renderer logic:
the muted `ChartLightGrey` and the still-resolved highlighted color both flow through
automatically, to the series' own ink and to its legend swatch alike.

Has no visible effect on `Bar`, `Histogram`, `Dumbbell`, `Range`, `Arrow` (single series
per plot, nothing to contrast against) or `Pie`/`Donut` (exactly one series, many
categories; highlighting one wedge is not part of this capability). Meaningful for `Line`,
`Area`, `GroupedBar`, `StackedBar`, `Scatter`/bubble, `DotPlot`.

### 4.14 Locale-aware number formatting

No dedicated type. `TAxisOptions` carries `LocaleName: string`, default `''` (declared
in 4.5);
`TAxisScale` has the `FormatValue` overload taking a `LocaleName`, and `BuildLabels`
dispatches to it automatically per axis (4.5); `TChartTooltip.Draw` takes a trailing
`LocaleName` parameter, default `''` (4.11).

`LocaleName` is empty by default, so a chart keeps
the fixed English invariant formatting (`.` decimal, `,` thousands) until a caller opts
in; this is deliberate, so test output stays reproducible.
A caller who wants Dutch or German output sets, for example, `Plot.YAxis.LocaleName :=
'nl-NL'`, which affects axis break labels (`BuildLabels`) and, when the hosting control
threads it through to `TChartTooltip.Draw`, the tooltip's value text too. `XAxis.LocaleName`
and `YAxis.LocaleName` are independent; a chart may show an invariant value axis and a
localized date axis (4.16), or vice versa.

### 4.15 Logarithmic value axis

In `Chart4D.Types.pas`:

```pascal
{$SCOPEDENUMS ON}
type
  TAxisScaleKind = (Linear, Logarithmic);
{$SCOPEDENUMS OFF}
```

`TAxisOptions` carries `Scale: TAxisScaleKind` (default `Linear`) and `LogBase: Double`
(default 10), both declared in 4.5. `Linear` is the plain axis described in 4.5 and 4.8;
a logarithmic scale is opt-in per axis.

**Guard.** Before computing the value axis, when `YAxis.Scale = Logarithmic`, every value
that would feed `ComputeRawValueRange` for the plot's `Kind` (4.8) must be strictly greater
than 0; the first value found that is not raises
`EChart4DException.CreateFmt(SLogAxisRequiresPositiveValues, [Value])` (4.2). This mirrors
the existing guard-clause convention (e.g. `BinWidth <= 0`).

**Range and breaks.** For a logarithmic axis, `ApplyHeadroom` (4.8) is skipped entirely;
instead the data range `[DataMin, DataMax]` (after `ComputeRawValueRange`, before any
headroom) is snapped outward to `[LogBase^MinExponent, LogBase^MaxExponent]` where
`MinExponent := Floor(LogN(LogBase, DataMin))` and `MaxExponent :=
Ceil(LogN(LogBase, DataMax))`. `TAxisScale.LogBreaks(MinValue, MaxValue, LogBase)` (4.5)
returns `Power(LogBase, Exponent)` for every integer `Exponent` from `MinExponent` to
`MaxExponent` inclusive; it raises the same `SLogAxisRequiresPositiveValues` guard when
`MinValue <= 0`. Manual `YAxis.MinValue`/`MaxValue`/`Breaks` still override all of this,
applied after the snap, exactly as manual overrides are applied in the linear case.

**Mapping.** `TLinearMapper` itself is unchanged (4.5). The render job builds
`FValueMapper` with `DataMin`/`DataMax` set to the log-space bounds
(`LogN(LogBase, LogBase^MinExponent) = MinExponent`, and likewise `MaxExponent`), and,
wherever it would otherwise call `FValueMapper.Map(Value)` for an actual data value, calls
`FValueMapper.Map(LogN(LogBase, Value))` instead. This is the only change needed to every
series-drawing routine in 4.8: none of their pixel-geometry descriptions change, because
the transform happens once, at the point where a value enters the mapper.

**Baseline and gridlines.** Gridlines are still drawn once per break (now log-spaced,
visually the classic "1, 10, 100, 1000" ladder). The baseline at value 0 (`DrawBaseline`,
4.8) is never drawn for a logarithmic axis: `DrawBaseline`'s existing `IsZeroInRange`
check (`FValueDataMin <= 0`) is already always false once the guard above has passed
(every value, and hence `DataMin`, is `> 0`), so no extra branch is needed there.

**Scope.** Meaningful for any kind with a value axis: `Line`, `Bar`, `GroupedBar`,
`StackedBar`, `Histogram`, `Area`, `Dumbbell`, `Scatter`/bubble, `DotPlot`, `Range`,
`Arrow`. Meaningless for `Pie`/`Donut`, which have no value axis at all (4.23); `YAxis
.Scale` is ignored for those kinds. Not supported together with `DateMode <> None` on the
same axis (4.5).

### 4.16 Date axis

In `Chart4D.Types.pas`:

```pascal
{$SCOPEDENUMS ON}
type
  TAxisDateMode = (None, Auto, Day, Month, Quarter, Year);
{$SCOPEDENUMS OFF}
```

`TAxisOptions` carries `DateMode: TAxisDateMode` (default `None`), declared in 4.5.
`None` keeps the plain numeric X axis, so a date axis is opt-in per axis. X values
are `TDateTime` (`= type Double`) compatible, so no series-level support is needed: a
`Line`/`Area`/`Scatter` series' `XValues` can hold dates as they are; setting `XAxis
.DateMode` only changes how the render job picks breaks and labels for them. Meaningful
only for a continuous X axis (`Line`, `Area`, `Scatter`, 4.19); has no effect on a
category X axis or on `YAxis`.

**`ResolveDateMode(MinValue, MaxValue, Mode)`.** Returns `Mode` unchanged unless `Mode =
Auto`, in which case it picks a concrete mode from the span in days,
`SpanDays := MaxValue - MinValue`, by fixed thresholds: `SpanDays <= 60` &rarr; `Day`;
`<= 730` (about 2 years) &rarr; `Month`; `<= 2920` (about 8 years) &rarr; `Quarter`;
otherwise `Year`. Fixed thresholds, rather than a dynamic search for a break count, keep
the choice a pure function of the span that two implementations compute identically.

**`DateBreaks(MinValue, MaxValue, Mode)`**, `Mode` already resolved (never `Auto`):
breaks are calendar-aligned, using `System.DateUtils`, and, like `NiceBreaks` (4.5), all
lie inside `[MinValue, MaxValue]`.

- `Day`: candidate steps `[1, 2, 5, 7, 14, 30]` days; pick the smallest candidate `>=
  SpanDays / 5` (target ~5 breaks). Breaks start at `Ceil(MinValue)` (the first whole day
  `>= MinValue`) and step forward by the chosen number of days while `<= MaxValue`.
- `Month`: candidate steps `[1, 2, 3, 6, 12]` months; pick the smallest candidate `>=
  MonthsBetween(MaxValue, MinValue) / 5`. Breaks start at the first day of the first
  month whose start is `>= MinValue`, stepping forward with `IncMonth` by the chosen
  number of months while `<= MaxValue`.
- `Quarter`: candidate steps `[1, 2, 4, 8]` quarters (1 quarter = 3 months); pick the
  smallest candidate `>= (MonthsBetween(MaxValue, MinValue) / 3) / 5`. Breaks start at the
  first day of the first calendar quarter (`Month in [1, 4, 7, 10]`) whose start is `>=
  MinValue`, stepping by `3 * chosen-quarters` months while `<= MaxValue`.
- `Year`: step chosen the same way `NiceStep` (4.5) picks a linear step, applied to the
  year count instead of a raw value (`RawStep := YearsBetween(MaxValue, MinValue) / 4`,
  rounded up to the nearest of `1, 2, 5, 10, 20, 50, 100` using the same `< 1.5 &rarr; 1`,
  `< 3 &rarr; 2`, `< 7 &rarr; 5`, else `&rarr; 10`-times-magnitude table). Breaks start at
  `EncodeDate(FirstYear, 1, 1)` for the first year `>= MinValue`, stepping by the chosen
  number of years while `<= MaxValue`.

**`FormatDateValue(Value, Mode, LocaleName = '')`**, `Mode` already resolved: `Day` &rarr;
`'d MMM'`; `Month` &rarr; `'MMM yyyy'`; `Quarter` &rarr; `'Q' + IntToStr(Quarter) + ' ' +
IntToStr(Year)` (no native `FormatDateTime` quarter token); `Year` &rarr; `'yyyy'`; all via
`FormatDateTime` with `TFormatSettings.Invariant` when `LocaleName = ''`, otherwise
`TFormatSettings.Create(LocaleName)` (4.14).

**Integration.** In `ComputeContinuousXAxis` (4.8), when `XAxis.Breaks` is empty and
`XAxis.DateMode <> None`: resolve the mode once, from the data range, with
`ResolveDateMode`, then use
`DateBreaks`/`FormatDateValue` in place of `NiceBreaks`/`BuildLabels` for `FXBreaks`/
`FXBreakLabels`. That one resolved mode drives both break placement and label
formatting (4.5); the mode is never re-resolved from the break span, so labels always
match the granularity the breaks were placed at.
`UseThousandSeparator`/`LabelSuffix` are ignored. Manual `XAxis.Breaks`/
`BreakLabels` still win entirely, exactly as they do for the numeric case.

### 4.17 Uncertainty and range bands

No dedicated type. `TChartSeries` carries `IsRangeBand: Boolean`, default `False` (4.4);
`TChartPlot` has `AddRangeBandSeries` (4.7). `False` keeps the plain `Line`/`Area`
rendering, so a band is opt-in per series.

A band series is meaningful only when the plot's `Kind` is `Line` or `Area`; on any other
kind `IsRangeBand` has no rendering effect (its rendering path never reads it), the same
scoping convention `EndValues` already uses for `Dumbbell`.

**Drawing.** Within `TLineSeriesRenderer`/`TAreaSeriesRenderer` (4.8), series are partitioned and
drawn in two passes, in series-list order within each pass: first every series with
`IsRangeBand = True`, then every series with `IsRangeBand = False`.
This partition, not raw list order, guarantees a band always renders behind any ordinary
line/area series, regardless of the order the caller added them in. For a band series: no
polyline and no hit targets are added the way an ordinary series' points are; instead, a
single filled polygon is drawn from the "low" points (`SeriesLinePoints` using `Values`)
forward and the "high" points (`SeriesLinePoints` using `EndValues`) backward, closing the
loop, filled with `SeriesColor(Index)` exactly as resolved, with no forced alpha (a
translucent band requires the caller to give the series a `Color` with a non-`$FF` alpha
channel, e.g. `$30107090`, the same convention as 4.18's overlay). No polyline is drawn on
top; a caller wanting a visible central line adds an ordinary `Line` series over the band.

**Hit targets.** Two circular targets per point (radius 12, matching `Line`'s own target
radius), at the low and high pixel positions, each reporting its own bound as `Value`,
and the same `SeriesName` and `CategoryLabel` (the formatted X value, or date label per
4.16) for both, so hovering the low edge of the band shows the low bound and hovering the
high edge shows the high bound.

**Validation.** When a band series' `EndValues` length does not match its `Values`
length, `EChart4DException.CreateFmt(SBandValueCountMismatch, [Series.Name, Length
(Values), Length(EndValues)])` (4.2), checked alongside the existing X/Y length guard for
`Line`/`Area` series (`ValidateLineSeriesLength`, 4.8).

### 4.18 Shaded range overlay

No dedicated type. `TAnnotationKind` has `HorizontalRangeOverlay`/`VerticalRangeOverlay`
(4.1); `TChartPlot` has `AddHorizontalRangeOverlay`/`AddVerticalRangeOverlay` (4.7).

**Geometry.** `HorizontalRangeOverlay` uses `Y` (low bound) and `Y2` (high bound), `X`/
`X2` unused; it is a filled rectangle between `FValueMapper.Map(Y)` and
`FValueMapper.Map(Y2)`, spanning `FPlotBounds.Left` to `.Right` when `Orientation =
Vertical`, or `.Top` to `.Bottom` when `Horizontal` (the same axis-swap `DrawHorizontal
LineAnnotation` already applies to a single value). `VerticalRangeOverlay` uses `X`/`X2`
(low/high bound on the category or continuous-X axis, via `CategoryAxisPixel`,
4.8) the same way `DrawVerticalLineAnnotation` maps a single `X`, spanning the full
perpendicular plot dimension. Both fill with `Annotation.Color` exactly as given (no
forced alpha; see 4.7's behavior note on these two methods).

**Draw order.** Both kinds are drawn as part of a `DrawRangeOverlays` step that runs
immediately after `DrawAxisLabels` and before `DrawGrid` (4.8), so the overlay sits behind
the gridlines, the baseline, and every series, matching the "zone marking behind the
series" intent of the kind. `DrawAnnotation`'s kind dispatch (4.8) excludes
these two kinds when the main annotation pass runs later, since they are already drawn.

**No hit map.** Unlike every other drawing path in this document, a range overlay
adds nothing to the hit map: it is background decoration, not a data point, so there is
nothing meaningful to report on hover; a tooltip on a background wash would be surprising
rather than useful. This is a deliberate, explicit exception to the general "every new
drawing path needs hit-map targets" rule.

### 4.19 Scatter and bubble

`TChartKind` includes `Scatter` (4.1). `TChartSeries` carries `Sizes: TArray<Double>`,
default empty (4.4). `TChartStyle` carries `ScatterPointRadius` (4), `MinBubbleRadius` (4),
and `MaxBubbleRadius` (24) (4.3). No dedicated `TChartPlot` method: a scatter series is an ordinary
`AddLineSeries` call (`Plot.Kind := TChartKind.Scatter;` set by the caller first, matching
the existing convention that `AddLineSeries` never sets `Kind` itself), with `Sizes`
optionally set afterward on the returned series to turn it into a bubble series.

A `Scatter` series reuses `SeriesLinePoints`/`EffectiveXValues` exactly as `Line` does
(4.8): `TChartKindTraits.UsesContinuousX` includes `Scatter` (4.1), and
`ComputeRawValueRange` gives it the
`Line`-like `ComputeSimpleValueRange(False)` branch (no forced 0),
since `Scatter` is not among the kinds that force 0. It also gets headroom below the
data minimum whenever `YAxis.MinValue` is automatic, exactly like `Line` (4.8), since a
scatter point marks a position rather than a length from a baseline the same way a line
point does. Drawing: for each point, one `FillCircle` at `XYPoint(XValues[i], Values[i])`;
no `DrawPolyline`.

**Bubble radius.** When a series' `Sizes` is empty, every point of that series draws at
the fixed `ScatterPointRadius`. When non-empty, radius is area-proportional (`Sqrt`
scaling, the perceptually correct convention for a size encoding), over a domain shared
across the whole plot for a fair comparison between series:
`MinSize`/`MaxSize` are the minimum/maximum of every value in every series' `Sizes` in the
plot (series without `Sizes` do not participate in this domain). For a point with size
`S`: `Radius := MinBubbleRadius + (MaxBubbleRadius - MinBubbleRadius) * Sqrt((S - MinSize)
/ (MaxSize - MinSize))`; when `MaxSize = MinSize` (degenerate, every sized point equal),
`Radius := (MinBubbleRadius + MaxBubbleRadius) / 2` for all of them, avoiding division by
zero, the same guard style `NiceBreaks` already uses for a degenerate value range (4.5).

**Hit targets.** One circular target per point, matching `Line`'s continuous-X
convention (`CategoryLabel` = formatted X value, or date label per 4.16) exactly,
except the radius is `Max(DrawnRadius, 12 * ScaleFactor)`, so a small or plain scatter
point still has at least the usual hoverable radius, while a large bubble is hoverable
across its full visible extent.

**Validation.** When a series' `Sizes` is non-empty and its length does not match
`Values`, `EChart4DException.CreateFmt(SSeriesSizeCountMismatch, [Series.Name, Length
(Values), Length(Sizes)])` (4.2), checked alongside the existing X/Y length guard.

### 4.20 Dot plot

`TChartKind` includes `DotPlot` (4.1). No dedicated `TChartSeries` or `TChartPlot` member: a dot
plot is `Categories` plus one or more ordinary `AddSeries`/`AddSeries(Name, Values)`
calls, exactly like `Bar`/`GroupedBar`, distinguished only by `Kind`; validated the same
way (`ValidateCategorySeries`, the same bucket `Bar`/`GroupedBar`/`StackedBar`/`Histogram`
fall into, 4.8).

Honors whichever `Orientation` is set (default `Vertical`), unlike `Dumbbell`, which
forces `Horizontal`; a dot plot does not need a fixed orientation to be readable.

Like `Scatter` (4.19) and `Dumbbell`, `DotPlot` never forces 0 into the value range (not
listed among the kinds that do, 4.8), which is the classic advantage of a dot plot over a bar
chart is exactly that its axis need not start at 0. It also gets headroom below the data
minimum whenever `YAxis.MinValue` is automatic (4.8), so the lowest dot does not land on the
plot boundary and collide with its own category label.

**Drawing.** For each series `j` and category `i`, one `FillCircle` at
`CategoryValuePoint(CategoryCenter(i), Values[j][i])`, radius `ScatterPointRadius` (the
same style field as 4.19, reused rather than duplicated). Multiple series at the same
category draw at the exact same category-center pixel, with no per-series dodge offset
(unlike `GroupedBar`), so they land "on the same row"; they are
distinguished only by color, and may visually overlap when their values coincide.

**Hit targets.** One circular target per series/category, matching `Bar`'s
`TChartHitMap.BuildInfo` fields (`SeriesIndex`, `SeriesName`, `CategoryLabel`, `Value`, `Color`)
exactly, radius `Max(ScatterPointRadius, 12 * ScaleFactor)` (the same minimum-hoverable-
size rule as 4.19).

Legend: `BuildSeriesLegendItems` (one item per named series) covers a
multi-series dot plot with no dot-plot-specific logic.

### 4.21 Range plot

`TChartKind` includes `Range` (4.1). `TChartPlot.AddRangeSeries(Name, LowValues, HighValues)`
(4.7): replaces all series with one named series, `Values := LowValues`, `EndValues :=
HighValues`, sets `Kind := Range` and `Orientation := Horizontal`, exactly like
`AddDumbbellSeries` except it also takes a `Name` and sets a different `Kind`.

Value range and headroom: computed exactly like `Dumbbell` (min/max across `Values` and
`EndValues`, no forced 0, headroom below the minimum when `YAxis.MinValue` is automatic;
4.8). Validated exactly like `Dumbbell`
(`Length(Values) = Length(EndValues)`, both matching `Categories` length), except the
count mismatch raises `EChart4DException.CreateFmt(SPairedValueCountMismatch,
['Range', Length(Values), Length(EndValues)])` (4.2). Every kind that reads `EndValues`
shares that one message, with its own name as the first format argument, which matches
`Dumbbell`'s wording exactly.

**Drawing.** One filled rectangle per category, from `Values[i]` to `EndValues[i]`, width
`0.7 * band` (the same width factor as `Bar`), in `SeriesColor(0)`, giving a solid "range
bar" rather than `Dumbbell`'s dots-and-connector.

**Hit targets.** One rectangular target per category (like `Bar`'s own target, not
`Dumbbell`'s two circles), spanning the same rectangle that was filled; `Info.Value :=
EndValues[i]` (the high bound), the same convention `StackedBar` already uses of reporting
a segment's own raw value rather than a derived one. `Info.SeriesName` is the series'
`Name` (may be non-empty, unlike `Dumbbell`'s hardcoded `''`).

### 4.22 Arrow plot

`TChartKind` includes `Arrow` (4.1). `TChartPlot.AddArrowSeries(Name, StartValues,
EndValues)` (4.7): replaces all series with one named series, `Values := StartValues`,
`EndValues := EndValues`, sets `Kind := Arrow` and `Orientation := Horizontal`, the same
shape as `AddRangeSeries` (4.21).

Value range, headroom, and validation: identical to `Range` (4.21), including reusing
`SPairedValueCountMismatch` with `'Arrow'` as the first format argument instead of
`'Range'`.

**Drawing.** One line with an arrowhead per category, from
`CategoryValuePoint(CategoryCenter(i), Values[i])` to
`CategoryValuePoint(CategoryCenter(i), EndValues[i])`, stroke width `SeriesLineWidth`,
color `SeriesColor(0)`, arrowhead drawn with the shared `TChartArrowPainter` helper
(4.8, already used for `Arrow`-kind annotations) unchanged.

The shaft stops where the two wings meet the line, at `ArrowHeadLength * Cos(25°)` back
from the tip, and not at the tip itself: a stroke drawn all the way to the apex sticks out
past the point by half its width, so the arrow appears to overshoot its own value. The
same applies to `Arrow` annotations (4.1), which share the helper. When the whole arrow is
shorter than that distance only the head is drawn.

**Hit targets.** Two circular targets per category (radius 12, matching `Dumbbell`'s
convention), at the start and end pixel positions, `Info.Color := SeriesColor(0)` for
both (unlike `Dumbbell`'s two fixed distinct colors, since visually this is one directional
arrow, not two independently colored ends), `Info.Value` the respective bound,
`Info.SeriesName` the series' `Name` for both.

### 4.23 Pie chart

`TChartKind` includes `Pie` (4.1). No dedicated `TChartSeries`/`TChartPlot` method: a pie chart is
`Categories` plus exactly one `AddSeries`/`AddSeries(Name, Values)` call.

**Validation.** `Plot.Series.Count <> 1` raises `EChart4DException.CreateFmt
(SPieRequiresSingleSeries, [Plot.Series.Count])` (4.2). Any value `< 0` raises
`EChart4DException.CreateFmt(SPieValuesMustBeNonNegative, [Value])`. When every value is
0 (including an empty series), every wedge has a sweep angle of 0 and nothing is drawn (no
exception), the same degenerate-total handling `SegmentValue` applies to a
zero-total stacked category (4.8): a data edge case, not a programming error, is not an
exception.

**Layout.** `Execute` (4.8) branches on `Kind in [Pie, Donut]` before its usual sequence:
`ValidateInput`, then a pie-specific layout (title/subtitle/legend exactly as in
`PerformLayout`, 4.8, but with insets always 0, per 4.8), then wedges and
segment labels, then `DrawAnnotations` (still supported: a caller may still add e.g. a
`TextLabel`), then `DrawFooter`. `ComputeValueAxis`, `ComputeCategoryAxis`,
`DrawAxisLabels`, `DrawGrid`, and `DrawValueLabels` (4.12) are not called at all for these
two kinds: there is no value axis, no category axis, no gridlines, and no baseline to
compute or draw for a shape with no axes. With no axes to define a data space,
`ComputeCircularAnnotationSpace` gives annotations a coordinate space of their own (4.1):
X is the 0-based category index, exactly as on a category chart, and Y is a fraction of
the plot height, 0 at the bottom edge and 1 at the top, so `(1, 0.5)` on a three-category
pie is the center of the plot rectangle.

**Geometry.** Center is the center of the plot rectangle (the content rect after title/
subtitle/legend/footer layout, with 0 insets). Outer radius is
`Min(PlotBounds.Width, PlotBounds.Height) / 2`. Wedges are drawn in category order,
starting at 12 o'clock and proceeding clockwise (screen-angle convention, 0&deg; at 3
o'clock, increasing clockwise, matching the existing `ArcTan2`-based convention already
used by `TChartArrowPainter`, 4.8): category `i`'s sweep angle is `360 * Values[i] / Total`
degrees; its start angle is `-90 + 360 * (sum of Values[0..i-1]) / Total` degrees, where
`Total` is the sum of every value.

Each wedge is drawn as a `FillPolygon` (`IChartCanvas` has no arc/sector primitive, and
none is added; a polygon approximation needs none, the same reasoning that already lets
`TChartArrowPainter` uses a plain triangle): the point list is `[Center] + ArcPoints(OuterRadius,
StartAngle, SweepAngle, SegmentCount)`, where `ArcPoints` samples the arc at `SegmentCount
+ 1` evenly spaced angles from `StartAngle` to `StartAngle + SweepAngle` inclusive, and
`SegmentCount := Max(2, Ceil(SweepAngle / 6))` (one segment per 6 degrees of sweep,
minimum 2, so even a very thin wedge is still a closed polygon). `FillPolygon` closes the
last point back to the first, back to `Center`.

**Segment labels**, drawn unconditionally (not gated by `ValueLabels`, 4.12, which has no
effect on `Pie`/`Donut`): for each wedge with a non-zero sweep angle, at the wedge's
mid-angle (`StartAngle + SweepAngle / 2`) and `0.65 * OuterRadius` from center, text
`Format('%s (%d%%)', [Categories[i], Round(100 * Values[i] / Total)])`, with the same
white background box as a value label (4.12), and the exact same deterministic
overlap-avoidance rule from 4.12 (fixed order = category order; skip a candidate whose
clamped box intersects an already-drawn one).

**Legend.** One item per category (`BuildCategoryLegendItems`, 4.8):
`Categories[i]`/`CategoryColor(i)` (4.7), since wedge color comes from the category
index, not a series index (there is exactly one series).

**Hit targets.** Circular sectors do not fit the existing `Bounds`-rectangle or `Center`+
`Radius`-circle shapes, so `TChartHitTarget` (4.11) carries sector fields:

```pascal
TChartHitTarget = record
  Bounds: TRectF;
  Center: TPointF;
  Radius: Single;
  Info: TChartHitInfo;
  IsSector: Boolean;      // when True, hit-testing uses the four fields below
  InnerRadius: Single;
  OuterRadius: Single;
  StartAngle: Single;     // degrees, same clockwise convention as above
  SweepAngle: Single;     // degrees
end;
```

These fields default to `False`/`0` via the `Default(TChartHitTarget)` pattern
used everywhere a target is built, so a plain `Bounds`/`Center`/`Radius`
target never carries stray sector data. One sector target per wedge: `Center`, `InnerRadius := 0`,
`OuterRadius`, `StartAngle`, `SweepAngle` as computed above; `Info.SeriesName := ''`,
`Info.CategoryLabel := Categories[i]`, `Info.Value := Values[i]`, `Info.Color :=
CategoryColor(i)`, and `Info.AnchorX`/`AnchorY` set to the same mid-angle,
`(InnerRadius + OuterRadius) / 2`-from-center point used for the segment label, so
`TChartTooltip.Draw`'s existing highlight-circle code (4.11) needs no change.

`TChartTooltip`'s private `TargetContainsPoint` (4.11) has a sector branch, checked
before the circular/rectangular ones: when `Target.IsSector`, compute `Distance
:= Point.Distance(Target.Center)`; the point is inside when `Distance` is between
`InnerRadius` and `OuterRadius` inclusive, and the point's own angle from `Center`
(`RadToDeg(ArcTan2(...))`, normalized to `[0, 360)`, same convention as above) falls
within `[StartAngle, StartAngle + SweepAngle)`, also normalized to handle the 0/360
wraparound. `Distance` is still reported as `Point.Distance(Target.Center)`, the same
convention the existing rectangular branch already uses (distance to the target's center,
not to its nearest edge), so `FindTarget`'s closest-wins tie-break is unaffected.

### 4.24 Donut chart

`TChartKind` includes `Donut` (4.1). `TChartStyle` carries `DonutInnerRadiusFactor: Single`,
default 0.6 (4.3). `TChartPlot` carries `DonutCenterText: string`, default `''` (4.7),
meaningful only when `Kind = Donut`.

Identical to `Pie` (4.23) in every respect (validation, layout branch, wedge angles,
legend, hit-testing) except:

- `InnerRadius := OuterRadius * DonutInnerRadiusFactor`, both in the wedge's `FillPolygon`
  geometry and in its `TChartHitTarget`. The wedge polygon becomes an annular sector: the
  point list is the forward outer arc followed by the reverse inner arc
  (`ArcPoints(OuterRadius, StartAngle, SweepAngle, SegmentCount) + ReverseArcPoints
  (InnerRadius, StartAngle, SweepAngle, SegmentCount)`), with no `Center` point, since the
  hole means the wedge never reaches the center.
- Segment labels (4.23) sit at `(InnerRadius + OuterRadius) / 2` from center instead of
  `0.65 * OuterRadius`, so they stay centered within the visible ring rather than falling
  inside the hole.
- When `DonutCenterText <> ''`, it is drawn centered (horizontally and vertically) in the
  hole, in `TitleFontSize`/`TitleColor`, not bold (unlike the chart `Title`, so it reads as
  a secondary annotation inside the ring rather than competing with the chart's own title),
  after the wedges and their labels and before `DrawAnnotations`; the caller is responsible
  for formatting it (e.g. `'Total: 1,234'`), the same plain-string convention
  `Source`/`Title`/`Subtitle` already use elsewhere in this library.

## 5. Tests (Tests\, DUnitX)

Console project `Chart4D.Tests.dpr` + `build.bat` (dcc32; the RAD Studio location is
read from the `BDS` environment variable, defaulting to
`c:\program files (x86)\embarcadero\studio\37.0` when unset). Fixtures:

- `Chart4D.Axis.Tests.pas`: the three NiceBreaks examples from 4.5, plus degenerate
  range and negative ranges; FormatValue (thousand separators, decimals, `5.0 → '5'`);
  BuildLabels (suffix on last only, suffix on all, manual BreakLabels win).
- `Chart4D.Mapper.Tests.pas`: Map endpoints, midpoint, inverted mapping.
- `Chart4D.Plot.Tests.pas`: auto palette via SeriesColor (wraps after 6), owned series
  lifecycle, OnChanged fired, guard exceptions (BinWidth <= 0).
- `Chart4D.Histogram.Tests.pas`: binning per 4.7 including empty middle bins and
  category labels.
- `Chart4D.Renderer.Tests.pas`: a `TRecordingCanvas` (records every call) verifying: a
  line chart renders without exception and produces background + title text + one
  polyline per series + gridlines; a bar chart produces one FillRect per category; a
  stacked proportions chart maps the top of each stack to the same pixel; legend drawn
  only when more than one named series; footer separator/source drawn only when Source
  is set; mismatched category/value lengths raise `EChart4DException`.
- `Chart4D.Style.Tests.pas`: `TChartStyle.Default` values per section 3.
- `Chart4D.Invariants.Tests.pas`: boundary and ink invariants for `TChartRenderer`,
  reasoning geometrically over a `TRecordingCanvas` for every chart kind: no recorded
  call may draw outside the bitmap, none may land inside the outer margin (other than
  the footer separator, which spans it by design), and every resolved series color must
  actually appear in the output.
- `Chart4D.Tooltip.Tests.pas`: the hit map contains one target per data point for a
  line chart and one per bar for a bar chart; `FindTarget` picks the nearest circular
  target within its radius and returns False outside every target; `Draw` produces a
  FillRect (box), a FillCircle (highlight) and text calls on a recording canvas; the
  tooltip box stays inside the chart bounds for anchors near every edge; the
  `LocaleName` overload of `Draw` formats `Info.Value` with that locale (4.14); a
  sector target (4.23) is found by `FindTarget` when the point falls between its inner
  and outer radius and within its angular span, including a case straddling the 0/360
  wraparound, and misses when outside either bound.
- `Chart4D.Axis.Tests.pas` also covers: the `LocaleName` overload of `FormatValue` against at
  least one non-invariant locale, and that the 2-argument overload's output is unchanged
  (4.14); `LogBreaks` against a known span (e.g. `LogBreaks(5, 3000, 10) =
  [1, 10, 100, 1000, 10000]` snapped to bounding powers) and its guard exception for
  `MinValue <= 0` (4.15); `ResolveDateMode` at each threshold boundary and `DateBreaks`/
  `FormatDateValue` for one fixture span per mode (`Day`, `Month`, `Quarter`, `Year`)
  (4.16).
- `Chart4D.Plot.Tests.pas` also covers: `SeriesColor` returns `ChartLightGrey` for every
  index except `HighlightedSeriesIndex`, and is unchanged at `-1` (4.13); `AddRangeSeries`/
  `AddArrowSeries` set `Kind`/`Orientation`/`Values`/`EndValues` like `AddDumbbellSeries`;
  `AddRangeBandSeries` appends (does not clear) and sets `IsRangeBand`; `CategoryColor`
  cycles the palette by category index (4.7).
- `Chart4D.Renderer.Tests.pas` also covers, each against a `TRecordingCanvas`: a logarithmic
  axis renders breaks at powers of the base and raises `EChart4DException` for a
  non-positive value (4.15); a date axis with `DateMode = Auto` picks the expected
  granularity for a known span (4.16); a range-band series draws its shaded polygon
  before an ordinary series added earlier, and produces two circular hit targets per
  point (4.17); a `HorizontalRangeOverlay`/`VerticalRangeOverlay` annotation draws before
  the first gridline and adds nothing to the hit map (4.18); a `Scatter` series with
  `Sizes` produces circles whose radii follow the `Sqrt`-scaling formula between
  `MinBubbleRadius` and `MaxBubbleRadius`, and raises `EChart4DException` on a `Sizes`/
  `Values` length mismatch (4.19); a `DotPlot` with two series draws both series' dots at
  the same category-center pixel (4.20); a `Range` chart produces one rectangular hit
  target per category reporting the high bound (4.21); an `Arrow` chart draws a line and
  reuses `TChartArrowPainter`'s triangle shape, with two circular hit targets per
  category (4.22); a `Pie` chart's wedge sweep angles sum to 360 degrees and each wedge's
  polygon points lie within `[0, OuterRadius]` of the computed center, a wedge is
  findable by `TChartTooltip.FindTarget` via its sector target, and a negative value or a
  second series raises `EChart4DException` (4.23); a `Donut` chart's wedge points all lie
  within `[InnerRadius, OuterRadius]` of the center and `DonutCenterText` produces a text
  call at the center (4.24); this fixture follows the same "reason geometrically over
  recorded calls" style as `Chart4D.Invariants.Tests.pas`, needing no rasterisation
  or baseline image.
- `Chart4D.ValueLabels.Tests.pas`: for each of `All`/`FirstAndLast`/`Extremes`, the
  expected candidate set per chart kind and group (4.12), including the tie-break rule for
  `Extremes`; two labels whose clamped boxes would intersect are drawn in the fixed
  series-then-index order, with only the first one actually drawn; a label placement per
  kind (`Line`, `Bar`, `Dumbbell`, `Arrow`) matches the offsets specified in 4.12.

- `Chart4D.Catalog.Tests.pas`: for the shared demo catalogue
  (`Examples\Common\Chart4DDemo.Catalog.pas`, 7), the numbers and names parsed back out of
  an example's displayed `Code` fragment match the data its `Build` procedure hands to the
  plot (`Line`, `GroupedBar`, `RangePlot`, `Pie`), and every example's heading matches its
  build data. The code shown beside a chart in the demos therefore cannot drift from the
  chart it claims to produce.

Tests use no `initialization` sections: fixtures carry the `[TestFixture]` attribute and
are discovered through RTTI. Test names are underscore-separated and read as the subject
under test, the condition it is put under, and the expected outcome
(`NiceBreaks_DegenerateRange_TreatsRangeAsPlusMinusOne`), with the middle part left out
where there is no distinct condition (`SetHistogramData_SetsChartKindToHistogram`).

## 6. Build

`Build.bat` at the repo root: `call rsvars.bat` from the RAD Studio installation named
by the `BDS` environment variable (defaulting to
`c:\program files (x86)\embarcadero\studio\37.0` when unset, so another installation is
a matter of setting `BDS` before the call), then `msbuild` each
package dproj (Release/Win32), then build and run the tests via `Tests\build.bat`, then
build both demos with dcc32. Everything must compile with zero hints and warnings.

## 7. Demos (Examples\)

Each demo creates its main form in code (`TForm.CreateNew`, no DFM), shows a sample
switcher (a combo box over the shared catalogue in
`Examples\Common\Chart4DDemo.Catalog.pas`) that rebuilds the plot for the selected
sample, displays the explanation and the code fragment that produces the chart beside
it, and has an
"Export PNG" button calling `SaveToPng` with `Source` set to
demonstrate the publication footer. Demo data: published real-world figures, World Bank
World Development Indicators for most samples, the electricity mix from Ember via Our
World in Data, and the temperature series from Met Office Hadley Centre HadCRUT5, each
credited in its chart's `Source` footer.

## 8. Source conventions

**Dependencies.** Chart4D is zero-dependency: the RTL, plus VCL or FMX for the adapter
units, and nothing else. `System.Generics.Collections` (`TObjectList<T>`, `TList<T>`) and
dynamic arrays (`TArray<T>`) are the collection types of this project. The framework
layering rules are in section 2.

**File header.** Every source file starts with the Embarcadero-style header:

```pascal
{*******************************************************}
{                                                       }
{       Chart4D Library - Editorial data charts         }
{                                                       }
{          Copyright(c) 2026 GDK Software               }
{                All rights reserved                    }
{                                                       }
{             Licensed under MIT License                }
{                                                       }
{*******************************************************}
```

**Documentation comments.** Every public member carries an XML documentation comment
(`/// <summary>`), and every unit carries a unit-level `/// <summary>` describing what it
is for. Test methods are not public API and are exempt; a test unit still carries the file
header and a unit-level summary describing what it tests.

**Comments in implementation code.** These should be rare: code is expected to explain
itself through naming and structure. What a comment is for is recording a reason the code
cannot show on its own, for example why a constant has this value, why steps run in this
order, or why a test fixture deliberately avoids a particular value. A comment that
restates what the next line does, or that narrates what changed or used to be there, has
no place; if you can delete a comment and lose no reason, delete it.

**Language.** All public API, identifiers, error messages, and documentation are in
English.

**Enumerations.** `{$SCOPEDENUMS ON}` in every unit that declares an enum; enum values
carry no prefix.

**Compiler output.** The library, the tests, the demos and the tools all compile with zero
hints and zero warnings, and the test suite stays green. `Build.bat` builds and runs all of
it in one go.
