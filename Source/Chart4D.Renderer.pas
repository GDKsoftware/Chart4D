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
unit Chart4D.Renderer;

/// <summary>
/// Renders a <c>TChartPlot</c> onto an <c>IChartCanvas</c>: layout, axes, gridlines,
/// series drawing for every chart kind, annotations, and the publication footer. This
/// is the only unit a framework adapter needs to draw a chart.
/// </summary>

interface

uses
  Chart4D.Canvas.Interfaces,
  Chart4D.Plot,
  Chart4D.Types;

type
  /// <summary>
  /// Renders a chart plot onto a drawing surface following the Chart4D editorial
  /// layout: title, subtitle, legend, plot area with value and category axes, series,
  /// annotations, and an optional footer.
  /// </summary>
  TChartRenderer = class
  public
    /// <summary>
    /// Renders <c>Plot</c> onto <c>Canvas</c> at the given pixel size. Does not mutate
    /// <c>Plot</c>. A plot with no series draws just the background, so an empty
    /// control still paints. Equivalent to the <c>HitMap</c> overload with the hit map
    /// discarded.
    /// </summary>
    /// <exception cref="EChart4DException">
    /// Raised when series value counts do not match the chart's categories or each
    /// other, or when a series has no values or a NaN value.
    /// </exception>
    class procedure Render(const Plot: TChartPlot; const Canvas: IChartCanvas;
                           const Width, Height: Single); overload;

    /// <summary>
    /// Renders <c>Plot</c> onto <c>Canvas</c> at the given pixel size and returns the
    /// hit map: one target per data point, used for hover/tooltip hit-testing. Does not
    /// mutate <c>Plot</c>. A plot with no series draws just the background and returns
    /// an empty hit map.
    /// </summary>
    /// <exception cref="EChart4DException">
    /// Raised when series value counts do not match the chart's categories or each
    /// other, or when a series has no values or a NaN value.
    /// </exception>
    class procedure Render(const Plot: TChartPlot; const Canvas: IChartCanvas;
                           const Width, Height: Single;
                           out HitMap: TArray<TChartHitTarget>); overload;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.TypInfo,
  System.Types,
  System.UITypes,
  Chart4D.Axis,
  Chart4D.Consts,
  Chart4D.Series,
  Chart4D.Style;

const
  /// <summary>
  /// The radius, in pixels at the reference scale, of a circular hit target whose drawn
  /// mark does not already give it a big enough one. Named separately from
  /// <c>TLegendEngine.LegendGap</c>, which happens to share the same value at that scale
  /// but is an unrelated concept (a layout gap, not a hit-test size), so a change to one
  /// can never silently move the other.
  /// </summary>
  DefaultHitTargetRadius = 12;

  /// <summary>
  /// The distance, in pixels at the reference scale, a value label is offset away from
  /// its data mark, along the value axis or in the fixed direction for the chart's
  /// orientation. Shared by every value-label placement rule (see SPEC.md 4.12).
  /// </summary>
  ValueLabelOffsetAtReferenceScale = 8;

type
  /// <summary>
  /// Array shapes the renderer needs that the RTL does not provide.
  /// </summary>
  TChartArray = class
  public
    /// <summary>Returns <c>Values</c> in reverse order.</summary>
    class function Reversed<T>(const Values: TArray<T>): TArray<T>; static;
  end;

  TLegendItem = record
    Name: string;
    Color: TAlphaColor;
    class function Create(const Name: string; const Color: TAlphaColor): TLegendItem; static;
  end;

  TLegendRow = record
    StartIndex: Integer;
    EndIndex: Integer;
    Height: Single;
    class function Create(const StartIndex, EndIndex: Integer; const Height: Single): TLegendRow; static;
  end;

  /// <summary>
  /// A candidate value label: the pixel point its box is centered on (already shifted
  /// away from the series/baseline per its chart kind's placement rule) and the raw data
  /// value it labels, used both for its formatted text and for <c>Extremes</c> selection.
  /// </summary>
  TValueLabelCandidate = record
    AnchorPoint: TPointF;
    Value: Double;
  end;

  /// <summary>
  /// Draws labels that sit on top of chart ink, each on its own <c>ChartLabelBackground</c>
  /// box: it sizes the box around the measured text, shifts it back inside the clamp
  /// bounds when it would stick out, and remembers where every box landed so a later label
  /// can be dropped rather than drawn over an earlier one.
  /// </summary>
  /// <remarks>
  /// The single implementation of the white-box label convention (see SPEC.md 4.12),
  /// shared by value labels, <c>TextLabel</c> annotations and pie/donut segment labels.
  /// One instance covers one group of labels that compete for space; two groups drawn in
  /// separate passes each get their own instance and so never crowd each other out.
  /// </remarks>
  TChartLabelPlacer = class
  private
    FCanvas: IChartCanvas;
    FScaleFactor: Single;
    FClampBounds: TRectF;
    FPlacedBoxes: TArray<TRectF>;

    function BackgroundBounds(const AnchorPoint: TPointF; const TextSize: TSizeF;
                              const AlignH: TTextAlignH): TRectF;
    function ClampShift(const Box: TRectF): TPointF;
    function IntersectsPlaced(const Box: TRectF): Boolean;
    procedure Place(const AnchorPoint: TPointF; const LabelText: string;
                    const TextStyle: TChartTextStyle; const AlignH: TTextAlignH;
                    const SkipWhenOverlapping: Boolean);
  public
    /// <summary>
    /// Creates a placer that draws on <c>Canvas</c> and keeps every label box inside
    /// <c>ClampBounds</c>.
    /// </summary>
    constructor Create(const Canvas: IChartCanvas; const ScaleFactor: Single; const ClampBounds: TRectF);

    /// <summary>Draws a label, clamped into bounds, whatever is already there.</summary>
    procedure Draw(const AnchorPoint: TPointF; const LabelText: string;
                   const TextStyle: TChartTextStyle; const AlignH: TTextAlignH);

    /// <summary>
    /// Draws a centred label, clamped into bounds, unless its box would overlap one this
    /// placer has already drawn, in which case the label is dropped.
    /// </summary>
    procedure DrawIfClear(const AnchorPoint: TPointF; const LabelText: string;
                          const TextStyle: TChartTextStyle);
  end;

  /// <summary>
  /// Collects the hover hit targets of a render pass: one per data point, in the shape
  /// that point was drawn in. Every drawing path adds to the same instance, so a chart
  /// built from more than one engine still produces a single hit map, and the rule for
  /// turning a data point into a <c>TChartHitInfo</c> lives in exactly one place.
  /// </summary>
  TChartHitMap = class
  private
    FTargets: TArray<TChartHitTarget>;
    FDefaultRadius: Single;
  public
    /// <summary>
    /// Creates an empty hit map whose circular targets are <c>DefaultRadius</c> pixels
    /// wide unless a call gives an explicit radius.
    /// </summary>
    constructor Create(const DefaultRadius: Single);

    /// <summary>Builds the information a hit on a data point reports.</summary>
    class function BuildInfo(const SeriesIndex, PointIndex: Integer; const SeriesName, CategoryLabel: string;
                             const Value: Double; const AnchorPoint: TPointF;
                             const Color: TAlphaColor): TChartHitInfo; static;

    /// <summary>Adds a circular target of <c>DefaultRadius</c> at <c>Center</c>.</summary>
    procedure AddCircle(const Center: TPointF; const Info: TChartHitInfo); overload;
    /// <summary>Adds a circular target of <c>Radius</c> at <c>Center</c>.</summary>
    procedure AddCircle(const Center: TPointF; const Info: TChartHitInfo; const Radius: Single); overload;
    /// <summary>Adds a rectangular target covering <c>Bounds</c>.</summary>
    procedure AddRect(const Bounds: TRectF; const Info: TChartHitInfo);
    /// <summary>Adds an annular sector target, as a <c>Pie</c> or <c>Donut</c> wedge needs.</summary>
    procedure AddSector(const Center: TPointF; const InnerRadius, OuterRadius, StartAngle, SweepAngle: Single;
                        const Info: TChartHitInfo);

    /// <summary>Every target added so far, in the order they were drawn.</summary>
    property Targets: TArray<TChartHitTarget> read FTargets;
    /// <summary>
    /// The radius of a circular target whose drawn mark does not already give it a big
    /// enough one, such as a line point or a small scatter point.
    /// </summary>
    property DefaultRadius: Single read FDefaultRadius;
  end;

  /// <summary>
  /// The plotted value-axis range and the breaks (with their labels) drawn as gridlines
  /// and axis text, as computed by <c>TValueAxisEngine</c>.
  /// </summary>
  TValueAxisRange = record
    Min: Double;
    Max: Double;
    Breaks: TArray<Double>;
    BreakLabels: TArray<string>;
  end;

  /// <summary>
  /// Computes the value axis for a plot: the data range, widened by headroom, a forced
  /// zero baseline, logarithmic snapping, or the proportional 0-1 range, depending on the
  /// chart kind and the axis options, and the breaks/labels drawn from that range. Reads
  /// only the plot; it has no dependency on layout, the canvas, or pixel mapping.
  /// </summary>
  TValueAxisEngine = class
  private
    FPlot: TChartPlot;

    procedure ValidateSeriesValues;
    procedure ValidateValueArray(const SeriesName: string; const Values: TArray<Double>);
    function ComputeProportionalRange: TValueAxisRange;
    function BuildPercentageLabels(const Breaks: TArray<Double>): TArray<string>;
    function BuildValueBreakLabels(const Breaks: TArray<Double>): TArray<string>;
    function ComputeRawValueRange: TValueRange;
    function ComputeSimpleValueRange: TValueRange;
    function ComputeStackedValueRange: TValueRange;
    function ComputeDumbbellValueRange: TValueRange;
    function ApplyHeadroom(const Range: TValueRange): TValueRange;
    function ComputeValueBreaks(const Range: TValueRange): TArray<Double>;
    function ComputeLogarithmicRange: TValueAxisRange;
    procedure ValidateLogAxisValues;
    procedure ValidateLogAxisOverride(const Value: Double);
    procedure ValidateLogAxisValueArray(const Values: TArray<Double>);
    function ComputeLogAxisDataRange: TValueRange;
  public
    constructor Create(const Plot: TChartPlot);
    function Compute: TValueAxisRange;
  end;

  /// <summary>
  /// Lays out and draws the chart legend: builds the item list (one per named series, or
  /// one per category for Pie/Donut), measures and wraps it into rows for the horizontal
  /// positions, and narrows the content rect it is given by whatever space the legend
  /// takes, on whichever side <c>TChartPlot.LegendPosition</c> puts it.
  /// </summary>
  TLegendEngine = class
  private
    FPlot: TChartPlot;
    FCanvas: IChartCanvas;
    FStyle: TChartStyle;

    function BuildSeriesLegendItems: TArray<TLegendItem>;
    function BuildCategoryLegendItems: TArray<TLegendItem>;
    function ReverseLegendItems(const Items: TArray<TLegendItem>): TArray<TLegendItem>;
    function ApplyTopLegendLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
    function ApplyBottomLegendLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
    function ApplyLeftLegendLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
    function ApplyRightLegendLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
    function ComputeLegendRows(const Items: TArray<TLegendItem>; const AvailableWidth: Single): TArray<TLegendRow>;
    function DrawHorizontalLegend(const Items: TArray<TLegendItem>; const Bounds: TRectF; const StartY: Single): Single;
    procedure DrawLegendRowItems(const Items: TArray<TLegendItem>; const Row: TLegendRow; const StartX, RowY: Single);
    function MeasureHorizontalLegendHeight(const Items: TArray<TLegendItem>; const AvailableWidth: Single): Single;
    function DrawVerticalLegend(const Items: TArray<TLegendItem>; const X, StartY: Single): Single;
    function MeasureVerticalLegendWidth(const Items: TArray<TLegendItem>): Single;
    procedure DrawLegendItem(const Item: TLegendItem; const X, Y, SwatchSize: Single; const TextStyle: TChartTextStyle);
    function LegendTextStyle: TChartTextStyle;
    function LegendSwatchSize: Single;
    function LegendSwatchTextGap: Single;
    function LegendItemGap: Single;
    function LegendRowSpacing: Single;
    /// <summary>
    /// The gap between the legend and the plot area, on whichever side the legend sits.
    /// Named separately from <c>TChartRenderJob.DefaultHitTargetRadius</c>, which happens
    /// to share the same literal value at the reference scale but is an unrelated concept
    /// (a hit-test size, not a layout gap) living in a different class, so a change to one
    /// can never silently move the other.
    /// </summary>
    function LegendGap: Single;
  public
    constructor Create(const Plot: TChartPlot; const Canvas: IChartCanvas; const Style: TChartStyle);
    function BuildItems: TArray<TLegendItem>;
    function ApplyLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
  end;

  /// <summary>
  /// Draws an arrow from one point to another: a shaft that stops where the head begins,
  /// and a filled triangular head. Shared by the <c>Arrow</c> chart kind and the
  /// <c>Arrow</c> annotation, which draw the same shape from different data.
  /// </summary>
  TChartArrowPainter = class
  private
    FCanvas: IChartCanvas;
    FScaleFactor: Single;

    function HeadLength: Single;
    function HeadAngle: Single;
    /// <summary>
    /// How far back from the tip the two wings meet the shaft, which is where the shaft
    /// has to stop.
    /// </summary>
    function HeadDepth: Single;
    procedure DrawShaft(const StartPoint, EndPoint: TPointF; const Color: TAlphaColor;
                        const Width: Single; const Dashed: Boolean);
    procedure DrawHead(const StartPoint, EndPoint: TPointF; const Color: TAlphaColor);

  public
    /// <summary>Creates an arrow painter drawing on <c>Canvas</c> at <c>ScaleFactor</c>.</summary>
    constructor Create(const Canvas: IChartCanvas; const ScaleFactor: Single);

    /// <summary>Draws a complete arrow from <c>StartPoint</c> to <c>EndPoint</c>.</summary>
    procedure Draw(const StartPoint, EndPoint: TPointF; const Color: TAlphaColor;
                   const Width: Single; const Dashed: Boolean);
  end;

  /// <summary>
  /// The pixel geometry of one render pass: where the plot area is, and how a data
  /// coordinate becomes a point inside it. Everything that has to turn values into
  /// pixels goes through this one object, so the orientation rule ("which screen axis is
  /// the value axis") is applied in a single place instead of being re-decided at every
  /// drawing site.
  /// </summary>
  TChartGeometry = class
  private
    FPlot: TChartPlot;
    FIsHorizontal: Boolean;
    FIsContinuousX: Boolean;
    FPlotBounds: TRectF;
    FValueMapper: TLinearMapper;
    FXMapper: TLinearMapper;
    FCategoryCount: Integer;
    FCategoryStart: Single;
    FCategoryBand: Single;

    procedure BuildValueMapper(const ValueRange: TValueRange);
    procedure BuildCategoryMapper;
    procedure BuildXMapper(const XRange: TValueRange);

  public
    /// <summary>
    /// Creates the geometry for <c>Plot</c>. Nothing can be mapped until <c>Build</c> has
    /// been given the laid-out plot bounds.
    /// </summary>
    constructor Create(const Plot: TChartPlot; const CategoryCount: Integer);

    /// <summary>
    /// Fixes the geometry to the laid-out <c>PlotBounds</c> and the plotted ranges of the
    /// value axis and, for a continuous-X kind, the X axis.
    /// </summary>
    procedure Build(const PlotBounds: TRectF; const ValueRange, XRange: TValueRange);

    /// <summary>
    /// Maps a data value to its pixel on the value axis, through the logarithm first when
    /// the value axis is logarithmic. A value at or below zero has no place on a
    /// logarithmic scale and is pinned to the bottom of the range.
    /// </summary>
    function MapValue(const Value: Double): Single;
    /// <summary>Maps an X coordinate to its pixel on a continuous X axis.</summary>
    function MapX(const Value: Double): Single;

    /// <summary>The pixel at the centre of the band of category <c>Index</c>.</summary>
    function CategoryCenter(const Index: Integer): Single;
    /// <summary>
    /// The pixel of a category-axis coordinate expressed as a <c>Double</c>: an X value
    /// on a continuous axis, or a 0-based category index on a discrete one.
    /// </summary>
    function CategoryAxisPixel(const Coordinate: Double): Single;

    /// <summary>Combines a category-axis pixel and a data value into a screen point.</summary>
    function CategoryValuePoint(const CategoryPixel: Single; const Value: Double): TPointF;
    /// <summary>Combines an X coordinate and a value into a screen point.</summary>
    function XYPoint(const X, Y: Double): TPointF;
    /// <summary>Moves a point by <c>Amount</c> along whichever screen axis is the value axis.</summary>
    function OffsetAlongValueAxis(const Point: TPointF; const Amount: Single): TPointF;

    /// <summary>The rectangle of a bar-shaped mark spanning two value pixels.</summary>
    function BarBounds(const CategoryPixel, BarWidth, ValuePixel, BaselinePixel: Single): TRectF;
    /// <summary>
    /// The width of a bar, or of a grouped-bar/range dodge band, as a fraction of its
    /// category band: the single source of truth shared by every kind that draws a
    /// bar-shaped mark, so the drawing and its value-label placement can never drift apart.
    /// </summary>
    function CategoryBarWidth: Single;

    /// <summary>
    /// The X coordinates of a series: its own <c>XValues</c> when it has them, otherwise
    /// its position index.
    /// </summary>
    class function EffectiveXValues(const Series: TChartSeries): TArray<Double>; static;
    /// <summary>Maps <c>Values</c> against the series' X coordinates into screen points.</summary>
    function SeriesPoints(const Series: TChartSeries; const Values: TArray<Double>): TArray<TPointF>;
    /// <summary>The screen points of a series' primary values.</summary>
    function SeriesLinePoints(const Series: TChartSeries): TArray<TPointF>;
    /// <summary>The screen points of a series' <c>EndValues</c>, the high edge of a band.</summary>
    function SeriesHighPoints(const Series: TChartSeries): TArray<TPointF>;

    /// <summary>Closes a run of line points down to a baseline, making a fillable area polygon.</summary>
    function AreaPolygonPoints(const LinePoints: TArray<TPointF>; const BaselinePixel: Single): TArray<TPointF>;
    /// <summary>Joins a low and a high run of points into one closed band polygon.</summary>
    class function BandPolygonPoints(const LowPoints, HighPoints: TArray<TPointF>): TArray<TPointF>; static;

    /// <summary>Whether the categories run down the screen instead of across it.</summary>
    property IsHorizontal: Boolean read FIsHorizontal;
    /// <summary>Whether the category axis is a continuous X axis rather than discrete bands.</summary>
    property IsContinuousX: Boolean read FIsContinuousX;
    /// <summary>The laid-out plot area.</summary>
    property PlotBounds: TRectF read FPlotBounds;
    /// <summary>The number of discrete categories, 0 on a continuous-X plot.</summary>
    property CategoryCount: Integer read FCategoryCount;
    /// <summary>The pixel width of one category band.</summary>
    property CategoryBand: Single read FCategoryBand;
  end;

  /// <summary>
  /// Everything a series renderer draws with, gathered once by the render job after
  /// layout: the model, the surface, the resolved style, the pixel geometry, the hit map
  /// to register targets in, the shared arrow painter, and the rectangle any label it
  /// draws itself has to stay inside.
  /// </summary>
  TChartDrawContext = record
    Plot: TChartPlot;
    Canvas: IChartCanvas;
    Style: TChartStyle;
    Geometry: TChartGeometry;
    HitMap: TChartHitMap;
    Arrows: TChartArrowPainter;
    LabelClampBounds: TRectF;
  end;

  /// <summary>
  /// Draws the series of one chart kind, and says where that kind's value labels go.
  /// </summary>
  /// <remarks>
  /// One descendant per <c>TChartKind</c>, chosen by <c>CreateFor</c>. Everything that
  /// differs per kind and cannot be reduced to a fact in <c>TChartKindTraits</c> lives
  /// here, so adding a chart kind means adding one class and one line to the factory,
  /// rather than remembering to extend a drawing case and a value-label case separately.
  /// </remarks>
  TChartSeriesRenderer = class
  protected
    FPlot: TChartPlot;
    FCanvas: IChartCanvas;
    FStyle: TChartStyle;
    FGeometry: TChartGeometry;
    FHitMap: TChartHitMap;
    FArrows: TChartArrowPainter;
    FLabelClampBounds: TRectF;

    /// <summary>The category label of <c>Index</c>, as a hit target reports it.</summary>
    function CategoryLabel(const Index: Integer): string;
    /// <summary>
    /// The X value of a continuous-axis point, formatted the way a hit target on that
    /// point reports it.
    /// </summary>
    function ContinuousPointLabel(const XValue: Double): string;
    /// <summary>The distance a value label is offset away from its mark.</summary>
    function ValueLabelOffset: Single;
    /// <summary>That offset as a vector, in the fixed direction for the chart's orientation.</summary>
    function ValueLabelLineOffset: TPointF;
    /// <summary>Where the value label of a bar-shaped mark goes: just past its far end.</summary>
    function BarValueLabelPoint(const CategoryPixel, ValuePixel, BaselinePixel: Single): TPointF;
    /// <summary>Turns drawn points and their values into label candidates, offset clear of the marks.</summary>
    function OffsetPointGroup(const Points: TArray<TPointF>;
                              const Values: TArray<Double>): TArray<TValueLabelCandidate>;
    /// <summary>
    /// The label candidates of a kind whose every data point has two ends: one group for
    /// the start ends and one for the end ends, each offset away from the other end so a
    /// label never lands on its own connector.
    /// </summary>
    function PairedEndGroups(const Series: TChartSeries): TArray<TArray<TValueLabelCandidate>>;
    /// <summary>Draws one bar-shaped mark and registers its rectangular hit target.</summary>
    procedure DrawBar(const SeriesIndex, CategoryIndex: Integer; const SeriesName: string;
                      const CategoryPixel: Single; const Value: Double; const Color: TAlphaColor;
                      const BarWidth: Single);
    /// <summary>Draws every category of a single-series bar-shaped kind at <c>BarWidth</c>.</summary>
    procedure DrawSingleSeriesBars(const BarWidth: Single);
    /// <summary>The label candidates of a single-series bar-shaped kind.</summary>
    function SingleSeriesBarGroups: TArray<TArray<TValueLabelCandidate>>;

  public
    /// <summary>Creates a renderer bound to the collaborators in <c>Context</c>.</summary>
    constructor Create(const Context: TChartDrawContext); virtual;

    /// <summary>Draws every series of this kind and registers their hit targets.</summary>
    procedure Draw; virtual; abstract;

    /// <summary>
    /// The groups of value-label candidates this kind offers. Each group competes for
    /// space on its own, and <c>TValueLabelMode</c> selects within a group. Kinds that
    /// carry no value labels keep the inherited empty result.
    /// </summary>
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; virtual;

    /// <summary>
    /// Creates the renderer for <c>Context.Plot.Kind</c>. The one place a chart kind is
    /// turned into behaviour.
    /// </summary>
    /// <exception cref="ENotSupportedException">Raised for a kind with no renderer.</exception>
    class function CreateFor(const Context: TChartDrawContext): TChartSeriesRenderer; static;
  end;

  /// <summary>
  /// Base for the kinds plotted against a continuous X axis. Their value labels sit just
  /// clear of each drawn point, one group per series.
  /// </summary>
  TXYSeriesRenderer = class(TChartSeriesRenderer)
  protected
    procedure AddPointHitTargets(const SeriesIndex: Integer; const Series: TChartSeries;
                                 const Points: TArray<TPointF>; const Color: TAlphaColor);
  public
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>
  /// Base for <c>Line</c> and <c>Area</c>: both draw range-band series in a pass of their
  /// own before the ordinary series, and differ only in the mark they draw for one series.
  /// </summary>
  TLineAreaSeriesRenderer = class(TXYSeriesRenderer)
  protected
    procedure DrawMark(const SeriesIndex: Integer; const Series: TChartSeries;
                       const Color: TAlphaColor); virtual; abstract;
    procedure DrawRangeBand(const SeriesIndex: Integer; const Series: TChartSeries; const Color: TAlphaColor);
  public
    procedure Draw; override;
  end;

  /// <summary>Draws a <c>Line</c> chart: one polyline per series.</summary>
  TLineSeriesRenderer = class(TLineAreaSeriesRenderer)
  protected
    procedure DrawMark(const SeriesIndex: Integer; const Series: TChartSeries; const Color: TAlphaColor); override;
  end;

  /// <summary>Draws an <c>Area</c> chart: a filled polygon down to the baseline, plus its line.</summary>
  TAreaSeriesRenderer = class(TLineAreaSeriesRenderer)
  protected
    procedure DrawMark(const SeriesIndex: Integer; const Series: TChartSeries; const Color: TAlphaColor); override;
  end;

  /// <summary>
  /// Draws a <c>Scatter</c> chart: one circle per point, area-proportional to the series'
  /// <c>Sizes</c> when it has them.
  /// </summary>
  TScatterSeriesRenderer = class(TXYSeriesRenderer)
  private
    function ComputeSizeDomain: TValueRange;
    procedure DrawPoints(const SeriesIndex: Integer; const Series: TChartSeries;
                         const Color: TAlphaColor; const SizeDomain: TValueRange);
  public
    /// <summary>
    /// The radius a point is drawn at: the plain scatter radius without <c>Sizes</c>,
    /// otherwise a bubble radius interpolated over the plot-wide size domain by area.
    /// </summary>
    class function PointDrawRadius(const Style: TChartStyle; const Series: TChartSeries;
                                   const PointIndex: Integer; const SizeDomain: TValueRange): Single; static;
    procedure Draw; override;
  end;

  /// <summary>Draws a <c>DotPlot</c>: one circle per category, per series.</summary>
  TDotPlotSeriesRenderer = class(TChartSeriesRenderer)
  private
    function SeriesPoints(const Series: TChartSeries): TArray<TPointF>;
    procedure DrawPoints(const SeriesIndex: Integer; const Series: TChartSeries; const Color: TAlphaColor);
  public
    procedure Draw; override;
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>Draws a <c>Bar</c> chart: one bar per category from the single series.</summary>
  TBarSeriesRenderer = class(TChartSeriesRenderer)
  public
    procedure Draw; override;
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>
  /// Draws a <c>Histogram</c>: like a bar chart, but the bins fill their band apart from a
  /// hairline gap, because adjacent bins are contiguous rather than separate categories.
  /// </summary>
  THistogramSeriesRenderer = class(TChartSeriesRenderer)
  private
    function BinWidth: Single;
  public
    procedure Draw; override;
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>Draws a <c>GroupedBar</c> chart: the series dodged side by side within each category.</summary>
  TGroupedBarSeriesRenderer = class(TChartSeriesRenderer)
  private
    function BarWidth: Single;
    function SeriesOffset(const SeriesIndex: Integer): Single;
    procedure DrawSet(const SeriesIndex: Integer);
  public
    procedure Draw; override;
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>Draws a <c>StackedBar</c> chart: the series stacked into one bar per category.</summary>
  TStackedBarSeriesRenderer = class(TChartSeriesRenderer)
  private
    function CategoryTotal(const CategoryIndex: Integer): Double;
    function SegmentValue(const RawValue, Total: Double): Double;
    procedure DrawColumn(const CategoryIndex: Integer; const BarWidth: Single);
    procedure DrawSegment(const SeriesIndex, CategoryIndex: Integer; const SeriesName: string;
                          const CategoryPixel, BarWidth: Single; const StartValue, EndValue, RawValue: Double;
                          const Color: TAlphaColor);
  public
    procedure Draw; override;
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>Draws a <c>Dumbbell</c> chart: a connector between two dots per category.</summary>
  TDumbbellSeriesRenderer = class(TChartSeriesRenderer)
  private
    procedure DrawItem(const CategoryIndex: Integer; const StartValue, EndValue: Double;
                       const ConnectorWidth, CircleRadius: Single);
  public
    procedure Draw; override;
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>Draws a <c>Range</c> chart: a bar spanning low to high per category.</summary>
  TRangeSeriesRenderer = class(TChartSeriesRenderer)
  private
    procedure DrawItem(const CategoryIndex: Integer; const SeriesName: string;
                       const LowValue, HighValue: Double; const Color: TAlphaColor; const BarWidth: Single);
  public
    procedure Draw; override;
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>Draws an <c>Arrow</c> chart: an arrow from start to end value per category.</summary>
  TArrowSeriesRenderer = class(TChartSeriesRenderer)
  private
    procedure DrawItem(const CategoryIndex: Integer; const SeriesName: string;
                       const StartValue, EndValue: Double; const Color: TAlphaColor);
  public
    procedure Draw; override;
    function BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>; override;
  end;

  /// <summary>
  /// Draws a <c>Pie</c> or <c>Donut</c> chart: wedge geometry, per-segment labels using
  /// the same overlap-avoidance rule value labels use (<c>TChartLabelPlacer</c>), the
  /// optional donut center text, and the sector hit targets for hover. Colours and labels
  /// by category rather than by series, and carries no value labels of its own.
  /// </summary>
  TCircularSeriesRenderer = class(TChartSeriesRenderer)
  private
    FLabelPlacer: TChartLabelPlacer;

    function Center: TPointF;
    function OuterRadius: Single;
    function InnerRadius(const OuterRadius: Single): Single;
    function Total(const Values: TArray<Double>): Double;
    function SegmentCount(const SweepAngle: Single): Integer;
    function ArcPoints(const Center: TPointF; const Radius, StartAngle, SweepAngle: Single;
                       const SegmentCount: Integer): TArray<TPointF>;
    procedure DrawWedge(const CategoryIndex: Integer; const Center: TPointF;
                        const InnerRadius, OuterRadius, StartAngle, SweepAngle: Single;
                        const IsDonut: Boolean; const Value, Total: Double);
    function SegmentLabelDistance(const InnerRadius, OuterRadius: Single; const IsDonut: Boolean): Single;
    function PointAtAngle(const Center: TPointF; const Distance, AngleDegrees: Single): TPointF;
    procedure DrawCenterText(const Center: TPointF);
    procedure DrawSegmentLabel(const AnchorPoint: TPointF; const LabelText: string);
  public
    constructor Create(const Context: TChartDrawContext); override;
    destructor Destroy; override;
    procedure Draw; override;
  end;

  /// <summary>
  /// Performs a single render pass of a chart plot onto a canvas: validates the data,
  /// computes axes and layout, then draws axis labels, gridlines, series, annotations,
  /// and the footer in order.
  /// </summary>
  TChartRenderJob = class
  private
    FPlot: TChartPlot;
    FCanvas: IChartCanvas;
    FWidth: Single;
    FHeight: Single;
    FStyle: TChartStyle;
    FIsContinuousX: Boolean;
    FPlotBounds: TRectF;
    FValueRange: TValueRange;
    FValueBreaks: TArray<Double>;
    FValueBreakLabels: TArray<string>;
    FCategoryLabels: TArray<string>;
    FCategoryCount: Integer;
    FXRange: TValueRange;
    FXBreaks: TArray<Double>;
    FXBreakLabels: TArray<string>;
    FHitMap: TChartHitMap;
    FGeometry: TChartGeometry;
    FArrows: TChartArrowPainter;
    FSeriesRenderer: TChartSeriesRenderer;

    function BuildScaledStyle(const Style: TChartStyle): TChartStyle;

    procedure ValidateInput;
    procedure ValidateCategorySeries;
    procedure ValidateSeriesLength(const Series: TChartSeries);
    procedure ValidatePairedSeries(const KindName: string);
    procedure ValidatePieSeries;
    procedure ValidateLineSeries;
    procedure ValidateLineSeriesLength(const Series: TChartSeries);
    procedure ValidateBandSeriesLength(const Series: TChartSeries);
    procedure ValidateSeriesSizesLength(const Series: TChartSeries);
    function CategoryWord(const Count: Integer): string;
    function KindName: string;
    function IsPieOrDonut: Boolean;
    procedure ComputeCircularAnnotationSpace;

    procedure ComputeValueAxis;
    function MapValue(const Value: Double): Single;

    procedure ComputeCategoryAxis;
    procedure ComputeDiscreteCategoryAxis;
    procedure ComputeContinuousXAxis;
    function ComputeXDataRange: TValueRange;

    procedure PerformLayout;
    function DrawTitleAndSubtitle(const ContentRect: TRectF): Single;
    function DrawTitle(const X, Y, MaxWidth: Single): Single;
    function DrawSubtitle(const X, Y, MaxWidth: Single): Single;
    function DrawWrappedTextBlock(const X, Y, MaxWidth: Single; const Text: string;
                                  const TextStyle: TChartTextStyle): Single;
    function WrapTextLines(const Text: string; const TextStyle: TChartTextStyle;
                           const MaxWidth: Single): TArray<string>;
    function ComputeFooterHeight: Single;
    function HasFooterContent: Boolean;

    function OuterMargin: Single;

    function ComputePlotBounds(const ContentRect: TRectF): TRectF;
    function ComputeTopInset: Single;
    function ComputeLeftInset: Single;
    function ComputeRightInset: Single;
    function ComputeBubbleRadiusInset: Single;
    function LeftEdgeAxisVisible(const IsHorizontal: Boolean): Boolean;
    function CategoryAxisLabels: TArray<string>;
    function LeftEdgeLabels(const IsHorizontal: Boolean): TArray<string>;
    function BottomEdgeLabels(const IsHorizontal: Boolean): TArray<string>;
    function ComputeBottomAxisLabelHeight: Single;
    function BottomEdgeAxisVisible(const IsHorizontal: Boolean): Boolean;
    function WidestLabelWidth(const Labels: TArray<string>; const TextStyle: TChartTextStyle): Single;
    function AxisTextStyle: TChartTextStyle;
    function LeftLabelGap: Single;
    function AxisLabelRightEdge: Single;
    function AxisLabelTopEdge: Single;
    function BottomLabelMarginAbove: Single;
    function BottomLabelMarginBelow: Single;

    procedure BuildGeometry;
    function CategoryCenter(const Index: Integer): Single;
    function CategoryValuePoint(const CategoryPixel: Single; const Value: Double): TPointF;

    procedure DrawAxisLabels;
    procedure DrawValueAxisLabels;
    procedure DrawValueAxisLabel(const Pixel: Single; const LabelText: string; const TextStyle: TChartTextStyle);
    procedure DrawCategoryAxisLabel(const Pixel: Single; const LabelText: string; const TextStyle: TChartTextStyle);
    procedure DrawCategoryAxisLabels;
    procedure DrawContinuousXLabels;
    procedure DrawDiscreteCategoryLabels;
    function SelectedCategoryLabelIndices: TArray<Integer>;
    function CategoryLabelExtent(const Index: Integer): Single;
    procedure DrawDiscreteCategoryLabel(const Index: Integer; const TextStyle: TChartTextStyle);
    function MarginBounds: TRectF;
    function ValueLabelClampBounds: TRectF;

    procedure DrawRangeOverlays;
    procedure DrawHorizontalRangeOverlay(const Annotation: TChartAnnotation);
    procedure DrawVerticalRangeOverlay(const Annotation: TChartAnnotation);
    procedure FillRangeBand(const LowPoints, HighPoints: TArray<TPointF>; const Color: TAlphaColor);
    function PlotSpanAtValuePixel(const Pixel: Single): TArray<TPointF>;
    function PlotSpanAtCategoryPixel(const Pixel: Single): TArray<TPointF>;
    procedure DrawLineAcrossPlot(const Pixel: Single; const Color: TAlphaColor;
                                 const Width: Single; const Dashed: Boolean);
    procedure DrawLineAlongPlot(const Pixel: Single; const Color: TAlphaColor;
                                const Width: Single; const Dashed: Boolean);

    procedure DrawGrid;
    procedure DrawGridlines;
    procedure DrawGridline(const Value: Double);
    procedure DrawBaseline;

    procedure BuildSeriesRenderer;
    procedure DrawSeries;

    procedure DrawValueLabels;
    function SelectValueLabelCandidates(const Group: TArray<TValueLabelCandidate>;
                                        const Mode: TValueLabelMode): TArray<TValueLabelCandidate>;
    procedure DrawValueLabelCandidate(const Placer: TChartLabelPlacer; const Candidate: TValueLabelCandidate);

    procedure DrawAnnotations;
    procedure DrawAnnotation(const Placer: TChartLabelPlacer; const Annotation: TChartAnnotation);
    procedure DrawTextLabelAnnotation(const Placer: TChartLabelPlacer; const Annotation: TChartAnnotation);
    procedure DrawSegmentAnnotation(const Annotation: TChartAnnotation);
    procedure DrawArrowAnnotation(const Annotation: TChartAnnotation);
    procedure DrawHorizontalLineAnnotation(const Annotation: TChartAnnotation);
    procedure DrawVerticalLineAnnotation(const Annotation: TChartAnnotation);
    function AnnotationPoint(const X, Y: Double): TPointF;
    function AnnotationLineWidth(const Annotation: TChartAnnotation): Single;
    function AnnotationFontSize(const Annotation: TChartAnnotation): Single;

    procedure DrawFooter;
    procedure DrawFooterSeparator(const FooterTop, Margin: Single);
    procedure DrawFooterSource(const FooterTop, FooterHeight, Margin: Single);
    procedure DrawFooterLogo(const FooterTop, FooterHeight, Margin: Single);

  public
    constructor Create(const Plot: TChartPlot; const Canvas: IChartCanvas; const Width, Height: Single);
    destructor Destroy; override;
    procedure Execute;

    property HitMap: TChartHitMap read FHitMap;
  end;

class function TLegendItem.Create(const Name: string; const Color: TAlphaColor): TLegendItem;
begin
  Result.Name := Name;
  Result.Color := Color;
end;

class function TLegendRow.Create(const StartIndex, EndIndex: Integer; const Height: Single): TLegendRow;
begin
  Result.StartIndex := StartIndex;
  Result.EndIndex := EndIndex;
  Result.Height := Height;
end;

constructor TChartHitMap.Create(const DefaultRadius: Single);
begin
  inherited Create;
  FDefaultRadius := DefaultRadius;
end;

class function TChartHitMap.BuildInfo(const SeriesIndex, PointIndex: Integer; const SeriesName, CategoryLabel: string;
                                      const Value: Double; const AnchorPoint: TPointF;
                                      const Color: TAlphaColor): TChartHitInfo;
begin
  Result.HasHit := True;
  Result.SeriesIndex := SeriesIndex;
  Result.PointIndex := PointIndex;
  Result.SeriesName := SeriesName;
  Result.CategoryLabel := CategoryLabel;
  Result.Value := Value;
  Result.AnchorX := AnchorPoint.X;
  Result.AnchorY := AnchorPoint.Y;
  Result.Color := Color;
end;

procedure TChartHitMap.AddCircle(const Center: TPointF; const Info: TChartHitInfo);
begin
  AddCircle(Center, Info, FDefaultRadius);
end;

procedure TChartHitMap.AddCircle(const Center: TPointF; const Info: TChartHitInfo; const Radius: Single);
begin
  var Target := Default(TChartHitTarget);
  Target.Center := Center;
  Target.Radius := Radius;
  Target.Info := Info;
  FTargets := FTargets + [Target];
end;

procedure TChartHitMap.AddRect(const Bounds: TRectF; const Info: TChartHitInfo);
begin
  var Target := Default(TChartHitTarget);
  Target.Bounds := Bounds;
  Target.Radius := 0;
  Target.Info := Info;
  FTargets := FTargets + [Target];
end;

procedure TChartHitMap.AddSector(const Center: TPointF; const InnerRadius, OuterRadius, StartAngle, SweepAngle: Single;
                                 const Info: TChartHitInfo);
begin
  var Target := Default(TChartHitTarget);
  Target.IsSector := True;
  Target.Center := Center;
  Target.InnerRadius := InnerRadius;
  Target.OuterRadius := OuterRadius;
  Target.StartAngle := StartAngle;
  Target.SweepAngle := SweepAngle;
  Target.Info := Info;
  FTargets := FTargets + [Target];
end;

class function TChartArray.Reversed<T>(const Values: TArray<T>): TArray<T>;
begin
  SetLength(Result, Length(Values));
  for var Index := 0 to High(Values) do
  begin
    Result[Index] := Values[High(Values) - Index];
  end;
end;

constructor TChartLabelPlacer.Create(const Canvas: IChartCanvas; const ScaleFactor: Single;
                                     const ClampBounds: TRectF);
begin
  inherited Create;
  FCanvas := Canvas;
  FScaleFactor := ScaleFactor;
  FClampBounds := ClampBounds;
end;

procedure TChartLabelPlacer.Draw(const AnchorPoint: TPointF; const LabelText: string;
                                 const TextStyle: TChartTextStyle; const AlignH: TTextAlignH);
begin
  Place(AnchorPoint, LabelText, TextStyle, AlignH, False);
end;

procedure TChartLabelPlacer.DrawIfClear(const AnchorPoint: TPointF; const LabelText: string;
                                        const TextStyle: TChartTextStyle);
begin
  Place(AnchorPoint, LabelText, TextStyle, TTextAlignH.Center, True);
end;

procedure TChartLabelPlacer.Place(const AnchorPoint: TPointF; const LabelText: string;
                                  const TextStyle: TChartTextStyle; const AlignH: TTextAlignH;
                                  const SkipWhenOverlapping: Boolean);
begin
  const TextSize = FCanvas.MeasureText(LabelText, TextStyle);

  var Background := BackgroundBounds(AnchorPoint, TextSize, AlignH);
  const Shift = ClampShift(Background);
  Background.Offset(Shift.X, Shift.Y);

  if SkipWhenOverlapping and IntersectsPlaced(Background) then
    Exit;

  FCanvas.FillRect(Background, ChartLabelBackground);
  FCanvas.DrawText(AnchorPoint.X + Shift.X, AnchorPoint.Y + Shift.Y, LabelText, TextStyle,
                   AlignH, TTextAlignV.Middle);

  FPlacedBoxes := FPlacedBoxes + [Background];
end;

function TChartLabelPlacer.BackgroundBounds(const AnchorPoint: TPointF; const TextSize: TSizeF;
                                            const AlignH: TTextAlignH): TRectF;
begin
  const Padding = 3 * FScaleFactor;
  const Origin = TChartTextAlign.ResolveOrigin(AnchorPoint.X, AnchorPoint.Y, TextSize,
                                               AlignH, TTextAlignV.Middle);

  Result := TRectF.Create(Origin.X - Padding, Origin.Y - Padding,
                          Origin.X + TextSize.Width + Padding, Origin.Y + TextSize.Height + Padding);
end;

function TChartLabelPlacer.ClampShift(const Box: TRectF): TPointF;
begin
  Result := TPointF.Create(0, 0);

  if Box.Left < FClampBounds.Left then
    Result.X := FClampBounds.Left - Box.Left
  else if Box.Right > FClampBounds.Right then
    Result.X := FClampBounds.Right - Box.Right;

  if Box.Top < FClampBounds.Top then
    Result.Y := FClampBounds.Top - Box.Top
  else if Box.Bottom > FClampBounds.Bottom then
    Result.Y := FClampBounds.Bottom - Box.Bottom;
end;

function TChartLabelPlacer.IntersectsPlaced(const Box: TRectF): Boolean;
begin
  Result := False;
  for var Existing in FPlacedBoxes do
  begin
    if Box.IntersectsWith(Existing) then
      Exit(True);
  end;
end;

constructor TValueAxisEngine.Create(const Plot: TChartPlot);
begin
  inherited Create;
  FPlot := Plot;
end;

function TValueAxisEngine.Compute: TValueAxisRange;
begin
  ValidateSeriesValues;

  const IsStackedProportions = (FPlot.Kind = TChartKind.StackedBar) and (FPlot.StackMode = TStackMode.Proportions);
  if IsStackedProportions then
    Exit(ComputeProportionalRange);

  if FPlot.YAxis.IsLogarithmic then
    Exit(ComputeLogarithmicRange);

  const RawRange = ComputeRawValueRange;
  var FinalRange := ApplyHeadroom(RawRange).WithOverrides(FPlot.YAxis);

  if not FPlot.YAxis.HasManualBreaks then
    FinalRange := FinalRange.ExpandedIfDegenerate;

  Result.Min := FinalRange.Min;
  Result.Max := FinalRange.Max;
  Result.Breaks := ComputeValueBreaks(FinalRange);
  Result.BreakLabels := BuildValueBreakLabels(Result.Breaks);
end;

function TValueAxisEngine.BuildValueBreakLabels(const Breaks: TArray<Double>): TArray<string>;
begin
  { DateMode is meaningful only for a continuous X axis (4.16); the value axis
    ignores it, so the labels here are always plain numeric ones. }
  var Options := FPlot.YAxis;
  Options.DateMode := TAxisDateMode.None;
  Result := TAxisScale.BuildLabels(Breaks, Options);
end;

procedure TValueAxisEngine.ValidateSeriesValues;
begin
  const UsesEndValues = TChartKindTraits.HasEndValues(FPlot.Kind);
  for var CurrentSeries in FPlot.Series do
  begin
    const HasNoValues = (Length(CurrentSeries.Values) = 0);
    if HasNoValues then
      raise EChart4DException.CreateFmt(SSeriesHasNoValues, [CurrentSeries.Name]);

    ValidateValueArray(CurrentSeries.Name, CurrentSeries.Values);

    if UsesEndValues or CurrentSeries.IsRangeBand then
      ValidateValueArray(CurrentSeries.Name, CurrentSeries.EndValues);
  end;
end;

procedure TValueAxisEngine.ValidateValueArray(const SeriesName: string; const Values: TArray<Double>);
begin
  for var Index := 0 to High(Values) do
  begin
    if IsNaN(Values[Index]) then
      raise EChart4DException.CreateFmt(SSeriesValueIsNaN, [SeriesName, Index]);
  end;
end;

procedure TValueAxisEngine.ValidateLogAxisValueArray(const Values: TArray<Double>);
begin
  for var Value in Values do
  begin
    if Value <= 0 then
      raise EChart4DException.CreateFmt(SLogAxisRequiresPositiveValues, [Value]);
  end;
end;

procedure TValueAxisEngine.ValidateLogAxisValues;
begin
  ValidateLogAxisOverride(FPlot.YAxis.MinValue);
  ValidateLogAxisOverride(FPlot.YAxis.MaxValue);

  const HasEndValues = TChartKindTraits.HasEndValues(FPlot.Kind);
  for var CurrentSeries in FPlot.Series do
  begin
    ValidateLogAxisValueArray(CurrentSeries.Values);

    if HasEndValues then
      ValidateLogAxisValueArray(CurrentSeries.EndValues);
  end;
end;

procedure TValueAxisEngine.ValidateLogAxisOverride(const Value: Double);
begin
  const HasOverride = not IsNaN(Value);
  if HasOverride and (Value <= 0) then
    raise EChart4DException.CreateFmt(SLogAxisRequiresPositiveValues, [Value]);
end;

function TValueAxisEngine.ComputeLogAxisDataRange: TValueRange;
begin
  const HasEndValues = TChartKindTraits.HasEndValues(FPlot.Kind);

  Result := TValueRange.Empty;
  for var CurrentSeries in FPlot.Series do
  begin
    Result.Extend(CurrentSeries.Values);

    if HasEndValues then
      Result.Extend(CurrentSeries.EndValues);
  end;
end;

function TValueAxisEngine.ComputeLogarithmicRange: TValueAxisRange;
begin
  const LogBase = FPlot.YAxis.LogBase;
  const HasInvalidLogBase = (LogBase <= 1);
  if HasInvalidLogBase then
    raise EChart4DException.CreateFmt(SLogBaseMustExceedOne, [LogBase]);

  ValidateLogAxisValues;

  const RawRange = ComputeLogAxisDataRange;
  const Epsilon = 1E-9;
  const MinExponent: Integer = Floor(LogN(LogBase, RawRange.Min) + Epsilon);
  const MaxExponent: Integer = Ceil(LogN(LogBase, RawRange.Max) - Epsilon);

  const SnappedRange = TValueRange.Create(Power(LogBase, MinExponent), Power(LogBase, MaxExponent));

  const FinalRange = SnappedRange.WithOverrides(FPlot.YAxis);
  Result.Min := FinalRange.Min;
  Result.Max := FinalRange.Max;

  if FPlot.YAxis.HasManualBreaks then
    Result.Breaks := FPlot.YAxis.Breaks
  else
    Result.Breaks := TAxisScale.LogBreaks(FinalRange.Min, FinalRange.Max, LogBase);

  Result.BreakLabels := BuildValueBreakLabels(Result.Breaks);
end;

function TValueAxisEngine.ComputeProportionalRange: TValueAxisRange;
begin
  if FPlot.YAxis.HasManualBreaks then
  begin
    Result.Breaks := FPlot.YAxis.Breaks;
    Result.BreakLabels := BuildValueBreakLabels(Result.Breaks);
  end
  else
  begin
    Result.Breaks := [0, 0.25, 0.5, 0.75, 1];
    Result.BreakLabels := BuildPercentageLabels(Result.Breaks);
  end;

  const ProportionRange = TValueRange.Create(0, 1).WithOverrides(FPlot.YAxis);
  Result.Min := ProportionRange.Min;
  Result.Max := ProportionRange.Max;
end;

function TValueAxisEngine.BuildPercentageLabels(const Breaks: TArray<Double>): TArray<string>;
begin
  if FPlot.YAxis.HasManualLabels then
    Exit(FPlot.YAxis.BreakLabels);

  SetLength(Result, Length(Breaks));
  for var Index := 0 to High(Breaks) do
  begin
    Result[Index] := Format('%d%%', [Round(Breaks[Index] * 100)]);
  end;
end;

function TValueAxisEngine.ComputeRawValueRange: TValueRange;
begin
  if FPlot.Kind = TChartKind.StackedBar then
    Result := ComputeStackedValueRange
  else if TChartKindTraits.HasEndValues(FPlot.Kind) then
    Result := ComputeDumbbellValueRange
  else
    Result := ComputeSimpleValueRange;

  if TChartKindTraits.IncludesZeroBaseline(FPlot.Kind) then
    Result.Extend(0);
end;

function TValueAxisEngine.ComputeSimpleValueRange: TValueRange;
begin
  Result := TValueRange.Empty;
  for var CurrentSeries in FPlot.Series do
  begin
    Result.Extend(CurrentSeries.Values);

    if CurrentSeries.IsRangeBand then
      Result.Extend(CurrentSeries.EndValues);
  end;
end;

function TValueAxisEngine.ComputeStackedValueRange: TValueRange;
begin
  Result := TValueRange.Empty;

  for var CategoryIndex := 0 to High(FPlot.Categories) do
  begin
    var PositiveSum := 0.0;
    var NegativeSum := 0.0;
    for var CurrentSeries in FPlot.Series do
    begin
      const Value = CurrentSeries.Values[CategoryIndex];
      if Value >= 0 then
        PositiveSum := PositiveSum + Value
      else
        NegativeSum := NegativeSum + Value;
    end;

    Result.Extend(PositiveSum);
    Result.Extend(NegativeSum);
  end;
end;

function TValueAxisEngine.ComputeDumbbellValueRange: TValueRange;
begin
  const DumbbellSeries = FPlot.Series[0];

  Result := TValueRange.Empty;
  Result.Extend(DumbbellSeries.Values);
  Result.Extend(DumbbellSeries.EndValues);
end;

function TValueAxisEngine.ApplyHeadroom(const Range: TValueRange): TValueRange;
begin
  Result := Range;
  const Headroom = 0.04 * Range.Span;

  Result.Max := Range.Max + Headroom;

  const MinIsAutomatic = IsNaN(FPlot.YAxis.MinValue);
  const ShouldExtendBelow = TChartKindTraits.MarksPositionNotBaseline(FPlot.Kind) and MinIsAutomatic;
  if ShouldExtendBelow then
    Result.Min := Range.Min - Headroom;
end;

function TValueAxisEngine.ComputeValueBreaks(const Range: TValueRange): TArray<Double>;
begin
  if FPlot.YAxis.HasManualBreaks then
    Result := FPlot.YAxis.Breaks
  else
    Result := TAxisScale.NiceBreaks(Range.Min, Range.Max);
end;

constructor TLegendEngine.Create(const Plot: TChartPlot; const Canvas: IChartCanvas; const Style: TChartStyle);
begin
  inherited Create;
  FPlot := Plot;
  FCanvas := Canvas;
  FStyle := Style;
end;

function TLegendEngine.BuildItems: TArray<TLegendItem>;
begin
  var Items: TArray<TLegendItem>;
  if TChartKindTraits.IsCircular(FPlot.Kind) then
    Items := BuildCategoryLegendItems
  else
    Items := BuildSeriesLegendItems;

  if FPlot.LegendReversed then
    Result := ReverseLegendItems(Items)
  else
    Result := Items;
end;

function TLegendEngine.BuildSeriesLegendItems: TArray<TLegendItem>;
begin
  Result := [];
  for var Index := 0 to FPlot.Series.Count - 1 do
  begin
    const CurrentSeries = FPlot.Series[Index];
    const HasName = (CurrentSeries.Name <> '');
    if HasName then
      Result := Result + [TLegendItem.Create(CurrentSeries.Name, FPlot.SeriesColor(Index))];
  end;
end;

function TLegendEngine.BuildCategoryLegendItems: TArray<TLegendItem>;
begin
  SetLength(Result, Length(FPlot.Categories));
  for var Index := 0 to High(FPlot.Categories) do
  begin
    Result[Index] := TLegendItem.Create(FPlot.Categories[Index], FPlot.CategoryColor(Index));
  end;
end;

function TLegendEngine.ReverseLegendItems(const Items: TArray<TLegendItem>): TArray<TLegendItem>;
begin
  Result := TChartArray.Reversed<TLegendItem>(Items);
end;

function TLegendEngine.ApplyLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
begin
  case FPlot.LegendPosition of
    TLegendPosition.Top    : Result := ApplyTopLegendLayout(ContentRect, Items);
    TLegendPosition.Bottom : Result := ApplyBottomLegendLayout(ContentRect, Items);
    TLegendPosition.Left   : Result := ApplyLeftLegendLayout(ContentRect, Items);
    TLegendPosition.Right  : Result := ApplyRightLegendLayout(ContentRect, Items);
  else
    Result := ContentRect;
  end;
end;

function TLegendEngine.ApplyTopLegendLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
begin
  const LegendBottom = DrawHorizontalLegend(Items, ContentRect, ContentRect.Top);

  Result := ContentRect;
  Result.Top := LegendBottom + LegendGap;
end;

function TLegendEngine.ApplyBottomLegendLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
begin
  const LegendHeight = MeasureHorizontalLegendHeight(Items, ContentRect.Width);
  const LegendTop = ContentRect.Bottom - LegendHeight;
  DrawHorizontalLegend(Items, ContentRect, LegendTop);

  Result := ContentRect;
  Result.Bottom := LegendTop - LegendGap;
end;

function TLegendEngine.ApplyLeftLegendLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
begin
  const LegendWidth = MeasureVerticalLegendWidth(Items);
  DrawVerticalLegend(Items, ContentRect.Left, ContentRect.Top);

  Result := ContentRect;
  Result.Left := ContentRect.Left + LegendWidth + LegendGap;
end;

function TLegendEngine.ApplyRightLegendLayout(const ContentRect: TRectF; const Items: TArray<TLegendItem>): TRectF;
begin
  const LegendWidth = MeasureVerticalLegendWidth(Items);
  const LegendX = ContentRect.Right - LegendWidth;
  DrawVerticalLegend(Items, LegendX, ContentRect.Top);

  Result := ContentRect;
  Result.Right := LegendX - LegendGap;
end;

function TLegendEngine.ComputeLegendRows(const Items: TArray<TLegendItem>; const AvailableWidth: Single): TArray<TLegendRow>;
begin
  const SwatchSize = LegendSwatchSize;
  const SwatchTextGap = LegendSwatchTextGap;
  const ItemGap = LegendItemGap;
  const TextStyle = LegendTextStyle;

  var Rows: TArray<TLegendRow> := [];
  var RowStart := 0;
  var RowHeight := SwatchSize;
  var CursorX: Single := 0;

  for var Index := 0 to High(Items) do
  begin
    const TextSize = FCanvas.MeasureText(Items[Index].Name, TextStyle);
    const ItemWidth = SwatchSize + SwatchTextGap + TextSize.Width;

    const NeedsWrap = (CursorX > 0) and (CursorX + ItemWidth > AvailableWidth);
    if NeedsWrap then
    begin
      Rows := Rows + [TLegendRow.Create(RowStart, Index - 1, RowHeight)];
      RowStart := Index;
      CursorX := 0;
      RowHeight := SwatchSize;
    end;

    RowHeight := Max(RowHeight, TextSize.Height);
    CursorX := CursorX + ItemWidth + ItemGap;
  end;

  const HasItems = (Length(Items) > 0);
  if HasItems then
    Rows := Rows + [TLegendRow.Create(RowStart, High(Items), RowHeight)];

  Result := Rows;
end;

function TLegendEngine.DrawHorizontalLegend(const Items: TArray<TLegendItem>; const Bounds: TRectF; const StartY: Single): Single;
begin
  const Rows = ComputeLegendRows(Items, Bounds.Width);
  const RowSpacing = LegendRowSpacing;

  var CursorY := StartY;
  for var Row in Rows do
  begin
    DrawLegendRowItems(Items, Row, Bounds.Left, CursorY);
    CursorY := CursorY + Row.Height + RowSpacing;
  end;

  Result := CursorY - RowSpacing;
end;

procedure TLegendEngine.DrawLegendRowItems(const Items: TArray<TLegendItem>; const Row: TLegendRow; const StartX, RowY: Single);
begin
  const SwatchSize = LegendSwatchSize;
  const SwatchTextGap = LegendSwatchTextGap;
  const ItemGap = LegendItemGap;
  const TextStyle = LegendTextStyle;

  var CursorX := StartX;
  for var Index := Row.StartIndex to Row.EndIndex do
  begin
    DrawLegendItem(Items[Index], CursorX, RowY, SwatchSize, TextStyle);
    const TextSize = FCanvas.MeasureText(Items[Index].Name, TextStyle);
    CursorX := CursorX + SwatchSize + SwatchTextGap + TextSize.Width + ItemGap;
  end;
end;

function TLegendEngine.MeasureHorizontalLegendHeight(const Items: TArray<TLegendItem>; const AvailableWidth: Single): Single;
begin
  const Rows = ComputeLegendRows(Items, AvailableWidth);
  const RowSpacing = LegendRowSpacing;

  Result := 0;
  for var Row in Rows do
  begin
    Result := Result + Row.Height + RowSpacing;
  end;

  const HasRows = (Length(Rows) > 0);
  if HasRows then
    Result := Result - RowSpacing;
end;

function TLegendEngine.DrawVerticalLegend(const Items: TArray<TLegendItem>; const X, StartY: Single): Single;
begin
  const SwatchSize = LegendSwatchSize;
  const RowGap = LegendRowSpacing;
  const TextStyle = LegendTextStyle;

  var CursorY := StartY;
  for var Item in Items do
  begin
    DrawLegendItem(Item, X, CursorY, SwatchSize, TextStyle);
    const TextSize = FCanvas.MeasureText(Item.Name, TextStyle);
    const RowHeight = Max(SwatchSize, TextSize.Height);
    CursorY := CursorY + RowHeight + RowGap;
  end;

  Result := CursorY;
end;

function TLegendEngine.MeasureVerticalLegendWidth(const Items: TArray<TLegendItem>): Single;
begin
  const SwatchSize = LegendSwatchSize;
  const SwatchTextGap = LegendSwatchTextGap;
  const TextStyle = LegendTextStyle;

  Result := 0;
  for var Item in Items do
  begin
    const TextSize = FCanvas.MeasureText(Item.Name, TextStyle);
    Result := Max(Result, SwatchSize + SwatchTextGap + TextSize.Width);
  end;
end;

procedure TLegendEngine.DrawLegendItem(const Item: TLegendItem; const X, Y, SwatchSize: Single; const TextStyle: TChartTextStyle);
begin
  FCanvas.FillRect(TRectF.Create(X, Y, X + SwatchSize, Y + SwatchSize), Item.Color);
  FCanvas.DrawText(X + SwatchSize + LegendSwatchTextGap, Y, Item.Name, TextStyle, TTextAlignH.Left, TTextAlignV.Top);
end;

function TLegendEngine.LegendTextStyle: TChartTextStyle;
begin
  Result := TChartTextStyle.Create(FStyle.FontName, FStyle.LegendFontSize, False, FStyle.TextColor);
end;

function TLegendEngine.LegendSwatchSize: Single;
begin
  Result := 14 * FStyle.ScaleFactor;
end;

function TLegendEngine.LegendSwatchTextGap: Single;
begin
  Result := 6 * FStyle.ScaleFactor;
end;

function TLegendEngine.LegendItemGap: Single;
begin
  Result := 24 * FStyle.ScaleFactor;
end;

function TLegendEngine.LegendRowSpacing: Single;
begin
  Result := 6 * FStyle.ScaleFactor;
end;

function TLegendEngine.LegendGap: Single;
begin
  Result := 12 * FStyle.ScaleFactor;
end;

constructor TChartArrowPainter.Create(const Canvas: IChartCanvas; const ScaleFactor: Single);
begin
  inherited Create;
  FCanvas := Canvas;
  FScaleFactor := ScaleFactor;
end;

procedure TChartArrowPainter.Draw(const StartPoint, EndPoint: TPointF; const Color: TAlphaColor;
                                  const Width: Single; const Dashed: Boolean);
begin
  DrawShaft(StartPoint, EndPoint, Color, Width, Dashed);
  DrawHead(StartPoint, EndPoint, Color);
end;

function TChartArrowPainter.HeadLength: Single;
begin
  Result := 10 * FScaleFactor;
end;

function TChartArrowPainter.HeadAngle: Single;
begin
  Result := DegToRad(25);
end;

function TChartArrowPainter.HeadDepth: Single;
begin
  Result := HeadLength * Cos(HeadAngle);
end;

procedure TChartArrowPainter.DrawShaft(const StartPoint, EndPoint: TPointF; const Color: TAlphaColor;
                                       const Width: Single; const Dashed: Boolean);
begin
  const DeltaX = EndPoint.X - StartPoint.X;
  const DeltaY = EndPoint.Y - StartPoint.Y;
  const Distance = Sqrt(Sqr(DeltaX) + Sqr(DeltaY));

  const HeadCoversTheWholeArrow = (Distance <= HeadDepth);
  if HeadCoversTheWholeArrow then
    Exit;

  const ShaftFraction = (Distance - HeadDepth) / Distance;
  const ShaftEndX = StartPoint.X + DeltaX * ShaftFraction;
  const ShaftEndY = StartPoint.Y + DeltaY * ShaftFraction;

  FCanvas.DrawLine(StartPoint.X, StartPoint.Y, ShaftEndX, ShaftEndY, Color, Width, Dashed);
end;

procedure TChartArrowPainter.DrawHead(const StartPoint, EndPoint: TPointF; const Color: TAlphaColor);
begin
  const ArrowLength = HeadLength;
  const ArrowAngle = HeadAngle;
  const LineAngle = ArcTan2(EndPoint.Y - StartPoint.Y, EndPoint.X - StartPoint.X);

  const LeftWing = TPointF.Create(
    EndPoint.X - ArrowLength * Cos(LineAngle - ArrowAngle),
    EndPoint.Y - ArrowLength * Sin(LineAngle - ArrowAngle));
  const RightWing = TPointF.Create(
    EndPoint.X - ArrowLength * Cos(LineAngle + ArrowAngle),
    EndPoint.Y - ArrowLength * Sin(LineAngle + ArrowAngle));

  FCanvas.FillPolygon([EndPoint, LeftWing, RightWing], Color);
end;

constructor TChartGeometry.Create(const Plot: TChartPlot; const CategoryCount: Integer);
begin
  inherited Create;
  FPlot := Plot;
  FIsHorizontal := (Plot.Orientation = TChartOrientation.Horizontal);
  FIsContinuousX := TChartKindTraits.UsesContinuousX(Plot.Kind);
  FCategoryCount := CategoryCount;
end;

procedure TChartGeometry.Build(const PlotBounds: TRectF; const ValueRange, XRange: TValueRange);
begin
  FPlotBounds := PlotBounds;

  BuildValueMapper(ValueRange);
  if FIsContinuousX then
    BuildXMapper(XRange)
  else
    BuildCategoryMapper;
end;

procedure TChartGeometry.BuildValueMapper(const ValueRange: TValueRange);
begin
  var MapperRange := ValueRange;
  if FPlot.YAxis.IsLogarithmic then
    MapperRange := TValueRange.Create(LogN(FPlot.YAxis.LogBase, ValueRange.Min),
                                      LogN(FPlot.YAxis.LogBase, ValueRange.Max));

  if FIsHorizontal then
    FValueMapper := TLinearMapper.Create(MapperRange.Min, MapperRange.Max,
                                         FPlotBounds.Left, FPlotBounds.Right, False)
  else
    FValueMapper := TLinearMapper.Create(MapperRange.Min, MapperRange.Max,
                                         FPlotBounds.Top, FPlotBounds.Bottom, True);
end;

procedure TChartGeometry.BuildCategoryMapper;
begin
  var CategoryAxisLength: Single;
  if FIsHorizontal then
  begin
    FCategoryStart := FPlotBounds.Top;
    CategoryAxisLength := FPlotBounds.Height;
  end
  else
  begin
    FCategoryStart := FPlotBounds.Left;
    CategoryAxisLength := FPlotBounds.Width;
  end;

  const HasCategories = (FCategoryCount > 0);
  if HasCategories then
    FCategoryBand := CategoryAxisLength / FCategoryCount
  else
    FCategoryBand := 0;
end;

procedure TChartGeometry.BuildXMapper(const XRange: TValueRange);
begin
  if FIsHorizontal then
    FXMapper := TLinearMapper.Create(XRange.Min, XRange.Max, FPlotBounds.Top, FPlotBounds.Bottom, False)
  else
    FXMapper := TLinearMapper.Create(XRange.Min, XRange.Max, FPlotBounds.Left, FPlotBounds.Right, False);
end;

function TChartGeometry.MapValue(const Value: Double): Single;
begin
  if not FPlot.YAxis.IsLogarithmic then
    Exit(FValueMapper.Map(Value));

  const HasNoLogSpaceValue = (Value <= 0);
  if HasNoLogSpaceValue then
    Exit(FValueMapper.Map(FValueMapper.DataMin));

  Result := FValueMapper.Map(LogN(FPlot.YAxis.LogBase, Value));
end;

function TChartGeometry.MapX(const Value: Double): Single;
begin
  Result := FXMapper.Map(Value);
end;

function TChartGeometry.CategoryCenter(const Index: Integer): Single;
begin
  Result := FCategoryStart + (Index + 0.5) * FCategoryBand;
end;

function TChartGeometry.CategoryAxisPixel(const Coordinate: Double): Single;
begin
  if FIsContinuousX then
    Result := MapX(Coordinate)
  else
    Result := FCategoryStart + (Coordinate + 0.5) * FCategoryBand;
end;

function TChartGeometry.CategoryValuePoint(const CategoryPixel: Single; const Value: Double): TPointF;
begin
  const ValuePixel = MapValue(Value);
  if FIsHorizontal then
    Result := TPointF.Create(ValuePixel, CategoryPixel)
  else
    Result := TPointF.Create(CategoryPixel, ValuePixel);
end;

function TChartGeometry.XYPoint(const X, Y: Double): TPointF;
begin
  Result := CategoryValuePoint(MapX(X), Y);
end;

function TChartGeometry.OffsetAlongValueAxis(const Point: TPointF; const Amount: Single): TPointF;
begin
  if FIsHorizontal then
    Result := TPointF.Create(Point.X + Amount, Point.Y)
  else
    Result := TPointF.Create(Point.X, Point.Y + Amount);
end;

function TChartGeometry.BarBounds(const CategoryPixel, BarWidth, ValuePixel, BaselinePixel: Single): TRectF;
begin
  const LowPixel = Min(ValuePixel, BaselinePixel);
  const HighPixel = Max(ValuePixel, BaselinePixel);

  if FIsHorizontal then
    Result := TRectF.Create(LowPixel, CategoryPixel - BarWidth / 2, HighPixel, CategoryPixel + BarWidth / 2)
  else
    Result := TRectF.Create(CategoryPixel - BarWidth / 2, LowPixel, CategoryPixel + BarWidth / 2, HighPixel);
end;

function TChartGeometry.CategoryBarWidth: Single;
begin
  Result := 0.7 * FCategoryBand;
end;

class function TChartGeometry.EffectiveXValues(const Series: TChartSeries): TArray<Double>;
begin
  const HasExplicitX = (Length(Series.XValues) > 0);
  if HasExplicitX then
    Exit(Series.XValues);

  SetLength(Result, Length(Series.Values));
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := Index;
  end;
end;

function TChartGeometry.SeriesPoints(const Series: TChartSeries; const Values: TArray<Double>): TArray<TPointF>;
begin
  const XValues = EffectiveXValues(Series);
  SetLength(Result, Length(Values));
  for var Index := 0 to High(Values) do
  begin
    Result[Index] := XYPoint(XValues[Index], Values[Index]);
  end;
end;

function TChartGeometry.SeriesLinePoints(const Series: TChartSeries): TArray<TPointF>;
begin
  Result := SeriesPoints(Series, Series.Values);
end;

function TChartGeometry.SeriesHighPoints(const Series: TChartSeries): TArray<TPointF>;
begin
  Result := SeriesPoints(Series, Series.EndValues);
end;

function TChartGeometry.AreaPolygonPoints(const LinePoints: TArray<TPointF>;
                                          const BaselinePixel: Single): TArray<TPointF>;
begin
  const LastPoint = LinePoints[High(LinePoints)];
  const FirstPoint = LinePoints[0];

  var Closing: TArray<TPointF>;
  if FIsHorizontal then
    Closing := [TPointF.Create(BaselinePixel, LastPoint.Y), TPointF.Create(BaselinePixel, FirstPoint.Y)]
  else
    Closing := [TPointF.Create(LastPoint.X, BaselinePixel), TPointF.Create(FirstPoint.X, BaselinePixel)];

  Result := LinePoints + Closing;
end;

class function TChartGeometry.BandPolygonPoints(const LowPoints, HighPoints: TArray<TPointF>): TArray<TPointF>;
begin
  Result := LowPoints + TChartArray.Reversed<TPointF>(HighPoints);
end;

constructor TChartSeriesRenderer.Create(const Context: TChartDrawContext);
begin
  inherited Create;
  FPlot := Context.Plot;
  FCanvas := Context.Canvas;
  FStyle := Context.Style;
  FGeometry := Context.Geometry;
  FHitMap := Context.HitMap;
  FArrows := Context.Arrows;
  FLabelClampBounds := Context.LabelClampBounds;
end;

class function TChartSeriesRenderer.CreateFor(const Context: TChartDrawContext): TChartSeriesRenderer;
begin
  case Context.Plot.Kind of
    TChartKind.Line       : Result := TLineSeriesRenderer.Create(Context);
    TChartKind.Area       : Result := TAreaSeriesRenderer.Create(Context);
    TChartKind.Scatter    : Result := TScatterSeriesRenderer.Create(Context);
    TChartKind.DotPlot    : Result := TDotPlotSeriesRenderer.Create(Context);
    TChartKind.Bar        : Result := TBarSeriesRenderer.Create(Context);
    TChartKind.Histogram  : Result := THistogramSeriesRenderer.Create(Context);
    TChartKind.GroupedBar : Result := TGroupedBarSeriesRenderer.Create(Context);
    TChartKind.StackedBar : Result := TStackedBarSeriesRenderer.Create(Context);
    TChartKind.Dumbbell   : Result := TDumbbellSeriesRenderer.Create(Context);
    TChartKind.Range      : Result := TRangeSeriesRenderer.Create(Context);
    TChartKind.Arrow      : Result := TArrowSeriesRenderer.Create(Context);
    TChartKind.Pie,
    TChartKind.Donut      : Result := TCircularSeriesRenderer.Create(Context);
  else
    raise ENotSupportedException.CreateFmt('Unsupported chart kind: %d', [Ord(Context.Plot.Kind)]);
  end;
end;

function TChartSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  Result := [];
end;

function TChartSeriesRenderer.CategoryLabel(const Index: Integer): string;
begin
  Result := FPlot.Categories[Index];
end;

function TChartSeriesRenderer.ContinuousPointLabel(const XValue: Double): string;
begin
  Result := TAxisScale.FormatValue(XValue, FPlot.XAxis.UseThousandSeparator);
end;

function TChartSeriesRenderer.ValueLabelOffset: Single;
begin
  Result := ValueLabelOffsetAtReferenceScale * FStyle.ScaleFactor;
end;

function TChartSeriesRenderer.ValueLabelLineOffset: TPointF;
begin
  const Amount = ValueLabelOffset;
  if FGeometry.IsHorizontal then
    Result := TPointF.Create(Amount, 0)
  else
    Result := TPointF.Create(0, -Amount);
end;

function TChartSeriesRenderer.BarValueLabelPoint(const CategoryPixel, ValuePixel, BaselinePixel: Single): TPointF;
begin
  const AwayFromBaselineSign = Sign(ValuePixel - BaselinePixel);

  var BasePoint: TPointF;
  if FGeometry.IsHorizontal then
    BasePoint := TPointF.Create(ValuePixel, CategoryPixel)
  else
    BasePoint := TPointF.Create(CategoryPixel, ValuePixel);

  Result := FGeometry.OffsetAlongValueAxis(BasePoint, AwayFromBaselineSign * ValueLabelOffset);
end;

function TChartSeriesRenderer.OffsetPointGroup(const Points: TArray<TPointF>;
                                               const Values: TArray<Double>): TArray<TValueLabelCandidate>;
begin
  const Offset = ValueLabelLineOffset;

  SetLength(Result, Length(Points));
  for var Index := 0 to High(Points) do
  begin
    Result[Index].AnchorPoint := TPointF.Create(Points[Index].X + Offset.X, Points[Index].Y + Offset.Y);
    Result[Index].Value := Values[Index];
  end;
end;

function TChartSeriesRenderer.PairedEndGroups(const Series: TChartSeries): TArray<TArray<TValueLabelCandidate>>;
begin
  const Amount = ValueLabelOffset;

  var StartGroup: TArray<TValueLabelCandidate>;
  var EndGroup: TArray<TValueLabelCandidate>;
  SetLength(StartGroup, Length(Series.Values));
  SetLength(EndGroup, Length(Series.Values));

  for var Index := 0 to High(Series.Values) do
  begin
    const CategoryPixel = FGeometry.CategoryCenter(Index);
    const StartValue = Series.Values[Index];
    const EndValue = Series.EndValues[Index];
    const AwayFromStartSign = Sign(FGeometry.MapValue(EndValue) - FGeometry.MapValue(StartValue));

    StartGroup[Index].AnchorPoint := FGeometry.OffsetAlongValueAxis(
      FGeometry.CategoryValuePoint(CategoryPixel, StartValue), -AwayFromStartSign * Amount);
    StartGroup[Index].Value := StartValue;

    EndGroup[Index].AnchorPoint := FGeometry.OffsetAlongValueAxis(
      FGeometry.CategoryValuePoint(CategoryPixel, EndValue), AwayFromStartSign * Amount);
    EndGroup[Index].Value := EndValue;
  end;

  Result := [StartGroup, EndGroup];
end;

procedure TChartSeriesRenderer.DrawBar(const SeriesIndex, CategoryIndex: Integer; const SeriesName: string;
                                       const CategoryPixel: Single; const Value: Double; const Color: TAlphaColor;
                                       const BarWidth: Single);
begin
  const BaselinePixel = FGeometry.MapValue(0);
  const Bounds = FGeometry.BarBounds(CategoryPixel, BarWidth, FGeometry.MapValue(Value), BaselinePixel);
  FCanvas.FillRect(Bounds, Color);

  const AnchorPoint = FGeometry.CategoryValuePoint(CategoryPixel, Value);
  const Info = TChartHitMap.BuildInfo(SeriesIndex, CategoryIndex, SeriesName, CategoryLabel(CategoryIndex),
                                      Value, AnchorPoint, Color);
  FHitMap.AddRect(Bounds, Info);
end;

procedure TChartSeriesRenderer.DrawSingleSeriesBars(const BarWidth: Single);
begin
  const BarSeries = FPlot.Series[0];
  const Color = FPlot.SeriesColor(0);

  for var Index := 0 to High(BarSeries.Values) do
  begin
    DrawBar(0, Index, BarSeries.Name, FGeometry.CategoryCenter(Index), BarSeries.Values[Index], Color, BarWidth);
  end;
end;

function TChartSeriesRenderer.SingleSeriesBarGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  const BarSeries = FPlot.Series[0];
  const BaselinePixel = FGeometry.MapValue(0);

  var Group: TArray<TValueLabelCandidate>;
  SetLength(Group, Length(BarSeries.Values));
  for var Index := 0 to High(BarSeries.Values) do
  begin
    const ValuePixel = FGeometry.MapValue(BarSeries.Values[Index]);
    Group[Index].AnchorPoint := BarValueLabelPoint(FGeometry.CategoryCenter(Index), ValuePixel, BaselinePixel);
    Group[Index].Value := BarSeries.Values[Index];
  end;

  Result := [Group];
end;

procedure TXYSeriesRenderer.AddPointHitTargets(const SeriesIndex: Integer; const Series: TChartSeries;
                                               const Points: TArray<TPointF>; const Color: TAlphaColor);
begin
  const XValues = TChartGeometry.EffectiveXValues(Series);
  for var Index := 0 to High(Points) do
  begin
    const Info = TChartHitMap.BuildInfo(SeriesIndex, Index, Series.Name, ContinuousPointLabel(XValues[Index]),
                                        Series.Values[Index], Points[Index], Color);
    FHitMap.AddCircle(Points[Index], Info);
  end;
end;

/// <summary>
/// One label group per ordinary series. A range band draws no marks of its own, so it
/// contributes no value-label candidates either.
/// </summary>
function TXYSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  Result := [];
  for var SeriesIndex := 0 to FPlot.Series.Count - 1 do
  begin
    const CurrentSeries = FPlot.Series[SeriesIndex];
    if CurrentSeries.IsRangeBand then
      Continue;

    Result := Result + [OffsetPointGroup(FGeometry.SeriesLinePoints(CurrentSeries), CurrentSeries.Values)];
  end;
end;

/// <summary>
/// Draws every series. Range bands go first, in a pass of their own, so that a shaded band
/// always ends up behind every line rather than on top of the ones that happen to be
/// declared before it.
/// </summary>
procedure TLineAreaSeriesRenderer.Draw;
begin
  for var Index := 0 to FPlot.Series.Count - 1 do
  begin
    const CurrentSeries = FPlot.Series[Index];
    if CurrentSeries.IsRangeBand then
      DrawRangeBand(Index, CurrentSeries, FPlot.SeriesColor(Index));
  end;

  for var Index := 0 to FPlot.Series.Count - 1 do
  begin
    const CurrentSeries = FPlot.Series[Index];
    if not CurrentSeries.IsRangeBand then
      DrawMark(Index, CurrentSeries, FPlot.SeriesColor(Index));
  end;
end;

procedure TLineAreaSeriesRenderer.DrawRangeBand(const SeriesIndex: Integer; const Series: TChartSeries;
                                                const Color: TAlphaColor);
begin
  const LowPoints = FGeometry.SeriesLinePoints(Series);
  const HasPoints = (Length(LowPoints) > 0);
  if not HasPoints then
    Exit;

  const HighPoints = FGeometry.SeriesHighPoints(Series);
  FCanvas.FillPolygon(TChartGeometry.BandPolygonPoints(LowPoints, HighPoints), Color);

  const XValues = TChartGeometry.EffectiveXValues(Series);
  for var Index := 0 to High(LowPoints) do
  begin
    const PointLabel = ContinuousPointLabel(XValues[Index]);

    const LowInfo = TChartHitMap.BuildInfo(SeriesIndex, Index, Series.Name, PointLabel,
                                           Series.Values[Index], LowPoints[Index], Color);
    FHitMap.AddCircle(LowPoints[Index], LowInfo);

    const HighInfo = TChartHitMap.BuildInfo(SeriesIndex, Index, Series.Name, PointLabel,
                                            Series.EndValues[Index], HighPoints[Index], Color);
    FHitMap.AddCircle(HighPoints[Index], HighInfo);
  end;
end;

procedure TLineSeriesRenderer.DrawMark(const SeriesIndex: Integer; const Series: TChartSeries;
                                       const Color: TAlphaColor);
begin
  const Points = FGeometry.SeriesLinePoints(Series);
  FCanvas.DrawPolyline(Points, Color, FStyle.SeriesLineWidth);
  AddPointHitTargets(SeriesIndex, Series, Points, Color);
end;

procedure TAreaSeriesRenderer.DrawMark(const SeriesIndex: Integer; const Series: TChartSeries;
                                       const Color: TAlphaColor);
begin
  const LinePoints = FGeometry.SeriesLinePoints(Series);
  const HasPoints = (Length(LinePoints) > 0);
  if not HasPoints then
    Exit;

  FCanvas.FillPolygon(FGeometry.AreaPolygonPoints(LinePoints, FGeometry.MapValue(0)), Color);
  FCanvas.DrawPolyline(LinePoints, Color, FStyle.SeriesLineWidth);
  AddPointHitTargets(SeriesIndex, Series, LinePoints, Color);
end;

procedure TScatterSeriesRenderer.Draw;
begin
  const SizeDomain = ComputeSizeDomain;
  for var Index := 0 to FPlot.Series.Count - 1 do
  begin
    DrawPoints(Index, FPlot.Series[Index], FPlot.SeriesColor(Index), SizeDomain);
  end;
end;

function TScatterSeriesRenderer.ComputeSizeDomain: TValueRange;
begin
  Result := TValueRange.Empty;
  for var CurrentSeries in FPlot.Series do
  begin
    Result.Extend(CurrentSeries.Sizes);
  end;
end;

class function TScatterSeriesRenderer.PointDrawRadius(const Style: TChartStyle; const Series: TChartSeries;
                                                      const PointIndex: Integer;
                                                      const SizeDomain: TValueRange): Single;
begin
  const HasSizes = (Length(Series.Sizes) > 0);
  if not HasSizes then
    Exit(Style.ScatterPointRadius);

  const IsDegenerateDomain = SameValue(SizeDomain.Min, SizeDomain.Max);
  if IsDegenerateDomain then
    Exit((Style.MinBubbleRadius + Style.MaxBubbleRadius) / 2);

  const NormalizedSize = (Series.Sizes[PointIndex] - SizeDomain.Min) / SizeDomain.Span;
  Result := Style.MinBubbleRadius + (Style.MaxBubbleRadius - Style.MinBubbleRadius) * Sqrt(NormalizedSize);
end;

procedure TScatterSeriesRenderer.DrawPoints(const SeriesIndex: Integer; const Series: TChartSeries;
                                            const Color: TAlphaColor; const SizeDomain: TValueRange);
begin
  const Points = FGeometry.SeriesLinePoints(Series);
  const XValues = TChartGeometry.EffectiveXValues(Series);

  for var Index := 0 to High(Points) do
  begin
    const DrawnRadius = PointDrawRadius(FStyle, Series, Index, SizeDomain);
    FCanvas.FillCircle(Points[Index].X, Points[Index].Y, DrawnRadius, Color);

    const Info = TChartHitMap.BuildInfo(SeriesIndex, Index, Series.Name, ContinuousPointLabel(XValues[Index]),
                                        Series.Values[Index], Points[Index], Color);
    FHitMap.AddCircle(Points[Index], Info, Max(DrawnRadius, FHitMap.DefaultRadius));
  end;
end;

procedure TDotPlotSeriesRenderer.Draw;
begin
  for var Index := 0 to FPlot.Series.Count - 1 do
  begin
    DrawPoints(Index, FPlot.Series[Index], FPlot.SeriesColor(Index));
  end;
end;

function TDotPlotSeriesRenderer.SeriesPoints(const Series: TChartSeries): TArray<TPointF>;
begin
  SetLength(Result, Length(Series.Values));
  for var Index := 0 to High(Series.Values) do
  begin
    Result[Index] := FGeometry.CategoryValuePoint(FGeometry.CategoryCenter(Index), Series.Values[Index]);
  end;
end;

procedure TDotPlotSeriesRenderer.DrawPoints(const SeriesIndex: Integer; const Series: TChartSeries;
                                            const Color: TAlphaColor);
begin
  const Radius = FStyle.ScatterPointRadius;
  const HitRadius = Max(Radius, FHitMap.DefaultRadius);
  const Points = SeriesPoints(Series);

  for var CategoryIndex := 0 to High(Points) do
  begin
    const Point = Points[CategoryIndex];
    FCanvas.FillCircle(Point.X, Point.Y, Radius, Color);

    const Info = TChartHitMap.BuildInfo(SeriesIndex, CategoryIndex, Series.Name, CategoryLabel(CategoryIndex),
                                        Series.Values[CategoryIndex], Point, Color);
    FHitMap.AddCircle(Point, Info, HitRadius);
  end;
end;

function TDotPlotSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  SetLength(Result, FPlot.Series.Count);
  for var SeriesIndex := 0 to FPlot.Series.Count - 1 do
  begin
    const CurrentSeries = FPlot.Series[SeriesIndex];
    Result[SeriesIndex] := OffsetPointGroup(SeriesPoints(CurrentSeries), CurrentSeries.Values);
  end;
end;

procedure TBarSeriesRenderer.Draw;
begin
  DrawSingleSeriesBars(FGeometry.CategoryBarWidth);
end;

function TBarSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  Result := SingleSeriesBarGroups;
end;

/// <summary>
/// A histogram bin fills its whole band apart from a hairline gap on either side, because
/// adjacent bins are contiguous ranges rather than separate categories: a bar-chart gap
/// would read as a break in the distribution that the data does not have.
/// </summary>
function THistogramSeriesRenderer.BinWidth: Single;
begin
  const Gap = 1 * FStyle.ScaleFactor;
  Result := FGeometry.CategoryBand - (2 * Gap);
end;

procedure THistogramSeriesRenderer.Draw;
begin
  DrawSingleSeriesBars(BinWidth);
end;

function THistogramSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  Result := SingleSeriesBarGroups;
end;

function TGroupedBarSeriesRenderer.BarWidth: Single;
begin
  Result := FGeometry.CategoryBarWidth / FPlot.Series.Count;
end;

function TGroupedBarSeriesRenderer.SeriesOffset(const SeriesIndex: Integer): Single;
begin
  Result := -FGeometry.CategoryBarWidth / 2 + (SeriesIndex + 0.5) * BarWidth;
end;

procedure TGroupedBarSeriesRenderer.Draw;
begin
  for var SeriesIndex := 0 to FPlot.Series.Count - 1 do
  begin
    DrawSet(SeriesIndex);
  end;
end;

procedure TGroupedBarSeriesRenderer.DrawSet(const SeriesIndex: Integer);
begin
  const GroupedSeries = FPlot.Series[SeriesIndex];
  const Color = FPlot.SeriesColor(SeriesIndex);
  const Offset = SeriesOffset(SeriesIndex);

  for var CategoryIndex := 0 to High(GroupedSeries.Values) do
  begin
    const CategoryPixel = FGeometry.CategoryCenter(CategoryIndex) + Offset;
    DrawBar(SeriesIndex, CategoryIndex, GroupedSeries.Name, CategoryPixel,
            GroupedSeries.Values[CategoryIndex], Color, BarWidth);
  end;
end;

function TGroupedBarSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  const BaselinePixel = FGeometry.MapValue(0);

  SetLength(Result, FPlot.Series.Count);
  for var SeriesIndex := 0 to FPlot.Series.Count - 1 do
  begin
    const GroupedSeries = FPlot.Series[SeriesIndex];
    const Offset = SeriesOffset(SeriesIndex);

    var Group: TArray<TValueLabelCandidate>;
    SetLength(Group, Length(GroupedSeries.Values));
    for var CategoryIndex := 0 to High(GroupedSeries.Values) do
    begin
      const CategoryPixel = FGeometry.CategoryCenter(CategoryIndex) + Offset;
      const ValuePixel = FGeometry.MapValue(GroupedSeries.Values[CategoryIndex]);
      Group[CategoryIndex].AnchorPoint := BarValueLabelPoint(CategoryPixel, ValuePixel, BaselinePixel);
      Group[CategoryIndex].Value := GroupedSeries.Values[CategoryIndex];
    end;
    Result[SeriesIndex] := Group;
  end;
end;

function TStackedBarSeriesRenderer.CategoryTotal(const CategoryIndex: Integer): Double;
begin
  Result := 0;
  for var CurrentSeries in FPlot.Series do
  begin
    Result := Result + CurrentSeries.Values[CategoryIndex];
  end;
end;

function TStackedBarSeriesRenderer.SegmentValue(const RawValue, Total: Double): Double;
begin
  const IsProportions = (FPlot.StackMode = TStackMode.Proportions);
  if not IsProportions then
    Exit(RawValue);

  const HasZeroTotal = SameValue(Total, 0);
  if HasZeroTotal then
    Exit(0);

  Result := RawValue / Total;
end;

procedure TStackedBarSeriesRenderer.Draw;
begin
  const BarWidth = FGeometry.CategoryBarWidth;
  for var CategoryIndex := 0 to FGeometry.CategoryCount - 1 do
  begin
    DrawColumn(CategoryIndex, BarWidth);
  end;
end;

procedure TStackedBarSeriesRenderer.DrawColumn(const CategoryIndex: Integer; const BarWidth: Single);
begin
  const CategoryPixel = FGeometry.CategoryCenter(CategoryIndex);
  const Total = CategoryTotal(CategoryIndex);

  var PositiveRunning := 0.0;
  var NegativeRunning := 0.0;
  for var SeriesIndex := 0 to FPlot.Series.Count - 1 do
  begin
    const StackedSeries = FPlot.Series[SeriesIndex];
    const RawValue = StackedSeries.Values[CategoryIndex];
    const Segment = SegmentValue(RawValue, Total);

    var StartValue: Double;
    if Segment >= 0 then
    begin
      StartValue := PositiveRunning;
      PositiveRunning := PositiveRunning + Segment;
    end
    else
    begin
      StartValue := NegativeRunning;
      NegativeRunning := NegativeRunning + Segment;
    end;

    DrawSegment(SeriesIndex, CategoryIndex, StackedSeries.Name, CategoryPixel, BarWidth,
                StartValue, StartValue + Segment, RawValue, FPlot.SeriesColor(SeriesIndex));
  end;
end;

procedure TStackedBarSeriesRenderer.DrawSegment(const SeriesIndex, CategoryIndex: Integer; const SeriesName: string;
                                                const CategoryPixel, BarWidth: Single;
                                                const StartValue, EndValue, RawValue: Double;
                                                const Color: TAlphaColor);
begin
  const Bounds = FGeometry.BarBounds(CategoryPixel, BarWidth,
                                     FGeometry.MapValue(StartValue), FGeometry.MapValue(EndValue));
  FCanvas.FillRect(Bounds, Color);

  const AnchorPoint = FGeometry.CategoryValuePoint(CategoryPixel, (StartValue + EndValue) / 2);
  const Info = TChartHitMap.BuildInfo(SeriesIndex, CategoryIndex, SeriesName, CategoryLabel(CategoryIndex),
                                      RawValue, AnchorPoint, Color);
  FHitMap.AddRect(Bounds, Info);
end;

function TStackedBarSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  const SeriesCount = FPlot.Series.Count;
  const BaselinePixel = FGeometry.MapValue(0);

  SetLength(Result, SeriesCount);
  for var SeriesIndex := 0 to SeriesCount - 1 do
  begin
    SetLength(Result[SeriesIndex], FGeometry.CategoryCount);
  end;

  for var CategoryIndex := 0 to FGeometry.CategoryCount - 1 do
  begin
    const CategoryPixel = FGeometry.CategoryCenter(CategoryIndex);
    const Total = CategoryTotal(CategoryIndex);

    var PositiveRunning := 0.0;
    var NegativeRunning := 0.0;
    for var SeriesIndex := 0 to SeriesCount - 1 do
    begin
      const RawValue = FPlot.Series[SeriesIndex].Values[CategoryIndex];
      const Segment = SegmentValue(RawValue, Total);

      var SegmentEnd: Double;
      if Segment >= 0 then
      begin
        PositiveRunning := PositiveRunning + Segment;
        SegmentEnd := PositiveRunning;
      end
      else
      begin
        NegativeRunning := NegativeRunning + Segment;
        SegmentEnd := NegativeRunning;
      end;

      Result[SeriesIndex][CategoryIndex].AnchorPoint :=
        BarValueLabelPoint(CategoryPixel, FGeometry.MapValue(SegmentEnd), BaselinePixel);
      Result[SeriesIndex][CategoryIndex].Value := RawValue;
    end;
  end;
end;

procedure TDumbbellSeriesRenderer.Draw;
begin
  const DumbbellSeries = FPlot.Series[0];
  const ConnectorWidth = 3 * FStyle.ScaleFactor;
  const CircleRadius = 5 * FStyle.ScaleFactor;

  for var Index := 0 to High(DumbbellSeries.Values) do
  begin
    DrawItem(Index, DumbbellSeries.Values[Index], DumbbellSeries.EndValues[Index], ConnectorWidth, CircleRadius);
  end;
end;

procedure TDumbbellSeriesRenderer.DrawItem(const CategoryIndex: Integer; const StartValue, EndValue: Double;
                                           const ConnectorWidth, CircleRadius: Single);
begin
  const CategoryPixel = FGeometry.CategoryCenter(CategoryIndex);
  const StartPoint = FGeometry.CategoryValuePoint(CategoryPixel, StartValue);
  const EndPoint = FGeometry.CategoryValuePoint(CategoryPixel, EndValue);

  FCanvas.DrawLine(StartPoint.X, StartPoint.Y, EndPoint.X, EndPoint.Y, ChartLightGrey, ConnectorWidth, False);
  FCanvas.FillCircle(StartPoint.X, StartPoint.Y, CircleRadius, ChartOrange);
  FCanvas.FillCircle(EndPoint.X, EndPoint.Y, CircleRadius, ChartBlue);

  const StartInfo = TChartHitMap.BuildInfo(0, CategoryIndex, '', CategoryLabel(CategoryIndex),
                                           StartValue, StartPoint, ChartOrange);
  FHitMap.AddCircle(StartPoint, StartInfo);

  const EndInfo = TChartHitMap.BuildInfo(0, CategoryIndex, '', CategoryLabel(CategoryIndex),
                                         EndValue, EndPoint, ChartBlue);
  FHitMap.AddCircle(EndPoint, EndInfo);
end;

function TDumbbellSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  Result := PairedEndGroups(FPlot.Series[0]);
end;

procedure TRangeSeriesRenderer.Draw;
begin
  const RangeSeries = FPlot.Series[0];
  const Color = FPlot.SeriesColor(0);
  const BarWidth = FGeometry.CategoryBarWidth;

  for var Index := 0 to High(RangeSeries.Values) do
  begin
    DrawItem(Index, RangeSeries.Name, RangeSeries.Values[Index], RangeSeries.EndValues[Index], Color, BarWidth);
  end;
end;

procedure TRangeSeriesRenderer.DrawItem(const CategoryIndex: Integer; const SeriesName: string;
                                        const LowValue, HighValue: Double; const Color: TAlphaColor;
                                        const BarWidth: Single);
begin
  const CategoryPixel = FGeometry.CategoryCenter(CategoryIndex);
  const Bounds = FGeometry.BarBounds(CategoryPixel, BarWidth,
                                     FGeometry.MapValue(HighValue), FGeometry.MapValue(LowValue));
  FCanvas.FillRect(Bounds, Color);

  const AnchorPoint = FGeometry.CategoryValuePoint(CategoryPixel, HighValue);
  const Info = TChartHitMap.BuildInfo(0, CategoryIndex, SeriesName, CategoryLabel(CategoryIndex),
                                      HighValue, AnchorPoint, Color);
  FHitMap.AddRect(Bounds, Info);
end;

function TRangeSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  Result := PairedEndGroups(FPlot.Series[0]);
end;

procedure TArrowSeriesRenderer.Draw;
begin
  const ArrowSeries = FPlot.Series[0];
  const Color = FPlot.SeriesColor(0);

  for var Index := 0 to High(ArrowSeries.Values) do
  begin
    DrawItem(Index, ArrowSeries.Name, ArrowSeries.Values[Index], ArrowSeries.EndValues[Index], Color);
  end;
end;

procedure TArrowSeriesRenderer.DrawItem(const CategoryIndex: Integer; const SeriesName: string;
                                        const StartValue, EndValue: Double; const Color: TAlphaColor);
begin
  const CategoryPixel = FGeometry.CategoryCenter(CategoryIndex);
  const StartPoint = FGeometry.CategoryValuePoint(CategoryPixel, StartValue);
  const EndPoint = FGeometry.CategoryValuePoint(CategoryPixel, EndValue);

  FArrows.Draw(StartPoint, EndPoint, Color, FStyle.SeriesLineWidth, False);

  const StartInfo = TChartHitMap.BuildInfo(0, CategoryIndex, SeriesName, CategoryLabel(CategoryIndex),
                                           StartValue, StartPoint, Color);
  FHitMap.AddCircle(StartPoint, StartInfo);

  const EndInfo = TChartHitMap.BuildInfo(0, CategoryIndex, SeriesName, CategoryLabel(CategoryIndex),
                                         EndValue, EndPoint, Color);
  FHitMap.AddCircle(EndPoint, EndInfo);
end;

/// <summary>
/// An arrow is labelled at its head only: the tail is where the value came from, and the
/// chart is about where it arrived. The head group is the second of the paired groups.
/// </summary>
function TArrowSeriesRenderer.BuildValueLabelGroups: TArray<TArray<TValueLabelCandidate>>;
begin
  Result := [PairedEndGroups(FPlot.Series[0])[1]];
end;

constructor TCircularSeriesRenderer.Create(const Context: TChartDrawContext);
begin
  inherited Create(Context);
  FLabelPlacer := TChartLabelPlacer.Create(Context.Canvas, Context.Style.ScaleFactor, Context.LabelClampBounds);
end;

destructor TCircularSeriesRenderer.Destroy;
begin
  FLabelPlacer.Free;
  inherited Destroy;
end;

procedure TCircularSeriesRenderer.Draw;
begin
  const PieSeries = FPlot.Series[0];
  const SeriesTotal = Total(PieSeries.Values);
  const IsDonut = (FPlot.Kind = TChartKind.Donut);
  const PieCenter = Center;
  const PieOuterRadius = OuterRadius;
  const PieInnerRadius = InnerRadius(PieOuterRadius);

  const HasZeroTotal = SameValue(SeriesTotal, 0);
  if not HasZeroTotal then
  begin
    var CumulativeValue := 0.0;
    for var Index := 0 to High(PieSeries.Values) do
    begin
      const Value = PieSeries.Values[Index];
      const SweepAngle = 360 * Value / SeriesTotal;
      const StartAngle = -90 + 360 * CumulativeValue / SeriesTotal;
      CumulativeValue := CumulativeValue + Value;

      const HasNoSweep = SameValue(SweepAngle, 0);
      if HasNoSweep then
        Continue;

      DrawWedge(Index, PieCenter, PieInnerRadius, PieOuterRadius, StartAngle, SweepAngle, IsDonut, Value, SeriesTotal);
    end;
  end;

  if IsDonut then
    DrawCenterText(PieCenter);
end;

function TCircularSeriesRenderer.Center: TPointF;
begin
  Result := FGeometry.PlotBounds.CenterPoint;
end;

function TCircularSeriesRenderer.OuterRadius: Single;
begin
  Result := Min(FGeometry.PlotBounds.Width, FGeometry.PlotBounds.Height) / 2;
end;

function TCircularSeriesRenderer.InnerRadius(const OuterRadius: Single): Single;
begin
  if FPlot.Kind = TChartKind.Donut then
    Result := OuterRadius * FStyle.DonutInnerRadiusFactor
  else
    Result := 0;
end;

function TCircularSeriesRenderer.Total(const Values: TArray<Double>): Double;
begin
  Result := 0;
  for var Value in Values do
  begin
    Result := Result + Value;
  end;
end;

function TCircularSeriesRenderer.SegmentCount(const SweepAngle: Single): Integer;
begin
  Result := Max(2, Ceil(SweepAngle / 6));
end;

function TCircularSeriesRenderer.ArcPoints(const Center: TPointF; const Radius, StartAngle, SweepAngle: Single;
                                           const SegmentCount: Integer): TArray<TPointF>;
begin
  SetLength(Result, SegmentCount + 1);
  for var Index := 0 to SegmentCount do
  begin
    const Angle = DegToRad(StartAngle + SweepAngle * Index / SegmentCount);
    Result[Index] := TPointF.Create(Center.X + Radius * Cos(Angle), Center.Y + Radius * Sin(Angle));
  end;
end;

procedure TCircularSeriesRenderer.DrawWedge(const CategoryIndex: Integer; const Center: TPointF;
                                            const InnerRadius, OuterRadius, StartAngle, SweepAngle: Single;
                                            const IsDonut: Boolean; const Value, Total: Double);
begin
  const Color = FPlot.CategoryColor(CategoryIndex);
  const Segments = SegmentCount(SweepAngle);

  var Points: TArray<TPointF>;
  if IsDonut then
    Points := ArcPoints(Center, OuterRadius, StartAngle, SweepAngle, Segments) +
              TChartArray.Reversed<TPointF>(ArcPoints(Center, InnerRadius, StartAngle, SweepAngle, Segments))
  else
    Points := [Center] + ArcPoints(Center, OuterRadius, StartAngle, SweepAngle, Segments);

  FCanvas.FillPolygon(Points, Color);

  const MidAngle = StartAngle + SweepAngle / 2;
  const LabelDistance = SegmentLabelDistance(InnerRadius, OuterRadius, IsDonut);
  const LabelPoint = PointAtAngle(Center, LabelDistance, MidAngle);
  const LabelText = Format('%s (%d%%)', [CategoryLabel(CategoryIndex), Round(100 * Value / Total)]);
  DrawSegmentLabel(LabelPoint, LabelText);

  const Info = TChartHitMap.BuildInfo(0, CategoryIndex, '', CategoryLabel(CategoryIndex),
                                      Value, LabelPoint, Color);
  FHitMap.AddSector(Center, InnerRadius, OuterRadius, StartAngle, SweepAngle, Info);
end;

function TCircularSeriesRenderer.SegmentLabelDistance(const InnerRadius, OuterRadius: Single;
                                                      const IsDonut: Boolean): Single;
begin
  if IsDonut then
    Result := (InnerRadius + OuterRadius) / 2
  else
    Result := 0.65 * OuterRadius;
end;

function TCircularSeriesRenderer.PointAtAngle(const Center: TPointF; const Distance, AngleDegrees: Single): TPointF;
begin
  const Angle = DegToRad(AngleDegrees);
  Result := TPointF.Create(Center.X + Distance * Cos(Angle), Center.Y + Distance * Sin(Angle));
end;

procedure TCircularSeriesRenderer.DrawCenterText(const Center: TPointF);
begin
  const HasCenterText = (FPlot.DonutCenterText <> '');
  if not HasCenterText then
    Exit;

  const TextStyle = TChartTextStyle.Create(FStyle.FontName, FStyle.TitleFontSize, False, FStyle.TitleColor);
  FCanvas.DrawText(Center.X, Center.Y, FPlot.DonutCenterText, TextStyle, TTextAlignH.Center, TTextAlignV.Middle);
end;

procedure TCircularSeriesRenderer.DrawSegmentLabel(const AnchorPoint: TPointF; const LabelText: string);
begin
  const TextStyle = TChartTextStyle.Create(FStyle.FontName, FStyle.AxisFontSize, False, FStyle.TextColor);
  FLabelPlacer.DrawIfClear(AnchorPoint, LabelText, TextStyle);
end;

class procedure TChartRenderer.Render(const Plot: TChartPlot; const Canvas: IChartCanvas;
                                      const Width, Height: Single);
begin
  var DiscardedHitMap: TArray<TChartHitTarget>;
  Render(Plot, Canvas, Width, Height, DiscardedHitMap);
end;

class procedure TChartRenderer.Render(const Plot: TChartPlot; const Canvas: IChartCanvas;
                                      const Width, Height: Single;
                                      out HitMap: TArray<TChartHitTarget>);
begin
  const Job = TChartRenderJob.Create(Plot, Canvas, Width, Height);
  try
    Job.Execute;
    HitMap := Job.HitMap.Targets;
  finally
    Job.Free;
  end;
end;

constructor TChartRenderJob.Create(const Plot: TChartPlot; const Canvas: IChartCanvas; const Width, Height: Single);
begin
  inherited Create;

  if Plot = nil then
    raise EChart4DException.Create(SRenderPlotRequired);
  if Canvas = nil then
    raise EChart4DException.Create(SRenderCanvasRequired);

  FPlot := Plot;
  FCanvas := Canvas;
  FWidth := Width;
  FHeight := Height;
  FStyle := BuildScaledStyle(Plot.Style);
  FHitMap := TChartHitMap.Create(DefaultHitTargetRadius * FStyle.ScaleFactor);
  FArrows := TChartArrowPainter.Create(Canvas, FStyle.ScaleFactor);
end;

destructor TChartRenderJob.Destroy;
begin
  FSeriesRenderer.Free;
  FArrows.Free;
  FGeometry.Free;
  FHitMap.Free;
  inherited Destroy;
end;

procedure TChartRenderJob.Execute;
begin
  { A plot with no series yet is a normal state for a control that paints before its
    first AddSeries, not an error: the render fills the background and stops, and the
    explicit export entry points (SaveToPng) guard against it themselves. }
  const HasNoSeries = (FPlot.Series.Count = 0);
  if HasNoSeries then
  begin
    FCanvas.FillBackground(FWidth, FHeight, FStyle.BackgroundColor);
    Exit;
  end;

  ValidateInput;

  if IsPieOrDonut then
  begin
    { Pie/Donut have no axes at all: title/subtitle/legend/footer layout is unchanged,
      but insets are always 0 (ComputeLeftInset/ComputeRightInset/ComputeBottomAxisLabelHeight
      guard on IsPieOrDonut), and ComputeValueAxis, ComputeCategoryAxis, DrawAxisLabels,
      DrawGrid and DrawValueLabels are skipped entirely: there is no value axis, category
      axis, gridlines, or baseline for a shape with no axes. Annotations are still
      supported, so ComputeCircularAnnotationSpace gives them a coordinate space of their
      own. See SPEC.md 4.23. }
    ComputeCircularAnnotationSpace;
    PerformLayout;
    BuildGeometry;
    BuildSeriesRenderer;
    DrawSeries;
    DrawAnnotations;
    DrawFooter;
    Exit;
  end;

  ComputeValueAxis;
  ComputeCategoryAxis;
  PerformLayout;
  BuildGeometry;
  BuildSeriesRenderer;
  DrawAxisLabels;
  DrawRangeOverlays;
  DrawGrid;
  DrawSeries;
  DrawValueLabels;
  DrawAnnotations;
  DrawFooter;
end;

function TChartRenderJob.BuildScaledStyle(const Style: TChartStyle): TChartStyle;
begin
  Result := Style;
  Result.TitleFontSize := Style.TitleFontSize * Style.ScaleFactor;
  Result.SubtitleFontSize := Style.SubtitleFontSize * Style.ScaleFactor;
  Result.LegendFontSize := Style.LegendFontSize * Style.ScaleFactor;
  Result.AxisFontSize := Style.AxisFontSize * Style.ScaleFactor;
  Result.CaptionFontSize := Style.CaptionFontSize * Style.ScaleFactor;
  Result.GridLineWidth := Style.GridLineWidth * Style.ScaleFactor;
  Result.BaselineWidth := Style.BaselineWidth * Style.ScaleFactor;
  Result.SeriesLineWidth := Style.SeriesLineWidth * Style.ScaleFactor;
  Result.ScatterPointRadius := Style.ScatterPointRadius * Style.ScaleFactor;
  Result.MinBubbleRadius := Style.MinBubbleRadius * Style.ScaleFactor;
  Result.MaxBubbleRadius := Style.MaxBubbleRadius * Style.ScaleFactor;
end;

/// <summary>
/// Checks that the plot's data fits the shape its kind draws. Which check applies follows
/// from <c>TChartKindTraits</c> rather than from a list of kinds repeated here, so a new
/// kind is validated the way its traits say it should be instead of silently falling
/// through to the category check.
/// </summary>
procedure TChartRenderJob.ValidateInput;
begin
  if TChartKindTraits.IsCircular(FPlot.Kind) then
    ValidatePieSeries
  else if TChartKindTraits.HasEndValues(FPlot.Kind) then
    ValidatePairedSeries(KindName)
  else if TChartKindTraits.UsesContinuousX(FPlot.Kind) then
    ValidateLineSeries
  else
    ValidateCategorySeries;
end;

/// <summary>The plot's chart kind as it is written in <c>TChartKind</c>, for error messages.</summary>
function TChartRenderJob.KindName: string;
begin
  Result := GetEnumName(TypeInfo(TChartKind), Ord(FPlot.Kind));
end;

procedure TChartRenderJob.ValidateCategorySeries;
begin
  for var CurrentSeries in FPlot.Series do
  begin
    ValidateSeriesLength(CurrentSeries);
  end;
end;

procedure TChartRenderJob.ValidateSeriesLength(const Series: TChartSeries);
begin
  const CategoryCount = Length(FPlot.Categories);
  const HasMismatch = (Length(Series.Values) <> CategoryCount);
  if HasMismatch then
    raise EChart4DException.CreateFmt(SSeriesValueCountMismatch,
                                      [Series.Name, Length(Series.Values), CategoryCount, CategoryWord(CategoryCount)]);
end;

/// <summary>
/// Validates the single series of a kind that reads <c>EndValues</c> as the second end of
/// every data point: its values have to match the categories, and its two ends each other.
/// <c>KindName</c> names the kind in the error message.
/// </summary>
procedure TChartRenderJob.ValidatePairedSeries(const KindName: string);
begin
  const PairedSeries = FPlot.Series[0];
  ValidateSeriesLength(PairedSeries);

  const HasEndMismatch = (Length(PairedSeries.Values) <> Length(PairedSeries.EndValues));
  if HasEndMismatch then
    raise EChart4DException.CreateFmt(SPairedValueCountMismatch,
                                      [KindName, Length(PairedSeries.Values), Length(PairedSeries.EndValues)]);
end;

procedure TChartRenderJob.ValidatePieSeries;
begin
  const HasSingleSeries = (FPlot.Series.Count = 1);
  if not HasSingleSeries then
    raise EChart4DException.CreateFmt(SPieRequiresSingleSeries, [FPlot.Series.Count]);

  const PieSeries = FPlot.Series[0];
  ValidateSeriesLength(PieSeries);

  for var Value in PieSeries.Values do
  begin
    if Value < 0 then
      raise EChart4DException.CreateFmt(SPieValuesMustBeNonNegative, [Value]);
  end;
end;

procedure TChartRenderJob.ValidateLineSeries;
begin
  const IsScatter = (FPlot.Kind = TChartKind.Scatter);
  for var CurrentSeries in FPlot.Series do
  begin
    ValidateLineSeriesLength(CurrentSeries);
    if CurrentSeries.IsRangeBand then
      ValidateBandSeriesLength(CurrentSeries);
    if IsScatter then
      ValidateSeriesSizesLength(CurrentSeries);
  end;
end;

procedure TChartRenderJob.ValidateLineSeriesLength(const Series: TChartSeries);
begin
  const HasExplicitX = (Length(Series.XValues) > 0);
  if HasExplicitX then
  begin
    const HasXYMismatch = (Length(Series.XValues) <> Length(Series.Values));
    if HasXYMismatch then
      raise EChart4DException.CreateFmt(SXYValueCountMismatch,
                                        [Series.Name, Length(Series.XValues), Length(Series.Values)]);
  end
  else
  begin
    const CategoryCount = Length(FPlot.Categories);
    const HasCategories = (CategoryCount > 0);
    const HasCategoryMismatch = HasCategories and (Length(Series.Values) <> CategoryCount);
    if HasCategoryMismatch then
      raise EChart4DException.CreateFmt(SSeriesValueCountMismatch,
                                        [Series.Name, Length(Series.Values), CategoryCount, CategoryWord(CategoryCount)]);
  end;
end;

procedure TChartRenderJob.ValidateBandSeriesLength(const Series: TChartSeries);
begin
  const HasMismatch = (Length(Series.Values) <> Length(Series.EndValues));
  if HasMismatch then
    raise EChart4DException.CreateFmt(SBandValueCountMismatch,
                                      [Series.Name, Length(Series.Values), Length(Series.EndValues)]);
end;

procedure TChartRenderJob.ValidateSeriesSizesLength(const Series: TChartSeries);
begin
  const HasSizes = (Length(Series.Sizes) > 0);
  if not HasSizes then
    Exit;

  const HasMismatch = (Length(Series.Sizes) <> Length(Series.Values));
  if HasMismatch then
    raise EChart4DException.CreateFmt(SSeriesSizeCountMismatch,
                                      [Series.Name, Length(Series.Values), Length(Series.Sizes)]);
end;

function TChartRenderJob.CategoryWord(const Count: Integer): string;
begin
  if Count = 1 then
    Result := 'y'
  else
    Result := 'ies';
end;

function TChartRenderJob.IsPieOrDonut: Boolean;
begin
  Result := TChartKindTraits.IsCircular(FPlot.Kind);
end;

/// <summary>
/// Gives a Pie/Donut chart, which has no axes, a coordinate space for its annotations:
/// X is the 0-based category index, exactly as on any other category chart, and Y is a
/// fraction of the plot height (0 = bottom edge, 1 = top edge), since a shape without a
/// value axis has no data scale to place an annotation on.
/// </summary>
procedure TChartRenderJob.ComputeCircularAnnotationSpace;
begin
  FCategoryCount := Length(FPlot.Categories);
  FValueRange := TValueRange.Create(0, 1);
end;

procedure TChartRenderJob.ComputeValueAxis;
begin
  const AxisEngine = TValueAxisEngine.Create(FPlot);
  try
    const Range = AxisEngine.Compute;
    FValueRange := TValueRange.Create(Range.Min, Range.Max);
    FValueBreaks := Range.Breaks;
    FValueBreakLabels := Range.BreakLabels;
  finally
    AxisEngine.Free;
  end;
end;

function TChartRenderJob.MapValue(const Value: Double): Single;
begin
  Result := FGeometry.MapValue(Value);
end;

procedure TChartRenderJob.ComputeCategoryAxis;
begin
  FIsContinuousX := TChartKindTraits.UsesContinuousX(FPlot.Kind);
  if FIsContinuousX then
    ComputeContinuousXAxis
  else
    ComputeDiscreteCategoryAxis;
end;

procedure TChartRenderJob.ComputeDiscreteCategoryAxis;
begin
  FCategoryLabels := FPlot.Categories;
  FCategoryCount := Length(FCategoryLabels);
end;

procedure TChartRenderJob.ComputeContinuousXAxis;
begin
  var FinalRange := ComputeXDataRange.WithOverrides(FPlot.XAxis);

  const HasManualBreaks = FPlot.XAxis.HasManualBreaks;
  const IsDateAxis = FPlot.XAxis.IsDateAxis;
  const UsesNiceBreaks = (not HasManualBreaks) and (not IsDateAxis);
  if UsesNiceBreaks then
    FinalRange := FinalRange.ExpandedIfDegenerate;

  FXRange := FinalRange;

  { A DateMode of Auto is resolved exactly once, from the data range, and that one
    concrete mode drives both break placement and label formatting: re-resolving from the
    break span could pick a different granularity near a threshold. See SPEC.md 4.16. }
  var LabelOptions := FPlot.XAxis;
  if IsDateAxis then
    LabelOptions.DateMode := TAxisScale.ResolveDateMode(FinalRange.Min, FinalRange.Max, FPlot.XAxis.DateMode);

  if HasManualBreaks then
    FXBreaks := FPlot.XAxis.Breaks
  else if IsDateAxis then
    FXBreaks := TAxisScale.DateBreaks(FinalRange.Min, FinalRange.Max, LabelOptions.DateMode)
  else
    FXBreaks := TAxisScale.NiceBreaks(FinalRange.Min, FinalRange.Max);

  FXBreakLabels := TAxisScale.BuildLabels(FXBreaks, LabelOptions);
end;

function TChartRenderJob.ComputeXDataRange: TValueRange;
begin
  Result := TValueRange.Empty;
  for var CurrentSeries in FPlot.Series do
  begin
    Result.Extend(TChartGeometry.EffectiveXValues(CurrentSeries));
  end;
end;

function TChartRenderJob.OuterMargin: Single;
begin
  Result := 16 * FStyle.ScaleFactor;
end;

procedure TChartRenderJob.PerformLayout;
begin
  FCanvas.FillBackground(FWidth, FHeight, FStyle.BackgroundColor);

  const Margin = OuterMargin;
  var ContentRect := TRectF.Create(Margin, Margin, FWidth - Margin, FHeight - Margin);
  ContentRect.Top := DrawTitleAndSubtitle(ContentRect);
  ContentRect.Bottom := ContentRect.Bottom - ComputeFooterHeight;

  const LegendEngine = TLegendEngine.Create(FPlot, FCanvas, FStyle);
  try
    const LegendItems = LegendEngine.BuildItems;
    const ShowLegend = (FPlot.LegendPosition <> TLegendPosition.None) and (Length(LegendItems) > 1);
    if ShowLegend then
      ContentRect := LegendEngine.ApplyLayout(ContentRect, LegendItems);
  finally
    LegendEngine.Free;
  end;

  FPlotBounds := ComputePlotBounds(ContentRect);
end;

function TChartRenderJob.DrawTitleAndSubtitle(const ContentRect: TRectF): Single;
begin
  Result := ContentRect.Top;

  const MaxWidth = ContentRect.Width;

  const HasTitle = (FPlot.Title <> '');
  if HasTitle then
    Result := DrawTitle(ContentRect.Left, Result, MaxWidth);

  const HasSubtitle = (FPlot.Subtitle <> '');
  if HasSubtitle then
    Result := DrawSubtitle(ContentRect.Left, Result, MaxWidth);
end;

function TChartRenderJob.DrawTitle(const X, Y, MaxWidth: Single): Single;
begin
  const TextStyle = TChartTextStyle.Create(FStyle.FontName, FStyle.TitleFontSize, True, FStyle.TitleColor);
  Result := DrawWrappedTextBlock(X, Y, MaxWidth, FPlot.Title, TextStyle);
end;

function TChartRenderJob.DrawSubtitle(const X, Y, MaxWidth: Single): Single;
begin
  const Margin = 9 * FStyle.ScaleFactor;
  const TextStyle = TChartTextStyle.Create(FStyle.FontName, FStyle.SubtitleFontSize, False, FStyle.TextColor);
  const TextTop = DrawWrappedTextBlock(X, Y + Margin, MaxWidth, FPlot.Subtitle, TextStyle);
  Result := TextTop + Margin;
end;

function TChartRenderJob.DrawWrappedTextBlock(const X, Y, MaxWidth: Single; const Text: string;
                                              const TextStyle: TChartTextStyle): Single;
begin
  const Lines = WrapTextLines(Text, TextStyle, MaxWidth);
  const LineHeight = FCanvas.MeasureText(LineHeightSampleText, TextStyle).Height;

  var LineTop := Y;
  for var Line in Lines do
  begin
    FCanvas.DrawText(X, LineTop, Line, TextStyle, TTextAlignH.Left, TTextAlignV.Top);
    LineTop := LineTop + LineHeight;
  end;

  Result := LineTop;
end;

function TChartRenderJob.WrapTextLines(const Text: string; const TextStyle: TChartTextStyle;
                                       const MaxWidth: Single): TArray<string>;
begin
  Result := [];

  const Words = Text.Split([' ']);
  var CurrentLine := '';
  for var Word in Words do
  begin
    const IsFirstWordOnLine = (CurrentLine = '');
    var Candidate := Word;
    if not IsFirstWordOnLine then
      Candidate := CurrentLine + ' ' + Word;
    const CandidateFits = (FCanvas.MeasureText(Candidate, TextStyle).Width <= MaxWidth);

    if CandidateFits or IsFirstWordOnLine then
      CurrentLine := Candidate
    else
    begin
      Result := Result + [CurrentLine];
      CurrentLine := Word;
    end;
  end;

  Result := Result + [CurrentLine];
end;

function TChartRenderJob.ComputeFooterHeight: Single;
begin
  if HasFooterContent then
    Result := 2.2 * FStyle.CaptionFontSize
  else
    Result := 0;
end;

/// <summary>
/// Whether the chart has anything to put in a footer: a source text or a logo. The
/// single source of truth for both the layout pass, which reserves the footer's height,
/// and the draw pass, which decides whether to draw it at all.
/// </summary>
function TChartRenderJob.HasFooterContent: Boolean;
begin
  Result := (FPlot.Source <> '') or (FPlot.LogoFilePath <> '');
end;

function TChartRenderJob.ComputePlotBounds(const ContentRect: TRectF): TRectF;
begin
  Result := ContentRect;
  Result.Left := Result.Left + ComputeLeftInset;
  Result.Right := Result.Right - ComputeRightInset;
  Result.Top := Result.Top + ComputeTopInset;
  Result.Bottom := Result.Bottom - ComputeBottomAxisLabelHeight;

  const BubbleInset = ComputeBubbleRadiusInset;
  if BubbleInset > 0 then
  begin
    Result.Left := Result.Left + BubbleInset;
    Result.Right := Result.Right - BubbleInset;
    Result.Top := Result.Top + BubbleInset;
    Result.Bottom := Result.Bottom - BubbleInset;
  end;
end;

/// <summary>
/// Room above the plot area for the topmost value-axis label. A label is centred on its
/// gridline, so half of it sits above that line. A scale with headroom above the data keeps
/// its highest break clear of the top edge by itself, while a scale that snaps its range
/// outward to round values, as a logarithmic one does, puts a break exactly on the edge
/// where its label would reach into the subtitle. Half a line of axis text is reserved in
/// that case only, so a scale that does not need it pays nothing for it.
/// </summary>
function TChartRenderJob.ComputeTopInset: Single;
begin
  if IsPieOrDonut then
    Exit(0);

  const IsHorizontal = (FPlot.Orientation = TChartOrientation.Horizontal);
  const AxisVisible = LeftEdgeAxisVisible(IsHorizontal);
  if IsHorizontal or not AxisVisible then
    Exit(0);

  const HasBreaks = (Length(FValueBreaks) > 0);
  if not HasBreaks then
    Exit(0);

  const HighestBreak = FValueBreaks[High(FValueBreaks)];
  const TopBreakSitsOnTheEdge = (HighestBreak >= FValueRange.Max);
  if not TopBreakSitsOnTheEdge then
    Exit(0);

  Result := FCanvas.MeasureText(LineHeightSampleText, AxisTextStyle).Height / 2;
end;

function TChartRenderJob.ComputeLeftInset: Single;
begin
  if IsPieOrDonut then
    Exit(0);

  const IsHorizontal = (FPlot.Orientation = TChartOrientation.Horizontal);
  const AxisVisible = LeftEdgeAxisVisible(IsHorizontal);
  if not AxisVisible then
    Exit(0);

  const Labels = LeftEdgeLabels(IsHorizontal);
  Result := WidestLabelWidth(Labels, AxisTextStyle) + LeftLabelGap;
end;

function TChartRenderJob.ComputeRightInset: Single;
begin
  if IsPieOrDonut then
    Exit(0);

  const IsHorizontal = (FPlot.Orientation = TChartOrientation.Horizontal);
  const AxisVisible = BottomEdgeAxisVisible(IsHorizontal);
  if not AxisVisible then
    Exit(0);

  const Labels = BottomEdgeLabels(IsHorizontal);
  const HasLabels = (Length(Labels) > 0);
  if not HasLabels then
    Exit(0);

  const LastLabelWidth = FCanvas.MeasureText(Labels[High(Labels)], AxisTextStyle).Width;
  Result := LastLabelWidth / 2;
end;

/// <summary>
/// How far the largest bubble overhangs the point it is centred on. The plot area is
/// pulled in by that much so a bubble at the edge of the data still fits inside the chart.
/// Asked of the scatter renderer rather than recomputed here, so the inset can never be
/// based on a different radius than the one actually drawn.
/// </summary>
function TChartRenderJob.ComputeBubbleRadiusInset: Single;
begin
  Result := 0;
  const IsScatter = (FPlot.Kind = TChartKind.Scatter);
  if not IsScatter then
    Exit;

  var SizeDomain := TValueRange.Empty;
  for var CurrentSeries in FPlot.Series do
  begin
    SizeDomain.Extend(CurrentSeries.Sizes);
  end;

  for var CurrentSeries in FPlot.Series do
  begin
    for var PointIndex := 0 to High(CurrentSeries.Sizes) do
    begin
      Result := Max(Result, TScatterSeriesRenderer.PointDrawRadius(FStyle, CurrentSeries, PointIndex, SizeDomain));
    end;
  end;
end;

function TChartRenderJob.LeftEdgeAxisVisible(const IsHorizontal: Boolean): Boolean;
begin
  if IsHorizontal then
    Result := FPlot.XAxis.Visible
  else
    Result := FPlot.YAxis.Visible;
end;

/// <summary>The labels drawn along the category axis, however that axis is built.</summary>
function TChartRenderJob.CategoryAxisLabels: TArray<string>;
begin
  if FIsContinuousX then
    Result := FXBreakLabels
  else
    Result := FCategoryLabels;
end;

/// <summary>
/// The labels running down the left edge of the plot. A horizontal chart runs its
/// categories down that edge and its values along the bottom; a vertical one is the other
/// way round.
/// </summary>
function TChartRenderJob.LeftEdgeLabels(const IsHorizontal: Boolean): TArray<string>;
begin
  if IsHorizontal then
    Result := CategoryAxisLabels
  else
    Result := FValueBreakLabels;
end;

/// <summary>The labels running along the bottom edge, the counterpart of <c>LeftEdgeLabels</c>.</summary>
function TChartRenderJob.BottomEdgeLabels(const IsHorizontal: Boolean): TArray<string>;
begin
  if IsHorizontal then
    Result := FValueBreakLabels
  else
    Result := CategoryAxisLabels;
end;

function TChartRenderJob.ComputeBottomAxisLabelHeight: Single;
begin
  if IsPieOrDonut then
    Exit(0);

  const IsHorizontal = (FPlot.Orientation = TChartOrientation.Horizontal);
  const AxisVisible = BottomEdgeAxisVisible(IsHorizontal);
  if not AxisVisible then
    Exit(0);

  const SampleSize = FCanvas.MeasureText('0', AxisTextStyle);
  Result := BottomLabelMarginAbove + SampleSize.Height + BottomLabelMarginBelow;
end;

function TChartRenderJob.BottomEdgeAxisVisible(const IsHorizontal: Boolean): Boolean;
begin
  if IsHorizontal then
    Result := FPlot.YAxis.Visible
  else
    Result := FPlot.XAxis.Visible;
end;

function TChartRenderJob.WidestLabelWidth(const Labels: TArray<string>; const TextStyle: TChartTextStyle): Single;
begin
  Result := 0;
  for var LabelText in Labels do
  begin
    const TextSize = FCanvas.MeasureText(LabelText, TextStyle);
    Result := Max(Result, TextSize.Width);
  end;
end;

function TChartRenderJob.AxisTextStyle: TChartTextStyle;
begin
  Result := TChartTextStyle.Create(FStyle.FontName, FStyle.AxisFontSize, False, FStyle.TextColor);
end;

function TChartRenderJob.LeftLabelGap: Single;
begin
  Result := 8 * FStyle.ScaleFactor;
end;

function TChartRenderJob.BottomLabelMarginAbove: Single;
begin
  Result := 5 * FStyle.ScaleFactor;
end;

/// <summary>
/// Where a value-axis label ends, to the left of the plot area. The plot area is inset for
/// a mark that can overhang its edge, a bubble being the kind that does. Labels belong to
/// the frame around the plot rather than to the plot itself, so that inset is taken off
/// again here: otherwise the labels would move inward with the plot and the overhanging
/// mark would come to rest on top of them.
/// </summary>
function TChartRenderJob.AxisLabelRightEdge: Single;
begin
  Result := FPlotBounds.Left - LeftLabelGap - ComputeBubbleRadiusInset;
end;

/// <summary>Where a label under the plot area starts, the counterpart of
/// <c>AxisLabelRightEdge</c> for the bottom edge.</summary>
function TChartRenderJob.AxisLabelTopEdge: Single;
begin
  Result := FPlotBounds.Bottom + BottomLabelMarginAbove + ComputeBubbleRadiusInset;
end;

function TChartRenderJob.BottomLabelMarginBelow: Single;
begin
  Result := 10 * FStyle.ScaleFactor;
end;

procedure TChartRenderJob.BuildGeometry;
begin
  FGeometry := TChartGeometry.Create(FPlot, FCategoryCount);
  FGeometry.Build(FPlotBounds, FValueRange, FXRange);
end;

function TChartRenderJob.CategoryCenter(const Index: Integer): Single;
begin
  Result := FGeometry.CategoryCenter(Index);
end;

function TChartRenderJob.CategoryValuePoint(const CategoryPixel: Single; const Value: Double): TPointF;
begin
  Result := FGeometry.CategoryValuePoint(CategoryPixel, Value);
end;

procedure TChartRenderJob.DrawAxisLabels;
begin
  DrawValueAxisLabels;
  DrawCategoryAxisLabels;
end;

procedure TChartRenderJob.DrawValueAxisLabels;
begin
  if not FPlot.YAxis.Visible then
    Exit;

  const TextStyle = AxisTextStyle;
  for var Index := 0 to High(FValueBreaks) do
  begin
    DrawValueAxisLabel(MapValue(FValueBreaks[Index]), FValueBreakLabels[Index], TextStyle);
  end;
end;

/// <summary>
/// Draws one label beside the value axis, on whichever edge of the plot that axis runs
/// along: to the left of it, right-aligned and centred on its gridline, or under it,
/// centred on its gridline horizontally.
/// </summary>
procedure TChartRenderJob.DrawValueAxisLabel(const Pixel: Single; const LabelText: string;
                                             const TextStyle: TChartTextStyle);
begin
  if FGeometry.IsHorizontal then
    FCanvas.DrawText(Pixel, AxisLabelTopEdge, LabelText, TextStyle, TTextAlignH.Center, TTextAlignV.Top)
  else
    FCanvas.DrawText(AxisLabelRightEdge, Pixel, LabelText, TextStyle, TTextAlignH.Right, TTextAlignV.Middle);
end;

/// <summary>The counterpart of <c>DrawValueAxisLabel</c> for the category axis' edge.</summary>
procedure TChartRenderJob.DrawCategoryAxisLabel(const Pixel: Single; const LabelText: string;
                                                const TextStyle: TChartTextStyle);
begin
  if FGeometry.IsHorizontal then
    FCanvas.DrawText(AxisLabelRightEdge, Pixel, LabelText, TextStyle, TTextAlignH.Right, TTextAlignV.Middle)
  else
    FCanvas.DrawText(Pixel, AxisLabelTopEdge, LabelText, TextStyle, TTextAlignH.Center, TTextAlignV.Top);
end;

procedure TChartRenderJob.DrawCategoryAxisLabels;
begin
  if not FPlot.XAxis.Visible then
    Exit;

  if FIsContinuousX then
    DrawContinuousXLabels
  else
    DrawDiscreteCategoryLabels;
end;

procedure TChartRenderJob.DrawContinuousXLabels;
begin
  const TextStyle = AxisTextStyle;
  for var Index := 0 to High(FXBreaks) do
  begin
    DrawCategoryAxisLabel(FGeometry.MapX(FXBreaks[Index]), FXBreakLabels[Index], TextStyle);
  end;
end;

procedure TChartRenderJob.DrawDiscreteCategoryLabels;
begin
  const TextStyle = AxisTextStyle;
  for var Index in SelectedCategoryLabelIndices do
    DrawDiscreteCategoryLabel(Index, TextStyle);
end;

function TChartRenderJob.CategoryLabelExtent(const Index: Integer): Single;
begin
  const TextSize = FCanvas.MeasureText(FCategoryLabels[Index], AxisTextStyle);
  if FGeometry.IsHorizontal then
    Result := TextSize.Height
  else
    Result := TextSize.Width;
end;

function TChartRenderJob.SelectedCategoryLabelIndices: TArray<Integer>;
begin
  Result := [];
  if FCategoryCount = 0 then
    Exit;

  const LastIndex = FCategoryCount - 1;
  Result := [0];
  var LastDrawnIndex := 0;
  var LastDrawnExtent := CategoryLabelExtent(0);

  for var Index := 1 to LastIndex - 1 do
  begin
    const Extent = CategoryLabelExtent(Index);
    const Distance = (Index - LastDrawnIndex) * FGeometry.CategoryBand;
    const RequiredGap = (LastDrawnExtent + Extent) / 2;
    const Fits = (Distance >= RequiredGap);
    if not Fits then
      Continue;

    Result := Result + [Index];
    LastDrawnIndex := Index;
    LastDrawnExtent := Extent;
  end;

  const HasDistinctLastIndex = (LastIndex > 0);
  if not HasDistinctLastIndex then
    Exit;

  const LastExtent = CategoryLabelExtent(LastIndex);
  const DistanceToLast = (LastIndex - LastDrawnIndex) * FGeometry.CategoryBand;
  const RequiredGapToLast = (LastDrawnExtent + LastExtent) / 2;
  const LastFits = (DistanceToLast >= RequiredGapToLast);
  if LastFits then
    Result := Result + [LastIndex];
end;

procedure TChartRenderJob.DrawDiscreteCategoryLabel(const Index: Integer; const TextStyle: TChartTextStyle);
begin
  DrawCategoryAxisLabel(CategoryCenter(Index), FCategoryLabels[Index], TextStyle);
end;

procedure TChartRenderJob.DrawRangeOverlays;
begin
  for var Annotation in FPlot.Annotations do
  begin
    if Annotation.Kind = TAnnotationKind.HorizontalRangeOverlay then
      DrawHorizontalRangeOverlay(Annotation)
    else if Annotation.Kind = TAnnotationKind.VerticalRangeOverlay then
      DrawVerticalRangeOverlay(Annotation);
  end;
end;

procedure TChartRenderJob.DrawHorizontalRangeOverlay(const Annotation: TChartAnnotation);
begin
  FillRangeBand(PlotSpanAtValuePixel(MapValue(Annotation.Y)),
                PlotSpanAtValuePixel(MapValue(Annotation.Y2)), Annotation.Color);
end;

procedure TChartRenderJob.DrawVerticalRangeOverlay(const Annotation: TChartAnnotation);
begin
  FillRangeBand(PlotSpanAtCategoryPixel(FGeometry.CategoryAxisPixel(Annotation.X)),
                PlotSpanAtCategoryPixel(FGeometry.CategoryAxisPixel(Annotation.X2)), Annotation.Color);
end;

procedure TChartRenderJob.FillRangeBand(const LowPoints, HighPoints: TArray<TPointF>; const Color: TAlphaColor);
begin
  FCanvas.FillPolygon(TChartGeometry.BandPolygonPoints(LowPoints, HighPoints), Color);
end;

/// <summary>
/// The two ends of the line that crosses the whole plot area at a given value-axis pixel:
/// a gridline, the baseline, a horizontal reference line, and the edge of a shaded value
/// band are all that same line, so they are all drawn from this one span.
/// </summary>
function TChartRenderJob.PlotSpanAtValuePixel(const Pixel: Single): TArray<TPointF>;
begin
  if FGeometry.IsHorizontal then
    Result := [TPointF.Create(Pixel, FPlotBounds.Top), TPointF.Create(Pixel, FPlotBounds.Bottom)]
  else
    Result := [TPointF.Create(FPlotBounds.Left, Pixel), TPointF.Create(FPlotBounds.Right, Pixel)];
end;

/// <summary>The counterpart of <c>PlotSpanAtValuePixel</c> for the category axis.</summary>
function TChartRenderJob.PlotSpanAtCategoryPixel(const Pixel: Single): TArray<TPointF>;
begin
  if FGeometry.IsHorizontal then
    Result := [TPointF.Create(FPlotBounds.Left, Pixel), TPointF.Create(FPlotBounds.Right, Pixel)]
  else
    Result := [TPointF.Create(Pixel, FPlotBounds.Top), TPointF.Create(Pixel, FPlotBounds.Bottom)];
end;

procedure TChartRenderJob.DrawLineAcrossPlot(const Pixel: Single; const Color: TAlphaColor;
                                             const Width: Single; const Dashed: Boolean);
begin
  const Span = PlotSpanAtValuePixel(Pixel);
  FCanvas.DrawLine(Span[0].X, Span[0].Y, Span[1].X, Span[1].Y, Color, Width, Dashed);
end;

procedure TChartRenderJob.DrawLineAlongPlot(const Pixel: Single; const Color: TAlphaColor;
                                            const Width: Single; const Dashed: Boolean);
begin
  const Span = PlotSpanAtCategoryPixel(Pixel);
  FCanvas.DrawLine(Span[0].X, Span[0].Y, Span[1].X, Span[1].Y, Color, Width, Dashed);
end;

procedure TChartRenderJob.DrawGrid;
begin
  if FStyle.ShowGridlines then
    DrawGridlines;
  if FStyle.ShowBaseline then
    DrawBaseline;
end;

procedure TChartRenderJob.DrawGridlines;
begin
  for var BreakValue in FValueBreaks do
  begin
    DrawGridline(BreakValue);
  end;
end;

procedure TChartRenderJob.DrawGridline(const Value: Double);
begin
  DrawLineAcrossPlot(MapValue(Value), FStyle.GridColor, FStyle.GridLineWidth, False);
end;

procedure TChartRenderJob.DrawBaseline;
begin
  const IsZeroInRange = (FValueRange.Min <= 0) and (FValueRange.Max >= 0);
  if not IsZeroInRange then
    Exit;

  DrawLineAcrossPlot(MapValue(0), FStyle.BaselineColor, FStyle.BaselineWidth, False);
end;

procedure TChartRenderJob.BuildSeriesRenderer;
begin
  var Context := Default(TChartDrawContext);
  Context.Plot := FPlot;
  Context.Canvas := FCanvas;
  Context.Style := FStyle;
  Context.Geometry := FGeometry;
  Context.HitMap := FHitMap;
  Context.Arrows := FArrows;
  Context.LabelClampBounds := MarginBounds;

  FSeriesRenderer := TChartSeriesRenderer.CreateFor(Context);
end;

procedure TChartRenderJob.DrawSeries;
begin
  FSeriesRenderer.Draw;
end;

procedure TChartRenderJob.DrawValueLabels;
begin
  const HasNoLabels = (FPlot.ValueLabels = TValueLabelMode.None);
  if HasNoLabels then
    Exit;

  const Placer = TChartLabelPlacer.Create(FCanvas, FStyle.ScaleFactor, ValueLabelClampBounds);
  try
    for var Group in FSeriesRenderer.BuildValueLabelGroups do
    begin
      for var Candidate in SelectValueLabelCandidates(Group, FPlot.ValueLabels) do
      begin
        DrawValueLabelCandidate(Placer, Candidate);
      end;
    end;
  finally
    Placer.Free;
  end;
end;

function TChartRenderJob.SelectValueLabelCandidates(const Group: TArray<TValueLabelCandidate>;
                                                     const Mode: TValueLabelMode): TArray<TValueLabelCandidate>;
begin
  const HasNoCandidates = (Length(Group) = 0);
  case Mode of
    TValueLabelMode.All :
      Result := Group;
    TValueLabelMode.FirstAndLast :
      if HasNoCandidates then
        Result := []
      else if Length(Group) = 1 then
        Result := [Group[0]]
      else
        Result := [Group[0], Group[High(Group)]];
    TValueLabelMode.Extremes :
      begin
        if HasNoCandidates then
        begin
          Result := [];
          Exit;
        end;

        var MinIndex := 0;
        var MaxIndex := 0;
        for var Index := 1 to High(Group) do
        begin
          if Group[Index].Value < Group[MinIndex].Value then
            MinIndex := Index;
          if Group[Index].Value > Group[MaxIndex].Value then
            MaxIndex := Index;
        end;

        if MinIndex = MaxIndex then
          Result := [Group[MinIndex]]
        else if MinIndex < MaxIndex then
          Result := [Group[MinIndex], Group[MaxIndex]]
        else
          Result := [Group[MaxIndex], Group[MinIndex]];
      end;
  else
    raise ENotSupportedException.CreateFmt('Unsupported value label mode: %d', [Ord(Mode)]);
  end;
end;

procedure TChartRenderJob.DrawValueLabelCandidate(const Placer: TChartLabelPlacer;
                                                  const Candidate: TValueLabelCandidate);
begin
  const LabelText = TAxisScale.FormatValue(Candidate.Value, FPlot.YAxis.UseThousandSeparator) + FPlot.YAxis.LabelSuffix;
  Placer.DrawIfClear(Candidate.AnchorPoint, LabelText, AxisTextStyle);
end;

procedure TChartRenderJob.DrawAnnotations;
begin
  const Placer = TChartLabelPlacer.Create(FCanvas, FStyle.ScaleFactor, MarginBounds);
  try
    for var Annotation in FPlot.Annotations do
    begin
      const IsAlreadyDrawnRangeOverlay = (Annotation.Kind in
        [TAnnotationKind.HorizontalRangeOverlay, TAnnotationKind.VerticalRangeOverlay]);
      if IsAlreadyDrawnRangeOverlay then
        Continue;

      DrawAnnotation(Placer, Annotation);
    end;
  finally
    Placer.Free;
  end;
end;

procedure TChartRenderJob.DrawAnnotation(const Placer: TChartLabelPlacer; const Annotation: TChartAnnotation);
begin
  case Annotation.Kind of
    TAnnotationKind.TextLabel      : DrawTextLabelAnnotation(Placer, Annotation);
    TAnnotationKind.Segment        : DrawSegmentAnnotation(Annotation);
    TAnnotationKind.Arrow          : DrawArrowAnnotation(Annotation);
    TAnnotationKind.HorizontalLine : DrawHorizontalLineAnnotation(Annotation);
    TAnnotationKind.VerticalLine   : DrawVerticalLineAnnotation(Annotation);
  else
    raise ENotSupportedException.CreateFmt('Unsupported annotation kind: %d', [Ord(Annotation.Kind)]);
  end;
end;

procedure TChartRenderJob.DrawTextLabelAnnotation(const Placer: TChartLabelPlacer;
                                                  const Annotation: TChartAnnotation);
begin
  const AnchorPoint = AnnotationPoint(Annotation.X, Annotation.Y);
  const TextStyle = TChartTextStyle.Create(FStyle.FontName, AnnotationFontSize(Annotation), False, Annotation.Color);

  Placer.Draw(AnchorPoint, Annotation.Text, TextStyle, Annotation.AlignH);
end;

function TChartRenderJob.MarginBounds: TRectF;
begin
  const Margin = OuterMargin;

  Result := TRectF.Create(Margin, Margin, FWidth - Margin, FHeight - Margin);
end;

function TChartRenderJob.ValueLabelClampBounds: TRectF;
begin
  Result := MarginBounds;

  if IsPieOrDonut then
    Exit;

  const IsHorizontal = (FPlot.Orientation = TChartOrientation.Horizontal);

  if LeftEdgeAxisVisible(IsHorizontal) then
    Result.Left := Max(Result.Left, FPlotBounds.Left);

  if BottomEdgeAxisVisible(IsHorizontal) then
    Result.Bottom := Min(Result.Bottom, FPlotBounds.Bottom);
end;

procedure TChartRenderJob.DrawSegmentAnnotation(const Annotation: TChartAnnotation);
begin
  const StartPoint = AnnotationPoint(Annotation.X, Annotation.Y);
  const EndPoint = AnnotationPoint(Annotation.X2, Annotation.Y2);
  const Width = AnnotationLineWidth(Annotation);

  FCanvas.DrawLine(StartPoint.X, StartPoint.Y, EndPoint.X, EndPoint.Y, Annotation.Color, Width, Annotation.Dashed);
end;

procedure TChartRenderJob.DrawArrowAnnotation(const Annotation: TChartAnnotation);
begin
  const StartPoint = AnnotationPoint(Annotation.X, Annotation.Y);
  const EndPoint = AnnotationPoint(Annotation.X2, Annotation.Y2);
  const Width = AnnotationLineWidth(Annotation);

  FArrows.Draw(StartPoint, EndPoint, Annotation.Color, Width, Annotation.Dashed);
end;

procedure TChartRenderJob.DrawHorizontalLineAnnotation(const Annotation: TChartAnnotation);
begin
  DrawLineAcrossPlot(MapValue(Annotation.Y), Annotation.Color,
                     AnnotationLineWidth(Annotation), Annotation.Dashed);
end;

procedure TChartRenderJob.DrawVerticalLineAnnotation(const Annotation: TChartAnnotation);
begin
  DrawLineAlongPlot(FGeometry.CategoryAxisPixel(Annotation.X), Annotation.Color,
                    AnnotationLineWidth(Annotation), Annotation.Dashed);
end;

function TChartRenderJob.AnnotationPoint(const X, Y: Double): TPointF;
begin
  Result := CategoryValuePoint(FGeometry.CategoryAxisPixel(X), Y);
end;

function TChartRenderJob.AnnotationLineWidth(const Annotation: TChartAnnotation): Single;
begin
  const HasCustomWidth = (Annotation.LineWidth <> 0);
  if HasCustomWidth then
    Result := Annotation.LineWidth * FStyle.ScaleFactor
  else
    Result := FStyle.SeriesLineWidth;
end;

function TChartRenderJob.AnnotationFontSize(const Annotation: TChartAnnotation): Single;
begin
  const HasCustomSize = (Annotation.FontSize <> 0);
  if HasCustomSize then
    Result := Annotation.FontSize * FStyle.ScaleFactor
  else
    Result := FStyle.AxisFontSize;
end;

procedure TChartRenderJob.DrawFooter;
begin
  if not HasFooterContent then
    Exit;

  const FooterHeight = ComputeFooterHeight;
  const Margin = OuterMargin;
  const FooterTop = FHeight - Margin - FooterHeight;

  DrawFooterSeparator(FooterTop, Margin);
  DrawFooterSource(FooterTop, FooterHeight, Margin);
  DrawFooterLogo(FooterTop, FooterHeight, Margin);
end;

procedure TChartRenderJob.DrawFooterSeparator(const FooterTop, Margin: Single);
begin
  FCanvas.DrawLine(Margin, FooterTop, FWidth - Margin, FooterTop, ChartTextDark, 1 * FStyle.ScaleFactor, False);
end;

procedure TChartRenderJob.DrawFooterSource(const FooterTop, FooterHeight, Margin: Single);
begin
  const HasSource = (FPlot.Source <> '');
  if not HasSource then
    Exit;

  const TextStyle = TChartTextStyle.Create(FStyle.FontName, FStyle.CaptionFontSize, False, FStyle.MutedTextColor);
  const CenterY = FooterTop + FooterHeight / 2;
  FCanvas.DrawText(Margin, CenterY, FPlot.Source, TextStyle, TTextAlignH.Left, TTextAlignV.Middle);
end;

procedure TChartRenderJob.DrawFooterLogo(const FooterTop, FooterHeight, Margin: Single);
begin
  const HasLogo = (FPlot.LogoFilePath <> '');
  if not HasLogo then
    Exit;

  const Bounds = TRectF.Create(Margin, FooterTop, FWidth - Margin, FooterTop + FooterHeight);
  FCanvas.DrawImage(FPlot.LogoFilePath, Bounds);
end;

end.
