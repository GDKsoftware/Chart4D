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
unit Chart4D.Hover.Tests;

/// <summary>
/// Tests for <c>TChartHoverState</c>: whether a pointer move is reported as a hover
/// change, including between the two same-index ends of a paired point.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4D.Hover,
  Chart4D.Types;

type
  [TestFixture]
  TChartHoverStateTests = class
  private
    FHoverState: TChartHoverState;

    function CircularTarget(const CenterX, CenterY: Single; const Value: Double): TChartHitTarget;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure MoveTo_BetweenPairedEndsOfOnePoint_ReportsChange;

    [Test]
    procedure MoveTo_WithinSameTarget_ReportsNoChange;

    [Test]
    procedure MoveTo_FromTargetToEmptySpace_ReportsChange;
  end;

implementation

uses
  System.Math,
  System.Types;

procedure TChartHoverStateTests.Setup;
begin
  FHoverState := TChartHoverState.Create;
end;

procedure TChartHoverStateTests.TearDown;
begin
  FHoverState.Free;
  FHoverState := nil;
end;

function TChartHoverStateTests.CircularTarget(const CenterX, CenterY: Single; const Value: Double): TChartHitTarget;
begin
  Result := Default(TChartHitTarget);
  Result.Center := TPointF.Create(CenterX, CenterY);
  Result.Radius := 8;
  Result.Info.HasHit := True;
  Result.Info.SeriesIndex := 0;
  Result.Info.PointIndex := 0;
  Result.Info.Value := Value;
  Result.Info.AnchorX := CenterX;
  Result.Info.AnchorY := CenterY;
end;

procedure TChartHoverStateTests.MoveTo_BetweenPairedEndsOfOnePoint_ReportsChange;
begin
  { A dumbbell, arrow or range-band point produces two targets with the same series and
    point indices, one per end, that differ only in value and anchor. Moving from one end
    to the other must count as a hover change, so the tooltip follows the pointer and
    OnDataPointHover fires for the second end. }
  FHoverState.HitMap := [CircularTarget(100, 100, 70), CircularTarget(200, 100, 76)];

  Assert.IsTrue(FHoverState.MoveTo(100, 100), 'Entering the first end must report a change');
  Assert.IsTrue(FHoverState.MoveTo(200, 100), 'Moving to the other end of the same point must report a change');
  Assert.IsTrue(SameValue(FHoverState.Info.Value, 76), 'The hover state must now report the second end''s value');
end;

procedure TChartHoverStateTests.MoveTo_WithinSameTarget_ReportsNoChange;
begin
  FHoverState.HitMap := [CircularTarget(100, 100, 70), CircularTarget(200, 100, 76)];

  Assert.IsTrue(FHoverState.MoveTo(100, 100), 'Entering the target must report a change');
  Assert.IsFalse(FHoverState.MoveTo(102, 101), 'Moving within the same target must not report a change');
end;

procedure TChartHoverStateTests.MoveTo_FromTargetToEmptySpace_ReportsChange;
begin
  FHoverState.HitMap := [CircularTarget(100, 100, 70)];

  Assert.IsTrue(FHoverState.MoveTo(100, 100), 'Entering the target must report a change');
  Assert.IsTrue(FHoverState.MoveTo(300, 300), 'Leaving every target must report a change');
  Assert.IsFalse(FHoverState.Info.HasHit, 'Nothing must be hovered after leaving every target');
end;

end.
