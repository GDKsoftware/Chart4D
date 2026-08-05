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
unit Chart4D.Hover;

/// <summary>
/// The hover state of a chart control: the hit map of the last render, which data point
/// the pointer is currently on, and whether a pointer move actually changed that. RTL-only,
/// so the VCL and FMX controls share one implementation of the rule instead of each
/// carrying their own copy.
/// </summary>

interface

uses
  Chart4D.Types;

type
  /// <summary>
  /// Tracks which data point of a rendered chart the pointer is on. A control feeds it
  /// the hit map after every render and the pointer position on every move; it answers
  /// whether the hovered point changed, which is the only moment the control has to fire
  /// <c>OnDataPointHover</c> and repaint.
  /// </summary>
  TChartHoverState = class
  private
    FHitMap: TArray<TChartHitTarget>;
    FInfo: TChartHitInfo;
    FEnabled: Boolean;

    function IsSameTarget(const Current, Candidate: TChartHitInfo): Boolean;
    function Apply(const Candidate: TChartHitInfo): Boolean;
    function GetIsVisible: Boolean;

  public
    /// <summary>Creates an enabled hover state with no hit map and nothing hovered.</summary>
    constructor Create;

    /// <summary>
    /// Moves the pointer to <c>(X, Y)</c> and hit-tests the current hit map. Returns
    /// <c>True</c> when the hovered data point changed. Does nothing and returns
    /// <c>False</c> while <c>Enabled</c> is <c>False</c>.
    /// </summary>
    function MoveTo(const X, Y: Single): Boolean;

    /// <summary>
    /// Clears the hovered data point, for when the pointer leaves the control. Returns
    /// <c>True</c> when something was hovered before.
    /// </summary>
    function Leave: Boolean;

    /// <summary>The hit map of the last render, replaced on every re-render.</summary>
    property HitMap: TArray<TChartHitTarget> read FHitMap write FHitMap;
    /// <summary>The currently hovered data point, with <c>HasHit = False</c> when there is none.</summary>
    property Info: TChartHitInfo read FInfo;
    /// <summary>Whether hovering is tracked at all. Default <c>True</c>.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
    /// <summary>Whether a tooltip should currently be drawn: enabled and something hovered.</summary>
    property IsVisible: Boolean read GetIsVisible;
  end;

implementation

uses
  System.Math,
  Chart4D.Tooltip;

constructor TChartHoverState.Create;
begin
  inherited Create;
  FEnabled := True;
end;

function TChartHoverState.GetIsVisible: Boolean;
begin
  Result := FEnabled and FInfo.HasHit;
end;

function TChartHoverState.MoveTo(const X, Y: Single): Boolean;
begin
  if not FEnabled then
    Exit(False);

  var Candidate: TChartHitInfo;
  TChartTooltip.FindTarget(FHitMap, X, Y, Candidate);
  Result := Apply(Candidate);
end;

function TChartHoverState.Leave: Boolean;
begin
  Result := Apply(Default(TChartHitInfo));
end;

function TChartHoverState.Apply(const Candidate: TChartHitInfo): Boolean;
begin
  Result := not IsSameTarget(FInfo, Candidate);
  if Result then
    FInfo := Candidate;
end;

function TChartHoverState.IsSameTarget(const Current, Candidate: TChartHitInfo): Boolean;
begin
  const BothMiss = (not Current.HasHit) and (not Candidate.HasHit);
  if BothMiss then
    Exit(True);

  Result := (Current.HasHit = Candidate.HasHit) and
            (Current.SeriesIndex = Candidate.SeriesIndex) and
            (Current.PointIndex = Candidate.PointIndex) and
            SameValue(Current.Value, Candidate.Value);
end;

end.
