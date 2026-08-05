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

end.
