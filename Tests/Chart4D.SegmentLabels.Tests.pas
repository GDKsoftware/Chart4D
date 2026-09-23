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
unit Chart4D.SegmentLabels.Tests;

/// <summary>
/// Tests for the segment labels of <c>Pie</c> and <c>Donut</c> charts: that no wedge is
/// drawn over a label, and which labels win when two would collide. See SPEC.md 4.23.
/// </summary>

interface

uses
  System.Types,
  DUnitX.TestFramework,
  Chart4D.Tests.Asserts,
  Chart4D.Canvas.Interfaces,
  Chart4D.Tests.RecordingCanvas,
  Chart4D.Types;

type
  [TestFixture]
  TSegmentLabelTests = class
  private
    FCanvas: IChartCanvas;
    FRecordingCanvas: TRecordingCanvas;

    procedure RenderPie(const Kind: TChartKind; const Categories: TArray<string>;
                        const Values: TArray<Double>);
    function RenderThirds(const Mode: TSegmentLabelMode): TArray<TChartHitTarget>;
    function LastCallIndexOfKind(const Kind: TCanvasCallKind): Integer;
    function CountOfText(const Text: string): Integer;
    procedure AssertEveryLabelDrawnAfterTheLastWedge;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure PieChart_EveryLabel_IsDrawnAfterTheLastWedge;

    [Test]
    procedure DonutChart_EveryLabel_IsDrawnAfterTheLastWedge;

    [Test]
    procedure PieChart_SmallSegmentBeforeALargerOne_NeverDisplacesTheLargerLabel;

    [Test]
    procedure PieChart_EqualSegmentsThatCollide_KeepTheEarlierCategory;

    [Test]
    procedure SegmentLabels_CategoryAndPercentage_ShowsBoth;

    [Test]
    procedure SegmentLabels_Percentage_ShowsTheShareAlone;

    [Test]
    procedure SegmentLabels_Category_ShowsTheCategoryAlone;

    [Test]
    procedure SegmentLabels_None_DrawsNoLabelsButKeepsTheHitTargets;
  end;

implementation

uses
  System.SysUtils,
  Chart4D.Plot,
  Chart4D.Renderer;

const
  ChartWidth = 640;
  ChartHeight = 450;

procedure TSegmentLabelTests.Setup;
begin
  FRecordingCanvas := TRecordingCanvas.Create;
  FCanvas := FRecordingCanvas;
end;

procedure TSegmentLabelTests.TearDown;
begin
  FCanvas := nil;
  FRecordingCanvas := nil;
end;

procedure TSegmentLabelTests.RenderPie(const Kind: TChartKind; const Categories: TArray<string>;
                                       const Values: TArray<Double>);
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := Kind;
    Plot.Categories := Categories;
    Plot.AddSeries('Share', Values);

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);
  finally
    Plot.Free;
  end;
end;

/// <summary>
/// Renders a pie of three equal segments, far enough apart that no label collides, with the
/// given label mode and no legend, so any category name or share in the output comes from a
/// segment label. Returns the hit map.
/// </summary>
function TSegmentLabelTests.RenderThirds(const Mode: TSegmentLabelMode): TArray<TChartHitTarget>;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.LegendPosition := TLegendPosition.None;
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Share', [1, 1, 1]);
    Plot.SegmentLabels := Mode;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight, Result);
  finally
    Plot.Free;
  end;
end;

function TSegmentLabelTests.CountOfText(const Text: string): Integer;
begin
  Result := 0;
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    if Call.Text = Text then
      Inc(Result);
  end;
end;

function TSegmentLabelTests.LastCallIndexOfKind(const Kind: TCanvasCallKind): Integer;
begin
  Result := -1;
  for var Index := 0 to FRecordingCanvas.Calls.Count - 1 do
  begin
    if FRecordingCanvas.Calls[Index].Kind = Kind then
      Result := Index;
  end;
end;

/// <summary>
/// Asserts that no wedge comes after any segment label in the recorded calls, which is
/// the only order in which a wedge cannot paint over a label. Segment labels are the text
/// ending in a closing percentage, "Category (n%)"; the legend and donut centre text never do.
/// </summary>
procedure TSegmentLabelTests.AssertEveryLabelDrawnAfterTheLastWedge;
begin
  const LastWedge = LastCallIndexOfKind(TCanvasCallKind.FillPolygon);
  Assert.IsTrue(LastWedge >= 0, 'The chart must draw its wedges');

  var LabelCount := 0;
  for var Index := 0 to FRecordingCanvas.Calls.Count - 1 do
  begin
    const Call = FRecordingCanvas.Calls[Index];
    const IsSegmentLabel = (Call.Kind = TCanvasCallKind.DrawText) and Call.Text.EndsWith('%)');
    if not IsSegmentLabel then
      Continue;

    Inc(LabelCount);
    Assert.IsTrue(Index > LastWedge,
      Format('The label "%s" must be drawn after every wedge, or a later one covers it', [Call.Text]));
  end;

  Assert.IsTrue(LabelCount > 0, 'The chart must draw segment labels for this check to mean anything');
end;

procedure TSegmentLabelTests.PieChart_EveryLabel_IsDrawnAfterTheLastWedge;
begin
  { Wedges were drawn in category order with each label right after its own wedge, so the
    next wedge painted over it: a label near a boundary lost its first half, and the
    covered label still held its place, so a later, visible label could be dropped for
    colliding with one nobody could see. }
  RenderPie(TChartKind.Pie, ['Lopen', 'Fiets', 'Bus', 'Trein', 'Auto'], [18, 27, 0.2, 9, 45.8]);

  AssertEveryLabelDrawnAfterTheLastWedge;
end;

procedure TSegmentLabelTests.DonutChart_EveryLabel_IsDrawnAfterTheLastWedge;
begin
  RenderPie(TChartKind.Donut, ['Lopen', 'Fiets', 'Bus', 'Trein', 'Auto'], [18, 27, 0.2, 9, 45.8]);

  AssertEveryLabelDrawnAfterTheLastWedge;
end;

procedure TSegmentLabelTests.PieChart_SmallSegmentBeforeALargerOne_NeverDisplacesTheLargerLabel;
begin
  { A 1% and an 8% segment side by side at the top of the pie put their labels on top of
    each other, so one has to go. Offered in category order the 1% label came first and
    pushed out the 8% one; the larger segment is the one worth naming. }
  RenderPie(TChartKind.Pie, ['A', 'B', 'C'], [1, 8, 91]);

  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('B (8%)'), 'The 8% segment must keep its label');
  Assert.IsFalse(FRecordingCanvas.HasTextEqualTo('A (1%)'),
    'The 1% label collides with the 8% one, so it is the one to drop');
  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('C (91%)'), 'The largest segment is always labelled');
end;

procedure TSegmentLabelTests.PieChart_EqualSegmentsThatCollide_KeepTheEarlierCategory;
begin
  { Two equal segments have no size to choose between them, so category order decides and
    the same data always keeps the same label. }
  RenderPie(TChartKind.Pie, ['A', 'B', 'C'], [4, 4, 92]);

  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('A (4%)'), 'The earlier of two equal segments keeps its label');
  Assert.IsFalse(FRecordingCanvas.HasTextEqualTo('B (4%)'),
    'The later of two equal, colliding segments is the one dropped');
end;

procedure TSegmentLabelTests.SegmentLabels_CategoryAndPercentage_ShowsBoth;
begin
  RenderThirds(TSegmentLabelMode.CategoryAndPercentage);

  Assert.AreEqual(1, CountOfText('A (33%)'));
  Assert.AreEqual(1, CountOfText('B (33%)'));
  Assert.AreEqual(1, CountOfText('C (33%)'));
end;

procedure TSegmentLabelTests.SegmentLabels_Percentage_ShowsTheShareAlone;
begin
  { For a chart whose legend already names the categories, which is where the name in
    every label only repeats it. }
  RenderThirds(TSegmentLabelMode.Percentage);

  Assert.AreEqual(3, CountOfText('33%'), 'Every segment must be labelled with its share');
  Assert.AreEqual(0, CountOfText('A (33%)'), 'The category must not appear in a share-only label');
  Assert.AreEqual(0, CountOfText('A'), 'The category must not appear in a share-only label');
end;

procedure TSegmentLabelTests.SegmentLabels_Category_ShowsTheCategoryAlone;
begin
  RenderThirds(TSegmentLabelMode.Category);

  Assert.AreEqual(1, CountOfText('A'));
  Assert.AreEqual(1, CountOfText('B'));
  Assert.AreEqual(1, CountOfText('C'));
  Assert.AreEqual(0, CountOfText('33%'), 'The share must not appear in a category-only label');
end;

procedure TSegmentLabelTests.SegmentLabels_None_DrawsNoLabelsButKeepsTheHitTargets;
begin
  const HitMap = RenderThirds(TSegmentLabelMode.None);

  Assert.AreEqual(0, FRecordingCanvas.CountOfKind(TCanvasCallKind.DrawText),
    'Without a legend, title or labels, the pie draws no text at all');
  Assert.AreEqual(0, FRecordingCanvas.CountOfKind(TCanvasCallKind.FillRect),
    'No label means no label background box either');
  Assert.AreEqual(3, Length(HitMap), 'Hover must still find every segment when it carries no label');
end;

end.
