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
unit Chart4D.Plot.Tests;

/// <summary>
/// Tests for <c>TChartPlot</c>: automatic palette cycling via <c>SeriesColor</c>,
/// owned series lifecycle, <c>OnChanged</c> notification, and guard exceptions.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4D.Plot;

type
  [TestFixture]
  TChartPlotSeriesColorTests = class
  private
    FPlot: TChartPlot;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SeriesColor_NoCustomColor_ReturnsPaletteColorByIndex;

    [Test]
    procedure SeriesColor_IndexBeyondPaletteLength_WrapsAroundPalette;

    [Test]
    procedure SeriesColor_SeriesHasCustomColor_ReturnsCustomColor;

    [Test]
    procedure SeriesColor_HighlightedSeriesIndexDefault_IsMinusOne;

    [Test]
    procedure SeriesColor_HighlightedSeriesIndexSet_ReturnsHighlightColorAndGreysOthers;

    [Test]
    procedure SeriesColor_HighlightedSeriesIndexOutOfRange_BehavesLikeDefault;

    [Test]
    procedure SeriesColor_NegativeIndex_RaisesGuardException;

    [Test]
    procedure SeriesColor_IndexBeyondSeriesCount_RaisesGuardException;

    [Test]
    procedure CategoryColor_NoOverride_ReturnsPaletteColorByIndex;

    [Test]
    procedure CategoryColor_IndexBeyondPaletteLength_WrapsAroundPalette;

    [Test]
    procedure CategoryColor_NegativeIndex_RaisesGuardException;
  end;

  [TestFixture]
  TChartPlotLifecycleTests = class
  private
    FPlot: TChartPlot;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure AddSeries_Name_AddsOwnedSeriesToSeriesList;

    [Test]
    procedure AddSeries_NameAndValues_SetsSeriesValues;

    [Test]
    procedure AddLineSeries_XAndYValues_SetsBothArrays;

    [Test]
    procedure AddSeries_Name_DefaultsIsRangeBandToFalse;

    [Test]
    procedure AddSeries_Name_DefaultsSizesToEmpty;

    [Test]
    procedure AddRangeBandSeries_Called_AppendsSeriesWithoutClearingExisting;

    [Test]
    procedure AddRangeBandSeries_Called_SetsValuesEndValuesAndIsRangeBand;

    [Test]
    procedure AddDumbbellSeries_ReplacesExistingSeriesWithOne;

    [Test]
    procedure AddDumbbellSeries_SetsKindDumbbellAndOrientationHorizontal;

    [Test]
    procedure AddRangeSeries_ReplacesExistingSeriesWithOneNamedSeries;

    [Test]
    procedure AddRangeSeries_SetsKindRangeAndOrientationHorizontal;

    [Test]
    procedure AddArrowSeries_ReplacesExistingSeriesWithOneNamedSeries;

    [Test]
    procedure AddArrowSeries_SetsKindArrowAndOrientationHorizontal;

    [Test]
    procedure ClearSeries_WithExistingSeries_EmptiesSeriesList;

    [Test]
    procedure DonutCenterText_Default_IsEmpty;
  end;

  [TestFixture]
  TChartPlotOnChangedTests = class
  private
    FPlot: TChartPlot;
    FChangedCount: Integer;
    FValueCountWhenChanged: Integer;

    procedure HandleChanged(Sender: TObject);
    procedure HandleChangedCapturingValueCount(Sender: TObject);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure AddSeries_Called_FiresOnChangedOnce;

    [Test]
    procedure AddSeriesWithValues_SetsValuesBeforeFiringOnChanged;

    [Test]
    procedure SetTitle_Called_FiresOnChanged;

    [Test]
    procedure ClearAnnotations_Called_FiresOnChanged;

    [Test]
    procedure SetHighlightedSeriesIndex_Called_FiresOnChanged;

    [Test]
    procedure SetValueLabels_Called_FiresOnChanged;

    [Test]
    procedure SetDonutCenterText_Called_FiresOnChanged;
  end;

  [TestFixture]
  TChartPlotGuardTests = class
  private
    FPlot: TChartPlot;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SetHistogramData_ZeroBinWidth_RaisesGuardException;

    [Test]
    procedure SetHistogramData_NegativeBinWidth_RaisesGuardException;

    [Test]
    procedure SetHistogramData_EmptyValues_RaisesGuardException;
  end;

implementation

uses
  System.SysUtils,
  System.UITypes,
  Chart4D.Style,
  Chart4D.Types;

procedure TChartPlotSeriesColorTests.Setup;
begin
  FPlot := TChartPlot.Create;
end;

procedure TChartPlotSeriesColorTests.TearDown;
begin
  FPlot.Free;
end;

procedure TChartPlotSeriesColorTests.SeriesColor_NoCustomColor_ReturnsPaletteColorByIndex;
begin
  FPlot.AddSeries('A');
  FPlot.AddSeries('B');

  const FirstColor = FPlot.SeriesColor(0);
  const SecondColor = FPlot.SeriesColor(1);

  Assert.AreEqual<TAlphaColor>(DefaultPalette[0], FirstColor);
  Assert.AreEqual<TAlphaColor>(DefaultPalette[1], SecondColor);
end;

procedure TChartPlotSeriesColorTests.SeriesColor_IndexBeyondPaletteLength_WrapsAroundPalette;
begin
  for var Index := 0 to 7 do
  begin
    FPlot.AddSeries(Format('Series%d', [Index]));
  end;

  const WrappedColor = FPlot.SeriesColor(6);
  const WrappedColorPlusOne = FPlot.SeriesColor(7);

  Assert.AreEqual<TAlphaColor>(DefaultPalette[0], WrappedColor);
  Assert.AreEqual<TAlphaColor>(DefaultPalette[1], WrappedColorPlusOne);
end;

procedure TChartPlotSeriesColorTests.SeriesColor_SeriesHasCustomColor_ReturnsCustomColor;
begin
  const CustomSeries = FPlot.AddSeries('Custom');
  CustomSeries.Color := TAlphaColor($FF123456);

  const Actual = FPlot.SeriesColor(0);

  Assert.AreEqual<TAlphaColor>(TAlphaColor($FF123456), Actual);
end;

procedure TChartPlotSeriesColorTests.SeriesColor_HighlightedSeriesIndexDefault_IsMinusOne;
begin
  Assert.AreEqual(-1, FPlot.HighlightedSeriesIndex);
end;

procedure TChartPlotSeriesColorTests.SeriesColor_HighlightedSeriesIndexSet_ReturnsHighlightColorAndGreysOthers;
begin
  FPlot.AddSeries('A');
  FPlot.AddSeries('B');
  FPlot.AddSeries('C');
  FPlot.HighlightedSeriesIndex := 1;

  Assert.AreEqual<TAlphaColor>(ChartLightGrey, FPlot.SeriesColor(0));
  Assert.AreEqual<TAlphaColor>(DefaultPalette[1], FPlot.SeriesColor(1));
  Assert.AreEqual<TAlphaColor>(ChartLightGrey, FPlot.SeriesColor(2));
end;

procedure TChartPlotSeriesColorTests.SeriesColor_HighlightedSeriesIndexOutOfRange_BehavesLikeDefault;
begin
  FPlot.AddSeries('A');
  FPlot.AddSeries('B');
  FPlot.HighlightedSeriesIndex := 5;

  Assert.AreEqual<TAlphaColor>(DefaultPalette[0], FPlot.SeriesColor(0));
  Assert.AreEqual<TAlphaColor>(DefaultPalette[1], FPlot.SeriesColor(1));
end;

procedure TChartPlotSeriesColorTests.SeriesColor_NegativeIndex_RaisesGuardException;
begin
  FPlot.AddSeries('A');

  Assert.WillRaise(
    procedure
    begin
      FPlot.SeriesColor(-1);
    end,
    EChart4DException,
    'SeriesColor must raise EChart4DException for a negative index');
end;

procedure TChartPlotSeriesColorTests.SeriesColor_IndexBeyondSeriesCount_RaisesGuardException;
begin
  FPlot.AddSeries('A');

  Assert.WillRaise(
    procedure
    begin
      FPlot.SeriesColor(1);
    end,
    EChart4DException,
    'SeriesColor must raise EChart4DException for an index beyond the series count');
end;

procedure TChartPlotSeriesColorTests.CategoryColor_NoOverride_ReturnsPaletteColorByIndex;
begin
  Assert.AreEqual<TAlphaColor>(DefaultPalette[0], FPlot.CategoryColor(0));
  Assert.AreEqual<TAlphaColor>(DefaultPalette[1], FPlot.CategoryColor(1));
end;

procedure TChartPlotSeriesColorTests.CategoryColor_IndexBeyondPaletteLength_WrapsAroundPalette;
begin
  Assert.AreEqual<TAlphaColor>(DefaultPalette[0], FPlot.CategoryColor(6));
  Assert.AreEqual<TAlphaColor>(DefaultPalette[1], FPlot.CategoryColor(7));
end;

procedure TChartPlotSeriesColorTests.CategoryColor_NegativeIndex_RaisesGuardException;
begin
  Assert.WillRaise(
    procedure
    begin
      FPlot.CategoryColor(-1);
    end,
    EChart4DException,
    'CategoryColor must raise EChart4DException for a negative index');
end;

procedure TChartPlotLifecycleTests.Setup;
begin
  FPlot := TChartPlot.Create;
end;

procedure TChartPlotLifecycleTests.TearDown;
begin
  FPlot.Free;
end;

procedure TChartPlotLifecycleTests.AddSeries_Name_AddsOwnedSeriesToSeriesList;
begin
  FPlot.AddSeries('Revenue');

  Assert.AreEqual(1, FPlot.Series.Count);
  Assert.AreEqual('Revenue', FPlot.Series[0].Name);
end;

procedure TChartPlotLifecycleTests.AddSeries_NameAndValues_SetsSeriesValues;
begin
  const AddedSeries = FPlot.AddSeries('Revenue', [10, 20, 30]);

  Assert.AreEqual<TArray<Double>>([10, 20, 30], AddedSeries.Values);
end;

procedure TChartPlotLifecycleTests.AddLineSeries_XAndYValues_SetsBothArrays;
begin
  const AddedSeries = FPlot.AddLineSeries('Netherlands', [1952, 1972], [72.1, 73.2]);

  Assert.AreEqual<TArray<Double>>([1952, 1972], AddedSeries.XValues);
  Assert.AreEqual<TArray<Double>>([72.1, 73.2], AddedSeries.Values);
end;

procedure TChartPlotLifecycleTests.AddSeries_Name_DefaultsIsRangeBandToFalse;
begin
  const AddedSeries = FPlot.AddSeries('Revenue');

  Assert.IsFalse(AddedSeries.IsRangeBand);
end;

procedure TChartPlotLifecycleTests.AddSeries_Name_DefaultsSizesToEmpty;
begin
  const AddedSeries = FPlot.AddSeries('Revenue');

  Assert.AreEqual<Integer>(0, Length(AddedSeries.Sizes));
end;

procedure TChartPlotLifecycleTests.AddRangeBandSeries_Called_AppendsSeriesWithoutClearingExisting;
begin
  FPlot.AddSeries('Existing');

  FPlot.AddRangeBandSeries('Range', [1, 2], [10, 20], [15, 25]);

  Assert.AreEqual(2, FPlot.Series.Count);
  Assert.AreEqual('Existing', FPlot.Series[0].Name);
  Assert.AreEqual('Range', FPlot.Series[1].Name);
end;

procedure TChartPlotLifecycleTests.AddRangeBandSeries_Called_SetsValuesEndValuesAndIsRangeBand;
begin
  const AddedSeries = FPlot.AddRangeBandSeries('Range', [1, 2], [10, 20], [15, 25]);

  Assert.AreEqual<TArray<Double>>([1, 2], AddedSeries.XValues);
  Assert.AreEqual<TArray<Double>>([10, 20], AddedSeries.Values);
  Assert.AreEqual<TArray<Double>>([15, 25], AddedSeries.EndValues);
  Assert.IsTrue(AddedSeries.IsRangeBand);
end;

procedure TChartPlotLifecycleTests.AddDumbbellSeries_ReplacesExistingSeriesWithOne;
begin
  FPlot.AddSeries('Existing');

  FPlot.AddDumbbellSeries([10, 20], [25, 22]);

  Assert.AreEqual(1, FPlot.Series.Count);
  Assert.AreEqual<TArray<Double>>([10, 20], FPlot.Series[0].Values);
  Assert.AreEqual<TArray<Double>>([25, 22], FPlot.Series[0].EndValues);
end;

procedure TChartPlotLifecycleTests.AddDumbbellSeries_SetsKindDumbbellAndOrientationHorizontal;
begin
  FPlot.AddDumbbellSeries([10, 20], [25, 22]);

  Assert.AreEqual<TChartKind>(TChartKind.Dumbbell, FPlot.Kind);
  Assert.AreEqual<TChartOrientation>(TChartOrientation.Horizontal, FPlot.Orientation);
end;

procedure TChartPlotLifecycleTests.AddRangeSeries_ReplacesExistingSeriesWithOneNamedSeries;
begin
  FPlot.AddSeries('Existing');

  FPlot.AddRangeSeries('Population', [10, 20], [25, 22]);

  Assert.AreEqual(1, FPlot.Series.Count);
  Assert.AreEqual('Population', FPlot.Series[0].Name);
  Assert.AreEqual<TArray<Double>>([10, 20], FPlot.Series[0].Values);
  Assert.AreEqual<TArray<Double>>([25, 22], FPlot.Series[0].EndValues);
end;

procedure TChartPlotLifecycleTests.AddRangeSeries_SetsKindRangeAndOrientationHorizontal;
begin
  FPlot.AddRangeSeries('Population', [10, 20], [25, 22]);

  Assert.AreEqual<TChartKind>(TChartKind.Range, FPlot.Kind);
  Assert.AreEqual<TChartOrientation>(TChartOrientation.Horizontal, FPlot.Orientation);
end;

procedure TChartPlotLifecycleTests.AddArrowSeries_ReplacesExistingSeriesWithOneNamedSeries;
begin
  FPlot.AddSeries('Existing');

  FPlot.AddArrowSeries('Change', [10, 20], [25, 22]);

  Assert.AreEqual(1, FPlot.Series.Count);
  Assert.AreEqual('Change', FPlot.Series[0].Name);
  Assert.AreEqual<TArray<Double>>([10, 20], FPlot.Series[0].Values);
  Assert.AreEqual<TArray<Double>>([25, 22], FPlot.Series[0].EndValues);
end;

procedure TChartPlotLifecycleTests.AddArrowSeries_SetsKindArrowAndOrientationHorizontal;
begin
  FPlot.AddArrowSeries('Change', [10, 20], [25, 22]);

  Assert.AreEqual<TChartKind>(TChartKind.Arrow, FPlot.Kind);
  Assert.AreEqual<TChartOrientation>(TChartOrientation.Horizontal, FPlot.Orientation);
end;

procedure TChartPlotLifecycleTests.ClearSeries_WithExistingSeries_EmptiesSeriesList;
begin
  FPlot.AddSeries('A');
  FPlot.AddSeries('B');

  FPlot.ClearSeries;

  Assert.AreEqual(0, FPlot.Series.Count);
end;

procedure TChartPlotLifecycleTests.DonutCenterText_Default_IsEmpty;
begin
  Assert.AreEqual('', FPlot.DonutCenterText);
end;

procedure TChartPlotOnChangedTests.Setup;
begin
  FPlot := TChartPlot.Create;
  FChangedCount := 0;
  FValueCountWhenChanged := 0;
  FPlot.OnChanged := HandleChanged;
end;

procedure TChartPlotOnChangedTests.TearDown;
begin
  FPlot.Free;
end;

procedure TChartPlotOnChangedTests.HandleChanged(Sender: TObject);
begin
  Inc(FChangedCount);
end;

procedure TChartPlotOnChangedTests.HandleChangedCapturingValueCount(Sender: TObject);
begin
  FValueCountWhenChanged := Length(FPlot.Series[FPlot.Series.Count - 1].Values);
end;

procedure TChartPlotOnChangedTests.AddSeries_Called_FiresOnChangedOnce;
begin
  FPlot.AddSeries('Revenue');

  Assert.AreEqual(1, FChangedCount);
end;

procedure TChartPlotOnChangedTests.AddSeriesWithValues_SetsValuesBeforeFiringOnChanged;
begin
  FPlot.OnChanged := HandleChangedCapturingValueCount;

  FPlot.AddSeries('Revenue', [10, 20, 30]);

  Assert.AreEqual(3, FValueCountWhenChanged);
end;

procedure TChartPlotOnChangedTests.SetTitle_Called_FiresOnChanged;
begin
  FPlot.Title := 'Life expectancy';

  Assert.AreEqual(1, FChangedCount);
end;

procedure TChartPlotOnChangedTests.ClearAnnotations_Called_FiresOnChanged;
begin
  FPlot.AddHorizontalLine(0, TAlphaColor($FF000000));
  FChangedCount := 0;

  FPlot.ClearAnnotations;

  Assert.AreEqual(1, FChangedCount);
end;

procedure TChartPlotOnChangedTests.SetHighlightedSeriesIndex_Called_FiresOnChanged;
begin
  FPlot.HighlightedSeriesIndex := 0;

  Assert.AreEqual(1, FChangedCount);
end;

procedure TChartPlotOnChangedTests.SetValueLabels_Called_FiresOnChanged;
begin
  FPlot.ValueLabels := TValueLabelMode.All;

  Assert.AreEqual(1, FChangedCount);
end;

procedure TChartPlotOnChangedTests.SetDonutCenterText_Called_FiresOnChanged;
begin
  FPlot.DonutCenterText := 'Total: 1,234';

  Assert.AreEqual(1, FChangedCount);
end;

procedure TChartPlotGuardTests.Setup;
begin
  FPlot := TChartPlot.Create;
end;

procedure TChartPlotGuardTests.TearDown;
begin
  FPlot.Free;
end;

procedure TChartPlotGuardTests.SetHistogramData_ZeroBinWidth_RaisesGuardException;
begin
  Assert.WillRaise(
    procedure
    begin
      FPlot.SetHistogramData([1, 2, 3], 0);
    end,
    EChart4DException,
    'SetHistogramData must raise EChart4DException when BinWidth is 0');
end;

procedure TChartPlotGuardTests.SetHistogramData_NegativeBinWidth_RaisesGuardException;
begin
  Assert.WillRaise(
    procedure
    begin
      FPlot.SetHistogramData([1, 2, 3], -1);
    end,
    EChart4DException,
    'SetHistogramData must raise EChart4DException when BinWidth is negative');
end;

procedure TChartPlotGuardTests.SetHistogramData_EmptyValues_RaisesGuardException;
begin
  Assert.WillRaise(
    procedure
    begin
      FPlot.SetHistogramData([], 2);
    end,
    EChart4DException,
    'SetHistogramData must raise EChart4DException when Values is empty');
end;

end.
