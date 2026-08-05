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
unit Chart4D.Tooltip;

/// <summary>
/// Hit-testing against a chart's hit map and drawing of the in-chart hover tooltip
/// (highlight circle plus text box), per the Chart4D editorial style.
/// </summary>

interface

uses
  System.Types,
  Chart4D.Canvas.Interfaces,
  Chart4D.Style,
  Chart4D.Types;

type
  /// <summary>
  /// Hit-tests a chart's hit map against a pointer position and draws the hover
  /// tooltip for the hit data point.
  /// </summary>
  TChartTooltip = class
  private
    class function TargetContainsPoint(const Target: TChartHitTarget; const X, Y: Single;
                                       out Distance: Single): Boolean; static;
    class function NormalizeAngleDegrees(const Angle: Single): Single; static;
    class function SectorContainsAngle(const PointAngle, StartAngle, SweepAngle: Single): Boolean; static;

    class function BuildLines(const Info: TChartHitInfo; const LocaleName: string): TArray<string>; static;
    class function MeasureLinesWidth(const Canvas: IChartCanvas; const Lines: TArray<string>;
                                     const TextStyle: TChartTextStyle): Single; static;
    class function ComputeBoxBounds(const Info: TChartHitInfo; const BoxWidth, BoxHeight: Single;
                                    const Width, Height, ScaleFactor: Single): TRectF; static;
    class procedure DrawBox(const Canvas: IChartCanvas; const Bounds: TRectF; const ScaleFactor: Single); static;
    class procedure DrawLines(const Canvas: IChartCanvas; const Lines: TArray<string>;
                              const TextStyle: TChartTextStyle; const Bounds: TRectF;
                              const Padding, LineHeight: Single); static;

  public
    /// <summary>
    /// Finds the hit target whose center/rectangle contains <c>(X, Y)</c> and is
    /// closest to it, and returns its data point information in <c>Info</c>. Returns
    /// <c>False</c>, with <c>Info.HasHit = False</c>, when no target contains the point.
    /// </summary>
    class function FindTarget(const HitMap: TArray<TChartHitTarget>;
                              const X, Y: Single; out Info: TChartHitInfo): Boolean; static;

    /// <summary>
    /// Draws the hover highlight circle at <c>Info</c>'s anchor and a tooltip box with
    /// the series name and category/value text, clamped inside
    /// <c>[0, Width] x [0, Height]</c>. <c>LocaleName</c>, when non-empty, formats
    /// <c>Info.Value</c> with that locale instead of the invariant convention.
    /// </summary>
    class procedure Draw(const Canvas: IChartCanvas; const Style: TChartStyle;
                         const Info: TChartHitInfo;
                         const Width, Height: Single;
                         const LocaleName: string = ''); static;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  Chart4D.Axis,
  Chart4D.Consts;

class function TChartTooltip.NormalizeAngleDegrees(const Angle: Single): Single;
begin
  Result := Angle - 360 * Floor(Angle / 360);
end;

class function TChartTooltip.SectorContainsAngle(const PointAngle, StartAngle, SweepAngle: Single): Boolean;
begin
  const NormalizedPoint = NormalizeAngleDegrees(PointAngle);
  const NormalizedStart = NormalizeAngleDegrees(StartAngle);

  var RelativeAngle := NormalizedPoint - NormalizedStart;
  if RelativeAngle < 0 then
    RelativeAngle := RelativeAngle + 360;

  Result := (RelativeAngle < SweepAngle);
end;

class function TChartTooltip.TargetContainsPoint(const Target: TChartHitTarget; const X, Y: Single;
                                                  out Distance: Single): Boolean;
begin
  const Point = TPointF.Create(X, Y);

  if Target.IsSector then
  begin
    Distance := Point.Distance(Target.Center);
    const IsWithinRadii = (Distance >= Target.InnerRadius) and (Distance <= Target.OuterRadius);
    if not IsWithinRadii then
      Exit(False);

    const PointAngle = RadToDeg(ArcTan2(Y - Target.Center.Y, X - Target.Center.X));
    Exit(SectorContainsAngle(PointAngle, Target.StartAngle, Target.SweepAngle));
  end;

  const IsCircular = (Target.Radius > 0);

  if IsCircular then
  begin
    Distance := Point.Distance(Target.Center);
    Result := (Distance <= Target.Radius);
  end
  else
  begin
    const CenterX = (Target.Bounds.Left + Target.Bounds.Right) / 2;
    const CenterY = (Target.Bounds.Top + Target.Bounds.Bottom) / 2;
    Distance := Point.Distance(TPointF.Create(CenterX, CenterY));
    Result := Target.Bounds.Contains(Point);
  end;
end;

class function TChartTooltip.FindTarget(const HitMap: TArray<TChartHitTarget>;
                                        const X, Y: Single; out Info: TChartHitInfo): Boolean;
begin
  Info := Default(TChartHitInfo);
  Result := False;

  var BestDistance := Infinity;
  for var Target in HitMap do
  begin
    var Distance: Single;
    const IsHit = TargetContainsPoint(Target, X, Y, Distance);

    const IsCloserHit = IsHit and (Distance < BestDistance);
    if IsCloserHit then
    begin
      BestDistance := Distance;
      Info := Target.Info;
      Result := True;
    end;
  end;
end;

class procedure TChartTooltip.Draw(const Canvas: IChartCanvas; const Style: TChartStyle;
                                   const Info: TChartHitInfo;
                                   const Width, Height: Single;
                                   const LocaleName: string = '');
begin
  const HighlightRadius = 5 * Style.ScaleFactor;
  Canvas.FillCircle(Info.AnchorX, Info.AnchorY, HighlightRadius, Info.Color);

  const TextStyle = TChartTextStyle.Create(Style.FontName, Style.CaptionFontSize, False, Style.TextColor);
  const Lines = BuildLines(Info, LocaleName);
  const Padding = 8 * Style.ScaleFactor;
  const LineHeight = Canvas.MeasureText(LineHeightSampleText, TextStyle).Height;

  const BoxWidth = MeasureLinesWidth(Canvas, Lines, TextStyle) + (2 * Padding);
  const BoxHeight = (Length(Lines) * LineHeight) + (2 * Padding);
  const Bounds = ComputeBoxBounds(Info, BoxWidth, BoxHeight, Width, Height, Style.ScaleFactor);

  DrawBox(Canvas, Bounds, Style.ScaleFactor);
  DrawLines(Canvas, Lines, TextStyle, Bounds, Padding, LineHeight);
end;

class function TChartTooltip.BuildLines(const Info: TChartHitInfo; const LocaleName: string): TArray<string>;
begin
  var FormattedValue: string;
  if LocaleName <> '' then
    FormattedValue := TAxisScale.FormatValue(Info.Value, False, LocaleName)
  else
    FormattedValue := TAxisScale.FormatValue(Info.Value, False);

  const ValueLine = Format('%s: %s', [Info.CategoryLabel, FormattedValue]);

  const HasSeriesName = (Info.SeriesName <> '');
  if HasSeriesName then
    Result := [Info.SeriesName, ValueLine]
  else
    Result := [ValueLine];
end;

class function TChartTooltip.MeasureLinesWidth(const Canvas: IChartCanvas; const Lines: TArray<string>;
                                               const TextStyle: TChartTextStyle): Single;
begin
  Result := 0;
  for var Line in Lines do
  begin
    const LineSize = Canvas.MeasureText(Line, TextStyle);
    Result := Max(Result, LineSize.Width);
  end;
end;

class function TChartTooltip.ComputeBoxBounds(const Info: TChartHitInfo; const BoxWidth, BoxHeight: Single;
                                              const Width, Height, ScaleFactor: Single): TRectF;
begin
  const Gap = 12 * ScaleFactor;

  var Left := Info.AnchorX - BoxWidth / 2;
  var Right := Left + BoxWidth;
  var Bottom := Info.AnchorY - Gap;
  var Top := Bottom - BoxHeight;

  const NeedsRightShift = (Left < 0);
  if NeedsRightShift then
  begin
    Right := Right - Left;
    Left := 0;
  end;

  const NeedsLeftShift = (Right > Width);
  if NeedsLeftShift then
  begin
    Left := Left - (Right - Width);
    Right := Width;
  end;

  const NeedsDownShift = (Top < 0);
  if NeedsDownShift then
  begin
    Bottom := Bottom - Top;
    Top := 0;
  end;

  const NeedsUpShift = (Bottom > Height);
  if NeedsUpShift then
  begin
    Top := Top - (Bottom - Height);
    Bottom := Height;
  end;

  Result := TRectF.Create(Max(Left, 0), Max(Top, 0), Min(Right, Width), Min(Bottom, Height));
end;

class procedure TChartTooltip.DrawBox(const Canvas: IChartCanvas; const Bounds: TRectF; const ScaleFactor: Single);
begin
  Canvas.FillRect(Bounds, ChartLabelBackground);

  const BorderWidth = 1 * ScaleFactor;
  Canvas.DrawLine(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Top, ChartGridGrey, BorderWidth, False);
  Canvas.DrawLine(Bounds.Right, Bounds.Top, Bounds.Right, Bounds.Bottom, ChartGridGrey, BorderWidth, False);
  Canvas.DrawLine(Bounds.Right, Bounds.Bottom, Bounds.Left, Bounds.Bottom, ChartGridGrey, BorderWidth, False);
  Canvas.DrawLine(Bounds.Left, Bounds.Bottom, Bounds.Left, Bounds.Top, ChartGridGrey, BorderWidth, False);
end;

class procedure TChartTooltip.DrawLines(const Canvas: IChartCanvas; const Lines: TArray<string>;
                                        const TextStyle: TChartTextStyle; const Bounds: TRectF;
                                        const Padding, LineHeight: Single);
begin
  var LineY := Bounds.Top + Padding;
  for var Line in Lines do
  begin
    Canvas.DrawText(Bounds.Left + Padding, LineY, Line, TextStyle, TTextAlignH.Left, TTextAlignV.Top);
    LineY := LineY + LineHeight;
  end;
end;

end.
