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
unit Chart4D.View.Tests;

/// <summary>
/// Tests for <c>TChartView</c>: when a render is skipped or repeated, which hover events
/// and repaint requests pointer moves produce, when the tooltip overlay is drawn, and
/// that the view lets go of the plot's <c>OnChanged</c> when it is destroyed.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4D.Tests.Asserts,
  Chart4D.Types,
  Chart4D.Plot,
  Chart4D.View,
  Chart4D.Tests.RecordingCanvas;

type
  [TestFixture]
  TChartViewTests = class
  private const
    ViewWidth = 640;
    ViewHeight = 450;

  private
    FPlot: TChartPlot;
    FView: TChartView;
    FHoverEventCount: Integer;
    FLastHoverInfo: TChartHitInfo;
    FLastHoverSender: TObject;
    FRepaintRequestCount: Integer;

    procedure HandleDataPointHover(Sender: TObject; const Info: TChartHitInfo);
    procedure HandleRepaintRequest(Sender: TObject);
    function RenderCallCount(const Width, Height: Single): NativeInt;
    function FirstBarTarget: TChartHitTarget;
    procedure HoverFirstBar;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Render_FirstCall_DrawsPlot;

    [Test]
    procedure Render_WhileStillValid_DrawsNothing;

    [Test]
    procedure Render_AfterPlotChange_DrawsAgain;

    [Test]
    procedure Render_AfterSizeChange_DrawsAgain;

    [Test]
    procedure Render_AfterInvalidate_DrawsAgain;

    [Test]
    procedure NeedsRender_AfterRenderAtSameSize_ReturnsFalse;

    [Test]
    procedure PlotChange_RequestsRepaintWithoutHoverEvent;

    [Test]
    procedure Invalidate_RequestsNoRepaint;

    [Test]
    procedure MouseMove_OntoDataPoint_FiresHoverEventAndRequestsRepaint;

    [Test]
    procedure MouseMove_WithinSameDataPoint_FiresNothing;

    [Test]
    procedure MouseMove_BeforeFirstRender_FiresNothing;

    [Test]
    procedure MouseMove_ShowTooltipsFalse_FiresNothing;

    [Test]
    procedure MouseLeave_AfterHover_FiresMissAndRequestsRepaint;

    [Test]
    procedure MouseLeave_NothingHovered_FiresNothing;

    [Test]
    procedure DrawOverlay_NothingHovered_DrawsNothing;

    [Test]
    procedure DrawOverlay_ShowTooltipsFalse_DrawsNothing;

    [Test]
    procedure DrawOverlay_DataPointHovered_DrawsTooltip;

    [Test]
    procedure DrawOverlay_ValueAxisFormatting_TooltipReadsTheWayTheAxisDoes;

    [Test]
    procedure Destroy_ReleasesPlotOnChanged;

    [Test]
    procedure Destroy_PlotOnChangedReassigned_LeavesItAlone;
  end;

implementation

uses
  System.Classes,
  Chart4D.Canvas.Interfaces,
  Chart4D.Renderer;

procedure TChartViewTests.Setup;
begin
  FPlot := TChartPlot.Create;
  FPlot.Kind := TChartKind.Bar;
  FPlot.Title := 'Life expectancy';
  FPlot.Categories := ['Netherlands', 'Belgium', 'France'];
  FPlot.AddSeries('2020', [81.4, 80.7, 82.2]);

  FView := TChartView.Create(FPlot);
  FView.OnDataPointHover := HandleDataPointHover;
  FView.OnRepaintRequest := HandleRepaintRequest;

  FHoverEventCount := 0;
  FLastHoverInfo := Default(TChartHitInfo);
  FLastHoverSender := nil;
  FRepaintRequestCount := 0;
end;

procedure TChartViewTests.TearDown;
begin
  FView.Free;
  FView := nil;
  FPlot.Free;
  FPlot := nil;
end;

procedure TChartViewTests.HandleDataPointHover(Sender: TObject; const Info: TChartHitInfo);
begin
  Inc(FHoverEventCount);
  FLastHoverInfo := Info;
  FLastHoverSender := Sender;
end;

procedure TChartViewTests.HandleRepaintRequest(Sender: TObject);
begin
  Inc(FRepaintRequestCount);
end;

function TChartViewTests.RenderCallCount(const Width, Height: Single): NativeInt;
begin
  const Canvas = TRecordingCanvas.Create;
  const CanvasReference: IChartCanvas = Canvas;
  FView.Render(CanvasReference, Width, Height);
  Result := Canvas.Calls.Count;
end;

function TChartViewTests.FirstBarTarget: TChartHitTarget;
begin
  { The recording canvas measures text deterministically, so an independent render at the
    view's size lays the bars out at exactly the pixels the view hit-tests against. }
  const CanvasReference: IChartCanvas = TRecordingCanvas.Create;
  var HitMap: TArray<TChartHitTarget>;
  TChartRenderer.Render(FPlot, CanvasReference, ViewWidth, ViewHeight, HitMap);
  Assert.IsTrue(Length(HitMap) > 0, 'The fixture plot must produce hit targets');
  Result := HitMap[0];
end;

procedure TChartViewTests.HoverFirstBar;
begin
  RenderCallCount(ViewWidth, ViewHeight);
  const Target = FirstBarTarget;
  FView.MouseMove(Target.Bounds.CenterPoint.X, Target.Bounds.CenterPoint.Y);
end;

procedure TChartViewTests.Render_FirstCall_DrawsPlot;
begin
  Assert.IsTrue(RenderCallCount(ViewWidth, ViewHeight) > 0, 'The first render must draw the plot');
end;

procedure TChartViewTests.Render_WhileStillValid_DrawsNothing;
begin
  RenderCallCount(ViewWidth, ViewHeight);

  Assert.AreEqual(0, RenderCallCount(ViewWidth, ViewHeight),
    'A render at the same size with no plot change must draw nothing');
end;

procedure TChartViewTests.Render_AfterPlotChange_DrawsAgain;
begin
  RenderCallCount(ViewWidth, ViewHeight);
  FPlot.Subtitle := 'Years at birth';

  Assert.IsTrue(RenderCallCount(ViewWidth, ViewHeight) > 0, 'A plot change must make the next render draw');
end;

procedure TChartViewTests.Render_AfterSizeChange_DrawsAgain;
begin
  RenderCallCount(ViewWidth, ViewHeight);

  Assert.IsTrue(RenderCallCount(ViewWidth + 10, ViewHeight) > 0, 'A wider render must draw');
  Assert.IsTrue(RenderCallCount(ViewWidth + 10, ViewHeight + 10) > 0, 'A taller render must draw');
end;

procedure TChartViewTests.Render_AfterInvalidate_DrawsAgain;
begin
  RenderCallCount(ViewWidth, ViewHeight);
  FView.Invalidate;

  Assert.IsTrue(RenderCallCount(ViewWidth, ViewHeight) > 0, 'Invalidate must make the next render draw');
end;

procedure TChartViewTests.NeedsRender_AfterRenderAtSameSize_ReturnsFalse;
begin
  Assert.IsTrue(FView.NeedsRender(ViewWidth, ViewHeight), 'A view that never rendered needs a render');

  RenderCallCount(ViewWidth, ViewHeight);

  Assert.IsFalse(FView.NeedsRender(ViewWidth, ViewHeight), 'A fresh render at this size is still valid');
  Assert.IsTrue(FView.NeedsRender(ViewWidth, ViewHeight + 1), 'Another size needs a render');
end;

procedure TChartViewTests.PlotChange_RequestsRepaintWithoutHoverEvent;
begin
  FPlot.Subtitle := 'Years at birth';

  Assert.AreEqual(1, FRepaintRequestCount, 'A plot change must request exactly one repaint');
  Assert.AreEqual(0, FHoverEventCount, 'A plot change must not fire OnDataPointHover');
end;

procedure TChartViewTests.Invalidate_RequestsNoRepaint;
begin
  FView.Invalidate;

  Assert.AreEqual(0, FRepaintRequestCount, 'Invalidate is for a caller that repaints anyway');
end;

procedure TChartViewTests.MouseMove_OntoDataPoint_FiresHoverEventAndRequestsRepaint;
begin
  HoverFirstBar;

  Assert.AreEqual(1, FHoverEventCount, 'Entering a bar must fire OnDataPointHover once');
  Assert.IsTrue(FLastHoverInfo.HasHit, 'The event must report a hit');
  Assert.AreEqual('Netherlands', FLastHoverInfo.CategoryLabel, 'The event must report the hovered bar');
  Assert.AreSame(FView, FLastHoverSender, 'The view must pass itself as Sender');
  Assert.AreEqual(1, FRepaintRequestCount, 'Entering a bar must request one repaint');
end;

procedure TChartViewTests.MouseMove_WithinSameDataPoint_FiresNothing;
begin
  HoverFirstBar;
  const Target = FirstBarTarget;

  FView.MouseMove(Target.Bounds.CenterPoint.X, Target.Bounds.CenterPoint.Y + 1);

  Assert.AreEqual(1, FHoverEventCount, 'Moving within the hovered bar must not fire again');
  Assert.AreEqual(1, FRepaintRequestCount, 'Moving within the hovered bar must not request a repaint');
end;

procedure TChartViewTests.MouseMove_BeforeFirstRender_FiresNothing;
begin
  const Target = FirstBarTarget;

  FView.MouseMove(Target.Bounds.CenterPoint.X, Target.Bounds.CenterPoint.Y);

  Assert.AreEqual(0, FHoverEventCount, 'Without a render there is no hit map to hover');
  Assert.AreEqual(0, FRepaintRequestCount, 'Without a hover change there is nothing to repaint');
end;

procedure TChartViewTests.MouseMove_ShowTooltipsFalse_FiresNothing;
begin
  FView.ShowTooltips := False;

  HoverFirstBar;

  Assert.AreEqual(0, FHoverEventCount, 'With tooltips off, hovering must not fire OnDataPointHover');
  Assert.AreEqual(0, FRepaintRequestCount, 'With tooltips off, hovering must not request a repaint');
end;

procedure TChartViewTests.MouseLeave_AfterHover_FiresMissAndRequestsRepaint;
begin
  HoverFirstBar;

  FView.MouseLeave;

  Assert.AreEqual(2, FHoverEventCount, 'Leaving must fire OnDataPointHover once more');
  Assert.IsFalse(FLastHoverInfo.HasHit, 'Leaving must report no hit');
  Assert.AreEqual(2, FRepaintRequestCount, 'Leaving must request one more repaint');
  Assert.IsFalse(FView.HasOverlay, 'Nothing is hovered after leaving');
end;

procedure TChartViewTests.MouseLeave_NothingHovered_FiresNothing;
begin
  RenderCallCount(ViewWidth, ViewHeight);

  FView.MouseLeave;

  Assert.AreEqual(0, FHoverEventCount, 'Leaving without a hovered point must not fire');
  Assert.AreEqual(0, FRepaintRequestCount, 'Leaving without a hovered point must not request a repaint');
end;

procedure TChartViewTests.DrawOverlay_NothingHovered_DrawsNothing;
begin
  RenderCallCount(ViewWidth, ViewHeight);
  const Canvas = TRecordingCanvas.Create;
  const CanvasReference: IChartCanvas = Canvas;

  FView.DrawOverlay(CanvasReference, ViewWidth, ViewHeight);

  Assert.IsFalse(FView.HasOverlay, 'Nothing is hovered');
  Assert.AreEqual(0, Canvas.Calls.Count, 'Without a hovered point no overlay may be drawn');
end;

procedure TChartViewTests.DrawOverlay_ShowTooltipsFalse_DrawsNothing;
begin
  HoverFirstBar;
  FView.ShowTooltips := False;
  const Canvas = TRecordingCanvas.Create;
  const CanvasReference: IChartCanvas = Canvas;

  FView.DrawOverlay(CanvasReference, ViewWidth, ViewHeight);

  Assert.IsFalse(FView.HasOverlay, 'Turning tooltips off hides the overlay');
  Assert.AreEqual(0, Canvas.Calls.Count, 'With tooltips off no overlay may be drawn');
end;

procedure TChartViewTests.DrawOverlay_DataPointHovered_DrawsTooltip;
begin
  HoverFirstBar;
  const Canvas = TRecordingCanvas.Create;
  const CanvasReference: IChartCanvas = Canvas;

  FView.DrawOverlay(CanvasReference, ViewWidth, ViewHeight);

  Assert.IsTrue(FView.HasOverlay, 'A hovered bar shows an overlay');
  Assert.AreEqual(1, Canvas.CountOfKind(TCanvasCallKind.FillCircle), 'The overlay must draw the highlight');
  Assert.IsTrue(Canvas.CountOfKind(TCanvasCallKind.FillRect) > 0, 'The overlay must draw the tooltip box');
  Assert.IsTrue(Canvas.HasTextEqualTo('2020'), 'The tooltip must name the hovered series');
  Assert.AreEqual(0, Canvas.CountOfKind(TCanvasCallKind.FillBackground),
    'The overlay must draw on top of the render, never the chart itself');
end;

procedure TChartViewTests.DrawOverlay_ValueAxisFormatting_TooltipReadsTheWayTheAxisDoes;
begin
  { A tooltip that formats its value differently from the axis right next to it reads as a
    different number, so the view must hand the tooltip the value axis' own settings. }
  FPlot.ClearSeries;
  FPlot.AddSeries('2020', [40000, 30000, 20000]);

  var AxisOptions := FPlot.YAxis;
  AxisOptions.UseThousandSeparator := True;
  AxisOptions.Decimals := 1;
  FPlot.YAxis := AxisOptions;

  HoverFirstBar;
  const Canvas = TRecordingCanvas.Create;
  const CanvasReference: IChartCanvas = Canvas;

  FView.DrawOverlay(CanvasReference, ViewWidth, ViewHeight);

  Assert.IsTrue(Canvas.HasTextEqualTo('Netherlands: 40,000.0'),
    'The tooltip must group and round its value exactly as the value axis does');
end;

procedure TChartViewTests.Destroy_ReleasesPlotOnChanged;
begin
  FView.Free;
  FView := nil;

  Assert.IsFalse(Assigned(FPlot.OnChanged), 'A destroyed view must not stay subscribed to the plot');
end;

procedure TChartViewTests.Destroy_PlotOnChangedReassigned_LeavesItAlone;
begin
  FPlot.OnChanged := HandleRepaintRequest;

  FView.Free;
  FView := nil;

  Assert.IsTrue(Assigned(FPlot.OnChanged), 'A handler assigned after the view took over must survive the view');
end;

end.
