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
  Chart4D.Tests.Asserts,
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

    [Test]
    procedure Default_MinimumTextContrast_IsTheWcagMinimumForNormalText;

    [Test]
    procedure Default_Palette_IsEmpty;
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

    [Test]
    procedure ReadableTextColor_MinimumOne_NeverSwitches;

    [Test]
    procedure ReadableTextColor_MinimumThree_KeepsDarkTextOnBlueAndGreen;

    [Test]
    procedure ReadableTextColor_MinimumThree_TurnsWhiteOnDarkRed;

    [Test]
    procedure ReadableTextColor_MinimumFourPointFive_TurnsWhiteOnBlueAndGreen;

    [Test]
    procedure ReadableTextColor_DefaultMinimumWithDarkText_MatchesTheMoreLegibleOfTheTwo;

    [Test]
    procedure ReadableTextColor_DefaultMinimumWithBlackText_KeepsBlackWhereWhiteReadsBetter;

    [Test]
    procedure ReadableTextColor_DefaultMinimumWithLightText_KeepsItWhereWhiteReadsBetter;
  end;

implementation

uses
  System.SysUtils,
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

procedure TChartStyleDefaultTests.Default_MinimumTextContrast_IsTheWcagMinimumForNormalText;
begin
  Assert.AreEqual(4.5, FStyle.MinimumTextContrast, 0.0001);
end;

procedure TChartStyleDefaultTests.Default_Palette_IsEmpty;
begin
  Assert.AreEqual(0, Length(FStyle.Palette), 'An empty palette means DefaultPalette');
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

procedure TChartColorsTests.ReadableTextColor_MinimumOne_NeverSwitches;
begin
  { Every pair of colors contrasts at least 1 to 1, so a minimum of 1 keeps one text color
    throughout, even on black. }
  for var Background in [ChartBlue, ChartGreen, ChartOrange, ChartDarkRed, TAlphaColors.Black] do
  begin
    Assert.AreEqual<TAlphaColor>(ChartTextDark, TChartColors.ReadableTextColor(ChartTextDark, Background, 1),
      Format('A minimum of 1 must keep the dark text on %.8x', [Background]));
  end;
end;

procedure TChartColorsTests.ReadableTextColor_MinimumThree_KeepsDarkTextOnBlueAndGreen;
begin
  { White reads better on both, about 4.5 to 1, but the dark text still reaches about 3.5,
    which clears the WCAG minimum for large text. }
  Assert.AreEqual<TAlphaColor>(ChartTextDark, TChartColors.ReadableTextColor(ChartTextDark, ChartBlue, 3));
  Assert.AreEqual<TAlphaColor>(ChartTextDark, TChartColors.ReadableTextColor(ChartTextDark, ChartGreen, 3));
end;

procedure TChartColorsTests.ReadableTextColor_MinimumThree_TurnsWhiteOnDarkRed;
begin
  { The dark text reaches only about 1.8 to 1 on dark red, below any useful minimum. }
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White, TChartColors.ReadableTextColor(ChartTextDark, ChartDarkRed, 3));
end;

procedure TChartColorsTests.ReadableTextColor_MinimumFourPointFive_TurnsWhiteOnBlueAndGreen;
begin
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White, TChartColors.ReadableTextColor(ChartTextDark, ChartBlue, 4.5));
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White, TChartColors.ReadableTextColor(ChartTextDark, ChartGreen, 4.5));
  Assert.AreEqual<TAlphaColor>(ChartTextDark, TChartColors.ReadableTextColor(ChartTextDark, ChartOrange, 4.5),
    'The dark text reaches about 8.3 to 1 on orange, well above the minimum');
end;

procedure TChartColorsTests.ReadableTextColor_DefaultMinimumWithDarkText_MatchesTheMoreLegibleOfTheTwo;
begin
  { Keeping a text color at the minimum can only differ from taking the more legible of the
    two where that color and white both reach the minimum. For ChartTextDark at 4.5 that
    needs a background of relative luminance at least about 0.247 and at most about 0.183,
    so it never happens, and the default leaves every label exactly as the plain "more
    legible" rule drew it. Checked over every grey and an RGB grid in steps of 15. }
  var Backgrounds: TArray<TAlphaColor> := [];
  for var Level := 0 to 255 do
    Backgrounds := Backgrounds + [TAlphaColor($FF000000 or (Cardinal(Level) shl 16) or (Cardinal(Level) shl 8) or Cardinal(Level))];
  for var Red := 0 to 17 do
    for var Green := 0 to 17 do
      for var Blue := 0 to 17 do
        Backgrounds := Backgrounds + [TAlphaColor($FF000000 or (Cardinal(Red * 15) shl 16) or
                                                  (Cardinal(Green * 15) shl 8) or Cardinal(Blue * 15))];

  for var Background in Backgrounds do
  begin
    const AtDefault = TChartColors.ReadableTextColor(ChartTextDark, Background, TChartStyle.Default.MinimumTextContrast);
    const MoreLegible = TChartColors.ReadableTextColor(ChartTextDark, Background, MaximumContrastRatio);
    if AtDefault <> MoreLegible then
      Assert.Fail(Format('On %.8x the default minimum picked %.8x where the more legible color is %.8x',
                         [Background, AtDefault, MoreLegible]));
  end;
end;

procedure TChartColorsTests.ReadableTextColor_DefaultMinimumWithBlackText_KeepsBlackWhereWhiteReadsBetter;
begin
  { The limit of the equivalence above: pure black text is too dark for it. On a mid grey
    of luminance about 0.178, black reaches about 4.56 to 1 and white about 4.61, so both
    clear 4.5; the default keeps black where the more legible color would be white. }
  const MidGrey = TAlphaColor($FF757575);

  Assert.AreEqual<TAlphaColor>(TAlphaColors.Black, TChartColors.ReadableTextColor(TAlphaColors.Black, MidGrey, 4.5));
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White,
    TChartColors.ReadableTextColor(TAlphaColors.Black, MidGrey, MaximumContrastRatio));
end;

procedure TChartColorsTests.ReadableTextColor_DefaultMinimumWithLightText_KeepsItWhereWhiteReadsBetter;
begin
  { The other limit: a text color of luminance about 0.181 is light enough to reach 4.5 to 1
    against black, where white of course reads better still. }
  const LightGrey = TAlphaColor($FF767676);

  Assert.AreEqual<TAlphaColor>(LightGrey, TChartColors.ReadableTextColor(LightGrey, TAlphaColors.Black, 4.5));
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White,
    TChartColors.ReadableTextColor(LightGrey, TAlphaColors.Black, MaximumContrastRatio));
end;

end.
