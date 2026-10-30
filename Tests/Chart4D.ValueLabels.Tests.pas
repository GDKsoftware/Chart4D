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
unit Chart4D.ValueLabels.Tests;

/// <summary>
/// Tests for built-in value labels (<c>TChartPlot.ValueLabels</c>): candidate selection
/// per mode and chart kind, the deterministic overlap-avoidance rule, and per-kind label
/// placement, all against a <c>TRecordingCanvas</c>.
/// </summary>

interface

uses
  System.Types,
  DUnitX.TestFramework,
  Chart4D.Canvas.Interfaces,
  Chart4D.Style,
  Chart4D.Tests.RecordingCanvas;

type
  [TestFixture]
  TChartValueLabelsTests = class
  private
    FCanvas: IChartCanvas;
    FRecordingCanvas: TRecordingCanvas;

    function WhiteBoxCount: Integer;
    function CountOfText(const Text: string): Integer;
    function CountOfValueLabelText(const Text: string): Integer;
    function ValueLabelCall(const Text: string): TCanvasCall;
    function BesideDistance(const Style: TChartStyle; const Text: string; const IsVerticalStep: Boolean): Single;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ValueLabels_None_DrawsNoLabels;

    [Test]
    procedure ValueLabels_AllMode_LineChartTwoSeries_LabelsEveryPointOfBothSeries;

    [Test]
    procedure ValueLabels_AllMode_ScatterChartTwoSeries_LabelsEveryPointOfBothSeries;

    [Test]
    procedure ValueLabels_AllMode_LineChartWithRangeBand_LabelsOnlyTheOrdinarySeries;

    [Test]
    procedure ValueLabels_AllMode_DotPlotTwoSeries_LabelsEveryPointOfBothSeries;

    [Test]
    procedure ValueLabels_FirstAndLastMode_BarChart_LabelsOnlyFirstAndLastCategory;

    [Test]
    procedure ValueLabels_ExtremesMode_TiedMaximum_KeepsFirstOccurrenceOnly;

    [Test]
    procedure ValueLabels_ExtremesMode_Dumbbell_SelectsPerGroupAcrossStartAndEnd;

    [Test]
    procedure ValueLabels_OverlappingCandidates_DrawsOnlyTheFirstInFixedOrder;

    [Test]
    procedure ValueLabels_LineChart_PlacementIsOffsetAboveThePoint;

    [Test]
    procedure ValueLabels_LineChartFirstAndLast_LabelsSitBeforeAndAfterTheLine;

    [Test]
    procedure ValueLabels_LineOnContinuousAxis_PlotLeavesRoomBeforeTheFirstPoint;

    [Test]
    procedure ValueLabels_HorizontalBarChart_LabelSitsBeyondTheEndOfTheBar;

    [Test]
    procedure ValueLabels_BarReachingThePlotEdge_LabelSitsInsideTheEndOfTheBar;

    [Test]
    procedure ValueLabels_LineChart_ValueAxisLabelsKeepTheirPlace;

    [Test]
    procedure ValueLabels_LineChartValley_LabelSitsBelowThePoint;

    [Test]
    procedure ValueLabels_BarReachingTheTop_LabelSitsInsideTheBarTop;

    [Test]
    procedure ValueLabels_StackedBarMixedSignValues_PlacementFollowsDivergingSegmentEnds;

    [Test]
    procedure ValueLabels_DumbbellChart_PlacementIsOffsetAwayFromTheOtherEnd;

    [Test]
    procedure ValueLabels_ArrowChart_PlacementIsOffsetBeyondTheArrowhead;

    [Test]
    procedure ValueLabels_ArrowChart_OnlyLabelsTheEndPointNeverTheStart;

    [Test]
    procedure ValueLabels_NearAxisLabels_AreDrawnAndStayOutOfTheAxisLabelBand;

    [Test]
    procedure ValueLabels_YAxisDecimals_LabelsCarryThatManyDecimals;

    [Test]
    procedure ValueLabels_StyleLabelBackgroundColor_FillsEveryValueLabelBox;

    [Test]
    procedure ArrowChart_ShaftStopsAtTheHeadInsteadOfRunningThroughTheTip;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  Chart4D.Axis,
  Chart4D.Plot,
  Chart4D.Renderer,
  Chart4D.Types;

procedure TChartValueLabelsTests.Setup;
begin
  FRecordingCanvas := TRecordingCanvas.Create;
  FCanvas := FRecordingCanvas;
end;

procedure TChartValueLabelsTests.TearDown;
begin
  FCanvas := nil;
  FRecordingCanvas := nil;
end;

function TChartValueLabelsTests.WhiteBoxCount: Integer;
begin
  Result := FRecordingCanvas.CountOfColor(TCanvasCallKind.FillRect, TAlphaColor($FFFFFFFF));
end;

function TChartValueLabelsTests.CountOfText(const Text: string): Integer;
begin
  Result := 0;
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    if Call.Text = Text then
      Inc(Result);
  end;
end;

function TChartValueLabelsTests.CountOfValueLabelText(const Text: string): Integer;
begin
  { A value label is the only text drawn Center/Middle aligned (see
    ValueLabels_NearAxisLabels_AreDrawnAndStayOutOfTheAxisLabelBand): axis break labels are
    Right/Middle, so this cannot conflate a value label with an axis break label that
    happens to format to the same text. }
  Result := 0;
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    const IsValueLabel = (Call.AlignH = TTextAlignH.Center) and (Call.AlignV = TTextAlignV.Middle);
    if IsValueLabel and (Call.Text = Text) then
      Inc(Result);
  end;
end;

function TChartValueLabelsTests.ValueLabelCall(const Text: string): TCanvasCall;
begin
  Result := Default(TCanvasCall);
  var WasDrawn := False;
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    const IsValueLabel = (Call.AlignH = TTextAlignH.Center) and (Call.AlignV = TTextAlignV.Middle);
    if IsValueLabel and (Call.Text = Text) then
    begin
      Result := Call;
      WasDrawn := True;
    end;
  end;

  Assert.IsTrue(WasDrawn, Format('no value label was drawn for %s', [Text]));
end;

function TChartValueLabelsTests.BesideDistance(const Style: TChartStyle; const Text: string;
                                               const IsVerticalStep: Boolean): Single;
begin
  { How far a value label's text center lies from the point it labels: the 4 px gap,
    the 3 px box padding and half the text, all at the style's scale. }
  const TextStyle = TChartTextStyle.Create(Style.FontName, Style.AxisFontSize, False, Style.TextColor);
  const TextSize = FRecordingCanvas.MeasureText(Text, TextStyle);
  const HalfText = IfThen(IsVerticalStep, TextSize.Height, TextSize.Width) / 2;

  Result := (4 + 3) * Style.ScaleFactor + HalfText;
end;

procedure TChartValueLabelsTests.ValueLabels_None_DrawsNoLabels;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [10, 20]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(0, WhiteBoxCount);
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_AllMode_LineChartTwoSeries_LabelsEveryPointOfBothSeries;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Line;
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Low', [10, 20, 30]);
    Plot.AddSeries('High', [70, 80, 90]);
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(6, WhiteBoxCount);
    { The Y axis is automatic here, so one of its "nice" breaks (e.g. 20) can format to the
      same text as one of these values; CountOfValueLabelText tells the two apart by their
      alignment, since only a value label is drawn Center/Middle. }
    for var Value in [10, 20, 30, 70, 80, 90] do
    begin
      Assert.AreEqual(1, CountOfValueLabelText(TAxisScale.FormatValue(Value, False)),
        Format('expected exactly one label for the value %d', [Value]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_AllMode_ScatterChartTwoSeries_LabelsEveryPointOfBothSeries;
begin
  const Plot = TChartPlot.Create;
  try
    { SPEC.md 4.12: one value-label group per series for Scatter/bubble, exactly like Line
      and Area, so BuildValueLabelGroups must have a case for Scatter and label every
      point of both series. A manual axis range and manual breaks keep every value well
      clear of an axis break label, so this test is not sensitive to the separate
      axis-label overlap-avoidance rule. }
    Plot.Kind := TChartKind.Scatter;
    Plot.AddLineSeries('Low', [1, 2, 3], [60, 140, 220]);
    Plot.AddLineSeries('High', [1, 2, 3], [620, 700, 780]);
    var YAxis := Plot.YAxis;
    YAxis.MinValue := 0;
    YAxis.MaxValue := 1000;
    YAxis.Breaks := [0, 250, 500, 750, 1000];
    Plot.YAxis := YAxis;
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(6, WhiteBoxCount);
    for var Value in [60, 140, 220, 620, 700, 780] do
    begin
      Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(Value, False)),
        Format('expected exactly one label for the value %d', [Value]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_AllMode_LineChartWithRangeBand_LabelsOnlyTheOrdinarySeries;
begin
  const Plot = TChartPlot.Create;
  try
    { A range band draws no marks, so it contributes no value-label candidates: only the
      ordinary series' points are labelled. }
    Plot.Kind := TChartKind.Line;
    Plot.AddLineSeries('Central', [1960, 1970, 1980], [51, 62, 73]);
    Plot.AddRangeBandSeries('Band', [1960, 1970, 1980], [41, 46, 56], [66, 76, 86]);
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(3, WhiteBoxCount);
    for var Value in [51, 62, 73] do
    begin
      Assert.AreEqual(1, CountOfValueLabelText(TAxisScale.FormatValue(Value, False)),
        Format('expected exactly one label for the value %d', [Value]));
    end;
    for var Value in [41, 46, 56] do
    begin
      Assert.AreEqual(0, CountOfValueLabelText(TAxisScale.FormatValue(Value, False)),
        Format('expected no label for the range band''s low bound %d', [Value]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_AllMode_DotPlotTwoSeries_LabelsEveryPointOfBothSeries;
begin
  const Plot = TChartPlot.Create;
  try
    { SPEC.md 4.12: one value-label group per series for DotPlot, exactly like GroupedBar,
      so BuildValueLabelGroups must have a case for DotPlot and label every point of both
      series. A manual axis range and manual breaks keep every value well clear of an axis
      break label, so this test is not sensitive to the separate axis-label
      overlap-avoidance rule. }
    Plot.Kind := TChartKind.DotPlot;
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('1960', [60, 140, 220]);
    Plot.AddSeries('2020', [620, 700, 780]);
    var YAxis := Plot.YAxis;
    YAxis.MinValue := 0;
    YAxis.MaxValue := 1000;
    YAxis.Breaks := [0, 250, 500, 750, 1000];
    Plot.YAxis := YAxis;
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(6, WhiteBoxCount);
    for var Value in [60, 140, 220, 620, 700, 780] do
    begin
      Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(Value, False)),
        Format('expected exactly one label for the value %d', [Value]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_FirstAndLastMode_BarChart_LabelsOnlyFirstAndLastCategory;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['A', 'B', 'C', 'D'];
    Plot.AddSeries('Only', [10.5, 20.5, 30.5, 40.5]);
    Plot.ValueLabels := TValueLabelMode.FirstAndLast;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(2, WhiteBoxCount);
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(10.5, False)));
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(40.5, False)));
    Assert.AreEqual(0, CountOfText(TAxisScale.FormatValue(20.5, False)));
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_ExtremesMode_TiedMaximum_KeepsFirstOccurrenceOnly;
begin
  const Plot = TChartPlot.Create;
  try
    { Categories 1 and 2 tie for the maximum (41.3); the tie-break rule keeps the first
      one in index order (category 1) and drops the later tie (category 2). }
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['A', 'B', 'C', 'D'];
    Plot.AddSeries('Only', [3.7, 41.3, 41.3, 2.1]);
    Plot.ValueLabels := TValueLabelMode.Extremes;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(2, WhiteBoxCount);
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(41.3, False)));
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(2.1, False)));
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_ExtremesMode_Dumbbell_SelectsPerGroupAcrossStartAndEnd;
begin
  const Plot = TChartPlot.Create;
  try
    { Dumbbell forms two groups, Start and End, each selected independently: the Start
      group's own min/max across categories, and likewise for End. Values are chosen well
      clear (at least 40 units, comfortably more than a label's own height in pixels) of
      the automatic "nice" value-axis breaks ([100, 200] for this range), so no value
      label collides with a Y-axis break label, which would otherwise suppress it under
      the overlap-avoidance rule and make this test unable to tell the two rules apart. }
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddDumbbellSeries([15, 60, 35], [240, 150, 285]);
    Plot.ValueLabels := TValueLabelMode.Extremes;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(4, WhiteBoxCount);
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(15, False)));
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(60, False)));
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(150, False)));
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(285, False)));
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_OverlappingCandidates_DrawsOnlyTheFirstInFixedOrder;
begin
  const Plot = TChartPlot.Create;
  try
    { Two line series with a single, nearly equal value each, on a wide manual axis
      range: both labels go above their points, so the two candidate boxes overlap. The
      fixed order draws the first series before the second, so only its label survives. }
    Plot.Kind := TChartKind.Line;
    Plot.Categories := ['Only'];
    Plot.AddSeries('First', [500]);
    Plot.AddSeries('Second', [502]);
    var YAxis := Plot.YAxis;
    YAxis.MinValue := 0;
    YAxis.MaxValue := 1000;
    Plot.YAxis := YAxis;
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(1, WhiteBoxCount);
    Assert.AreEqual(1, CountOfValueLabelText(TAxisScale.FormatValue(500, False)));
    Assert.AreEqual(0, CountOfValueLabelText(TAxisScale.FormatValue(502, False)));
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_LineChart_PlacementIsOffsetAboveThePoint;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Line;
    Plot.Categories := ['Only'];
    Plot.AddSeries('S', [10]);
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const LinePoint = FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawPolyline)[0].Points[0];
    const LabelText = TAxisScale.FormatValue(10, False);

    var LabelCall := Default(TCanvasCall);
    var LabelWasDrawn := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text = LabelText then
      begin
        LabelCall := Call;
        LabelWasDrawn := True;
      end;
    end;

    Assert.IsTrue(LabelWasDrawn, Format('no label was drawn for the value %s', [LabelText]));

    { A single point has no line ends, so its label goes above it, the box clear of it. }
    const Distance = BesideDistance(Plot.Style, LabelText, True);
    Assert.AreEqual(LinePoint.X, LabelCall.TextX, 0.01);
    Assert.AreEqual(LinePoint.Y - Distance, LabelCall.TextY, 0.01);
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_LineChartFirstAndLast_LabelsSitBeforeAndAfterTheLine;
begin
  const Plot = TChartPlot.Create;
  try
    { An X axis that runs a decade past the data on both sides leaves room before the
      first point and after the last. Non-round values keep the label texts apart from
      the axis break labels. }
    Plot.Kind := TChartKind.Line;
    Plot.AddLineSeries('S', [2000, 2010, 2020], [10.5, 20.5, 30.5]);
    var XAxis := Plot.XAxis;
    XAxis.MinValue := 1990;
    XAxis.MaxValue := 2030;
    Plot.XAxis := XAxis;
    Plot.ValueLabels := TValueLabelMode.FirstAndLast;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const LinePoints = FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawPolyline)[0].Points;
    const FirstPoint = LinePoints[0];
    const LastPoint = LinePoints[High(LinePoints)];
    const FirstText = TAxisScale.FormatValue(10.5, False);
    const LastText = TAxisScale.FormatValue(30.5, False);

    const FirstLabel = ValueLabelCall(FirstText);
    const LastLabel = ValueLabelCall(LastText);

    Assert.AreEqual(FirstPoint.X - BesideDistance(Plot.Style, FirstText, False), FirstLabel.TextX, 0.01,
      'the first label must sit before the start of the line');
    Assert.AreEqual(FirstPoint.Y, FirstLabel.TextY, 0.01);
    Assert.AreEqual(LastPoint.X + BesideDistance(Plot.Style, LastText, False), LastLabel.TextX, 0.01,
      'the last label must sit after the end of the line');
    Assert.AreEqual(LastPoint.Y, LastLabel.TextY, 0.01);
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_LineOnContinuousAxis_PlotLeavesRoomBeforeTheFirstPoint;
begin
  const Plot = TChartPlot.Create;
  try
    { The first point of a continuous X axis lies on the left edge of the data. With value
      labels on, the plot area is pulled in far enough for the label to sit before it,
      while the value axis labels stay where they are. The manual value range keeps the
      point clear of the bottom edge. }
    Plot.Kind := TChartKind.Line;
    Plot.AddLineSeries('S', [1990, 2000, 2010], [10.5, 20.5, 30.5]);
    var YAxis := Plot.YAxis;
    YAxis.MinValue := 0;
    YAxis.MaxValue := 40;
    Plot.YAxis := YAxis;
    Plot.ValueLabels := TValueLabelMode.FirstAndLast;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const FirstPoint = FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawPolyline)[0].Points[0];
    const FirstText = TAxisScale.FormatValue(10.5, False);

    const FirstLabel = ValueLabelCall(FirstText);

    Assert.AreEqual(FirstPoint.X - BesideDistance(Plot.Style, FirstText, False), FirstLabel.TextX, 0.01,
      'the first label must sit before the start of the line');
    Assert.AreEqual(FirstPoint.Y, FirstLabel.TextY, 0.01);
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_HorizontalBarChart_LabelSitsBeyondTheEndOfTheBar;
begin
  const Plot = TChartPlot.Create;
  try
    { A manual value range leaves room past the end of the bar, so this measures the
      placement itself rather than the edge clamp. }
    Plot.Kind := TChartKind.Bar;
    Plot.Orientation := TChartOrientation.Horizontal;
    Plot.Categories := ['Only'];
    Plot.AddSeries('S', [10.5]);
    var YAxis := Plot.YAxis;
    YAxis.MinValue := 0;
    YAxis.MaxValue := 40;
    Plot.YAxis := YAxis;
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    var BarBounds: TRectF;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect) do
    begin
      if Call.Color = Plot.SeriesColor(0) then
        BarBounds := Call.Bounds;
    end;

    const LabelText = TAxisScale.FormatValue(10.5, False);
    const LabelCall = ValueLabelCall(LabelText);

    Assert.AreEqual(BarBounds.Right + BesideDistance(Plot.Style, LabelText, False), LabelCall.TextX, 0.01,
      'the label must sit beside the end of the bar, not across it');
    Assert.AreEqual((BarBounds.Top + BarBounds.Bottom) / 2, LabelCall.TextY, 0.01);
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_BarReachingThePlotEdge_LabelSitsInsideTheEndOfTheBar;
begin
  const Plot = TChartPlot.Create;
  try
    { The value range ends exactly at the bar's value, so there is no room past the end of
      the bar. The label goes just inside the end instead of straddling it. }
    Plot.Kind := TChartKind.Bar;
    Plot.Orientation := TChartOrientation.Horizontal;
    Plot.Categories := ['Only'];
    Plot.AddSeries('S', [94.5]);
    var YAxis := Plot.YAxis;
    YAxis.MinValue := 0;
    YAxis.MaxValue := 94.5;
    Plot.YAxis := YAxis;
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    var BarBounds: TRectF;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect) do
    begin
      if Call.Color = Plot.SeriesColor(0) then
        BarBounds := Call.Bounds;
    end;

    const LabelText = TAxisScale.FormatValue(94.5, False);
    const LabelCall = ValueLabelCall(LabelText);

    Assert.AreEqual(BarBounds.Right - BesideDistance(Plot.Style, LabelText, False), LabelCall.TextX, 0.01,
      'the label must sit just inside the end of the bar');
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_LineChartValley_LabelSitsBelowThePoint;
begin
  const Plot = TChartPlot.Create;
  try
    { The middle point is lower than both its neighbours, so a label above it would sit in
      the dip, on the line. It goes below the point instead. }
    Plot.Kind := TChartKind.Line;
    Plot.AddLineSeries('S', [2000, 2010, 2020], [30.5, 10.5, 30.5]);
    var YAxis := Plot.YAxis;
    YAxis.MinValue := 0;
    YAxis.MaxValue := 40;
    Plot.YAxis := YAxis;
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    const Valley = FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawPolyline)[0].Points[1];
    const ValleyText = TAxisScale.FormatValue(10.5, False);

    const ValleyLabel = ValueLabelCall(ValleyText);

    Assert.AreEqual(Valley.X, ValleyLabel.TextX, 0.01);
    Assert.AreEqual(Valley.Y + BesideDistance(Plot.Style, ValleyText, True), ValleyLabel.TextY, 0.01,
      'the label of a valley must sit below the point');
  finally
    Plot.Free;
  end;
end;
procedure TChartValueLabelsTests.ValueLabels_LineChart_ValueAxisLabelsKeepTheirPlace;
begin
  { The room made for the labels at the ends of the lines comes out of the data area only:
    the value axis labels line up where they do without value labels. }
  var AxisLabelRight: array[Boolean] of Single;
  for var ShowsValueLabels := False to True do
  begin
    const Recording = TRecordingCanvas.Create;
    const RecordingCanvas: IChartCanvas = Recording;
    const Plot = TChartPlot.Create;
    try
      Plot.Kind := TChartKind.Line;
      Plot.AddLineSeries('S', [1990, 2000, 2010], [10.5, 20.5, 30.5]);
      if ShowsValueLabels then
        Plot.ValueLabels := TValueLabelMode.FirstAndLast;

      TChartRenderer.Render(Plot, RecordingCanvas, 640, 450);
    finally
      Plot.Free;
    end;

    AxisLabelRight[ShowsValueLabels] := 0;
    for var Call in Recording.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      const IsValueAxisLabel = (Call.AlignH = TTextAlignH.Right) and (Call.AlignV = TTextAlignV.Middle);
      if IsValueAxisLabel then
        AxisLabelRight[ShowsValueLabels] := Call.TextX;
    end;
  end;

  Assert.IsTrue(AxisLabelRight[False] > 0, 'the fixture must draw value axis labels');
  Assert.AreEqual(AxisLabelRight[False], AxisLabelRight[True], 0.01);
end;
procedure TChartValueLabelsTests.ValueLabels_BarReachingTheTop_LabelSitsInsideTheBarTop;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['Only'];
    Plot.AddSeries('S', [10]);
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    var BarBounds: TRectF;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect) do
    begin
      if Call.Color <> TAlphaColor($FFFFFFFF) then
        BarBounds := Call.Bounds;
    end;

    const LabelText = TAxisScale.FormatValue(10, False);
    var LabelCall := Default(TCanvasCall);
    var LabelWasDrawn := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text = LabelText then
      begin
        LabelCall := Call;
        LabelWasDrawn := True;
      end;
    end;

    Assert.IsTrue(LabelWasDrawn, Format('no label was drawn for the value %s', [LabelText]));

    Assert.AreEqual((BarBounds.Left + BarBounds.Right) / 2, LabelCall.TextX, 0.01);

    { A single bar reaches the top of the value range, so a label above it would run out
      of the plot area into the title. It sits just inside the top of the bar instead. }
    Assert.AreEqual(BarBounds.Top + BesideDistance(Plot.Style, LabelText, True), LabelCall.TextY, 0.01,
      'the label must sit just inside the top of the bar');
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_StackedBarMixedSignValues_PlacementFollowsDivergingSegmentEnds;
begin
  const Plot = TChartPlot.Create;
  try
    { Values +5, -3 and +2 in one category stack divergingly (see the matching renderer
      test): the positive segments end at +5 and +7 while the negative one hangs down to
      -3. Each label must anchor at its own segment's outer end, offset away from the
      baseline: a single running total would instead anchor the -3 label at +2 and the
      +2 label at +4, both inside the stack. A manual axis range keeps every anchor well
      inside the plot area, and manual breaks keep the break-label texts distinct from
      the value-label texts. }
    Plot.Kind := TChartKind.StackedBar;
    Plot.LegendPosition := TLegendPosition.None;
    Plot.Categories := ['2020'];
    Plot.AddSeries('First', [5]);
    Plot.AddSeries('Second', [-3]);
    Plot.AddSeries('Third', [2]);
    var YAxis := Plot.YAxis;
    YAxis.MinValue := -10;
    YAxis.MaxValue := 10;
    YAxis.Breaks := [-10, 0, 10];
    Plot.YAxis := YAxis;
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(3, WhiteBoxCount, 'every segment must be labelled');

    var FirstSegment := Default(TCanvasCall);
    var SecondSegment := Default(TCanvasCall);
    var ThirdSegment := Default(TCanvasCall);
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect) do
    begin
      if Call.Color = Plot.SeriesColor(0) then
        FirstSegment := Call
      else if Call.Color = Plot.SeriesColor(1) then
        SecondSegment := Call
      else if Call.Color = Plot.SeriesColor(2) then
        ThirdSegment := Call;
    end;

    var FirstLabel := Default(TCanvasCall);
    var SecondLabel := Default(TCanvasCall);
    var ThirdLabel := Default(TCanvasCall);
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      const IsValueLabel = (Call.AlignH = TTextAlignH.Center) and (Call.AlignV = TTextAlignV.Middle);
      if not IsValueLabel then
        Continue;

      if Call.Text = TAxisScale.FormatValue(5, False) then
        FirstLabel := Call
      else if Call.Text = TAxisScale.FormatValue(-3, False) then
        SecondLabel := Call
      else if Call.Text = TAxisScale.FormatValue(2, False) then
        ThirdLabel := Call;
    end;

    const BarCenter = (FirstSegment.Bounds.Left + FirstSegment.Bounds.Right) / 2;
    Assert.AreEqual(BarCenter, FirstLabel.TextX, 0.01);
    Assert.AreEqual(BarCenter, SecondLabel.TextX, 0.01);
    Assert.AreEqual(BarCenter, ThirdLabel.TextX, 0.01);

    const Distance = BesideDistance(Plot.Style, FirstLabel.Text, True);
    Assert.AreEqual(FirstSegment.Bounds.Top - Distance, FirstLabel.TextY, 0.01,
      'the +5 label must sit above its own segment''s top, at +5');
    Assert.AreEqual(SecondSegment.Bounds.Bottom + Distance, SecondLabel.TextY, 0.01,
      'the -3 label must sit below its own segment''s bottom, at -3, not inside the positive stack');
    Assert.AreEqual(ThirdSegment.Bounds.Top - Distance, ThirdLabel.TextY, 0.01,
      'the +2 label must sit above its own segment''s top, at +7');
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_DumbbellChart_PlacementIsOffsetAwayFromTheOtherEnd;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['Only'];
    Plot.AddDumbbellSeries([10], [30]);
    Plot.ValueLabels := TValueLabelMode.All;

    { A manual value range keeps both dots well inside the plot area, so this test
      measures the placement offset itself rather than the edge clamp, which
      ValueLabels_NearAxisLabels_AreDrawnAndStayOutOfTheAxisLabelBand covers separately. }
    var YAxis := Plot.YAxis;
    YAxis.MinValue := 0;
    YAxis.MaxValue := 40;
    Plot.YAxis := YAxis;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    var StartCircle, EndCircle: TCanvasCall;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillCircle) do
    begin
      if Call.Color = ChartOrange then
        StartCircle := Call
      else if Call.Color = ChartBlue then
        EndCircle := Call;
    end;

    const StartText = TAxisScale.FormatValue(10, False);
    const EndText = TAxisScale.FormatValue(30, False);
    var StartLabel := Default(TCanvasCall);
    var EndLabel := Default(TCanvasCall);
    var StartWasDrawn := False;
    var EndWasDrawn := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text = StartText then
      begin
        StartLabel := Call;
        StartWasDrawn := True;
      end
      else if Call.Text = EndText then
      begin
        EndLabel := Call;
        EndWasDrawn := True;
      end;
    end;

    Assert.IsTrue(StartWasDrawn, 'the start of the dumbbell was not labelled');
    Assert.IsTrue(EndWasDrawn, 'the end of the dumbbell was not labelled');

    { AddDumbbellSeries forces Horizontal orientation, so the value axis runs
      left-to-right, not inverted: the higher value (End, 30) maps further right than
      Start (10). Each label sits beside its own dot, on the side away from the other end. }
    Assert.AreEqual(StartCircle.CenterX - BesideDistance(Plot.Style, StartText, False), StartLabel.TextX, 0.01);
    Assert.AreEqual(EndCircle.CenterX + BesideDistance(Plot.Style, EndText, False), EndLabel.TextX, 0.01);
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_ArrowChart_PlacementIsOffsetBeyondTheArrowhead;
begin
  const Plot = TChartPlot.Create;
  try
    { Non-round values so neither coincides with an automatic "nice" value-axis break
      label, which would otherwise draw the same text a second time, the same convention
      the Dumbbell placement test above uses. }
    Plot.Categories := ['Only'];
    Plot.AddArrowSeries('Change', [70.1], [82.5]);
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    { The label is placed beyond the arrowhead, so the apex is the reference, not the end
      of the shaft: the shaft stops at the base of the head so its stroke cannot poke
      through the tip. DrawArrowHead fills [apex, left wing, right wing], so the apex is
      the polygon's first point. }
    var Head := Default(TCanvasCall);
    var HeadWasDrawn := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillPolygon) do
    begin
      if Call.Color = Plot.SeriesColor(0) then
      begin
        Head := Call;
        HeadWasDrawn := True;
      end;
    end;

    Assert.IsTrue(HeadWasDrawn, 'the arrow head was not drawn');

    const Apex = Head.Points[0];

    const EndText = TAxisScale.FormatValue(82.5, False);
    var EndLabel := Default(TCanvasCall);
    var EndWasLabelled := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text = EndText then
      begin
        EndLabel := Call;
        EndWasLabelled := True;
      end;
    end;

    Assert.IsTrue(EndWasLabelled, 'the arrowhead value was not labelled');

    const RawAnchor = TPointF.Create(Apex.X + BesideDistance(Plot.Style, EndText, False), Apex.Y);

    { AddArrowSeries forces Horizontal orientation, so the value axis runs left to right and
      the arrowhead (End, the higher value) sits close to the plot's right edge. Placing the
      label beyond it, unclamped, would push its own background box past the 16 px
      outer margin. This checks that outcome directly, rather than through a second copy of
      the clamp formula: first, that the fixture's raw box really would violate the margin
      (so the rest of this test proves something), then that the anchor actually drawn keeps
      the box's right edge on or inside the margin. }
    const Style = Plot.Style;
    const TextStyle = TChartTextStyle.Create(Style.FontName, Style.AxisFontSize, False, Style.TextColor);
    const TextSize = FRecordingCanvas.MeasureText(EndText, TextStyle);
    const Padding = 3 * Style.ScaleFactor;
    const Margin = 16 * Style.ScaleFactor;

    const RawBoxRight = RawAnchor.X + TextSize.Width / 2 + Padding;
    Assert.IsTrue(RawBoxRight > 640 - Margin,
      'the fixture must place the raw anchor so the clamp actually has to act, or this test proves nothing');

    Assert.AreNotEqual(RawAnchor.X, EndLabel.TextX, 0.01,
      'the label was not moved away from the raw, unclamped anchor');

    const ActualBoxRight = EndLabel.TextX + TextSize.Width / 2 + Padding;
    Assert.IsTrue(ActualBoxRight <= 640 - Margin + 0.01,
      Format('the label''s background box right edge is at %.2f, outside the %d px outer margin', [ActualBoxRight, Round(Margin)]));
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_ArrowChart_OnlyLabelsTheEndPointNeverTheStart;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['Only'];
    Plot.AddArrowSeries('Change', [70.1], [82.5]);
    Plot.ValueLabels := TValueLabelMode.All;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(1, WhiteBoxCount);
    Assert.AreEqual(1, CountOfText(TAxisScale.FormatValue(82.5, False)));
    Assert.AreEqual(0, CountOfText(TAxisScale.FormatValue(70.1, False)));
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_YAxisDecimals_LabelsCarryThatManyDecimals;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [10.5, 20]);
    Plot.ValueLabels := TValueLabelMode.All;

    var AxisOptions := Plot.YAxis;
    AxisOptions.Decimals := 2;
    Plot.YAxis := AxisOptions;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(1, CountOfValueLabelText('10.50'));
    Assert.AreEqual(1, CountOfValueLabelText('20.00'));
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_StyleLabelBackgroundColor_FillsEveryValueLabelBox;
begin
  { Value labels share the label-box convention with segment labels and text annotations
    (SPEC.md 4.29), so the style's box color reaches them too. }
  const Cream = TAlphaColor($FFFFF3C4);
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['A', 'B'];
    Plot.AddSeries('Only', [10, 20]);
    Plot.ValueLabels := TValueLabelMode.All;

    var Style := Plot.Style;
    Style.LabelBackgroundColor := Cream;
    Plot.Style := Style;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(2, FRecordingCanvas.CountOfColor(TCanvasCallKind.FillRect, Cream),
      'Both value labels must sit on a box of the style''s color');
    Assert.AreEqual(0, WhiteBoxCount, 'No value label may keep the white box');
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ArrowChart_ShaftStopsAtTheHeadInsteadOfRunningThroughTheTip;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Categories := ['Only'];
    Plot.AddArrowSeries('Change', [12.0], [4.0]);

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    var Shaft := Default(TCanvasCall);
    var ShaftWasDrawn := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawLine) do
    begin
      if Call.Color = Plot.SeriesColor(0) then
      begin
        Shaft := Call;
        ShaftWasDrawn := True;
      end;
    end;

    var Head := Default(TCanvasCall);
    var HeadWasDrawn := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillPolygon) do
    begin
      if Call.Color = Plot.SeriesColor(0) then
      begin
        Head := Call;
        HeadWasDrawn := True;
      end;
    end;

    Assert.IsTrue(ShaftWasDrawn, 'the arrow shaft was not drawn');
    Assert.IsTrue(HeadWasDrawn, 'the arrow head was not drawn');

    const Apex = Head.Points[0];
    const LeftWing = Head.Points[1];
    const RightWing = Head.Points[2];

    { The arrow points left, so the shaft must stop to the right of the apex: drawing it
      all the way to the tip makes the stroke poke out past the point by half its width. }
    Assert.IsTrue(Shaft.X2 > Apex.X,
                  Format('the shaft ends at %.2f, at or past the apex at %.2f', [Shaft.X2, Apex.X]));

    { It must stop exactly where the wings meet, so no gap opens up between shaft and head. }
    const WingBaseX = (LeftWing.X + RightWing.X) / 2;
    Assert.AreEqual(WingBaseX, Shaft.X2, 0.01, 'the shaft should end at the base of the head');

    Assert.AreEqual(Shaft.Y2, Apex.Y, 0.01, 'a horizontal arrow keeps the shaft on the head axis');
  finally
    Plot.Free;
  end;
end;

procedure TChartValueLabelsTests.ValueLabels_NearAxisLabels_AreDrawnAndStayOutOfTheAxisLabelBand;
begin
  const Plot = TChartPlot.Create;
  try
    { SPEC.md 4.12: a value label that would land on the value-axis label band is moved
      inside the plot area, not dropped. Both series put their minimum on the leftmost
      point, where the label box would otherwise reach across the axis labels, and the
      four selected extremes are far enough apart in value that none of them can suppress
      another through the label-versus-label rule. }
    Plot.Kind := TChartKind.Line;
    Plot.AddLineSeries('Low', [1, 2, 3], [10, 20, 30]);
    Plot.AddLineSeries('High', [1, 2, 3], [40, 50, 60]);
    Plot.ValueLabels := TValueLabelMode.Extremes;

    TChartRenderer.Render(Plot, FCanvas, 640, 450);

    Assert.AreEqual(4, WhiteBoxCount, 'every selected extreme must be labelled');

    { A value label is the only text drawn centered on both axes: the axis break labels are
      Right/Middle and Center/Top, the title, subtitle and legend are Left aligned. }
    var ValueLabelTexts := '';
    var AxisLabelRight: Double := 0.0;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      const IsValueLabel = (Call.AlignH = TTextAlignH.Center) and (Call.AlignV = TTextAlignV.Middle);
      if IsValueLabel then
        ValueLabelTexts := ValueLabelTexts + Call.Text + ' ';

      const IsValueAxisLabel = (Call.AlignH = TTextAlignH.Right) and (Call.AlignV = TTextAlignV.Middle);
      if IsValueAxisLabel then
        AxisLabelRight := Max(AxisLabelRight, Call.TextX);
    end;

    Assert.AreEqual('10 30 40 60 ', ValueLabelTexts, 'both extremes of both series must be labelled');
    Assert.IsTrue(AxisLabelRight > 0, 'the value axis must have drawn its break labels');

    const Style = TChartStyle.Default;
    const TextStyle = TChartTextStyle.Create(Style.FontName, Style.AxisFontSize, False, Style.TextColor);
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      const IsValueLabel = (Call.AlignH = TTextAlignH.Center) and (Call.AlignV = TTextAlignV.Middle);
      if not IsValueLabel then
        Continue;

      const LabelLeft = Call.TextX - FRecordingCanvas.MeasureText(Call.Text, TextStyle).Width / 2;
      Assert.IsTrue(LabelLeft >= AxisLabelRight,
                    Format('value label "%s" starts at %.2f, inside the axis label band ending at %.2f',
                           [Call.Text, LabelLeft, AxisLabelRight]));
    end;
  finally
    Plot.Free;
  end;
end;

end.
