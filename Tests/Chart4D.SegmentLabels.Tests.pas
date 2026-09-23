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
    function LastCallIndexOfKind(const Kind: TCanvasCallKind): Integer;
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

end.
