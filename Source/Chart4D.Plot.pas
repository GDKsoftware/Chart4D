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
unit Chart4D.Plot;

/// <summary>
/// The mutable chart model: series, categories, annotations, axis options, and style,
/// with change notification for owning controls to repaint on.
/// </summary>

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.UITypes,
  Chart4D.Axis,
  Chart4D.Series,
  Chart4D.Style,
  Chart4D.Types;

type
  /// <summary>
  /// The data and configuration for a single chart: kind, series, categories,
  /// annotations, axis options, and style. Fires <c>OnChanged</c> on every mutation so
  /// an owning control can repaint.
  /// </summary>
  TChartPlot = class
  private
    FKind: TChartKind;
    FTitle: string;
    FSubtitle: string;
    FSource: string;
    FLogoFilePath: string;
    FCategories: TArray<string>;
    FSeries: TObjectList<TChartSeries>;
    FStyle: TChartStyle;
    FXAxis: TAxisOptions;
    FYAxis: TAxisOptions;
    FOrientation: TChartOrientation;
    FStackMode: TStackMode;
    FLegendPosition: TLegendPosition;
    FLegendReversed: Boolean;
    FAnnotations: TArray<TChartAnnotation>;
    FValueLabels: TValueLabelMode;
    FHighlightedSeriesIndex: Integer;
    FDonutCenterText: string;
    FOnChanged: TNotifyEvent;

    procedure SetKind(const Value: TChartKind);
    procedure SetTitle(const Value: string);
    procedure SetSubtitle(const Value: string);
    procedure SetSource(const Value: string);
    procedure SetLogoFilePath(const Value: string);
    procedure SetCategories(const Value: TArray<string>);
    procedure SetStyle(const Value: TChartStyle);
    procedure SetXAxis(const Value: TAxisOptions);
    procedure SetYAxis(const Value: TAxisOptions);
    procedure SetOrientation(const Value: TChartOrientation);
    procedure SetStackMode(const Value: TStackMode);
    procedure SetLegendPosition(const Value: TLegendPosition);
    procedure SetLegendReversed(const Value: Boolean);
    procedure SetValueLabels(const Value: TValueLabelMode);
    procedure SetHighlightedSeriesIndex(const Value: Integer);
    procedure SetDonutCenterText(const Value: string);

    procedure NotifyChanged;
    procedure AppendAnnotation(const Annotation: TChartAnnotation);

  public
    /// <summary>
    /// Creates an empty plot with default style, default axis options, orientation
    /// <c>Vertical</c>, stack mode <c>Values</c>, and legend position <c>Top</c>.
    /// </summary>
    constructor Create;
    /// <summary>Destroys the plot and its owned series.</summary>
    destructor Destroy; override;

    /// <summary>Adds a new, empty, named series and fires <c>OnChanged</c>.</summary>
    function AddSeries(const Name: string): TChartSeries; overload;
    /// <summary>Adds a new named series with the given values and fires <c>OnChanged</c>.</summary>
    function AddSeries(const Name: string; const Values: TArray<Double>): TChartSeries; overload;
    /// <summary>
    /// Adds a new named series with explicit X and Y values, for <c>Line</c>/<c>Area</c>
    /// charts, and fires <c>OnChanged</c>.
    /// </summary>
    function AddLineSeries(const Name: string;
                           const XValues, YValues: TArray<Double>): TChartSeries;
    /// <summary>
    /// Appends a new named uncertainty/range band series built from <c>XValues</c>,
    /// <c>LowValues</c> and <c>HighValues</c>, setting <c>IsRangeBand</c> to <c>True</c>,
    /// exactly like <c>AddLineSeries</c> otherwise, and fires <c>OnChanged</c>. Meaningful
    /// only when the plot's <c>Kind</c> is <c>Line</c> or <c>Area</c>.
    /// </summary>
    function AddRangeBandSeries(const Name: string;
                                const XValues, LowValues, HighValues: TArray<Double>): TChartSeries;
    /// <summary>
    /// Replaces all series with a single dumbbell series built from
    /// <c>StartValues</c>/<c>EndValues</c>, sets <c>Kind</c> to <c>Dumbbell</c> and
    /// <c>Orientation</c> to <c>Horizontal</c>, and fires <c>OnChanged</c>.
    /// </summary>
    function AddDumbbellSeries(const StartValues, EndValues: TArray<Double>): TChartSeries;
    /// <summary>
    /// Replaces all series with a single named range series built from
    /// <c>LowValues</c>/<c>HighValues</c>, sets <c>Kind</c> to <c>Range</c> and
    /// <c>Orientation</c> to <c>Horizontal</c>, and fires <c>OnChanged</c>.
    /// </summary>
    function AddRangeSeries(const Name: string; const LowValues, HighValues: TArray<Double>): TChartSeries;
    /// <summary>
    /// Replaces all series with a single named arrow series built from
    /// <c>StartValues</c>/<c>EndValues</c>, sets <c>Kind</c> to <c>Arrow</c> and
    /// <c>Orientation</c> to <c>Horizontal</c>, and fires <c>OnChanged</c>.
    /// </summary>
    function AddArrowSeries(const Name: string; const StartValues, EndValues: TArray<Double>): TChartSeries;
    /// <summary>
    /// Replaces all series and categories with a single histogram count series binned
    /// from <c>Values</c>, sets <c>Kind</c> to <c>Histogram</c>, and fires
    /// <c>OnChanged</c>.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when <c>BinWidth</c> is not greater than 0 or <c>Values</c> is empty.</exception>
    procedure SetHistogramData(const Values: TArray<Double>; const BinWidth: Double);
    /// <summary>Removes every series and fires <c>OnChanged</c>.</summary>
    procedure ClearSeries;

    /// <summary>Adds a text label annotation and fires <c>OnChanged</c>.</summary>
    procedure AddTextAnnotation(const X, Y: Double; const Text: string;
                                const Color: TAlphaColor; const AlignH: TTextAlignH = TTextAlignH.Left);
    /// <summary>Adds a straight segment annotation and fires <c>OnChanged</c>.</summary>
    procedure AddSegment(const X1, Y1, X2, Y2: Double);
    /// <summary>Adds an arrow annotation and fires <c>OnChanged</c>.</summary>
    procedure AddArrow(const X1, Y1, X2, Y2: Double);
    /// <summary>Adds a full-width horizontal reference line and fires <c>OnChanged</c>.</summary>
    procedure AddHorizontalLine(const Y: Double; const Color: TAlphaColor;
                                const Dashed: Boolean = False);
    /// <summary>Adds a full-width vertical reference line and fires <c>OnChanged</c>.</summary>
    procedure AddVerticalLine(const X: Double; const Color: TAlphaColor;
                              const Dashed: Boolean = False);
    /// <summary>
    /// Adds a shaded horizontal band annotation between <c>Y1</c> (low bound) and
    /// <c>Y2</c> (high bound), spanning the full plot width, drawn behind the grid and
    /// every series, and fires <c>OnChanged</c>.
    /// </summary>
    procedure AddHorizontalRangeOverlay(const Y1, Y2: Double; const Color: TAlphaColor);
    /// <summary>
    /// Adds a shaded vertical band annotation between <c>X1</c> (low bound) and <c>X2</c>
    /// (high bound), spanning the full plot height, drawn behind the grid and every
    /// series, and fires <c>OnChanged</c>.
    /// </summary>
    procedure AddVerticalRangeOverlay(const X1, X2: Double; const Color: TAlphaColor);
    /// <summary>Removes every annotation and fires <c>OnChanged</c>.</summary>
    procedure ClearAnnotations;

    /// <summary>
    /// Returns the color of the series at <c>Index</c>: its own <c>Color</c> when
    /// non-zero, otherwise <c>DefaultPalette[Index mod Length(DefaultPalette)]</c>. When
    /// <c>HighlightedSeriesIndex</c> is a valid series index other than <c>Index</c>,
    /// returns <c>ChartLightGrey</c> instead, muting every series but the highlighted one.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when <c>Index</c> is outside the series list.</exception>
    function SeriesColor(const Index: Integer): TAlphaColor;

    /// <summary>
    /// Returns the color for category <c>Index</c>: always
    /// <c>DefaultPalette[Index mod Length(DefaultPalette)]</c>. Categories have no
    /// per-category color override. Used by <c>Pie</c>/<c>Donut</c> charts, which color
    /// by category rather than by series.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when <c>Index</c> is negative.</exception>
    function CategoryColor(const Index: Integer): TAlphaColor;

    /// <summary>The chart kind.</summary>
    property Kind: TChartKind read FKind write SetKind;
    /// <summary>The chart title, drawn bold at the top left.</summary>
    property Title: string read FTitle write SetTitle;
    /// <summary>The chart subtitle, drawn below the title.</summary>
    property Subtitle: string read FSubtitle write SetSubtitle;
    /// <summary>The footer source text, e.g. 'Source: Eurostat'.</summary>
    property Source: string read FSource write SetSource;
    /// <summary>The optional footer logo file path (PNG).</summary>
    property LogoFilePath: string read FLogoFilePath write SetLogoFilePath;
    /// <summary>The category labels along the category axis.</summary>
    property Categories: TArray<string> read FCategories write SetCategories;
    /// <summary>The owned list of data series.</summary>
    property Series: TObjectList<TChartSeries> read FSeries;
    /// <summary>The visual style applied when rendering.</summary>
    property Style: TChartStyle read FStyle write SetStyle;
    /// <summary>The X axis (category axis for Line/Area charts) options.</summary>
    property XAxis: TAxisOptions read FXAxis write SetXAxis;
    /// <summary>The Y axis (value axis) options.</summary>
    property YAxis: TAxisOptions read FYAxis write SetYAxis;
    /// <summary>The chart orientation. Default <c>Vertical</c>.</summary>
    property Orientation: TChartOrientation read FOrientation write SetOrientation;
    /// <summary>How a stacked bar chart combines series values. Default <c>Values</c>.</summary>
    property StackMode: TStackMode read FStackMode write SetStackMode;
    /// <summary>Where the legend is drawn. Default <c>Top</c>.</summary>
    property LegendPosition: TLegendPosition read FLegendPosition write SetLegendPosition;
    /// <summary>Whether legend items are drawn in reverse series order.</summary>
    property LegendReversed: Boolean read FLegendReversed write SetLegendReversed;
    /// <summary>The annotations drawn on top of the series.</summary>
    property Annotations: TArray<TChartAnnotation> read FAnnotations;
    /// <summary>Which data points get a built-in value label. Default <c>None</c>.</summary>
    property ValueLabels: TValueLabelMode read FValueLabels write SetValueLabels;
    /// <summary>
    /// The index of the series drawn in its own color while every other series is muted
    /// to <c>ChartLightGrey</c>, or -1 (default) to draw every series in its own color.
    /// </summary>
    property HighlightedSeriesIndex: Integer read FHighlightedSeriesIndex write SetHighlightedSeriesIndex;
    /// <summary>
    /// The text drawn centered in a <c>Donut</c> chart's hole, e.g. <c>'Total: 1,234'</c>.
    /// Default <c>''</c> (nothing drawn). Meaningful only when <c>Kind = Donut</c>.
    /// </summary>
    property DonutCenterText: string read FDonutCenterText write SetDonutCenterText;
    /// <summary>Fired after every mutation of the plot.</summary>
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Chart4D.Consts;

type
  /// <summary>
  /// Bins a set of observations into fixed-width buckets, producing the counts and the
  /// category labels a histogram plots. Kept apart from <c>TChartPlot</c>, which holds
  /// chart data rather than deriving it: the plot asks for a binning and stores the
  /// result, and the binning rule can be reasoned about without the model around it.
  /// </summary>
  TChartHistogramBinning = record
    /// <summary>The lower bound of each bin, formatted as a category label.</summary>
    Categories: TArray<string>;
    /// <summary>The number of observations that fell into each bin.</summary>
    Counts: TArray<Double>;

    /// <summary>
    /// Bins <c>Values</c> into buckets of <c>BinWidth</c>, spanning from the bucket of the
    /// smallest value to the bucket of the largest. An empty input yields no bins.
    /// </summary>
    class function Build(const Values: TArray<Double>; const BinWidth: Double): TChartHistogramBinning; static;
  end;

class function TChartHistogramBinning.Build(const Values: TArray<Double>;
                                            const BinWidth: Double): TChartHistogramBinning;

  function BinIndexFor(const Value: Double): Integer;
  begin
    Result := Floor(Value / BinWidth);
  end;

begin
  Result := Default(TChartHistogramBinning);

  const HasValues = (Length(Values) > 0);
  if not HasValues then
    Exit;

  var BinRange := TValueRange.Create(BinIndexFor(Values[0]), BinIndexFor(Values[0]));
  for var Value in Values do
  begin
    BinRange.Extend(BinIndexFor(Value));
  end;

  const FirstBin = Round(BinRange.Min);
  const BinCount = Round(BinRange.Max) - FirstBin + 1;

  SetLength(Result.Counts, BinCount);
  SetLength(Result.Categories, BinCount);
  for var Index := 0 to BinCount - 1 do
  begin
    Result.Categories[Index] := TAxisScale.FormatValue((FirstBin + Index) * BinWidth, False);
  end;

  for var Value in Values do
  begin
    const BinIndex = BinIndexFor(Value) - FirstBin;
    Result.Counts[BinIndex] := Result.Counts[BinIndex] + 1;
  end;
end;

constructor TChartPlot.Create;
begin
  inherited Create;
  FSeries := TObjectList<TChartSeries>.Create(True);
  FKind := TChartKind.Line;
  FStyle := TChartStyle.Default;
  FXAxis := TAxisOptions.Default;
  FYAxis := TAxisOptions.Default;
  FOrientation := TChartOrientation.Vertical;
  FStackMode := TStackMode.Values;
  FLegendPosition := TLegendPosition.Top;
  FValueLabels := TValueLabelMode.None;
  FHighlightedSeriesIndex := -1;
end;

destructor TChartPlot.Destroy;
begin
  FSeries.Free;
  inherited Destroy;
end;

function TChartPlot.AddSeries(const Name: string): TChartSeries;
begin
  Result := TChartSeries.Create(Name);
  FSeries.Add(Result);
  NotifyChanged;
end;

function TChartPlot.AddSeries(const Name: string; const Values: TArray<Double>): TChartSeries;
begin
  Result := TChartSeries.Create(Name);
  Result.Values := Values;
  FSeries.Add(Result);
  NotifyChanged;
end;

function TChartPlot.AddLineSeries(const Name: string;
                                  const XValues, YValues: TArray<Double>): TChartSeries;
begin
  Result := TChartSeries.Create(Name);
  Result.XValues := XValues;
  Result.Values := YValues;
  FSeries.Add(Result);
  NotifyChanged;
end;

function TChartPlot.AddRangeBandSeries(const Name: string;
                                       const XValues, LowValues, HighValues: TArray<Double>): TChartSeries;
begin
  Result := TChartSeries.Create(Name);
  Result.XValues := XValues;
  Result.Values := LowValues;
  Result.EndValues := HighValues;
  Result.IsRangeBand := True;
  FSeries.Add(Result);
  NotifyChanged;
end;

function TChartPlot.AddDumbbellSeries(const StartValues, EndValues: TArray<Double>): TChartSeries;
begin
  FSeries.Clear;
  Result := TChartSeries.Create('');
  Result.Values := StartValues;
  Result.EndValues := EndValues;
  FSeries.Add(Result);
  FKind := TChartKind.Dumbbell;
  FOrientation := TChartOrientation.Horizontal;
  NotifyChanged;
end;

function TChartPlot.AddRangeSeries(const Name: string; const LowValues, HighValues: TArray<Double>): TChartSeries;
begin
  FSeries.Clear;
  Result := TChartSeries.Create(Name);
  Result.Values := LowValues;
  Result.EndValues := HighValues;
  FSeries.Add(Result);
  FKind := TChartKind.Range;
  FOrientation := TChartOrientation.Horizontal;
  NotifyChanged;
end;

function TChartPlot.AddArrowSeries(const Name: string; const StartValues, EndValues: TArray<Double>): TChartSeries;
begin
  FSeries.Clear;
  Result := TChartSeries.Create(Name);
  Result.Values := StartValues;
  Result.EndValues := EndValues;
  FSeries.Add(Result);
  FKind := TChartKind.Arrow;
  FOrientation := TChartOrientation.Horizontal;
  NotifyChanged;
end;

procedure TChartPlot.SetHistogramData(const Values: TArray<Double>; const BinWidth: Double);
begin
  const HasInvalidBinWidth = (BinWidth <= 0);
  if HasInvalidBinWidth then
    raise EChart4DException.CreateFmt(SBinWidthMustBePositive, [BinWidth]);

  const HasNoValues = (Length(Values) = 0);
  if HasNoValues then
    raise EChart4DException.Create(SHistogramValuesEmpty);

  const Binning = TChartHistogramBinning.Build(Values, BinWidth);

  FSeries.Clear;
  const CountSeries = TChartSeries.Create('Count');
  CountSeries.Values := Binning.Counts;
  FSeries.Add(CountSeries);

  FCategories := Binning.Categories;
  FKind := TChartKind.Histogram;
  NotifyChanged;
end;

procedure TChartPlot.ClearSeries;
begin
  FSeries.Clear;
  NotifyChanged;
end;

procedure TChartPlot.AddTextAnnotation(const X, Y: Double; const Text: string;
                                       const Color: TAlphaColor; const AlignH: TTextAlignH = TTextAlignH.Left);
begin
  var Annotation := Default(TChartAnnotation);
  Annotation.Kind := TAnnotationKind.TextLabel;
  Annotation.X := X;
  Annotation.Y := Y;
  Annotation.Text := Text;
  Annotation.Color := Color;
  Annotation.AlignH := AlignH;
  AppendAnnotation(Annotation);
end;

procedure TChartPlot.AddSegment(const X1, Y1, X2, Y2: Double);
begin
  var Annotation := Default(TChartAnnotation);
  Annotation.Kind := TAnnotationKind.Segment;
  Annotation.X := X1;
  Annotation.Y := Y1;
  Annotation.X2 := X2;
  Annotation.Y2 := Y2;
  Annotation.Color := ChartTextDark;
  AppendAnnotation(Annotation);
end;

procedure TChartPlot.AddArrow(const X1, Y1, X2, Y2: Double);
begin
  var Annotation := Default(TChartAnnotation);
  Annotation.Kind := TAnnotationKind.Arrow;
  Annotation.X := X1;
  Annotation.Y := Y1;
  Annotation.X2 := X2;
  Annotation.Y2 := Y2;
  Annotation.Color := ChartTextDark;
  AppendAnnotation(Annotation);
end;

procedure TChartPlot.AddHorizontalLine(const Y: Double; const Color: TAlphaColor;
                                       const Dashed: Boolean = False);
begin
  var Annotation := Default(TChartAnnotation);
  Annotation.Kind := TAnnotationKind.HorizontalLine;
  Annotation.Y := Y;
  Annotation.Color := Color;
  Annotation.Dashed := Dashed;
  AppendAnnotation(Annotation);
end;

procedure TChartPlot.AddVerticalLine(const X: Double; const Color: TAlphaColor;
                                     const Dashed: Boolean = False);
begin
  var Annotation := Default(TChartAnnotation);
  Annotation.Kind := TAnnotationKind.VerticalLine;
  Annotation.X := X;
  Annotation.Color := Color;
  Annotation.Dashed := Dashed;
  AppendAnnotation(Annotation);
end;

procedure TChartPlot.AddHorizontalRangeOverlay(const Y1, Y2: Double; const Color: TAlphaColor);
begin
  var Annotation := Default(TChartAnnotation);
  Annotation.Kind := TAnnotationKind.HorizontalRangeOverlay;
  Annotation.Y := Y1;
  Annotation.Y2 := Y2;
  Annotation.Color := Color;
  AppendAnnotation(Annotation);
end;

procedure TChartPlot.AddVerticalRangeOverlay(const X1, X2: Double; const Color: TAlphaColor);
begin
  var Annotation := Default(TChartAnnotation);
  Annotation.Kind := TAnnotationKind.VerticalRangeOverlay;
  Annotation.X := X1;
  Annotation.X2 := X2;
  Annotation.Color := Color;
  AppendAnnotation(Annotation);
end;

procedure TChartPlot.ClearAnnotations;
begin
  FAnnotations := [];
  NotifyChanged;
end;

function TChartPlot.SeriesColor(const Index: Integer): TAlphaColor;
begin
  const HasValidIndex = (Index >= 0) and (Index < FSeries.Count);
  if not HasValidIndex then
    raise EChart4DException.CreateFmt(SSeriesColorIndexOutOfRange, [Index, FSeries.Count]);

  const CurrentSeries = FSeries[Index];
  const HasCustomColor = (CurrentSeries.Color <> 0);
  if HasCustomColor then
    Result := CurrentSeries.Color
  else
    Result := DefaultPalette[Index mod Length(DefaultPalette)];

  const HasValidHighlight = (FHighlightedSeriesIndex >= 0) and (FHighlightedSeriesIndex < FSeries.Count);
  const IsMuted = HasValidHighlight and (Index <> FHighlightedSeriesIndex);
  if IsMuted then
    Result := ChartLightGrey;
end;

function TChartPlot.CategoryColor(const Index: Integer): TAlphaColor;
begin
  const IsNegative = (Index < 0);
  if IsNegative then
    raise EChart4DException.CreateFmt(SCategoryColorIndexNegative, [Index]);

  Result := DefaultPalette[Index mod Length(DefaultPalette)];
end;

procedure TChartPlot.SetKind(const Value: TChartKind);
begin
  FKind := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetTitle(const Value: string);
begin
  FTitle := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetSubtitle(const Value: string);
begin
  FSubtitle := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetSource(const Value: string);
begin
  FSource := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetLogoFilePath(const Value: string);
begin
  FLogoFilePath := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetCategories(const Value: TArray<string>);
begin
  FCategories := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetStyle(const Value: TChartStyle);
begin
  FStyle := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetXAxis(const Value: TAxisOptions);
begin
  FXAxis := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetYAxis(const Value: TAxisOptions);
begin
  FYAxis := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetOrientation(const Value: TChartOrientation);
begin
  FOrientation := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetStackMode(const Value: TStackMode);
begin
  FStackMode := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetLegendPosition(const Value: TLegendPosition);
begin
  FLegendPosition := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetLegendReversed(const Value: Boolean);
begin
  FLegendReversed := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetValueLabels(const Value: TValueLabelMode);
begin
  FValueLabels := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetHighlightedSeriesIndex(const Value: Integer);
begin
  FHighlightedSeriesIndex := Value;
  NotifyChanged;
end;

procedure TChartPlot.SetDonutCenterText(const Value: string);
begin
  FDonutCenterText := Value;
  NotifyChanged;
end;

procedure TChartPlot.NotifyChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TChartPlot.AppendAnnotation(const Annotation: TChartAnnotation);
begin
  FAnnotations := FAnnotations + [Annotation];
  NotifyChanged;
end;

end.
