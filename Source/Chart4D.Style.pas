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
  /// The opaque white drawn behind text that sits on top of chart ink: value labels,
  /// <c>TextLabel</c> annotations, pie and donut segment labels, and the hover tooltip
  /// box. Deliberately a constant rather than <c>TChartStyle.BackgroundColor</c>, even
  /// though the default style happens to use the same value: such text has to stay
  /// legible against whatever is directly behind it, so a caller who repaints the chart
  /// background a different color must not have every label go transparent along with it.
  /// </summary>
  ChartLabelBackground = TAlphaColor($FFFFFFFF);

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
    /// Returns the default editorial style described in the specification.
    /// </summary>
    class function Default: TChartStyle; static;
  end;

implementation

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
end;

end.
