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
unit Chart4D.Style;

/// <summary>
/// The visual style record and the default editorial palette used by Chart4D charts.
/// </summary>

interface

uses
  System.UITypes;

const
  /// <summary>Editorial palette blue, first color of <c>DefaultPalette</c>.</summary>
  ChartBlue = TAlphaColor($FF1380A1);
  /// <summary>Editorial palette orange, second color of <c>DefaultPalette</c>.</summary>
  ChartOrange = TAlphaColor($FFFAAB18);
  /// <summary>Editorial palette dark red, third color of <c>DefaultPalette</c>.</summary>
  ChartDarkRed = TAlphaColor($FF990000);
  /// <summary>Editorial palette green, fourth color of <c>DefaultPalette</c>.</summary>
  ChartGreen = TAlphaColor($FF588300);
  /// <summary>Default title/axis/legend text color.</summary>
  ChartTextDark = TAlphaColor($FF222222);
  /// <summary>Default muted text color, used for the footer source text.</summary>
  ChartTextMuted = TAlphaColor($FF555555);
  /// <summary>Default color of the zero-value baseline.</summary>
  ChartBaselineGrey = TAlphaColor($FF333333);
  /// <summary>Default gridline color.</summary>
  ChartGridGrey = TAlphaColor($FFCBCBCB);
  /// <summary>Editorial palette light grey, sixth color of <c>DefaultPalette</c>.</summary>
  ChartLightGrey = TAlphaColor($FFDDDDDD);

  /// <summary>
  /// The opaque white drawn behind text that sits on top of chart ink: the default of
  /// <c>TChartStyle.LabelBackgroundColor</c>, which value labels, <c>TextLabel</c>
  /// annotations and pie and donut segment labels use, and the fixed color of the hover
  /// tooltip box. Deliberately not <c>TChartStyle.BackgroundColor</c>, even though the
  /// default style happens to use the same value: such text has to stay legible against
  /// whatever is directly behind it, so a caller who repaints the chart background a
  /// different color must not have every label go transparent along with it.
  /// </summary>
  ChartLabelBackground = TAlphaColor($FFFFFFFF);

  /// <summary>
  /// The highest WCAG contrast ratio there is, black against white. As a minimum text
  /// contrast it is never reached by anything but that pair, so text simply takes
  /// whichever candidate color reads better.
  /// </summary>
  MaximumContrastRatio = 21.0;

  /// <summary>
  /// The default series color palette. <c>TChartPlot.SeriesColor</c> cycles through it
  /// when a series does not set its own <c>Color</c>.
  /// </summary>
  DefaultPalette: array[0..5] of TAlphaColor =
    (ChartBlue, ChartOrange, ChartDarkRed, ChartGreen, ChartBaselineGrey, ChartLightGrey);

type
  /// <summary>
  /// The visual style applied when rendering a chart: fonts, sizes, and colors. Sizes
  /// are pixels at the 640x450 reference size, multiplied by <c>ScaleFactor</c> when
  /// rendering.
  /// </summary>
  TChartStyle = record
    /// <summary>The font family name used for all chart text.</summary>
    FontName: string;
    /// <summary>The title font size in pixels at the reference size.</summary>
    TitleFontSize: Single;
    /// <summary>The subtitle font size in pixels at the reference size.</summary>
    SubtitleFontSize: Single;
    /// <summary>The legend text font size in pixels at the reference size.</summary>
    LegendFontSize: Single;
    /// <summary>The axis label font size in pixels at the reference size.</summary>
    AxisFontSize: Single;
    /// <summary>The footer caption font size in pixels at the reference size.</summary>
    CaptionFontSize: Single;
    /// <summary>The title text color.</summary>
    TitleColor: TAlphaColor;
    /// <summary>The subtitle, legend, and axis text color.</summary>
    TextColor: TAlphaColor;
    /// <summary>The footer source text color.</summary>
    MutedTextColor: TAlphaColor;
    /// <summary>The chart background color.</summary>
    BackgroundColor: TAlphaColor;
    /// <summary>The value-axis gridline color.</summary>
    GridColor: TAlphaColor;
    /// <summary>The zero-value baseline color.</summary>
    BaselineColor: TAlphaColor;
    /// <summary>Whether gridlines are drawn on the value axis.</summary>
    ShowGridlines: Boolean;
    /// <summary>Whether the zero-value baseline is drawn.</summary>
    ShowBaseline: Boolean;
    /// <summary>The gridline stroke width in pixels at the reference size.</summary>
    GridLineWidth: Single;
    /// <summary>The baseline stroke width in pixels at the reference size.</summary>
    BaselineWidth: Single;
    /// <summary>The series line stroke width in pixels at the reference size.</summary>
    SeriesLineWidth: Single;
    /// <summary>The scale factor applied to every size when rendering.</summary>
    ScaleFactor: Single;
    /// <summary>
    /// The radius, in pixels at the reference size, of a <c>Scatter</c> or <c>DotPlot</c>
    /// point whose series has no per-point <c>Sizes</c> (a plain, non-bubble point).
    /// </summary>
    ScatterPointRadius: Single;
    /// <summary>
    /// The smallest radius, in pixels at the reference size, drawn for a bubble series
    /// point at the minimum of the plot-wide <c>Sizes</c> domain.
    /// </summary>
    MinBubbleRadius: Single;
    /// <summary>
    /// The largest radius, in pixels at the reference size, drawn for a bubble series
    /// point at the maximum of the plot-wide <c>Sizes</c> domain.
    /// </summary>
    MaxBubbleRadius: Single;
    /// <summary>
    /// The inner radius of a <c>Donut</c> wedge, as a fraction of its outer radius. A
    /// ratio, not a pixel size: not scaled by <c>ScaleFactor</c>.
    /// </summary>
    DonutInnerRadiusFactor: Single;
    /// <summary>
    /// The box drawn behind value labels, <c>TextLabel</c> annotations and pie and donut
    /// segment labels. Default <c>ChartLabelBackground</c>, opaque white. An alpha below
    /// 255 lets the ink behind show through, and an alpha of 0, such as
    /// <c>TAlphaColors.Null</c>, draws no box at all, while a label still keeps the room it
    /// would have taken so labels go on avoiding each other. The hover tooltip keeps
    /// <c>ChartLabelBackground</c> whatever this is.
    /// </summary>
    LabelBackgroundColor: TAlphaColor;
    /// <summary>
    /// The WCAG contrast ratio a pie or donut segment label's <c>TextColor</c> must reach
    /// against what is behind it before the label gives it up. At or above it the label
    /// keeps <c>TextColor</c>; below it the label takes whichever of <c>TextColor</c> and
    /// white reads better. Default 4.5, the WCAG AA minimum for normal text. 1 never
    /// switches, and so does 0, the value of a zeroed record; 3 is the WCAG minimum for
    /// large text; <c>MaximumContrastRatio</c> always takes the more legible of the two.
    /// </summary>
    MinimumTextContrast: Double;

    /// <summary>
    /// Returns the default editorial style described in the specification.
    /// </summary>
    class function Default: TChartStyle; static;
  end;

  /// <summary>
  /// The color arithmetic behind text that has to stay legible on colored ink:
  /// compositing one color over another, WCAG relative luminance and contrast ratio, and
  /// picking the more legible of two text colors on a background.
  /// </summary>
  TChartColors = record
    /// <summary>
    /// Returns <c>Over</c> composited on top of <c>Under</c> with the "over" operator,
    /// using each color's own alpha. An opaque <c>Over</c> returns itself, a fully
    /// transparent one returns <c>Under</c>.
    /// </summary>
    class function Blend(const Over, Under: TAlphaColor): TAlphaColor; static;
    /// <summary>
    /// The WCAG 2 relative luminance of <c>Color</c>'s red, green and blue, from 0 for
    /// black to 1 for white. Alpha is ignored.
    /// </summary>
    class function RelativeLuminance(const Color: TAlphaColor): Double; static;
    /// <summary>
    /// The WCAG 2 contrast ratio between two colors, from 1 for identical luminance to 21
    /// for black against white. Symmetric in its arguments.
    /// </summary>
    class function ContrastRatio(const First, Second: TAlphaColor): Double; static;
    /// <summary>
    /// Returns <c>Preferred</c> when its contrast ratio against <c>Background</c> reaches
    /// <c>MinimumContrast</c>. Otherwise returns whichever of <c>Preferred</c> and white
    /// contrasts more with <c>Background</c>, <c>Preferred</c> on a tie. The default,
    /// <c>MaximumContrastRatio</c>, therefore always returns the more legible of the two,
    /// and a minimum of 1 or less always returns <c>Preferred</c>.
    /// </summary>
    class function ReadableTextColor(const Preferred, Background: TAlphaColor;
                                     const MinimumContrast: Double = MaximumContrastRatio): TAlphaColor; static;
  end;

implementation

uses
  System.Math;

class function TChartStyle.Default: TChartStyle;
begin
  {$IFDEF MSWINDOWS}
  Result.FontName := 'Arial';
  {$ELSE}
  Result.FontName := 'Helvetica';
  {$ENDIF}
  Result.TitleFontSize := 28;
  Result.SubtitleFontSize := 22;
  Result.LegendFontSize := 18;
  Result.AxisFontSize := 18;
  Result.CaptionFontSize := 16;
  Result.TitleColor := ChartTextDark;
  Result.TextColor := ChartTextDark;
  Result.MutedTextColor := ChartTextMuted;
  Result.BackgroundColor := TAlphaColor($FFFFFFFF);
  Result.GridColor := ChartGridGrey;
  Result.BaselineColor := ChartBaselineGrey;
  Result.ShowGridlines := True;
  Result.ShowBaseline := True;
  Result.GridLineWidth := 1;
  Result.BaselineWidth := 2;
  Result.SeriesLineWidth := 3;
  Result.ScaleFactor := 1.0;
  Result.ScatterPointRadius := 4;
  Result.MinBubbleRadius := 4;
  Result.MaxBubbleRadius := 24;
  Result.DonutInnerRadiusFactor := 0.6;
  Result.LabelBackgroundColor := ChartLabelBackground;
  Result.MinimumTextContrast := 4.5;
end;

class function TChartColors.Blend(const Over, Under: TAlphaColor): TAlphaColor;
begin
  const Top = TAlphaColorRec(Over);
  const Bottom = TAlphaColorRec(Under);
  const TopAlpha: Double = Top.A / 255;
  const BottomAlpha: Double = Bottom.A / 255;

  const ResultAlpha = TopAlpha + BottomAlpha * (1 - TopAlpha);
  const IsFullyTransparent = (ResultAlpha <= 0);
  if IsFullyTransparent then
    Exit(TAlphaColors.Null);

  var Blended: TAlphaColorRec;
  Blended.A := Round(ResultAlpha * 255);
  Blended.R := Round((Top.R * TopAlpha + Bottom.R * BottomAlpha * (1 - TopAlpha)) / ResultAlpha);
  Blended.G := Round((Top.G * TopAlpha + Bottom.G * BottomAlpha * (1 - TopAlpha)) / ResultAlpha);
  Blended.B := Round((Top.B * TopAlpha + Bottom.B * BottomAlpha * (1 - TopAlpha)) / ResultAlpha);
  Result := Blended.Color;
end;

class function TChartColors.RelativeLuminance(const Color: TAlphaColor): Double;

  function LinearChannel(const Channel: Byte): Double;
  begin
    { The sRGB transfer curve, undone. The exponent is typed so Win64 cannot pick the
      Single overload of Power. }
    const GammaExponent: Double = 2.4;
    const Encoded: Double = Channel / 255;
    if Encoded <= 0.04045 then
      Result := Encoded / 12.92
    else
      Result := Power((Encoded + 0.055) / 1.055, GammaExponent);
  end;

begin
  const Channels = TAlphaColorRec(Color);
  Result := 0.2126 * LinearChannel(Channels.R) + 0.7152 * LinearChannel(Channels.G) +
            0.0722 * LinearChannel(Channels.B);
end;

class function TChartColors.ContrastRatio(const First, Second: TAlphaColor): Double;
begin
  const FirstLuminance = RelativeLuminance(First);
  const SecondLuminance = RelativeLuminance(Second);
  Result := (Max(FirstLuminance, SecondLuminance) + 0.05) / (Min(FirstLuminance, SecondLuminance) + 0.05);
end;

class function TChartColors.ReadableTextColor(const Preferred, Background: TAlphaColor;
                                              const MinimumContrast: Double): TAlphaColor;
begin
  const PreferredContrast = ContrastRatio(Preferred, Background);
  const PreferredIsReadable = (PreferredContrast >= MinimumContrast);
  if PreferredIsReadable then
    Exit(Preferred);

  const WhiteContrast = ContrastRatio(TAlphaColors.White, Background);
  if PreferredContrast >= WhiteContrast then
    Result := Preferred
  else
    Result := TAlphaColors.White;
end;

end.
