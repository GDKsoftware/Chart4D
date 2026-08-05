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
unit Chart4D.Invariants.Tests;

/// <summary>
/// Boundary and ink invariants for <c>TChartRenderer</c>, using <c>TRecordingCanvas</c>
/// to reason geometrically about where every drawn call lands, without rasterising.
/// Covers every chart kind, guarding against an annotation
/// clipped at the chart edge): no recorded call may draw outside the bitmap, none may
/// land inside the outer margin (other than the footer separator, which spans it by
/// design), and every resolved series color must actually appear in the output.
/// </summary>

interface

uses
  System.Types,
  System.UITypes,
  DUnitX.TestFramework,
  Chart4D.Canvas.Interfaces,
  Chart4D.Plot,
  Chart4D.Tests.RecordingCanvas,
  Chart4D.Types;

type
  [TestFixture]
  TChartInvariantTests = class
  private
    FCanvas: IChartCanvas;
    FRecordingCanvas: TRecordingCanvas;

    function TryGetInkBounds(const Call: TCanvasCall; out Bounds: TRectF): Boolean;
    function PointsBounds(const Points: TArray<TPointF>; const Outset: Single): TRectF;
    function TextCallBounds(const Call: TCanvasCall): TRectF;
    function IsFooterSeparator(const Call: TCanvasCall): Boolean;

    procedure AssertNoInkOutsideCanvas(const Width, Height: Single);
    procedure AssertNoInkInsideMargin(const Width, Height, Margin: Single);
    procedure AssertColorAppearsSomewhere(const Color: TAlphaColor; const Description: string);

    procedure RenderAndAssertBoundaryInvariants(const Plot: TChartPlot);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Render_LineChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_AreaChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_BarChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_GroupedBarChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_StackedBarChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_HistogramChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_DumbbellChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_DumbbellChart_ResolvedDotColorsAppear;

    [Test]
    procedure Render_ScatterChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_BubbleChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_BubbleChart_LargestBubbleAtDataExtreme_ObeysBoundaryInvariants;

    [Test]
    procedure Render_LineChart_LoneRangeBandSeries_ObeysBoundaryInvariants;

    [Test]
    procedure Render_ScatterChart_SinglePoint_DrawsExactlyOneNonOverlappingXLabel;

    [Test]
    procedure Render_DotPlotChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_DotPlotChart_AutomaticMinimum_LowestMarkSitsStrictlyInsidePlotArea;

    [Test]
    procedure Render_RangeChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_ArrowChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_ArrowChart_ResolvedSeriesColorAppears;

    [Test]
    procedure Render_PieChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Render_DonutChart_ObeysBoundaryAndInkInvariants;

    [Test]
    procedure Annotation_AnchoredAtRightEdge_ClampsFullyInsideBoundsWithFullText;

    [Test]
    procedure Annotation_AnchoredAtLeftEdge_ClampsFullyInsideBoundsWithFullText;

    [Test]
    procedure Annotation_AnchoredAtTopEdge_ClampsFullyInsideBoundsWithFullText;

    [Test]
    procedure Annotation_AnchoredAtBottomEdge_ClampsFullyInsideBoundsWithFullText;

    [Test]
    procedure Render_LongTitleAndSubtitle_WrapObeysBoundaryAndInkInvariants;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.TypInfo,
  Chart4D.Renderer,
  Chart4D.Style;

const
  ChartWidth = 640;
  ChartHeight = 450;

procedure TChartInvariantTests.Setup;
begin
  FRecordingCanvas := TRecordingCanvas.Create;
  FCanvas := FRecordingCanvas;
end;

procedure TChartInvariantTests.TearDown;
begin
  FCanvas := nil;
  FRecordingCanvas := nil;
end;

function TChartInvariantTests.PointsBounds(const Points: TArray<TPointF>; const Outset: Single): TRectF;
begin
  Result := TRectF.Create(Points[0]);
  for var Point in Points do
  begin
    Result.Left := Min(Result.Left, Point.X);
    Result.Top := Min(Result.Top, Point.Y);
    Result.Right := Max(Result.Right, Point.X);
    Result.Bottom := Max(Result.Bottom, Point.Y);
  end;

  Result.Inflate(Outset, Outset);
end;

function TChartInvariantTests.TextCallBounds(const Call: TCanvasCall): TRectF;
begin
  const TextSize = FRecordingCanvas.MeasureText(Call.Text, Call.TextStyle);

  var Left: Single;
  case Call.AlignH of
    TTextAlignH.Left   : Left := Call.TextX;
    TTextAlignH.Center : Left := Call.TextX - TextSize.Width / 2;
    TTextAlignH.Right  : Left := Call.TextX - TextSize.Width;
  else
    Left := Call.TextX;
  end;

  var Top: Single;
  case Call.AlignV of
    TTextAlignV.Top    : Top := Call.TextY;
    TTextAlignV.Middle : Top := Call.TextY - TextSize.Height / 2;
    TTextAlignV.Bottom : Top := Call.TextY - TextSize.Height;
  else
    Top := Call.TextY;
  end;

  Result := TRectF.Create(Left, Top, Left + TextSize.Width, Top + TextSize.Height);
end;

function TChartInvariantTests.IsFooterSeparator(const Call: TCanvasCall): Boolean;
begin
  Result := (Call.Kind = TCanvasCallKind.DrawLine) and (Call.Color = ChartTextDark) and
            SameValue(Call.Y1, Call.Y2);
end;

function TChartInvariantTests.TryGetInkBounds(const Call: TCanvasCall; out Bounds: TRectF): Boolean;
begin
  Result := True;
  case Call.Kind of
    TCanvasCallKind.FillBackground:
      Result := False;
    TCanvasCallKind.DrawLine:
      begin
        const HalfStroke = Call.StrokeWidth / 2;
        Bounds := TRectF.Create(Min(Call.X1, Call.X2), Min(Call.Y1, Call.Y2),
                                Max(Call.X1, Call.X2), Max(Call.Y1, Call.Y2));
        Bounds.Inflate(HalfStroke, HalfStroke);
      end;
    TCanvasCallKind.DrawPolyline:
      Bounds := PointsBounds(Call.Points, Call.StrokeWidth / 2);
    TCanvasCallKind.FillPolygon:
      Bounds := PointsBounds(Call.Points, 0);
    TCanvasCallKind.FillRect:
      Bounds := Call.Bounds;
    TCanvasCallKind.FillCircle:
      Bounds := TRectF.Create(Call.CenterX - Call.Radius, Call.CenterY - Call.Radius,
                              Call.CenterX + Call.Radius, Call.CenterY + Call.Radius);
    TCanvasCallKind.DrawText:
      Bounds := TextCallBounds(Call);
    TCanvasCallKind.DrawImage:
      Bounds := Call.Bounds;
  else
    Result := False;
  end;
end;

procedure TChartInvariantTests.AssertNoInkOutsideCanvas(const Width, Height: Single);
begin
  for var Call in FRecordingCanvas.Calls do
  begin
    var Bounds: TRectF;
    if not TryGetInkBounds(Call, Bounds) then
      Continue;

    const Message = Format('%s call at [%.2f, %.2f, %.2f, %.2f] must stay within the %dx%d bitmap',
                           [GetEnumName(TypeInfo(TCanvasCallKind), Ord(Call.Kind)),
                            Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom,
                            Trunc(Width), Trunc(Height)]);

    Assert.IsTrue(Bounds.Left >= -0.01, Message);
    Assert.IsTrue(Bounds.Top >= -0.01, Message);
    Assert.IsTrue(Bounds.Right <= Width + 0.01, Message);
    Assert.IsTrue(Bounds.Bottom <= Height + 0.01, Message);
  end;
end;

procedure TChartInvariantTests.AssertNoInkInsideMargin(const Width, Height, Margin: Single);
begin
  for var Call in FRecordingCanvas.Calls do
  begin
    if IsFooterSeparator(Call) then
      Continue;

    var Bounds: TRectF;
    if not TryGetInkBounds(Call, Bounds) then
      Continue;

    const Message = Format('%s call at [%.2f, %.2f, %.2f, %.2f] must stay outside the %.0f px outer margin',
                           [GetEnumName(TypeInfo(TCanvasCallKind), Ord(Call.Kind)),
                            Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom, Margin]);

    Assert.IsTrue(Bounds.Left >= Margin - 0.01, Message);
    Assert.IsTrue(Bounds.Top >= Margin - 0.01, Message);
    Assert.IsTrue(Bounds.Right <= Width - Margin + 0.01, Message);
    Assert.IsTrue(Bounds.Bottom <= Height - Margin + 0.01, Message);
  end;
end;

procedure TChartInvariantTests.AssertColorAppearsSomewhere(const Color: TAlphaColor; const Description: string);
begin
  for var Call in FRecordingCanvas.Calls do
  begin
    if Call.Color = Color then
      Exit;
  end;

  Assert.Fail(Format('Expected color for %s (0x%.8x) to appear in at least one recorded call', [Description, Color]));
end;

procedure TChartInvariantTests.RenderAndAssertBoundaryInvariants(const Plot: TChartPlot);
begin
  TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

  AssertNoInkOutsideCanvas(ChartWidth, ChartHeight);
  AssertNoInkInsideMargin(ChartWidth, ChartHeight, 16 * Plot.Style.ScaleFactor);

  for var Index := 0 to Plot.Series.Count - 1 do
  begin
    AssertColorAppearsSomewhere(Plot.SeriesColor(Index), Plot.Series[Index].Name);
  end;
end;

procedure TChartInvariantTests.Render_LineChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Line;
    Plot.Title := 'Life expectancy at birth';
    Plot.Subtitle := 'Selected countries, years';
    Plot.Categories := ['1952', '1972', '1992', '2012'];
    Plot.AddSeries('Netherlands', [72.1, 73.2, 77.4, 81.2]);
    Plot.AddSeries('Belgium', [68.0, 71.1, 76.0, 80.3]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_AreaChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Area;
    Plot.Title := 'Electricity mix';
    Plot.Categories := ['2015', '2018', '2021'];
    Plot.AddSeries('Renewables', [20, 28, 35]);
    Plot.Source := 'Source: Ember / Our World in Data';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_BarChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Title := 'Life expectancy at birth';
    Plot.Categories := ['North', 'South', 'East', 'West'];
    Plot.AddSeries('2022', [72.4, 68.9, 75.1, 81.2]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_GroupedBarChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.GroupedBar;
    Plot.Title := 'Population by age group';
    Plot.Categories := ['2000', '2010', '2020'];
    Plot.AddSeries('0-14', [20, 18, 16]);
    Plot.AddSeries('65+', [14, 17, 20]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_StackedBarChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.StackedBar;
    Plot.Title := 'Electricity mix';
    Plot.Categories := ['2015', '2018', '2021'];
    Plot.AddSeries('Fossil', [65, 55, 45]);
    Plot.AddSeries('Renewables', [20, 28, 35]);
    Plot.AddSeries('Nuclear', [15, 17, 20]);
    Plot.Source := 'Source: Ember / Our World in Data';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_HistogramChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Distribution';
    Plot.SetHistogramData([1, 1, 2, 2, 2, 3, 4, 4, 5, 8, 9], 2);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_DumbbellChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Life expectancy gain';
    Plot.Categories := ['France', 'Spain', 'Italy'];
    Plot.AddDumbbellSeries([70.1, 69.4, 68.8], [82.5, 83.6, 83.4]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_DumbbellChart_ResolvedDotColorsAppear;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Life expectancy gain';
    Plot.Categories := ['France', 'Spain', 'Italy'];
    Plot.AddDumbbellSeries([70.1, 69.4, 68.8], [82.5, 83.6, 83.4]);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    AssertColorAppearsSomewhere(ChartOrange, 'dumbbell start dot');
    AssertColorAppearsSomewhere(ChartBlue, 'dumbbell end dot');
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_ScatterChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Scatter;
    Plot.Title := 'Income versus life expectancy';
    Plot.AddLineSeries('Countries', [1000, 15000, 42000, 68000], [58.4, 71.2, 79.6, 81.8]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_BubbleChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Scatter;
    Plot.Title := 'Bubble size shows population';
    const BubbleSeries = Plot.AddLineSeries('Countries', [1000, 15000, 42000, 68000], [58.4, 71.2, 79.6, 81.8]);
    BubbleSeries.Sizes := [1412.0, 11.5, 17.4, 0.4];
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_BubbleChart_LargestBubbleAtDataExtreme_ObeysBoundaryInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    { The largest bubble sits at the data's rightmost X value, where the right inset is
      only half an axis label's width, not a bubble radius: the right inset for a bubble
      series must still reserve room for the bubble's own radius, or this point's circle
      overflows the right edge. }
    Plot.Kind := TChartKind.Scatter;
    Plot.Title := 'Largest bubble at the data extreme';
    const BubbleSeries = Plot.AddLineSeries('Countries', [1, 2, 3, 4], [10, 20, 30, 40]);
    BubbleSeries.Sizes := [5, 50, 500, 5000];
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_LineChart_LoneRangeBandSeries_ObeysBoundaryInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    { No companion ordinary series, an explicitly valid usage (SPEC.md 4.17): the band's
      high bound (EndValues) must still be included in Y-axis autoscaling, or the band
      polygon overflows the top of the plot area. }
    Plot.Kind := TChartKind.Line;
    Plot.Title := 'Band with no companion line';
    Plot.AddRangeBandSeries('Band', [1, 2, 3], [10, 11, 12], [20, 22, 19]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_ScatterChart_SinglePoint_DrawsExactlyOneNonOverlappingXLabel;
begin
  const Plot = TChartPlot.Create;
  try
    { A single point degenerates both the value and the X data range to a single value.
      NiceBreaks still widens that degenerate range for label purposes, so the mapper
      driving the axis labels must widen its own data span to match; otherwise every
      break maps to the same pixel and every label is drawn stacked on top of the others. }
    Plot.Kind := TChartKind.Scatter;
    Plot.AddLineSeries('Only', [1], [10]);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    var SeenCalls: TArray<TCanvasCall> := [];
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      for var Seen in SeenCalls do
      begin
        const IsSamePosition = SameValue(Seen.TextX, Call.TextX, 0.5) and SameValue(Seen.TextY, Call.TextY, 0.5);
        if IsSamePosition then
          Assert.AreEqual(Seen.Text, Call.Text,
            'Two different labels must not collapse onto the same pixel position');
      end;
      SeenCalls := SeenCalls + [Call];
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_DotPlotChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.DotPlot;
    Plot.Title := 'Life expectancy, two years compared';
    Plot.Categories := ['Netherlands', 'Belgium', 'France'];
    Plot.AddSeries('1960', [73.5, 70.5, 70.2]);
    Plot.AddSeries('2020', [81.8, 81.4, 82.5]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_DotPlotChart_AutomaticMinimum_LowestMarkSitsStrictlyInsidePlotArea;
begin
  { DotPlot marks a position rather than a length from a baseline, exactly like
    Line/Dumbbell/Range/Arrow, so it must get the same 4% headroom below an automatic
    minimum (SPEC.md 4.8): the lowest dot must sit clear of the plot area's bottom edge,
    not on it. This is checked against the plot's own bottom edge rather than a
    hand-computed headroom value, by comparing two renders of the same data: one with
    YAxis.MinValue pinned to the data minimum, which (SPEC.md 4.5) overrides the headroom
    rule entirely, so its lowest dot must land exactly on the bottom edge and thereby
    reveals where that edge is; and one with an automatic axis, whose lowest dot must land
    strictly above that same pixel row. A test that only compared two manually supplied
    breaks against each other would still pass even if the headroom rule were removed. }
  const PinnedPlot = TChartPlot.Create;
  try
    PinnedPlot.Kind := TChartKind.DotPlot;
    PinnedPlot.Categories := ['A', 'B', 'C'];
    PinnedPlot.AddSeries('Only', [60, 140, 220]);
    var PinnedYAxis := PinnedPlot.YAxis;
    PinnedYAxis.MinValue := 60;
    PinnedPlot.YAxis := PinnedYAxis;

    TChartRenderer.Render(PinnedPlot, FCanvas, ChartWidth, ChartHeight);

    var PlotBottomY: Single := 0;
    var FoundPinnedLowestDot := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillCircle) do
    begin
      if (not FoundPinnedLowestDot) or (Call.CenterY > PlotBottomY) then
      begin
        PlotBottomY := Call.CenterY;
        FoundPinnedLowestDot := True;
      end;
    end;
    Assert.IsTrue(FoundPinnedLowestDot, 'Expected at least one dot to be drawn');

    Setup;

    const AutoPlot = TChartPlot.Create;
    try
      AutoPlot.Kind := TChartKind.DotPlot;
      AutoPlot.Categories := ['A', 'B', 'C'];
      AutoPlot.AddSeries('Only', [60, 140, 220]);

      TChartRenderer.Render(AutoPlot, FCanvas, ChartWidth, ChartHeight);

      var AutoLowestDotY: Single := 0;
      var FoundAutoLowestDot := False;
      for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillCircle) do
      begin
        if (not FoundAutoLowestDot) or (Call.CenterY > AutoLowestDotY) then
        begin
          AutoLowestDotY := Call.CenterY;
          FoundAutoLowestDot := True;
        end;
      end;
      Assert.IsTrue(FoundAutoLowestDot, 'Expected at least one dot to be drawn');

      Assert.IsTrue(AutoLowestDotY < PlotBottomY - 0.5,
        'The automatic minimum must push the lowest dot strictly above the plot area''s bottom edge, not on it');
    finally
      AutoPlot.Free;
    end;
  finally
    PinnedPlot.Free;
  end;
end;

procedure TChartInvariantTests.Render_RangeChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Forecast temperature range';
    Plot.Categories := ['Mon', 'Tue', 'Wed'];
    Plot.AddRangeSeries('Range', [12.1, 10.4, 9.8], [22.5, 23.6, 21.4]);
    Plot.Source := 'Source: KNMI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_ArrowChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Population change';
    Plot.Categories := ['France', 'Spain', 'Italy'];
    Plot.AddArrowSeries('Change', [70.1, 69.4, 68.8], [82.5, 83.6, 83.4]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_ArrowChart_ResolvedSeriesColorAppears;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Population change';
    Plot.Categories := ['France', 'Spain', 'Italy'];
    Plot.AddArrowSeries('Change', [70.1, 69.4, 68.8], [82.5, 83.6, 83.4]);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    AssertColorAppearsSomewhere(Plot.SeriesColor(0), 'arrow series color');
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_PieChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.Title := 'Market share';
    Plot.Categories := ['North', 'South', 'East', 'West'];
    Plot.AddSeries('Share', [10, 20, 30, 40]);
    Plot.Source := 'Source: internal';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_DonutChart_ObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Donut;
    Plot.Title := 'Market share';
    Plot.Categories := ['North', 'South', 'East', 'West'];
    Plot.AddSeries('Share', [10, 20, 30, 40]);
    Plot.DonutCenterText := 'Total: 100';
    Plot.Source := 'Source: internal';

    RenderAndAssertBoundaryInvariants(Plot);
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Annotation_AnchoredAtRightEdge_ClampsFullyInsideBoundsWithFullText;
begin
  const Plot = TChartPlot.Create;
  try
    { The scenario that first exposed edge clipping: a horizontal bar chart with a
      Left-aligned label anchored at the value axis maximum, which maps to the right edge
      of the plot area (right inset only reserves room for the last axis label, not for
      an annotation), so an unclamped box runs off the right edge of the bitmap. }
    Plot.Kind := TChartKind.Bar;
    Plot.Orientation := TChartOrientation.Horizontal;
    Plot.Categories := ['Netherlands'];
    Plot.AddSeries('Value', [82.5]);
    Plot.AddTextAnnotation(0, 82.5, '82.5 years', ChartTextDark, TTextAlignH.Left);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('82.5 years'),
                  'The clamped annotation must still draw its full, unshortened text');

    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text <> '82.5 years' then
        Continue;

      const Bounds = TextCallBounds(Call);
      Assert.IsTrue(Bounds.Left >= -0.01, Format('Annotation text left %.2f runs off the left edge', [Bounds.Left]));
      Assert.IsTrue(Bounds.Right <= ChartWidth + 0.01, Format('Annotation text right %.2f runs off the right edge', [Bounds.Right]));
    end;

    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect) do
    begin
      if Call.Color <> TAlphaColor($FFFFFFFF) then
        Continue;

      Assert.IsTrue(Call.Bounds.Left >= -0.01, Format('Annotation background left %.2f runs off the left edge', [Call.Bounds.Left]));
      Assert.IsTrue(Call.Bounds.Right <= ChartWidth + 0.01, Format('Annotation background right %.2f runs off the right edge', [Call.Bounds.Right]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Annotation_AnchoredAtLeftEdge_ClampsFullyInsideBoundsWithFullText;
begin
  const Plot = TChartPlot.Create;
  try
    { Mirror of the right-edge scenario: a horizontal bar chart (value axis always
      includes 0) with a Right-aligned label anchored at the value axis minimum, which
      maps to the left edge of the plot area, so an unclamped box runs off the left edge. }
    Plot.Kind := TChartKind.Bar;
    Plot.Orientation := TChartOrientation.Horizontal;
    Plot.Categories := ['Netherlands'];
    Plot.AddSeries('Value', [82.5]);
    Plot.AddTextAnnotation(0, 0, 'Starting point of this series', ChartTextDark, TTextAlignH.Right);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('Starting point of this series'),
                  'The clamped annotation must still draw its full, unshortened text');

    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text <> 'Starting point of this series' then
        Continue;

      const Bounds = TextCallBounds(Call);
      Assert.IsTrue(Bounds.Left >= -0.01, Format('Annotation text left %.2f runs off the left edge', [Bounds.Left]));
      Assert.IsTrue(Bounds.Right <= ChartWidth + 0.01, Format('Annotation text right %.2f runs off the right edge', [Bounds.Right]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Annotation_AnchoredAtTopEdge_ClampsFullyInsideBoundsWithFullText;
begin
  const Plot = TChartPlot.Create;
  try
    { Vertical orientation maps the value axis maximum to the top of the plot area. With
      the automatic 4% headroom removed (manual MaxValue) and no title/subtitle/legend
      above the plot, the top of the plot area sits exactly at the 16 px outer margin, so
      a large annotation centered vertically on it unclamped runs off the top edge. }
    Plot.Kind := TChartKind.Bar;
    var YAxis := Plot.YAxis;
    YAxis.MaxValue := 30;
    Plot.YAxis := YAxis;
    var Style := Plot.Style;
    Style.AxisFontSize := 44;
    Plot.Style := Style;
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Value', [10, 20, 30]);
    Plot.AddTextAnnotation(1, 30, 'Peak value reached this year', ChartTextDark, TTextAlignH.Center);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('Peak value reached this year'),
                  'The clamped annotation must still draw its full, unshortened text');

    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text <> 'Peak value reached this year' then
        Continue;

      const Bounds = TextCallBounds(Call);
      Assert.IsTrue(Bounds.Top >= -0.01, Format('Annotation text top %.2f runs off the top edge', [Bounds.Top]));
      Assert.IsTrue(Bounds.Bottom <= ChartHeight + 0.01, Format('Annotation text bottom %.2f runs off the bottom edge', [Bounds.Bottom]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Annotation_AnchoredAtBottomEdge_ClampsFullyInsideBoundsWithFullText;
begin
  const Plot = TChartPlot.Create;
  try
    { Mirror of the top-edge scenario: the value axis minimum (0, already forced into
      range for Bar) maps to the bottom of the plot area. The category axis is hidden so
      no label height cushions the bottom, leaving only the 16 px outer margin, which a
      large unclamped annotation centered on it overflows. }
    Plot.Kind := TChartKind.Bar;
    var XAxis := Plot.XAxis;
    XAxis.Visible := False;
    Plot.XAxis := XAxis;
    var Style := Plot.Style;
    Style.AxisFontSize := 44;
    Plot.Style := Style;
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Value', [10, 20, 30]);
    Plot.AddTextAnnotation(1, 0, 'Baseline value for this series', ChartTextDark, TTextAlignH.Center);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);

    Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('Baseline value for this series'),
                  'The clamped annotation must still draw its full, unshortened text');

    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if Call.Text <> 'Baseline value for this series' then
        Continue;

      const Bounds = TextCallBounds(Call);
      Assert.IsTrue(Bounds.Top >= -0.01, Format('Annotation text top %.2f runs off the top edge', [Bounds.Top]));
      Assert.IsTrue(Bounds.Bottom <= ChartHeight + 0.01, Format('Annotation text bottom %.2f runs off the bottom edge', [Bounds.Bottom]));
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartInvariantTests.Render_LongTitleAndSubtitle_WrapObeysBoundaryAndInkInvariants;
begin
  const Plot = TChartPlot.Create;
  try
    { A title or subtitle wider than the available width wraps rather than running past
      the right edge, so a title and subtitle long enough that each needs several lines
      must still stay fully inside the canvas and outside the outer margin. }
    Plot.Title := 'This editorial chart title is deliberately written as a long sentence to force wrapping';
    Plot.Subtitle := 'And this subtitle is just as long, so it must wrap onto its own extra lines too';
    Plot.Categories := ['1952', '1972', '1992', '2012'];
    Plot.AddSeries('Netherlands', [72.1, 73.2, 77.4, 81.2]);
    Plot.AddSeries('Belgium', [68.0, 71.1, 76.0, 80.3]);
    Plot.Source := 'Source: World Bank WDI';

    RenderAndAssertBoundaryInvariants(Plot);

    var SawWrappedLine := False;
    for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
    begin
      if (Call.Text <> Plot.Title) and (Plot.Title.Contains(Call.Text)) and (Call.Text <> '') then
        SawWrappedLine := True;
    end;
    Assert.IsTrue(SawWrappedLine, 'The long title must be split across more than one DrawText call');
  finally
    Plot.Free;
  end;
end;

end.
