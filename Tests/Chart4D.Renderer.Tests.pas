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
unit Chart4D.Renderer.Tests;

/// <summary>
/// Tests for <c>TChartRenderer</c>, using <c>TRecordingCanvas</c> to assert on the
/// drawing calls a render pass produces for each chart kind and layout rule.
/// </summary>

interface

uses
  System.UITypes,
  DUnitX.TestFramework,
  Chart4D.Canvas.Interfaces,
  Chart4D.Tests.RecordingCanvas;

type
  [TestFixture]
  TChartRendererTests = class
  private
    FCanvas: IChartCanvas;
    FRecordingCanvas: TRecordingCanvas;

    function TopFillRectPerCategory(const Calls: TArray<TCanvasCall>): TArray<Single>;
    function IndexOfFirstCall(const Kind: TCanvasCallKind): Integer;
    function IndexOfFirstCallOfColor(const Kind: TCanvasCallKind; const Color: TAlphaColor): Integer;
    function CategoryAxisLabelCalls(const Categories: TArray<string>): TArray<TCanvasCall>;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Render_LineChart_DrawsBackgroundTitleAndOnePolylinePerSeries;

    [Test]
    procedure Render_LineChart_DrawsGridlineForEveryValueBreak;

    [Test]
    procedure Render_BarChart_DrawsOneFillRectPerCategory;

    [Test]
    procedure Render_StackedBarProportions_MapsTopOfEveryStackToSamePixel;

    [Test]
    procedure Render_StackedBarMixedSignValues_StacksPositiveAndNegativeSegmentsFromBaseline;

    [Test]
    procedure Render_MultipleNamedSeries_DrawsLegendWithSeriesNames;

    [Test]
    procedure Render_SingleNamedSeries_DoesNotDrawLegend;

    [Test]
    procedure Render_SourceSet_DrawsFooterSeparatorAndSourceText;

    [Test]
    procedure Render_NoSourceOrLogo_DoesNotDrawFooter;

    [Test]
    procedure Render_MismatchedCategoryAndValueLengths_RaisesException;

    [Test]
    procedure Render_LogarithmicValueAxis_DrawsGridlinesAtPowersOfTheBase;

    [Test]
    procedure Render_LogarithmicValueAxisWithNonPositiveValue_RaisesException;

    [Test]
    procedure Render_DateAxisAutoMode_DrawsLabelsProducedByTheAxisDatePipeline;

    [Test]
    procedure Render_DateAxisAutoModeNarrowBreakSpan_LabelsFollowTheModeResolvedFromTheDataRange;

    [Test]
    procedure Render_ValueAxisDateModeAuto_DrawsPlainNumericLabels;

    [Test]
    procedure Render_RangeBandSeries_DrawsPolygonBeforeOrdinarySeriesAddedEarlier;

    [Test]
    procedure Render_RangeBandSeries_ProducesTwoCircularHitTargetsPerPoint;

    [Test]
    procedure Render_RangeBandSeriesEndValuesMismatch_RaisesException;

    [Test]
    procedure Render_HorizontalRangeOverlay_DrawsBeforeFirstGridlineAndAddsNoHitTarget;

    [Test]
    procedure Render_VerticalRangeOverlay_DrawsBeforeFirstGridlineAndAddsNoHitTarget;

    [Test]
    procedure Render_ScatterSeriesWithSizes_RadiiFollowSqrtScalingFormula;

    [Test]
    procedure Render_ScatterSeriesSizesValuesMismatch_RaisesException;

    [Test]
    procedure Render_DotPlotTwoSeries_DrawsBothSeriesAtSameCategoryCenterPixel;

    [Test]
    procedure Render_RangeSeries_DrawsOneFillRectPerCategoryWithHighBoundHitTarget;

    [Test]
    procedure Render_RangeSeriesEndValuesMismatch_RaisesException;

    [Test]
    procedure Render_ArrowSeries_DrawsLineAndArrowheadPerCategory;

    [Test]
    procedure Render_ArrowSeries_ProducesTwoCircularHitTargetsWithSameSeriesColor;

    [Test]
    procedure Render_ArrowSeriesEndValuesMismatch_RaisesException;

    [Test]
    procedure Render_PieChart_WedgeSweepAnglesSumTo360;

    [Test]
    procedure Render_PieChart_WedgePolygonPointsWithinOuterRadiusOfCenter;

    [Test]
    procedure Render_PieChart_WedgeFindableViaSectorHitTarget;

    [Test]
    procedure Render_PieChartNegativeValue_RaisesException;

    [Test]
    procedure Render_PieChartSecondSeries_RaisesException;

    [Test]
    procedure Render_DonutChart_WedgePointsWithinInnerAndOuterRadiusOfCenter;

    [Test]
    procedure Render_DonutChart_CenterTextDrawsTextCallAtCenter;

    [Test]
    procedure Render_PieChartTextAnnotation_DrawsAtCategoryIndexAndPlotHeightFraction;

    [Test]
    procedure Render_DonutChartTextAnnotation_DrawsAtCategoryIndexAndPlotHeightFraction;

    [Test]
    procedure Render_ColumnChart_FourShortCategoryNames_DrawsLabelForEveryCategory;

    [Test]
    procedure Render_ColumnChart_TenLongCountryNames_ThinsLabelsButKeepsFirstAndLastWithoutCollision;

    [Test]
    procedure Render_HorizontalChart_ManyShortCategories_ThinsByHeightWhileVerticalDrawsAll;

    [Test]
    procedure Render_ShortTitle_DrawsAsSingleLine;

    [Test]
    procedure Render_LongTitle_WrapsOntoTwoLines;

    [Test]
    procedure Render_LongTitle_PlotAreaMovesDownComparedToShortTitle;

    [Test]
    procedure Render_NilPlot_RaisesException;

    [Test]
    procedure Render_NilCanvas_RaisesException;

    [Test]
    procedure Render_PlotWithoutSeries_DrawsOnlyBackgroundAndReturnsEmptyHitMap;

    [Test]
    procedure Render_SeriesWithoutValues_RaisesException;

    [Test]
    procedure Render_SeriesWithNaNValue_RaisesException;

    [Test]
    procedure Render_ReversedManualValueRange_RaisesException;

    [Test]
    procedure Render_LogarithmicValueAxisLogBaseOne_RaisesException;

    [Test]
    procedure Render_LogarithmicValueAxisManualMinValueZero_RaisesException;
  end;

implementation

uses
  System.DateUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Math,
  System.SysUtils,
  System.Types,
  Chart4D.Axis,
  Chart4D.Plot,
  Chart4D.Renderer,
  Chart4D.Style,
  Chart4D.Tooltip,
  Chart4D.Types;

procedure TChartRendererTests.Setup;
begin
  FRecordingCanvas := TRecordingCanvas.Create;
  FCanvas := FRecordingCanvas;
end;

procedure TChartRendererTests.TearDown;
begin
  FCanvas := nil;
  FRecordingCanvas := nil;
end;

procedure TChartRendererTests.Render_LineChart_DrawsBackgroundTitleAndOnePolylinePerSeries;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Life expectancy';
    Plot.Categories := ['1952', '1972', '1992'];
    Plot.AddSeries('Netherlands', [72.1, 73.2, 77.4]);
    Plot.AddSeries('Belgium', [68.0, 71.1, 76.0]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(1, FRecordingCanvas.CountOfKind(TCanvasCallKind.FillBackground));
    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('Life expectancy'));

    const Polylines = FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawPolyline);
    Assert.AreEqual(2, Length(Polylines));

    { A count alone would pass for two identical lines, so each polyline is matched to its
      own series by colour, and its shape is checked against that series' own values: one
      point per category, rising left to right, and the lower series below the higher one
      at every category. }
    var DutchLine := Default(TCanvasCall);
    var BelgianLine := Default(TCanvasCall);
    for var Call in Polylines do
    begin
      if Call.Color = Plot.SeriesColor(0) then
        DutchLine := Call
      else if Call.Color = Plot.SeriesColor(1) then
        BelgianLine := Call;
    end;

    Assert.AreEqual(3, Length(DutchLine.Points), 'the first series needs one point per category');
    Assert.AreEqual(3, Length(BelgianLine.Points), 'the second series needs one point per category');

    for var Index := 0 to 2 do
    begin
      Assert.IsTrue(BelgianLine.Points[Index].Y > DutchLine.Points[Index].Y,
                    Format('Belgium is below the Netherlands at every category, so its pixel Y must be larger, at index %d', [Index]));
    end;

    for var Index := 1 to 2 do
    begin
      Assert.IsTrue(DutchLine.Points[Index].X > DutchLine.Points[Index - 1].X,
                    'categories run left to right');
      Assert.IsTrue(DutchLine.Points[Index].Y < DutchLine.Points[Index - 1].Y,
                    'the series rises, so each point sits higher than the one before it');
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_LineChart_DrawsGridlineForEveryValueBreak;
begin
  { Values run 1 to 3, so 4% headroom (SPEC.md 4.8) widens the range by 0.04 * 2 = 0.08 on
    each side to [0.92, 3.08]. Feeding that into the NiceBreaks rule (SPEC.md 4.5) by hand:
    RawStep = 2.16 / 4 = 0.54, Magnitude = 0.1, Normalized = 5.4, which falls in the "< 7"
    band, so NiceFactor = 5 and Step = 0.5. Breaks run from Ceil(0.92 / 0.5) * 0.5 = 1.0 to
    Floor(3.08 / 0.5) * 0.5 = 3.0, giving exactly five breaks: 1.0, 1.5, 2.0, 2.5, 3.0. This
    expected count is worked out independently of TAxisScale.NiceBreaks, so the test still
    catches a wrong headroom or break computation rather than only confirming the two agree. }
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Only', [1, 2, 3]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const GridlineCount = FRecordingCanvas.CountOfColor(TCanvasCallKind.DrawLine, ChartGridGrey);

    Assert.AreEqual(5, GridlineCount);
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_BarChart_DrawsOneFillRectPerCategory;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['North', 'South', 'East', 'West'];
    Plot.AddSeries('Count', [3, -2, 5, 1]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    var Bars := FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect);
    Assert.AreEqual(4, Length(Bars));

    TArray.Sort<TCanvasCall>(Bars, TComparer<TCanvasCall>.Construct(
      function(const Left, Right: TCanvasCall): Integer
      begin
        Result := CompareValue(Left.Bounds.Left, Right.Bounds.Left);
      end));

    { North, South, East, West sit left to right, so Bars, sorted by X, line up with
      [3, -2, 5, 1]. A single linear value axis maps every bar through the same scale
      from the same zero baseline, so each bar's own height must be proportional to its
      own value: four identical bars, or bars in the wrong order, would fail these ratios
      even though they would still satisfy a bare rectangle count. }
    const NorthHeight = Bars[0].Bounds.Height;
    const SouthHeight = Bars[1].Bounds.Height;
    const EastHeight = Bars[2].Bounds.Height;
    const WestHeight = Bars[3].Bounds.Height;

    Assert.AreEqual(3 / 5, NorthHeight / EastHeight, 0.02, 'North (3) must be 3/5 the height of East (5)');
    Assert.AreEqual(2 / 5, SouthHeight / EastHeight, 0.02, 'South (-2) must be 2/5 the height of East (5)');
    Assert.AreEqual(1 / 5, WestHeight / EastHeight, 0.02, 'West (1) must be 1/5 the height of East (5)');

    { South is the only negative value, so its bar hangs below the zero baseline while
      the other three rise above it: North, East and West must therefore share one
      baseline pixel (their common Bounds.Bottom), and South's Bounds.Top must sit at
      that same pixel instead of sharing their Bottom. }
    Assert.AreEqual(Bars[0].Bounds.Bottom, Bars[2].Bounds.Bottom, 0.01, 'North and East must share the zero baseline');
    Assert.AreEqual(Bars[0].Bounds.Bottom, Bars[3].Bounds.Bottom, 0.01, 'North and West must share the zero baseline');
    Assert.AreEqual(Bars[0].Bounds.Bottom, Bars[1].Bounds.Top, 0.01,
      'South, the only negative bar, must hang from the same baseline the positive bars rise from');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_StackedBarProportions_MapsTopOfEveryStackToSamePixel;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.StackedBar;
    Plot.StackMode := TStackMode.Proportions;
    Plot.LegendPosition := TLegendPosition.None;
    Plot.Categories := ['2020', '2021', '2022'];
    Plot.AddSeries('North', [4, 5, 2]);
    Plot.AddSeries('South', [3, 4, 9]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const RectCalls = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect);
    const TopPerCategory = TopFillRectPerCategory(RectCalls);

    Assert.AreEqual(3, Length(TopPerCategory));
    for var Index := 1 to High(TopPerCategory) do
    begin
      Assert.AreEqual(TopPerCategory[0], TopPerCategory[Index], 0.01);
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_StackedBarMixedSignValues_StacksPositiveAndNegativeSegmentsFromBaseline;
begin
  { Values +5, -3 and +2 in one category must stack divergingly: the positive segments
    pile up from the zero baseline to +7 while the negative segment hangs below it to -3,
    matching the axis range ComputeStackedValueRange reserves from the separate positive
    and negative sums. A single running total would instead draw the -3 segment backwards
    over the +5 one and leave the +2 segment short of the reserved top. }
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.StackedBar;
    Plot.LegendPosition := TLegendPosition.None;
    Plot.Categories := ['2020'];
    Plot.AddSeries('First', [5]);
    Plot.AddSeries('Second', [-3]);
    Plot.AddSeries('Third', [2]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const Segments = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect);
    Assert.AreEqual(3, Length(Segments), 'A stacked bar must draw one segment per series');

    const FirstSegment = Segments[0];
    const SecondSegment = Segments[1];
    const ThirdSegment = Segments[2];

    Assert.AreEqual(FirstSegment.Bounds.Bottom, SecondSegment.Bounds.Top, 0.01,
      'The negative segment must hang from the same zero baseline the first positive segment rises from');
    Assert.AreEqual(FirstSegment.Bounds.Top, ThirdSegment.Bounds.Bottom, 0.01,
      'The second positive segment must stack on top of the first, unaffected by the negative one');

    Assert.AreEqual(5 / 2, FirstSegment.Bounds.Height / ThirdSegment.Bounds.Height, 0.02,
      'The +5 segment must be 5/2 the height of the +2 segment');
    Assert.AreEqual(3 / 2, SecondSegment.Bounds.Height / ThirdSegment.Bounds.Height, 0.02,
      'The -3 segment must be 3/2 the height of the +2 segment');

    Assert.AreEqual(3, Length(HitMap));
    Assert.IsTrue(SameValue(HitMap[0].Info.Value, 5), 'The first hit target must report its own raw value');
    Assert.IsTrue(SameValue(HitMap[1].Info.Value, -3), 'The second hit target must report its own raw value');
    Assert.IsTrue(SameValue(HitMap[2].Info.Value, 2), 'The third hit target must report its own raw value');

    Assert.IsTrue(HitMap[1].Bounds.Top >= HitMap[0].Bounds.Bottom - 0.01,
      'The negative segment''s hit target must sit entirely below the first positive one');
    Assert.IsTrue(HitMap[2].Bounds.Bottom <= HitMap[0].Bounds.Top + 0.01,
      'The second positive segment''s hit target must sit entirely above the first one');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_MultipleNamedSeries_DrawsLegendWithSeriesNames;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.GroupedBar;
    Plot.Categories := ['2020', '2021'];
    Plot.AddSeries('North', [4, 5]);
    Plot.AddSeries('South', [3, 4]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('North'));
    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('South'));
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_SingleNamedSeries_DoesNotDrawLegend;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['2020', '2021'];
    Plot.AddSeries('OnlySeries', [4, 5]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.IsFalse(FRecordingCanvas.HasTextEqualTo('OnlySeries'));
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_SourceSet_DrawsFooterSeparatorAndSourceText;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, 2]);
    Plot.Source := 'Source: Eurostat';

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('Source: Eurostat'));
    Assert.AreEqual(1, FRecordingCanvas.CountOfColor(TCanvasCallKind.DrawLine, ChartTextDark));
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_NoSourceOrLogo_DoesNotDrawFooter;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, 2]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(0, FRecordingCanvas.CountOfKind(TCanvasCallKind.DrawImage));
    Assert.AreEqual(0, FRecordingCanvas.CountOfColor(TCanvasCallKind.DrawLine, ChartTextDark));
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_MismatchedCategoryAndValueLengths_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Count', [1, 2, 3]);

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException on mismatched category/value counts');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_LogarithmicValueAxis_DrawsGridlinesAtPowersOfTheBase;
begin
  { The data already sits exactly on powers of the base 10: MinExponent = Floor(Log10(1)) = 0,
    MaxExponent = Ceil(Log10(1000)) = 3 (SPEC.md 4.15), so the snapped range needs no widening
    and the break ladder is exactly 10^0, 10^1, 10^2, 10^3, four breaks. This count is worked
    out by hand from the data rather than from TAxisScale.LogBreaks, so the test still catches
    a wrong exponent computation rather than only confirming the two agree. }
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B', 'C', 'D'];
    Plot.AddSeries('Only', [1, 10, 100, 1000]);

    var AxisOptions := Plot.YAxis;
    AxisOptions.Scale := TAxisScaleKind.Logarithmic;
    Plot.YAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const GridlineCount = FRecordingCanvas.CountOfColor(TCanvasCallKind.DrawLine, ChartGridGrey);

    Assert.AreEqual(4, GridlineCount);
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_LogarithmicValueAxisWithNonPositiveValue_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [0, 10]);

    var AxisOptions := Plot.YAxis;
    AxisOptions.Scale := TAxisScaleKind.Logarithmic;
    Plot.YAxis := AxisOptions;

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'A logarithmic value axis must raise EChart4DException for a non-positive value');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_DateAxisAutoMode_DrawsLabelsProducedByTheAxisDatePipeline;
begin
  { This is a wiring test, not a test of the date-granularity algorithm: ResolveDateMode's
    thresholds and DateBreaks' calendar stepping are each covered independently, and in
    isolation, in Chart4D.Axis.Tests.pas. What this test guards is that the renderer, when
    XAxis.DateMode is Auto, actually resolves the mode and feeds the resulting breaks through
    BuildLabels and onto the canvas, rather than silently ignoring the axis' date pipeline
    (e.g. falling back to a plain numeric axis). }
  const Plot = TChartPlot.Create;
  try
    var AxisOptions := Plot.XAxis;
    AxisOptions.DateMode := TAxisDateMode.Auto;
    Plot.XAxis := AxisOptions;

    const MinDate = EncodeDate(2024, 1, 1);
    const OnlySeries = Plot.AddSeries('Only', [1, 2, 3]);
    OnlySeries.XValues := [MinDate, MinDate + 5, MinDate + 10];

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const ResolvedMode = TAxisScale.ResolveDateMode(MinDate, MinDate + 10, TAxisDateMode.Auto);
    const ExpectedBreaks = TAxisScale.DateBreaks(MinDate, MinDate + 10, ResolvedMode);
    var ResolvedOptions := AxisOptions;
    ResolvedOptions.DateMode := ResolvedMode;
    const ExpectedLabels = TAxisScale.BuildLabels(ExpectedBreaks, ResolvedOptions);

    Assert.AreEqual(Integer(TAxisDateMode.Day), Integer(ResolvedMode));
    for var ExpectedLabel in ExpectedLabels do
    begin
      Assert.IsTrue(FRecordingCanvas.HasTextEqualTo(ExpectedLabel),
        Format('Missing expected date-axis label "%s"', [ExpectedLabel]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_DateAxisAutoModeNarrowBreakSpan_LabelsFollowTheModeResolvedFromTheDataRange;
begin
  { A 90-day data range resolves Auto to Month, but the calendar-aligned breaks it
    produces (1 Feb, 1 Mar, 1 Apr) span only 60 days: re-resolving the mode from that
    narrower break span would flip the labels to day granularity. SPEC.md 4.16: the mode
    is resolved exactly once, from the data range, and that one mode drives both break
    placement and label formatting. }
  const Plot = TChartPlot.Create;
  try
    var AxisOptions := Plot.XAxis;
    AxisOptions.DateMode := TAxisDateMode.Auto;
    Plot.XAxis := AxisOptions;

    const MinDate = EncodeDate(2024, 1, 15);
    const OnlySeries = Plot.AddSeries('Only', [1, 2, 3]);
    OnlySeries.XValues := [MinDate, MinDate + 45, MinDate + 90];

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('Feb 2024'),
      'Month-mode breaks must be labelled at month granularity');
    Assert.IsFalse(FRecordingCanvas.HasTextEqualTo('1 Feb'),
      'Labels must never re-resolve to day granularity from the narrower break span');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_ValueAxisDateModeAuto_DrawsPlainNumericLabels;
begin
  { SPEC.md 4.16: DateMode is meaningful only for a continuous X axis and has no effect
    on YAxis. An Auto date mode left on the value axis must neither raise nor date-format
    the value labels. }
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [0, 100]);

    var AxisOptions := Plot.YAxis;
    AxisOptions.DateMode := TAxisDateMode.Auto;
    Plot.YAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('0'),
      'The value axis must keep its plain numeric labels when DateMode is Auto');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_RangeBandSeries_DrawsPolygonBeforeOrdinarySeriesAddedEarlier;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Line;
    Plot.AddLineSeries('Netherlands', [1960, 1970, 1980], [73.5, 73.7, 75.9]);
    Plot.AddRangeBandSeries('Range', [1960, 1970, 1980], [70, 71, 72], [76, 77, 78]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const FirstPolygonIndex = IndexOfFirstCall(TCanvasCallKind.FillPolygon);
    const FirstPolylineIndex = IndexOfFirstCall(TCanvasCallKind.DrawPolyline);

    Assert.IsTrue(FirstPolygonIndex >= 0, 'A range-band series must draw a FillPolygon call');
    Assert.IsTrue(FirstPolylineIndex >= 0, 'The ordinary line series must draw a DrawPolyline call');
    Assert.IsTrue(FirstPolygonIndex < FirstPolylineIndex,
      'The range-band polygon must draw before the ordinary series added earlier');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_RangeBandSeries_ProducesTwoCircularHitTargetsPerPoint;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Line;
    Plot.AddRangeBandSeries('Range', [1960, 1970, 1980], [70, 71, 72], [76, 77, 78]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    Assert.AreEqual(6, Length(HitMap));

    var LowMatchCount := 0;
    var HighMatchCount := 0;
    for var Target in HitMap do
    begin
      Assert.IsTrue(Target.Radius > 0, 'A range-band hit target must be circular');

      if SameValue(Target.Info.Value, 70) or SameValue(Target.Info.Value, 71) or SameValue(Target.Info.Value, 72) then
        Inc(LowMatchCount);
      if SameValue(Target.Info.Value, 76) or SameValue(Target.Info.Value, 77) or SameValue(Target.Info.Value, 78) then
        Inc(HighMatchCount);
    end;

    Assert.AreEqual(3, LowMatchCount);
    Assert.AreEqual(3, HighMatchCount);
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_RangeBandSeriesEndValuesMismatch_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Line;
    Plot.AddRangeBandSeries('Range', [1960, 1970, 1980], [70, 71, 72], [76, 77]);

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException when a band series has mismatched low/high value counts');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_HorizontalRangeOverlay_DrawsBeforeFirstGridlineAndAddsNoHitTarget;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Only', [1, 2, 3]);
    Plot.AddHorizontalRangeOverlay(1, 2, TAlphaColor($30990000));

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const FirstOverlayIndex = IndexOfFirstCall(TCanvasCallKind.FillPolygon);
    const FirstGridlineIndex = IndexOfFirstCallOfColor(TCanvasCallKind.DrawLine, ChartGridGrey);

    Assert.IsTrue(FirstOverlayIndex >= 0, 'A HorizontalRangeOverlay must draw a FillPolygon call');
    Assert.IsTrue(FirstGridlineIndex >= 0, 'The chart must draw at least one gridline');
    Assert.IsTrue(FirstOverlayIndex < FirstGridlineIndex,
      'A HorizontalRangeOverlay must draw before the first gridline');
    Assert.AreEqual(3, Length(HitMap), 'A range overlay must add nothing to the hit map');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_VerticalRangeOverlay_DrawsBeforeFirstGridlineAndAddsNoHitTarget;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Only', [1, 2, 3]);
    Plot.AddVerticalRangeOverlay(0, 1, TAlphaColor($30990000));

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const FirstOverlayIndex = IndexOfFirstCall(TCanvasCallKind.FillPolygon);
    const FirstGridlineIndex = IndexOfFirstCallOfColor(TCanvasCallKind.DrawLine, ChartGridGrey);

    Assert.IsTrue(FirstOverlayIndex >= 0, 'A VerticalRangeOverlay must draw a FillPolygon call');
    Assert.IsTrue(FirstGridlineIndex >= 0, 'The chart must draw at least one gridline');
    Assert.IsTrue(FirstOverlayIndex < FirstGridlineIndex,
      'A VerticalRangeOverlay must draw before the first gridline');
    Assert.AreEqual(3, Length(HitMap), 'A range overlay must add nothing to the hit map');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_ScatterSeriesWithSizes_RadiiFollowSqrtScalingFormula;
begin
  { Sizes span [10, 30], and the style default sets MinBubbleRadius = 4, MaxBubbleRadius = 24
    (SPEC.md 3). Working the area-proportional Sqrt scaling (SPEC.md 4.8) out by hand for each
    size: 10 (the minimum) maps to 4.0 exactly; 30 (the maximum) maps to 24.0 exactly; 20 sits
    halfway through the [10, 30] domain, so its radius is 4 + 20 * Sqrt(0.5) = 18.14213562. These
    literal figures are worked out independently of the renderer's own formula, so the test
    still catches a wrong scaling computation rather than only confirming the two agree. }
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Scatter;
    const ScatterSeries = Plot.AddLineSeries('Only', [1, 2, 3], [10, 20, 30]);
    ScatterSeries.Sizes := [10, 20, 30];

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const ExpectedRadii: TArray<Single> = [4.0, 18.14213562, 24.0];

    const Circles = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillCircle);
    Assert.AreEqual(3, Length(Circles));
    for var Index := 0 to High(Circles) do
    begin
      Assert.AreEqual(ExpectedRadii[Index], Circles[Index].Radius, 0.01);
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_ScatterSeriesSizesValuesMismatch_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Scatter;
    const ScatterSeries = Plot.AddLineSeries('Only', [1, 2, 3], [10, 20, 30]);
    ScatterSeries.Sizes := [5, 6];

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException when a scatter series Sizes length does not match Values');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_DotPlotTwoSeries_DrawsBothSeriesAtSameCategoryCenterPixel;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.DotPlot;
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('First', [10, 20]);
    Plot.AddSeries('Second', [15, 25]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const Circles = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillCircle);
    Assert.AreEqual(4, Length(Circles));

    var XGroups: TArray<Single> := [];
    var CountPerGroup: TArray<Integer> := [];
    for var Circle in Circles do
    begin
      var GroupIndex := -1;
      for var Index := 0 to High(XGroups) do
      begin
        if SameValue(XGroups[Index], Circle.CenterX, 0.01) then
        begin
          GroupIndex := Index;
          Break;
        end;
      end;

      const IsNewGroup = (GroupIndex = -1);
      if IsNewGroup then
      begin
        XGroups := XGroups + [Circle.CenterX];
        CountPerGroup := CountPerGroup + [1];
      end
      else
        CountPerGroup[GroupIndex] := CountPerGroup[GroupIndex] + 1;
    end;

    Assert.AreEqual(2, Length(XGroups), 'Expected one shared X pixel per category');
    for var Count in CountPerGroup do
    begin
      Assert.AreEqual(2, Count, 'Each category X pixel must have exactly the two series'' dots');
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_RangeSeries_DrawsOneFillRectPerCategoryWithHighBoundHitTarget;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['Mon', 'Tue', 'Wed'];
    Plot.AddRangeSeries('Temperature', [12.1, 10.4, 9.8], [22.5, 23.6, 21.4]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const FillRects = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect);
    Assert.AreEqual(3, Length(FillRects), 'A range plot must draw one filled rectangle per category');

    Assert.AreEqual(3, Length(HitMap));
    for var Index := 0 to High(HitMap) do
    begin
      Assert.IsTrue(HitMap[Index].Radius = 0, 'A range hit target must be rectangular, not circular');
      Assert.AreEqual('Temperature', HitMap[Index].Info.SeriesName);
    end;
    Assert.IsTrue(SameValue(HitMap[0].Info.Value, 22.5), 'Info.Value must report the high bound (EndValues)');
    Assert.IsTrue(SameValue(HitMap[1].Info.Value, 23.6), 'Info.Value must report the high bound (EndValues)');
    Assert.IsTrue(SameValue(HitMap[2].Info.Value, 21.4), 'Info.Value must report the high bound (EndValues)');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_RangeSeriesEndValuesMismatch_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['Mon', 'Tue', 'Wed'];
    Plot.AddRangeSeries('Temperature', [12.1, 10.4, 9.8], [22.5, 23.6]);

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException when a range series has mismatched start/end value counts');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_ArrowSeries_DrawsLineAndArrowheadPerCategory;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['France', 'Spain', 'Italy'];
    Plot.AddArrowSeries('Change', [70.1, 69.4, 68.8], [82.5, 83.6, 83.4]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const ShaftColor = Plot.SeriesColor(0);
    var ShaftCount := 0;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawLine) do
    begin
      if Call.Color = ShaftColor then
        Inc(ShaftCount);
    end;
    const Polygons = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillPolygon);

    Assert.AreEqual(3, ShaftCount, 'An arrow plot must draw one shaft line per category, in the series'' own color');
    Assert.AreEqual(3, Length(Polygons), 'An arrow plot must draw one arrowhead triangle per category');

    { Counting shafts and heads would pass for three arrows drawn on top of each other, or
      pointing the wrong way. Every category here rises, and the kind is horizontal, so each
      arrow must run left to right with its head at the right-hand end, and the three must
      sit on separate rows. }
    var Shafts: TArray<TCanvasCall>;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawLine) do
    begin
      if Call.Color = ShaftColor then
        Shafts := Shafts + [Call];
    end;

    for var Index := 0 to 2 do
    begin
      Assert.IsTrue(Shafts[Index].X2 > Shafts[Index].X1,
                    Format('the value rises, so the arrow at index %d must run left to right', [Index]));
      Assert.AreEqual(Shafts[Index].Y1, Shafts[Index].Y2, 0.01,
                      Format('a horizontal arrow stays on one row, at index %d', [Index]));

      const Apex = Polygons[Index].Points[0];
      Assert.IsTrue(Apex.X > Shafts[Index].X2,
                    Format('the head sits beyond the end of its shaft, at index %d', [Index]));
      Assert.AreEqual(Shafts[Index].Y1, Apex.Y, 0.01,
                      Format('the head shares the row of its shaft, at index %d', [Index]));
    end;

    Assert.IsTrue(Shafts[1].Y1 > Shafts[0].Y1, 'the second category sits on a row below the first');
    Assert.IsTrue(Shafts[2].Y1 > Shafts[1].Y1, 'the third category sits on a row below the second');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_ArrowSeries_ProducesTwoCircularHitTargetsWithSameSeriesColor;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['France', 'Spain', 'Italy'];
    Plot.AddArrowSeries('Change', [70.1, 69.4, 68.8], [82.5, 83.6, 83.4]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    Assert.AreEqual(6, Length(HitMap));

    const ExpectedColor = Plot.SeriesColor(0);
    var StartMatchCount := 0;
    var EndMatchCount := 0;
    for var Target in HitMap do
    begin
      Assert.IsTrue(Target.Radius > 0, 'An arrow hit target must be circular');
      Assert.AreEqual<TAlphaColor>(ExpectedColor, Target.Info.Color, 'Both arrow ends must report the series'' own color');
      Assert.AreEqual('Change', Target.Info.SeriesName);

      if SameValue(Target.Info.Value, 70.1) or SameValue(Target.Info.Value, 69.4) or SameValue(Target.Info.Value, 68.8) then
        Inc(StartMatchCount);
      if SameValue(Target.Info.Value, 82.5) or SameValue(Target.Info.Value, 83.6) or SameValue(Target.Info.Value, 83.4) then
        Inc(EndMatchCount);
    end;

    Assert.AreEqual(3, StartMatchCount);
    Assert.AreEqual(3, EndMatchCount);
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_ArrowSeriesEndValuesMismatch_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['France', 'Spain', 'Italy'];
    Plot.AddArrowSeries('Change', [70.1, 69.4, 68.8], [82.5, 83.6]);

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException when an arrow series has mismatched start/end value counts');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_PieChart_WedgeSweepAnglesSumTo360;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.Categories := ['North', 'South', 'East', 'West'];
    Plot.AddSeries('Share', [10, 20, 30, 40]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    Assert.AreEqual(4, Length(HitMap));

    var TotalSweep := 0.0;
    for var Target in HitMap do
    begin
      Assert.IsTrue(Target.IsSector, 'A pie wedge hit target must be a sector');
      TotalSweep := TotalSweep + Target.SweepAngle;
    end;

    Assert.IsTrue(SameValue(360, TotalSweep, 0.01), 'A pie chart''s wedge sweep angles must sum to 360 degrees');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_PieChart_WedgePolygonPointsWithinOuterRadiusOfCenter;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.Categories := ['North', 'South', 'East'];
    Plot.AddSeries('Share', [10, 20, 30]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const Center = HitMap[0].Center;
    const OuterRadius = HitMap[0].OuterRadius;

    const Polygons = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillPolygon);
    Assert.AreEqual(3, Length(Polygons), 'A pie chart must draw one FillPolygon wedge per category');

    for var Polygon in Polygons do
    begin
      for var Point in Polygon.Points do
      begin
        const Distance = Point.Distance(Center);
        Assert.IsTrue(Distance <= OuterRadius + 0.5,
          'Every pie wedge polygon point must lie within [0, OuterRadius] of the computed center');
      end;
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_PieChart_WedgeFindableViaSectorHitTarget;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.Categories := ['North', 'South', 'East'];
    Plot.AddSeries('Share', [10, 20, 30]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const FirstTarget = HitMap[0];
    var Info: TChartHitInfo;
    const Found = TChartTooltip.FindTarget(HitMap, FirstTarget.Info.AnchorX, FirstTarget.Info.AnchorY, Info);

    Assert.IsTrue(Found, 'A point at a wedge''s own label anchor must be found via its sector hit target');
    Assert.AreEqual('North', Info.CategoryLabel);
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_PieChartNegativeValue_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.Categories := ['North', 'South'];
    Plot.AddSeries('Share', [10, -5]);

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException for a negative Pie/Donut value');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_PieChartSecondSeries_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.Categories := ['North', 'South'];
    Plot.AddSeries('Share', [10, 20]);
    Plot.AddSeries('Other', [5, 5]);

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException when a Pie/Donut plot has more than one series');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_DonutChart_WedgePointsWithinInnerAndOuterRadiusOfCenter;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Donut;
    Plot.Categories := ['North', 'South', 'East'];
    Plot.AddSeries('Share', [10, 20, 30]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const Center = HitMap[0].Center;
    const InnerRadius = HitMap[0].InnerRadius;
    const OuterRadius = HitMap[0].OuterRadius;
    Assert.IsTrue(InnerRadius > 0, 'A donut wedge must have a non-zero inner radius');

    const Polygons = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillPolygon);
    Assert.AreEqual(3, Length(Polygons), 'A donut chart must draw one FillPolygon wedge per category');

    for var Polygon in Polygons do
    begin
      for var Point in Polygon.Points do
      begin
        const Distance = Point.Distance(Center);
        Assert.IsTrue((Distance >= InnerRadius - 0.5) and (Distance <= OuterRadius + 0.5),
          'Every donut wedge polygon point must lie within [InnerRadius, OuterRadius] of the center');
      end;
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_DonutChart_CenterTextDrawsTextCallAtCenter;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Donut;
    Plot.Categories := ['North', 'South'];
    Plot.AddSeries('Share', [10, 20]);
    Plot.DonutCenterText := 'Total: 30';

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const Center = HitMap[0].Center;
    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('Total: 30'));

    var FoundAtCenter := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      const IsCenterText = (Call.Text = 'Total: 30') and SameValue(Call.TextX, Center.X, 0.01) and
                           SameValue(Call.TextY, Center.Y, 0.01);
      if IsCenterText then
      begin
        FoundAtCenter := True;
        Assert.AreEqual(Plot.Style.TitleFontSize, Call.TextStyle.Size, 'DonutCenterText must use TitleFontSize');
        Assert.AreEqual(Plot.Style.TitleColor, Call.TextStyle.Color, 'DonutCenterText must use TitleColor');
        Assert.IsFalse(Call.TextStyle.Bold, 'DonutCenterText is deliberately not bold, per SPEC.md 4.24');
      end;
    end;

    Assert.IsTrue(FoundAtCenter, 'DonutCenterText must be drawn at the computed center');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_PieChartTextAnnotation_DrawsAtCategoryIndexAndPlotHeightFraction;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.Categories := ['North', 'South', 'East'];
    Plot.AddSeries('Share', [10, 20, 30]);
    Plot.AddTextAnnotation(1, 0.5, 'Callout', ChartTextDark, TTextAlignH.Center);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    { X = 1 is the middle of three category bands and Y = 0.5 half the plot height, which
      together is the center of the plot rectangle: exactly where the wedges' own center
      sits, so the wedge hit targets provide the expected point. }
    const Center = HitMap[0].Center;
    var FoundAtCenter := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      const IsAnnotationAtCenter = (Call.Text = 'Callout') and SameValue(Call.TextX, Center.X, 0.01) and
                                   SameValue(Call.TextY, Center.Y, 0.01);
      if IsAnnotationAtCenter then
        FoundAtCenter := True;
    end;

    Assert.IsTrue(FoundAtCenter,
      'A pie annotation at (1, 0.5) must be drawn at the plot center instead of collapsing to a corner');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_DonutChartTextAnnotation_DrawsAtCategoryIndexAndPlotHeightFraction;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Donut;
    Plot.Categories := ['North', 'South', 'East'];
    Plot.AddSeries('Share', [10, 20, 30]);
    Plot.AddTextAnnotation(1, 0.5, 'Callout', ChartTextDark, TTextAlignH.Center);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    const Center = HitMap[0].Center;
    var FoundAtCenter := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      const IsAnnotationAtCenter = (Call.Text = 'Callout') and SameValue(Call.TextX, Center.X, 0.01) and
                                   SameValue(Call.TextY, Center.Y, 0.01);
      if IsAnnotationAtCenter then
        FoundAtCenter := True;
    end;

    Assert.IsTrue(FoundAtCenter,
      'A donut annotation at (1, 0.5) must be drawn at the plot center instead of collapsing to a corner');
  finally
    Plot.Free;
  end;
end;

function TChartRendererTests.IndexOfFirstCall(const Kind: TCanvasCallKind): Integer;
begin
  Result := -1;
  for var Index := 0 to FRecordingCanvas.Calls.Count - 1 do
  begin
    const IsMatch = (FRecordingCanvas.Calls[Index].Kind = Kind);
    if IsMatch then
      Exit(Index);
  end;
end;

function TChartRendererTests.IndexOfFirstCallOfColor(const Kind: TCanvasCallKind; const Color: TAlphaColor): Integer;
begin
  Result := -1;
  for var Index := 0 to FRecordingCanvas.Calls.Count - 1 do
  begin
    const CurrentCall = FRecordingCanvas.Calls[Index];
    const IsMatch = (CurrentCall.Kind = Kind) and (CurrentCall.Color = Color);
    if IsMatch then
      Exit(Index);
  end;
end;

function TChartRendererTests.TopFillRectPerCategory(const Calls: TArray<TCanvasCall>): TArray<Single>;
begin
  var CategoryCenters: TArray<Single> := [];
  var CategoryTops: TArray<Single> := [];

  for var Call in Calls do
  begin
    const CenterX = (Call.Bounds.Left + Call.Bounds.Right) / 2;

    var GroupIndex := -1;
    for var Index := 0 to High(CategoryCenters) do
    begin
      const IsSameCategory = SameValue(CategoryCenters[Index], CenterX, 0.01);
      if IsSameCategory then
      begin
        GroupIndex := Index;
        Break;
      end;
    end;

    const IsNewCategory = (GroupIndex = -1);
    if IsNewCategory then
    begin
      CategoryCenters := CategoryCenters + [CenterX];
      CategoryTops := CategoryTops + [Call.Bounds.Top];
    end
    else
    begin
      CategoryTops[GroupIndex] := Min(CategoryTops[GroupIndex], Call.Bounds.Top);
    end;
  end;

  Result := CategoryTops;
end;

function TChartRendererTests.CategoryAxisLabelCalls(const Categories: TArray<string>): TArray<TCanvasCall>;
begin
  Result := [];
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    var IsCategoryLabel := False;
    for var CategoryText in Categories do
    begin
      if Call.Text = CategoryText then
      begin
        IsCategoryLabel := True;
        Break;
      end;
    end;

    if IsCategoryLabel then
      Result := Result + [Call];
  end;
end;

procedure TChartRendererTests.Render_ColumnChart_FourShortCategoryNames_DrawsLabelForEveryCategory;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['North', 'South', 'East', 'West'];
    Plot.AddSeries('Count', [3, 2, 5, 1]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const LabelCalls = CategoryAxisLabelCalls(Plot.Categories);

    Assert.AreEqual(4, Length(LabelCalls),
      'Four short category names must all fit and all be drawn');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_ColumnChart_TenLongCountryNames_ThinsLabelsButKeepsFirstAndLastWithoutCollision;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['Netherlands', 'Belgium', 'Germany', 'France', 'Switzerland',
      'Luxembourg', 'Portugal', 'Denmark', 'Ireland', 'UK'];
    Plot.AddSeries('Life expectancy', [82.3, 82.2, 81.3, 82.7, 84.0, 82.6, 82.0, 81.6, 82.8, 81.2]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    var LabelCalls := CategoryAxisLabelCalls(Plot.Categories);

    Assert.IsTrue(Length(LabelCalls) < Length(Plot.Categories),
      'Ten country-length category names must not all fit, so some must be thinned out');

    var HasFirst := False;
    var HasLast := False;
    for var Call in LabelCalls do
    begin
      if Call.Text = Plot.Categories[0] then
        HasFirst := True;
      if Call.Text = Plot.Categories[High(Plot.Categories)] then
        HasLast := True;
    end;
    Assert.IsTrue(HasFirst, 'The first category must stay labelled to anchor the axis');
    Assert.IsTrue(HasLast, 'The last category must stay labelled to anchor the axis');

    TArray.Sort<TCanvasCall>(LabelCalls, TComparer<TCanvasCall>.Construct(
      function(const Left, Right: TCanvasCall): Integer
      begin
        Result := CompareValue(Left.TextX, Right.TextX);
      end));

    for var Index := 1 to High(LabelCalls) do
    begin
      const Previous = LabelCalls[Index - 1];
      const Current = LabelCalls[Index];
      const PreviousWidth = FCanvas.MeasureText(Previous.Text, Previous.TextStyle).Width;
      const CurrentWidth = FCanvas.MeasureText(Current.Text, Current.TextStyle).Width;
      const Distance = Current.TextX - Previous.TextX;
      const RequiredGap = (PreviousWidth + CurrentWidth) / 2;

      Assert.IsTrue(Distance >= RequiredGap - 0.01,
        Format('Drawn labels "%s" and "%s" must not collide', [Previous.Text, Current.Text]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_HorizontalChart_ManyShortCategories_ThinsByHeightWhileVerticalDrawsAll;
begin
  // Single-letter names so every label's measured width is identical and tiny: any
  // thinning that still happens must come from the band being too narrow, not from
  // label length, which isolates the height-vs-width difference between orientations.
  var Categories: TArray<string> := [];
  for var Index := 0 to 19 do
    Categories := Categories + [Chr(Ord('A') + Index)];

  const VerticalPlot = TChartPlot.Create;
  try
    VerticalPlot.Kind := TChartKind.Bar;
    VerticalPlot.Orientation := TChartOrientation.Vertical;
    VerticalPlot.Categories := Categories;
    var Values: TArray<Double> := [];
    for var Index := 0 to 19 do
      Values := Values + [Index + 1];
    VerticalPlot.AddSeries('Count', Values);

    TChartRenderer.Render(VerticalPlot, FCanvas, 640, 450);
    const VerticalLabelCount = Length(CategoryAxisLabelCalls(Categories));

    Setup;

    const HorizontalPlot = TChartPlot.Create;
    try
      HorizontalPlot.Kind := TChartKind.Bar;
      HorizontalPlot.Orientation := TChartOrientation.Horizontal;
      HorizontalPlot.Categories := Categories;
      HorizontalPlot.AddSeries('Count', Values);

      TChartRenderer.Render(HorizontalPlot, FCanvas, 640, 450);
      const HorizontalLabelCount = Length(CategoryAxisLabelCalls(Categories));

      Assert.AreEqual(20, VerticalLabelCount,
        'Short category names stacked side by side must all fit and all be drawn');
      Assert.IsTrue(HorizontalLabelCount < 20,
        'The same short names stacked one per row must be thinned, since the constraint is label height, not width');
    finally
      HorizontalPlot.Free;
    end;
  finally
    VerticalPlot.Free;
  end;
end;

procedure TChartRendererTests.Render_ShortTitle_DrawsAsSingleLine;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Short title';
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, 2]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    var TitleCalls := 0;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text = Plot.Title then
        Inc(TitleCalls);
    end;

    Assert.AreEqual(1, TitleCalls, 'A title that fits within the available width must draw as a single line');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_LongTitle_WrapsOntoTwoLines;
begin
  const FirstWord = StringOfChar('A', 34);
  const SecondWord = StringOfChar('B', 34);

  const Plot = TChartPlot.Create;
  try
    Plot.Title := FirstWord + ' ' + SecondWord;
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, 2]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.IsFalse(FRecordingCanvas.HasTextEqualTo(Plot.Title),
      'A title wider than the available width must not be drawn as a single unwrapped line');
    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo(FirstWord), 'The first word must be drawn on its own line');
    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo(SecondWord), 'The second word must wrap onto a second line');

    var FirstLineY: Single := 0;
    var SecondLineY: Single := 0;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text = FirstWord then
        FirstLineY := Call.TextY;
      if Call.Text = SecondWord then
        SecondLineY := Call.TextY;
    end;

    const ExpectedLineHeight = Plot.Style.TitleFontSize * 1.2;
    Assert.AreEqual(FirstLineY + ExpectedLineHeight, SecondLineY, 0.01,
      'The wrapped second line must sit exactly one title line height below the first');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_LongTitle_PlotAreaMovesDownComparedToShortTitle;
begin
  const FirstWord = StringOfChar('A', 34);
  const SecondWord = StringOfChar('B', 34);

  const ShortPlot = TChartPlot.Create;
  try
    ShortPlot.Title := 'Short title';
    ShortPlot.Categories := ['A', 'B'];
    ShortPlot.AddSeries('Only', [10, 20]);
    var ShortYAxis := ShortPlot.YAxis;
    ShortYAxis.MaxValue := 100;
    ShortYAxis.Breaks := [100];
    ShortPlot.YAxis := ShortYAxis;

    TChartRenderer.Render(ShortPlot, FCanvas, 640, 450);
    const ShortPlotTopY = FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawLine)[0].Y1;

    Setup;

    const LongPlot = TChartPlot.Create;
    try
      LongPlot.Title := FirstWord + ' ' + SecondWord;
      LongPlot.Categories := ['A', 'B'];
      LongPlot.AddSeries('Only', [10, 20]);
      var LongYAxis := LongPlot.YAxis;
      LongYAxis.MaxValue := 100;
      LongYAxis.Breaks := [100];
      LongPlot.YAxis := LongYAxis;

      TChartRenderer.Render(LongPlot, FCanvas, 640, 450);
      const LongPlotTopY = FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawLine)[0].Y1;

      const ExpectedLineHeight = LongPlot.Style.TitleFontSize * 1.2;
      Assert.AreEqual(ShortPlotTopY + ExpectedLineHeight, LongPlotTopY, 0.01,
        'Wrapping the title onto a second line must push the plot area down by exactly one title line height');
    finally
      LongPlot.Free;
    end;
  finally
    ShortPlot.Free;
  end;
end;

procedure TChartRendererTests.Render_NilPlot_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TChartRenderer.Render(nil, FCanvas, 640, 450);
    end,
    EChart4DException,
    'TChartRenderer.Render must raise EChart4DException on a nil plot');
end;

procedure TChartRendererTests.Render_NilCanvas_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, 2]);

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, nil, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException on a nil canvas');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_PlotWithoutSeries_DrawsOnlyBackgroundAndReturnsEmptyHitMap;
begin
  { A control that paints before its first AddSeries renders on every paint cycle, so an
    empty plot must not raise: it fills the background, draws nothing else, and yields an
    empty hit map. Only explicit export entry points (SaveToPng) still treat an empty
    plot as an error. }
  const Plot = TChartPlot.Create;
  try
    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    Assert.AreEqual(1, FRecordingCanvas.CountOfKind(TCanvasCallKind.FillBackground));
    Assert.AreEqual(1, FRecordingCanvas.Calls.Count, 'An empty plot must draw nothing but the background');
    Assert.AreEqual(0, Length(HitMap), 'An empty plot must yield an empty hit map');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_SeriesWithoutValues_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.AddSeries('Only');

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException when a series has no values');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_SeriesWithNaNValue_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, NaN]);

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException when a series value is NaN');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_ReversedManualValueRange_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, 2]);

    var AxisOptions := Plot.YAxis;
    AxisOptions.MinValue := 100;
    AxisOptions.MaxValue := 10;
    Plot.YAxis := AxisOptions;

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'TChartRenderer.Render must raise EChart4DException on a reversed manual value range');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_LogarithmicValueAxisLogBaseOne_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, 10]);

    var AxisOptions := Plot.YAxis;
    AxisOptions.Scale := TAxisScaleKind.Logarithmic;
    AxisOptions.LogBase := 1;
    Plot.YAxis := AxisOptions;

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'A logarithmic value axis must raise EChart4DException when LogBase is 1');
  finally
    Plot.Free;
  end;
end;

procedure TChartRendererTests.Render_LogarithmicValueAxisManualMinValueZero_RaisesException;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [1, 10]);

    var AxisOptions := Plot.YAxis;
    AxisOptions.Scale := TAxisScaleKind.Logarithmic;
    AxisOptions.MinValue := 0;
    Plot.YAxis := AxisOptions;

    Assert.WillRaise(
      procedure
      begin
        TChartRenderer.Render(Plot, FCanvas, 640, 450);
      end,
      EChart4DException,
      'A logarithmic value axis must raise EChart4DException for a manual MinValue of 0');
  finally
    Plot.Free;
  end;
end;

end.
