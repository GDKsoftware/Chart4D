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
unit Chart4D.Tooltip.Tests;

/// <summary>
/// Tests for the hover hit map produced by <c>TChartRenderer.Render</c> and for
/// <c>TChartTooltip.FindTarget</c>/<c>TChartTooltip.Draw</c>.
/// </summary>

interface

uses
  System.Types,
  System.UITypes,
  DUnitX.TestFramework,
  Chart4D.Canvas.Interfaces,
  Chart4D.Tests.RecordingCanvas,
  Chart4D.Types;

type
  [TestFixture]
  TChartTooltipTests = class
  private
    FCanvas: IChartCanvas;
    FRecordingCanvas: TRecordingCanvas;

    function BuildCircleTarget(const Center: TPointF; const Radius: Single; const SeriesName: string): TChartHitTarget;
    function BuildRectTarget(const Bounds: TRectF; const SeriesName: string): TChartHitTarget;
    function BuildSectorTarget(const Center: TPointF; const InnerRadius, OuterRadius, StartAngle, SweepAngle: Single;
                              const CategoryLabel: string): TChartHitTarget;
    function BuildInfo(const SeriesName, CategoryLabel: string; const Value: Double;
                       const AnchorX, AnchorY: Single; const Color: TAlphaColor): TChartHitInfo;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Render_LineChart_HitMap_OneTargetPerDataPoint;

    [Test]
    procedure Render_BarChart_HitMap_OneTargetPerBar;

    [Test]
    procedure FindTarget_PointInsideNearestCircularTarget_ReturnsItsInfo;

    [Test]
    procedure FindTarget_PointInsideTwoOverlappingTargets_ReturnsNearestOne;

    [Test]
    procedure FindTarget_PointOutsideEveryTarget_ReturnsFalse;

    [Test]
    procedure FindTarget_PointInsideRectangularTarget_ReturnsItsInfo;

    [Test]
    procedure FindTarget_PointJustOutsideRectangularTarget_ReturnsFalse;

    [Test]
    procedure Draw_ValidInfo_DrawsBoxHighlightAndText;

    [Test]
    procedure Draw_InfoWithoutSeriesName_DrawsOnlyTheValueLine;

    [Test]
    procedure Draw_DutchLocale_FormatsValueWithLocaleDecimalSeparator;

    [Test]
    procedure Draw_AnchorAtTopLeftCorner_BoxStaysInsideChartBounds;

    [Test]
    procedure Draw_AnchorAtBottomRightCorner_BoxStaysInsideChartBounds;

    [Test]
    procedure Draw_AnchorAtTopRightCorner_BoxStaysInsideChartBounds;

    [Test]
    procedure Draw_AnchorAtBottomLeftCorner_BoxStaysInsideChartBounds;

    [Test]
    procedure FindTarget_PointBetweenInnerAndOuterRadiusWithinAngularSpan_FindsSectorTarget;

    [Test]
    procedure FindTarget_PointStraddlingZeroThreeSixtyWraparound_FindsSectorTarget;

    [Test]
    procedure FindTarget_PointOutsideSectorRadialBounds_Misses;

    [Test]
    procedure FindTarget_PointOutsideSectorAngularSpan_Misses;
  end;

implementation

uses
  System.Math,
  Chart4D.Plot,
  Chart4D.Renderer,
  Chart4D.Style,
  Chart4D.Tooltip;

procedure TChartTooltipTests.Setup;
begin
  FRecordingCanvas := TRecordingCanvas.Create;
  FCanvas := FRecordingCanvas;
end;

procedure TChartTooltipTests.TearDown;
begin
  FCanvas := nil;
  FRecordingCanvas := nil;
end;

procedure TChartTooltipTests.Render_LineChart_HitMap_OneTargetPerDataPoint;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.AddSeries('Netherlands', [72.1, 73.2, 77.4, 79.8]);
    Plot.AddSeries('Belgium', [68.0, 71.1, 76.0, 79.4]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    Assert.AreEqual(8, Length(HitMap));
    for var Target in HitMap do
    begin
      Assert.IsTrue(Target.Radius > 0, 'Line chart hit targets must be circular');
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartTooltipTests.Render_BarChart_HitMap_OneTargetPerBar;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Bar;
    Plot.Categories := ['North', 'South', 'East', 'West'];
    Plot.AddSeries('Count', [3, -2, 5, 1]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, 640, 450, HitMap);

    Assert.AreEqual(4, Length(HitMap));
    for var Target in HitMap do
    begin
      Assert.AreEqual<Single>(0, Target.Radius, 'Bar chart hit targets must be rectangular');
    end;
  finally
    Plot.Free;
  end;
end;

procedure TChartTooltipTests.FindTarget_PointInsideNearestCircularTarget_ReturnsItsInfo;
begin
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildCircleTarget(TPointF.Create(100, 100), 12, 'Near')];
  HitMap := HitMap + [BuildCircleTarget(TPointF.Create(300, 300), 12, 'Far')];

  var Info: TChartHitInfo;
  const Found = TChartTooltip.FindTarget(HitMap, 102, 101, Info);

  Assert.IsTrue(Found);
  Assert.AreEqual('Near', Info.SeriesName);
end;

procedure TChartTooltipTests.FindTarget_PointInsideTwoOverlappingTargets_ReturnsNearestOne;
begin
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildCircleTarget(TPointF.Create(100, 100), 20, 'A')];
  HitMap := HitMap + [BuildCircleTarget(TPointF.Create(110, 100), 20, 'B')];

  var Info: TChartHitInfo;
  const Found = TChartTooltip.FindTarget(HitMap, 108, 100, Info);

  Assert.IsTrue(Found);
  Assert.AreEqual('B', Info.SeriesName);
end;

procedure TChartTooltipTests.FindTarget_PointOutsideEveryTarget_ReturnsFalse;
begin
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildCircleTarget(TPointF.Create(100, 100), 12, 'Near')];

  var Info: TChartHitInfo;
  const Found = TChartTooltip.FindTarget(HitMap, 500, 500, Info);

  Assert.IsFalse(Found);
  Assert.IsFalse(Info.HasHit);
end;

procedure TChartTooltipTests.FindTarget_PointInsideRectangularTarget_ReturnsItsInfo;
begin
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildRectTarget(TRectF.Create(50, 100, 90, 200), 'Bar')];

  var Info: TChartHitInfo;
  const Found = TChartTooltip.FindTarget(HitMap, 55, 195, Info);

  Assert.IsTrue(Found, 'A point anywhere inside a rectangular target''s bounds must hit it');
  Assert.AreEqual('Bar', Info.SeriesName);
end;

procedure TChartTooltipTests.FindTarget_PointJustOutsideRectangularTarget_ReturnsFalse;
begin
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildRectTarget(TRectF.Create(50, 100, 90, 200), 'Bar')];

  var Info: TChartHitInfo;
  const Found = TChartTooltip.FindTarget(HitMap, 91, 150, Info);

  Assert.IsFalse(Found, 'A point just outside a rectangular target''s bounds must miss it');
  Assert.IsFalse(Info.HasHit);
end;

procedure TChartTooltipTests.Draw_ValidInfo_DrawsBoxHighlightAndText;
begin
  const Info = BuildInfo('Netherlands', '1992', 77.4, 320, 225, ChartBlue);

  TChartTooltip.Draw(FCanvas, TChartStyle.Default, Info, 640, 450);

  Assert.AreEqual(1, FRecordingCanvas.CountOfKind(TCanvasCallKind.FillRect));
  Assert.AreEqual(1, FRecordingCanvas.CountOfKind(TCanvasCallKind.FillCircle));
  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('Netherlands'));
  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('1992: 77.4'));

  const Circle = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillCircle)[0];
  Assert.AreEqual(Info.AnchorX, Circle.CenterX, 0.01, 'the highlight circle must be centered on the hovered anchor');
  Assert.AreEqual(Info.AnchorY, Circle.CenterY, 0.01, 'the highlight circle must be centered on the hovered anchor');
  Assert.AreEqual<TAlphaColor>(Info.Color, Circle.Color, 'the highlight circle must use the hovered point''s own color');

  { The anchor sits well clear of every chart edge, so the box's own edge clamp cannot move
    it: this fixture exercises the placement rule (above the anchor, straddling its X)
    rather than the clamp, which the four corner tests below cover separately. }
  const Box = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect)[0].Bounds;
  Assert.IsTrue(Box.Bottom < Info.AnchorY, 'the tooltip box must sit above the hovered anchor');
  Assert.IsTrue(Box.Left <= Info.AnchorX, 'the tooltip box must straddle the anchor''s X position');
  Assert.IsTrue(Box.Right >= Info.AnchorX, 'the tooltip box must straddle the anchor''s X position');
end;

procedure TChartTooltipTests.Draw_InfoWithoutSeriesName_DrawsOnlyTheValueLine;
begin
  const Info = BuildInfo('', '1992', 77.4, 320, 225, ChartBlue);

  TChartTooltip.Draw(FCanvas, TChartStyle.Default, Info, 640, 450);

  Assert.AreEqual(1, FRecordingCanvas.CountOfKind(TCanvasCallKind.DrawText),
    'A tooltip without a series name must draw the value line and nothing else');
  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('1992: 77.4'));
end;

procedure TChartTooltipTests.Draw_DutchLocale_FormatsValueWithLocaleDecimalSeparator;
begin
  const Info = BuildInfo('Netherlands', '1992', 77.4, 320, 225, ChartBlue);

  TChartTooltip.Draw(FCanvas, TChartStyle.Default, Info, 640, 450, 'nl-NL');

  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('1992: 77,4'));
end;

procedure TChartTooltipTests.Draw_AnchorAtTopLeftCorner_BoxStaysInsideChartBounds;
begin
  const Info = BuildInfo('Series', 'Cat', 1, 0, 0, ChartBlue);

  TChartTooltip.Draw(FCanvas, TChartStyle.Default, Info, 640, 450);

  const Bounds = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect)[0].Bounds;
  Assert.IsTrue(Bounds.Left >= 0);
  Assert.IsTrue(Bounds.Top >= 0);
  Assert.IsTrue(Bounds.Right <= 640);
  Assert.IsTrue(Bounds.Bottom <= 450);
end;

procedure TChartTooltipTests.Draw_AnchorAtBottomRightCorner_BoxStaysInsideChartBounds;
begin
  const Info = BuildInfo('Series', 'Cat', 1, 640, 450, ChartBlue);

  TChartTooltip.Draw(FCanvas, TChartStyle.Default, Info, 640, 450);

  const Bounds = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect)[0].Bounds;
  Assert.IsTrue(Bounds.Left >= 0);
  Assert.IsTrue(Bounds.Top >= 0);
  Assert.IsTrue(Bounds.Right <= 640);
  Assert.IsTrue(Bounds.Bottom <= 450);
end;

procedure TChartTooltipTests.Draw_AnchorAtTopRightCorner_BoxStaysInsideChartBounds;
begin
  const Info = BuildInfo('Series', 'Cat', 1, 640, 0, ChartBlue);

  TChartTooltip.Draw(FCanvas, TChartStyle.Default, Info, 640, 450);

  const Bounds = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect)[0].Bounds;
  Assert.IsTrue(Bounds.Left >= 0);
  Assert.IsTrue(Bounds.Top >= 0);
  Assert.IsTrue(Bounds.Right <= 640);
  Assert.IsTrue(Bounds.Bottom <= 450);
end;

procedure TChartTooltipTests.Draw_AnchorAtBottomLeftCorner_BoxStaysInsideChartBounds;
begin
  const Info = BuildInfo('Series', 'Cat', 1, 0, 450, ChartBlue);

  TChartTooltip.Draw(FCanvas, TChartStyle.Default, Info, 640, 450);

  const Bounds = FRecordingCanvas.CallsOfKind(TCanvasCallKind.FillRect)[0].Bounds;
  Assert.IsTrue(Bounds.Left >= 0);
  Assert.IsTrue(Bounds.Top >= 0);
  Assert.IsTrue(Bounds.Right <= 640);
  Assert.IsTrue(Bounds.Bottom <= 450);
end;

function TChartTooltipTests.BuildCircleTarget(const Center: TPointF; const Radius: Single; const SeriesName: string): TChartHitTarget;
begin
  Result := Default(TChartHitTarget);
  Result.Center := Center;
  Result.Radius := Radius;
  Result.Info.HasHit := True;
  Result.Info.SeriesName := SeriesName;
end;

function TChartTooltipTests.BuildRectTarget(const Bounds: TRectF; const SeriesName: string): TChartHitTarget;
begin
  Result := Default(TChartHitTarget);
  Result.Bounds := Bounds;
  Result.Info.HasHit := True;
  Result.Info.SeriesName := SeriesName;
end;

function TChartTooltipTests.BuildSectorTarget(const Center: TPointF; const InnerRadius, OuterRadius, StartAngle, SweepAngle: Single;
                                              const CategoryLabel: string): TChartHitTarget;
begin
  Result := Default(TChartHitTarget);
  Result.IsSector := True;
  Result.Center := Center;
  Result.InnerRadius := InnerRadius;
  Result.OuterRadius := OuterRadius;
  Result.StartAngle := StartAngle;
  Result.SweepAngle := SweepAngle;
  Result.Info.HasHit := True;
  Result.Info.CategoryLabel := CategoryLabel;
end;

procedure TChartTooltipTests.FindTarget_PointBetweenInnerAndOuterRadiusWithinAngularSpan_FindsSectorTarget;
begin
  const Center = TPointF.Create(100, 100);
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildSectorTarget(Center, 20, 50, -90, 90, 'Quarter')];

  const Angle = DegToRad(-45);
  const TestPoint = TPointF.Create(Center.X + 35 * Cos(Angle), Center.Y + 35 * Sin(Angle));

  var Info: TChartHitInfo;
  const Found = TChartTooltip.FindTarget(HitMap, TestPoint.X, TestPoint.Y, Info);

  Assert.IsTrue(Found, 'A point between InnerRadius and OuterRadius, within the angular span, must hit the sector');
  Assert.AreEqual('Quarter', Info.CategoryLabel);
end;

procedure TChartTooltipTests.FindTarget_PointStraddlingZeroThreeSixtyWraparound_FindsSectorTarget;
begin
  const Center = TPointF.Create(100, 100);
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildSectorTarget(Center, 10, 50, 340, 40, 'Wraparound')];

  { Angle 0 degrees is within [340, 380), which wraps past 360. }
  const TestPoint = TPointF.Create(Center.X + 35, Center.Y);

  var Info: TChartHitInfo;
  const Found = TChartTooltip.FindTarget(HitMap, TestPoint.X, TestPoint.Y, Info);

  Assert.IsTrue(Found, 'A sector straddling the 0/360 wraparound must still be found');
  Assert.AreEqual('Wraparound', Info.CategoryLabel);
end;

procedure TChartTooltipTests.FindTarget_PointOutsideSectorRadialBounds_Misses;
begin
  const Center = TPointF.Create(100, 100);
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildSectorTarget(Center, 20, 50, -90, 90, 'Quarter')];

  const Angle = DegToRad(-45);
  const InsideHoleTestPoint = TPointF.Create(Center.X + 10 * Cos(Angle), Center.Y + 10 * Sin(Angle));
  const OutsideOuterTestPoint = TPointF.Create(Center.X + 80 * Cos(Angle), Center.Y + 80 * Sin(Angle));

  var Info: TChartHitInfo;
  Assert.IsFalse(TChartTooltip.FindTarget(HitMap, InsideHoleTestPoint.X, InsideHoleTestPoint.Y, Info),
    'A point closer to the center than InnerRadius must miss');
  Assert.IsFalse(TChartTooltip.FindTarget(HitMap, OutsideOuterTestPoint.X, OutsideOuterTestPoint.Y, Info),
    'A point farther from the center than OuterRadius must miss');
end;

procedure TChartTooltipTests.FindTarget_PointOutsideSectorAngularSpan_Misses;
begin
  const Center = TPointF.Create(100, 100);
  var HitMap: TArray<TChartHitTarget> := [];
  HitMap := HitMap + [BuildSectorTarget(Center, 20, 50, -90, 90, 'Quarter')];

  const Angle = DegToRad(90);
  const TestPoint = TPointF.Create(Center.X + 35 * Cos(Angle), Center.Y + 35 * Sin(Angle));

  var Info: TChartHitInfo;
  const Found = TChartTooltip.FindTarget(HitMap, TestPoint.X, TestPoint.Y, Info);

  Assert.IsFalse(Found, 'A point at the correct radius but outside the angular span must miss');
end;

function TChartTooltipTests.BuildInfo(const SeriesName, CategoryLabel: string; const Value: Double;
                                      const AnchorX, AnchorY: Single; const Color: TAlphaColor): TChartHitInfo;
begin
  Result := Default(TChartHitInfo);
  Result.HasHit := True;
  Result.SeriesName := SeriesName;
  Result.CategoryLabel := CategoryLabel;
  Result.Value := Value;
  Result.AnchorX := AnchorX;
  Result.AnchorY := AnchorY;
  Result.Color := Color;
end;

end.
