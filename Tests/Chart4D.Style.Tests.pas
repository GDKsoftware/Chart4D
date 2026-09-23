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
unit Chart4D.Style.Tests;

/// <summary>
/// Tests for <c>TChartStyle.Default</c>: every editorial style value from SPEC.md
/// section 3.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4D.Style;

type
  [TestFixture]
  TChartStyleDefaultTests = class
  private
    FStyle: TChartStyle;

  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Default_FontName_IsArialOnWindows;

    [Test]
    procedure Default_TitleFontSizeAndColor_MatchEditorialStyle;

    [Test]
    procedure Default_SubtitleFontSizeAndColor_MatchEditorialStyle;

    [Test]
    procedure Default_LegendFontSizeAndColor_MatchEditorialStyle;

    [Test]
    procedure Default_AxisFontSizeAndColor_MatchEditorialStyle;

    [Test]
    procedure Default_CaptionFontSizeAndMutedColor_MatchEditorialStyle;

    [Test]
    procedure Default_GridColorAndWidth_MatchEditorialStyle;

    [Test]
    procedure Default_BaselineColorAndWidth_MatchEditorialStyle;

    [Test]
    procedure Default_BackgroundColor_IsWhite;

    [Test]
    procedure Default_SeriesLineWidth_IsThree;

    [Test]
    procedure Default_ShowGridlinesAndBaseline_AreEnabled;

    [Test]
    procedure Default_ScaleFactor_IsOne;

    [Test]
    procedure Default_ScatterAndBubbleRadii_MatchEditorialStyle;

    [Test]
    procedure Default_DonutInnerRadiusFactor_IsPointSix;

    [Test]
    procedure Default_LabelBackgroundColor_IsOpaqueWhite;
  end;

  [TestFixture]
  TChartColorsTests = class
  public
    [Test]
    procedure Blend_OpaqueOver_ReturnsOver;

    [Test]
    procedure Blend_FullyTransparentOver_ReturnsUnder;

    [Test]
    procedure Blend_HalfTransparentWhiteOverBlack_ReturnsMidGrey;

    [Test]
    procedure ContrastRatio_BlackAgainstWhite_IsTwentyOne;

    [Test]
    procedure ContrastRatio_SwappedArguments_IsTheSame;

    [Test]
    procedure ReadableTextColor_DarkBackground_ReturnsWhite;

    [Test]
    procedure ReadableTextColor_LightBackground_KeepsThePreferredColor;
  end;

implementation

uses
  System.UITypes;

procedure TChartStyleDefaultTests.Setup;
begin
  FStyle := TChartStyle.Default;
end;

procedure TChartStyleDefaultTests.Default_FontName_IsArialOnWindows;
begin
  Assert.AreEqual('Arial', FStyle.FontName);
end;

procedure TChartStyleDefaultTests.Default_TitleFontSizeAndColor_MatchEditorialStyle;
begin
  Assert.AreEqual<Single>(28, FStyle.TitleFontSize);
  Assert.AreEqual<TAlphaColor>(ChartTextDark, FStyle.TitleColor);
end;

procedure TChartStyleDefaultTests.Default_SubtitleFontSizeAndColor_MatchEditorialStyle;
begin
  Assert.AreEqual<Single>(22, FStyle.SubtitleFontSize);
  Assert.AreEqual<TAlphaColor>(ChartTextDark, FStyle.TextColor);
end;

procedure TChartStyleDefaultTests.Default_LegendFontSizeAndColor_MatchEditorialStyle;
begin
  Assert.AreEqual<Single>(18, FStyle.LegendFontSize);
  Assert.AreEqual<TAlphaColor>(ChartTextDark, FStyle.TextColor);
end;

procedure TChartStyleDefaultTests.Default_AxisFontSizeAndColor_MatchEditorialStyle;
begin
  Assert.AreEqual<Single>(18, FStyle.AxisFontSize);
  Assert.AreEqual<TAlphaColor>(ChartTextDark, FStyle.TextColor);
end;

procedure TChartStyleDefaultTests.Default_CaptionFontSizeAndMutedColor_MatchEditorialStyle;
begin
  Assert.AreEqual<Single>(16, FStyle.CaptionFontSize);
  Assert.AreEqual<TAlphaColor>(ChartTextMuted, FStyle.MutedTextColor);
end;

procedure TChartStyleDefaultTests.Default_GridColorAndWidth_MatchEditorialStyle;
begin
  Assert.AreEqual<TAlphaColor>(ChartGridGrey, FStyle.GridColor);
  Assert.AreEqual<Single>(1, FStyle.GridLineWidth);
end;

procedure TChartStyleDefaultTests.Default_BaselineColorAndWidth_MatchEditorialStyle;
begin
  Assert.AreEqual<TAlphaColor>(ChartBaselineGrey, FStyle.BaselineColor);
  Assert.AreEqual<Single>(2, FStyle.BaselineWidth);
end;

procedure TChartStyleDefaultTests.Default_BackgroundColor_IsWhite;
begin
  Assert.AreEqual<TAlphaColor>(TAlphaColor($FFFFFFFF), FStyle.BackgroundColor);
end;

procedure TChartStyleDefaultTests.Default_SeriesLineWidth_IsThree;
begin
  Assert.AreEqual<Single>(3, FStyle.SeriesLineWidth);
end;

procedure TChartStyleDefaultTests.Default_ShowGridlinesAndBaseline_AreEnabled;
begin
  Assert.IsTrue(FStyle.ShowGridlines);
  Assert.IsTrue(FStyle.ShowBaseline);
end;

procedure TChartStyleDefaultTests.Default_ScaleFactor_IsOne;
begin
  Assert.AreEqual<Single>(1.0, FStyle.ScaleFactor);
end;

procedure TChartStyleDefaultTests.Default_ScatterAndBubbleRadii_MatchEditorialStyle;
begin
  Assert.AreEqual<Single>(4, FStyle.ScatterPointRadius);
  Assert.AreEqual<Single>(4, FStyle.MinBubbleRadius);
  Assert.AreEqual<Single>(24, FStyle.MaxBubbleRadius);
end;

procedure TChartStyleDefaultTests.Default_DonutInnerRadiusFactor_IsPointSix;
begin
  Assert.AreEqual<Single>(0.6, FStyle.DonutInnerRadiusFactor);
end;

procedure TChartStyleDefaultTests.Default_LabelBackgroundColor_IsOpaqueWhite;
begin
  Assert.AreEqual<TAlphaColor>(ChartLabelBackground, FStyle.LabelBackgroundColor,
    'Labels must keep the opaque white box they always had until a caller changes it');
end;

procedure TChartColorsTests.Blend_OpaqueOver_ReturnsOver;
begin
  Assert.AreEqual<TAlphaColor>(ChartOrange, TChartColors.Blend(ChartOrange, ChartBlue));
end;

procedure TChartColorsTests.Blend_FullyTransparentOver_ReturnsUnder;
begin
  Assert.AreEqual<TAlphaColor>(ChartBlue, TChartColors.Blend(TAlphaColors.Null, ChartBlue));
end;

procedure TChartColorsTests.Blend_HalfTransparentWhiteOverBlack_ReturnsMidGrey;
begin
  const HalfWhite = TAlphaColor($80FFFFFF);

  const Blended = TChartColors.Blend(HalfWhite, TAlphaColors.Black);

  Assert.AreEqual<TAlphaColor>(TAlphaColor($FF808080), Blended,
    'Half-transparent white over opaque black is an opaque mid grey');
end;

procedure TChartColorsTests.ContrastRatio_BlackAgainstWhite_IsTwentyOne;
begin
  Assert.AreEqual(21.0, TChartColors.ContrastRatio(TAlphaColors.Black, TAlphaColors.White), 0.0001);
end;

procedure TChartColorsTests.ContrastRatio_SwappedArguments_IsTheSame;
begin
  const Forward = TChartColors.ContrastRatio(ChartBlue, ChartOrange);
  const Backward = TChartColors.ContrastRatio(ChartOrange, ChartBlue);

  Assert.AreEqual(Forward, Backward, 0.0001);
end;

procedure TChartColorsTests.ReadableTextColor_DarkBackground_ReturnsWhite;
begin
  { Dark red: white contrasts about 8.9 to 1, the default dark text only about 1.8. }
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White, TChartColors.ReadableTextColor(ChartTextDark, ChartDarkRed));
end;

procedure TChartColorsTests.ReadableTextColor_LightBackground_KeepsThePreferredColor;
begin
  { Orange: the default dark text contrasts about 8.3 to 1, white only about 1.9. }
  Assert.AreEqual<TAlphaColor>(ChartTextDark, TChartColors.ReadableTextColor(ChartTextDark, ChartOrange));
end;

end.
