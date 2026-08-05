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
unit Chart4D.Types;

/// <summary>
/// Core enumerations, the annotation record, and the base exception type shared by
/// every Chart4D unit. RTL-only: no VCL or FMX dependencies.
/// </summary>

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes;

{$SCOPEDENUMS ON}
type
  /// <summary>
  /// The kind of chart a <c>TChartPlot</c> renders. <c>Scatter</c>, <c>DotPlot</c>,
  /// <c>Range</c>, <c>Arrow</c>, <c>Pie</c> and <c>Donut</c> follow <c>Area</c>: a kind is
  /// only ever appended, so the ordinal of an existing one never shifts. A <c>Scatter</c> series
  /// with a non-empty <c>Sizes</c> array (<c>TChartSeries</c>) is a bubble series; bubble
  /// charts are not a separate kind. <c>Pie</c> and <c>Donut</c> have no axes at all: they
  /// draw exactly one series as wedges of a circle, colored and labelled by category.
  /// </summary>
  TChartKind = (Line, Bar, GroupedBar, StackedBar, Dumbbell, Histogram, Area, Scatter, DotPlot, Range, Arrow, Pie, Donut);

  /// <summary>
  /// The direction in which categories run across the plot area.
  /// </summary>
  TChartOrientation = (Vertical, Horizontal);

  /// <summary>
  /// How a stacked bar chart combines its series values per category.
  /// </summary>
  TStackMode = (Values, Proportions);

  /// <summary>
  /// Where the legend is drawn relative to the plot area, or <c>None</c> to hide it.
  /// </summary>
  TLegendPosition = (None, Top, Right, Bottom, Left);

  /// <summary>
  /// The kind of annotation drawn relative to a chart's series. Most kinds draw on top
  /// of the series; <c>HorizontalRangeOverlay</c> and <c>VerticalRangeOverlay</c> draw
  /// behind the grid and every series instead, as a shaded background zone.
  /// </summary>
  TAnnotationKind = (TextLabel, Segment, Arrow, HorizontalLine, VerticalLine,
                     HorizontalRangeOverlay, VerticalRangeOverlay);

  /// <summary>
  /// Horizontal text alignment relative to an anchor point.
  /// </summary>
  TTextAlignH = (Left, Center, Right);

  /// <summary>
  /// Vertical text alignment relative to an anchor point.
  /// </summary>
  TTextAlignV = (Top, Middle, Bottom);

  /// <summary>
  /// Which data points a chart draws a built-in value label for. Default <c>None</c>.
  /// </summary>
  TValueLabelMode = (None, All, FirstAndLast, Extremes);

  /// <summary>
  /// The kind of scale a value axis maps data through. Default <c>Linear</c>.
  /// </summary>
  TAxisScaleKind = (Linear, Logarithmic);

  /// <summary>
  /// The calendar granularity a continuous X axis picks breaks and labels at.
  /// <c>Auto</c> resolves to a concrete mode from the data span; <c>None</c> keeps the
  /// axis plain-numeric. Default <c>None</c>.
  /// </summary>
  TAxisDateMode = (None, Auto, Day, Month, Quarter, Year);

  /// <summary>
  /// A single annotation drawn on top of a chart's series: a text label, a segment,
  /// an arrow, or a full-width horizontal/vertical reference line.
  /// </summary>
  /// <remarks>
  /// Coordinates are in data space. For category charts the category axis coordinate
  /// is the 0-based category index expressed as <c>Double</c>. A <c>FontSize</c> or
  /// <c>LineWidth</c> value of 0 means "use the style default". <c>TextLabel</c>
  /// annotations are drawn with a white background rectangle behind the text so they
  /// stay readable on top of series. <c>HorizontalRangeOverlay</c>/<c>VerticalRangeOverlay</c>
  /// reuse <c>Y</c>/<c>Y2</c> or <c>X</c>/<c>X2</c> as the low/high bound of a filled band
  /// spanning the full plot area.
  /// </remarks>
  TChartAnnotation = record
    /// <summary>The annotation kind, which determines how the other fields are used.</summary>
    Kind: TAnnotationKind;
    /// <summary>Primary X coordinate in data space.</summary>
    X: Double;
    /// <summary>Primary Y coordinate in data space.</summary>
    Y: Double;
    /// <summary>Secondary X coordinate in data space, used by <c>Segment</c> and <c>Arrow</c>.</summary>
    X2: Double;
    /// <summary>Secondary Y coordinate in data space, used by <c>Segment</c> and <c>Arrow</c>.</summary>
    Y2: Double;
    /// <summary>The label text, used by <c>TextLabel</c>.</summary>
    Text: string;
    /// <summary>The annotation color.</summary>
    Color: TAlphaColor;
    /// <summary>The label font size, or 0 to use the style default.</summary>
    FontSize: Single;
    /// <summary>The line width, or 0 to use the style default.</summary>
    LineWidth: Single;
    /// <summary>Whether the line is drawn dashed.</summary>
    Dashed: Boolean;
    /// <summary>Horizontal alignment of the label text.</summary>
    AlignH: TTextAlignH;
  end;

  /// <summary>
  /// Base exception raised by Chart4D for invalid input and rendering errors.
  /// </summary>
  EChart4DException = class(Exception);
{$SCOPEDENUMS OFF}

  /// <summary>
  /// The facts about a <c>TChartKind</c> that more than one part of the library has to
  /// agree on: whether it is drawn as a circle, whether its category axis is continuous,
  /// whether it reads <c>TChartSeries.EndValues</c>, and how its value axis treats zero.
  /// </summary>
  /// <remarks>
  /// Every one of these used to be an inline <c>Kind in [...]</c> set repeated at each
  /// site that needed it, which meant a new chart kind had to be remembered in each of
  /// them separately. Adding a kind now means revisiting this one type, and nothing
  /// silently keeps the default answer somewhere else.
  /// </remarks>
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

  /// <summary>
  /// The result of a hover hit-test against a chart's hit map: which data point, if
  /// any, is under the pointer, and the information needed to draw a tooltip for it.
  /// </summary>
  TChartHitInfo = record
    /// <summary>Whether the hit-test found a target under the pointer.</summary>
    HasHit: Boolean;
    /// <summary>The index of the series the hit target belongs to.</summary>
    SeriesIndex: Integer;
    /// <summary>The index of the data point within the series.</summary>
    PointIndex: Integer;
    /// <summary>The series name, or empty when the series has no name.</summary>
    SeriesName: string;
    /// <summary>The category label, or the formatted X value for <c>Line</c>/<c>Area</c>.</summary>
    CategoryLabel: string;
    /// <summary>The data value of the hit point.</summary>
    Value: Double;
    /// <summary>The pixel X coordinate of the data point's anchor.</summary>
    AnchorX: Single;
    /// <summary>The pixel Y coordinate of the data point's anchor.</summary>
    AnchorY: Single;
    /// <summary>The resolved series color.</summary>
    Color: TAlphaColor;
  end;

  /// <summary>
  /// A single hoverable region of a rendered chart: a data point drawn either as a
  /// circular target (line points, dumbbell dots), a rectangular one (bars, stack
  /// segments, histogram bins), or, when <c>IsSector</c> is <c>True</c>, an annular
  /// sector (a <c>Pie</c>/<c>Donut</c> wedge).
  /// </summary>
  TChartHitTarget = record
    /// <summary>The hit rectangle, used when <c>Radius</c> is 0 and <c>IsSector</c> is <c>False</c>.</summary>
    Bounds: TRectF;
    /// <summary>The hit center, used when <c>Radius</c> is greater than 0, or when <c>IsSector</c> is <c>True</c>.</summary>
    Center: TPointF;
    /// <summary>When greater than 0, the target is circular and <c>Bounds</c> is ignored.</summary>
    Radius: Single;
    /// <summary>The data point information reported for a hit on this target.</summary>
    Info: TChartHitInfo;
    /// <summary>
    /// When <c>True</c>, the target is an annular sector (a <c>Pie</c>/<c>Donut</c> wedge)
    /// and hit-testing uses <c>Center</c>, <c>InnerRadius</c>, <c>OuterRadius</c>,
    /// <c>StartAngle</c> and <c>SweepAngle</c> instead of <c>Bounds</c>/<c>Radius</c>.
    /// </summary>
    IsSector: Boolean;
    /// <summary>The sector's inner radius, in pixels; 0 for a <c>Pie</c> wedge.</summary>
    InnerRadius: Single;
    /// <summary>The sector's outer radius, in pixels.</summary>
    OuterRadius: Single;
    /// <summary>
    /// The sector's start angle in degrees, 0&deg; at 3 o'clock, increasing clockwise
    /// (screen-angle convention).
    /// </summary>
    StartAngle: Single;
    /// <summary>The sector's sweep angle in degrees, measured clockwise from <c>StartAngle</c>.</summary>
    SweepAngle: Single;
  end;

  /// <summary>
  /// Fired when the hovered data point of a chart control changes, including when the
  /// pointer leaves every target (<c>Info.HasHit = False</c>).
  /// </summary>
  TChartHoverEvent = procedure(Sender: TObject; const Info: TChartHitInfo) of object;

implementation

class function TChartKindTraits.IsCircular(const Kind: TChartKind): Boolean;
begin
  Result := (Kind in [TChartKind.Pie, TChartKind.Donut]);
end;

class function TChartKindTraits.UsesContinuousX(const Kind: TChartKind): Boolean;
begin
  Result := (Kind in [TChartKind.Line, TChartKind.Area, TChartKind.Scatter]);
end;

class function TChartKindTraits.HasEndValues(const Kind: TChartKind): Boolean;
begin
  Result := (Kind in [TChartKind.Dumbbell, TChartKind.Range, TChartKind.Arrow]);
end;

class function TChartKindTraits.IncludesZeroBaseline(const Kind: TChartKind): Boolean;
begin
  Result := (Kind in [TChartKind.Bar, TChartKind.GroupedBar, TChartKind.StackedBar, TChartKind.Histogram,
                      TChartKind.Area]);
end;

class function TChartKindTraits.MarksPositionNotBaseline(const Kind: TChartKind): Boolean;
begin
  Result := (Kind in [TChartKind.Line, TChartKind.Dumbbell, TChartKind.Range, TChartKind.Arrow,
                      TChartKind.Scatter, TChartKind.DotPlot]);
end;

end.
