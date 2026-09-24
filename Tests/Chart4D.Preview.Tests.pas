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
unit Chart4D.Preview.Tests;

/// <summary>
/// Tests for <c>TChartPreview</c>: the settings it carries over from the developer's own
/// plot, the sample data it picks per chart kind, and the fact that refilling replaces
/// the previous sample instead of adding to it.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4D.Plot,
  Chart4D.Tests.Asserts;

type
  [TestFixture]
  TChartPreviewTests = class
  private
    FSettings: TChartPlot;
    FPreview: TChartPlot;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure FillFrom_DefaultPlot_AddsOneCategorySeries;

    [Test]
    procedure FillFrom_GroupedBar_AddsTwoSeries;

    [Test]
    procedure FillFrom_Scatter_GivesTheSeriesXValues;

    [Test]
    procedure FillFrom_Range_GivesTheSeriesEndValues;

    [Test]
    procedure FillFrom_TextSettings_AreCopiedToThePreview;

    [Test]
    procedure FillFrom_LayoutSettings_AreCopiedToThePreview;

    [Test]
    procedure FillFrom_CalledTwice_KeepsTheSeriesCount;
  end;

implementation

uses
  Chart4D.Types,
  Chart4D.Preview;

procedure TChartPreviewTests.Setup;
begin
  FSettings := TChartPlot.Create;
  FPreview := TChartPlot.Create;
end;

procedure TChartPreviewTests.TearDown;
begin
  FPreview.Free;
  FSettings.Free;
end;

procedure TChartPreviewTests.FillFrom_DefaultPlot_AddsOneCategorySeries;
begin
  TChartPreview.FillFrom(FSettings, FPreview);

  Assert.AreEqual(1, FPreview.Series.Count);
  Assert.IsTrue(Length(FPreview.Categories) > 0, 'a category chart needs category labels');

  const HasAValuePerCategory = (Length(FPreview.Series[0].Values) = Length(FPreview.Categories));
  Assert.IsTrue(HasAValuePerCategory, 'every category needs a value');
end;

procedure TChartPreviewTests.FillFrom_GroupedBar_AddsTwoSeries;
begin
  FSettings.Kind := TChartKind.GroupedBar;

  TChartPreview.FillFrom(FSettings, FPreview);

  Assert.AreEqual(2, FPreview.Series.Count, 'a grouped bar chart only shows its point with two series');
end;

procedure TChartPreviewTests.FillFrom_Scatter_GivesTheSeriesXValues;
begin
  FSettings.Kind := TChartKind.Scatter;

  TChartPreview.FillFrom(FSettings, FPreview);

  const Series = FPreview.Series[0];
  const HasAnXValuePerValue = (Length(Series.XValues) = Length(Series.Values));
  Assert.IsTrue(HasAnXValuePerValue, 'a scatter series needs an X value per Y value');
end;

procedure TChartPreviewTests.FillFrom_Range_GivesTheSeriesEndValues;
begin
  FSettings.Kind := TChartKind.Range;

  TChartPreview.FillFrom(FSettings, FPreview);

  const Series = FPreview.Series[0];
  const HasBothEnds = (Length(Series.EndValues) = Length(Series.Values));
  Assert.IsTrue(HasBothEnds, 'a range series needs both ends of every span');
end;

procedure TChartPreviewTests.FillFrom_TextSettings_AreCopiedToThePreview;
begin
  FSettings.Title := 'Almost everyone is online';
  FSettings.Subtitle := 'Share of the population using the internet';
  FSettings.Source := 'Source: World Bank';
  FSettings.DonutCenterText := '91%';

  TChartPreview.FillFrom(FSettings, FPreview);

  Assert.AreEqual(FSettings.Title, FPreview.Title);
  Assert.AreEqual(FSettings.Subtitle, FPreview.Subtitle);
  Assert.AreEqual(FSettings.Source, FPreview.Source);
  Assert.AreEqual(FSettings.DonutCenterText, FPreview.DonutCenterText);
end;

procedure TChartPreviewTests.FillFrom_LayoutSettings_AreCopiedToThePreview;
begin
  FSettings.Kind := TChartKind.Bar;
  FSettings.Orientation := TChartOrientation.Horizontal;
  FSettings.StackMode := TStackMode.Proportions;
  FSettings.LegendPosition := TLegendPosition.Bottom;
  FSettings.LegendReversed := True;
  FSettings.ValueLabels := TValueLabelMode.Extremes;
  FSettings.SegmentLabels := TSegmentLabelMode.Percentage;
  FSettings.SegmentLabelDecimals := 1;

  TChartPreview.FillFrom(FSettings, FPreview);

  Assert.AreEqual<TChartKind>(TChartKind.Bar, FPreview.Kind);
  Assert.AreEqual<TChartOrientation>(TChartOrientation.Horizontal, FPreview.Orientation);
  Assert.AreEqual<TStackMode>(TStackMode.Proportions, FPreview.StackMode);
  Assert.AreEqual<TLegendPosition>(TLegendPosition.Bottom, FPreview.LegendPosition);
  Assert.IsTrue(FPreview.LegendReversed);
  Assert.AreEqual<TValueLabelMode>(TValueLabelMode.Extremes, FPreview.ValueLabels);
  Assert.AreEqual<TSegmentLabelMode>(TSegmentLabelMode.Percentage, FPreview.SegmentLabels);
  Assert.AreEqual(1, FPreview.SegmentLabelDecimals);
end;

procedure TChartPreviewTests.FillFrom_CalledTwice_KeepsTheSeriesCount;
begin
  TChartPreview.FillFrom(FSettings, FPreview);
  const CountAfterFirstFill = FPreview.Series.Count;

  TChartPreview.FillFrom(FSettings, FPreview);

  Assert.AreEqual(CountAfterFirstFill, FPreview.Series.Count,
                  'refilling replaces the sample instead of adding to it');
end;

end.
