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
unit Chart4D.LegendLabels.Tests;

/// <summary>
/// Tests for what a legend entry shows: the name, the value, the share of the total, or a
/// combination, for series entries and for the category entries of a <c>Pie</c> or
/// <c>Donut</c>. See SPEC.md 4.32.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4D.Axis,
  Chart4D.Canvas.Interfaces,
  Chart4D.Tests.RecordingCanvas,
  Chart4D.Types;

type
  [TestFixture]
  TLegendLabelTests = class
  private
    FCanvas: IChartCanvas;
    FRecordingCanvas: TRecordingCanvas;

    procedure RenderStackedBar(const Mode: TLegendLabelMode; const Categories: TArray<string>;
                               const WindValues, SolarValues: TArray<Double>);
    procedure RenderPieThirds(const Mode: TLegendLabelMode; const LegendLabelDecimals: Integer;
                              const YAxis: TAxisOptions);
    function CountOfText(const Text: string): Integer;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Name', 'Name;Wind', ';')]
    [TestCase('Value', 'Value;30', ';')]
    [TestCase('Percentage', 'Percentage;30%', ';')]
    [TestCase('NameAndValue', 'NameAndValue;Wind (30)', ';')]
    [TestCase('ValueAndName', 'ValueAndName;30 Wind', ';')]
    [TestCase('NameAndPercentage', 'NameAndPercentage;Wind (30%)', ';')]
    [TestCase('PercentageAndName', 'PercentageAndName;30% Wind', ';')]
    [TestCase('NameValueAndPercentage', 'NameValueAndPercentage;Wind (30, 30%)', ';')]
    procedure LegendLabels_SingleBarStack_ShowsTheSeriesEntryInTheChosenForm(const Mode: TLegendLabelMode;
                                                                            const Expected: string);

    [Test]
    procedure LegendLabels_SeveralCategories_SumsTheValuesOfEachSeries;

    [Test]
    procedure LegendLabels_AllValuesZero_ShowsAZeroShare;

    [Test]
    procedure LegendLabels_Pie_ShowsEachCategoryWithItsShare;

    [Test]
    procedure LegendLabelDecimals_One_ShowsOneDecimal;

    [Test]
    procedure LegendLabelDecimals_DutchValueAxisLocale_UsesCommaDecimalSeparator;
  end;

implementation

uses
  Chart4D.Consts,
  Chart4D.Plot,
  Chart4D.Renderer;

const
  ChartWidth = 640;
  ChartHeight = 450;

procedure TLegendLabelTests.Setup;
begin
  FRecordingCanvas := TRecordingCanvas.Create;
  FCanvas := FRecordingCanvas;
end;

procedure TLegendLabelTests.TearDown;
begin
  FCanvas := nil;
  FRecordingCanvas := nil;
end;

/// <summary>
/// Renders a stacked bar chart with a "Wind" and a "Solar" series, so the legend carries
/// two entries, with the given legend label mode.
/// </summary>
procedure TLegendLabelTests.RenderStackedBar(const Mode: TLegendLabelMode; const Categories: TArray<string>;
                                             const WindValues, SolarValues: TArray<Double>);
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.StackedBar;
    Plot.Categories := Categories;
    Plot.AddSeries('Wind', WindValues);
    Plot.AddSeries('Solar', SolarValues);
    Plot.LegendLabels := Mode;

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight, HitMap);
  finally
    Plot.Free;
  end;
end;

/// <summary>
/// Renders a pie of three equal segments without segment labels, so any category name or
/// share in the output comes from the legend.
/// </summary>
procedure TLegendLabelTests.RenderPieThirds(const Mode: TLegendLabelMode; const LegendLabelDecimals: Integer;
                                            const YAxis: TAxisOptions);
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Share', [1, 1, 1]);
    Plot.SegmentLabels := TSegmentLabelMode.None;
    Plot.YAxis := YAxis;
    Plot.LegendLabels := Mode;
    Plot.LegendLabelDecimals := LegendLabelDecimals;

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight, HitMap);
  finally
    Plot.Free;
  end;
end;

function TLegendLabelTests.CountOfText(const Text: string): Integer;
begin
  Result := 0;
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    if Call.Text = Text then
      Inc(Result);
  end;
end;

procedure TLegendLabelTests.LegendLabels_SingleBarStack_ShowsTheSeriesEntryInTheChosenForm(
  const Mode: TLegendLabelMode; const Expected: string);
begin
  RenderStackedBar(Mode, ['2026'], [30], [70]);

  Assert.AreEqual(1, CountOfText(Expected), 'The Wind entry must read exactly as its mode says');
end;

procedure TLegendLabelTests.LegendLabels_SeveralCategories_SumsTheValuesOfEachSeries;
begin
  RenderStackedBar(TLegendLabelMode.NameValueAndPercentage, ['2025', '2026'], [10, 20], [30, 40]);

  Assert.AreEqual(1, CountOfText('Wind (30, 30%)'), 'A series entry takes the sum of its values');
  Assert.AreEqual(1, CountOfText('Solar (70, 70%)'), 'A series entry takes the sum of its values');
end;

procedure TLegendLabelTests.LegendLabels_AllValuesZero_ShowsAZeroShare;
begin
  RenderStackedBar(TLegendLabelMode.NameAndPercentage, ['2026'], [0], [0]);

  Assert.AreEqual(1, CountOfText('Wind (0%)'), 'A zero total must not divide by zero');
  Assert.AreEqual(1, CountOfText('Solar (0%)'), 'A zero total must not divide by zero');
end;

procedure TLegendLabelTests.LegendLabels_Pie_ShowsEachCategoryWithItsShare;
begin
  RenderPieThirds(TLegendLabelMode.NameAndPercentage, AutomaticDecimals, TAxisOptions.Default);

  Assert.AreEqual(1, CountOfText('A (33%)'));
  Assert.AreEqual(1, CountOfText('B (33%)'));
  Assert.AreEqual(1, CountOfText('C (33%)'));
end;

procedure TLegendLabelTests.LegendLabelDecimals_One_ShowsOneDecimal;
begin
  RenderPieThirds(TLegendLabelMode.Percentage, 1, TAxisOptions.Default);

  Assert.AreEqual(3, CountOfText('33.3%'));
end;

procedure TLegendLabelTests.LegendLabelDecimals_DutchValueAxisLocale_UsesCommaDecimalSeparator;
begin
  var YAxis := TAxisOptions.Default;
  YAxis.LocaleName := 'nl-NL';

  RenderPieThirds(TLegendLabelMode.Percentage, 1, YAxis);

  Assert.AreEqual(3, CountOfText('33,3%'));
end;

end.
