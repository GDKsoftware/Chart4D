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

end.
