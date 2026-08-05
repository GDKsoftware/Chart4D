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
unit Chart4D.Histogram.Tests;

/// <summary>
/// Tests for <c>TChartPlot.SetHistogramData</c>: binning per SPEC.md section 4.7,
/// including empty middle bins and generated category labels.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4D.Plot;

type
  [TestFixture]
  THistogramBinningTests = class
  private
    FPlot: TChartPlot;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SetHistogramData_ValuesAcrossFiveBins_CountsEachBinCorrectly;

    [Test]
    procedure SetHistogramData_EmptyMiddleBin_GetsZeroCount;

    [Test]
    procedure SetHistogramData_CategoriesAreLowerBinBoundsFormatted;

    [Test]
    procedure SetHistogramData_SetsChartKindToHistogram;

    [Test]
    procedure SetHistogramData_ValueAtBinLowerBound_FallsIntoThatBin;

    [Test]
    procedure SetHistogramData_ReplacesExistingSeriesWithSingleCountSeries;
  end;

implementation

uses
  System.SysUtils,
  Chart4D.Types;

procedure THistogramBinningTests.Setup;
begin
  FPlot := TChartPlot.Create;
end;

procedure THistogramBinningTests.TearDown;
begin
  FPlot.Free;
end;

procedure THistogramBinningTests.SetHistogramData_ValuesAcrossFiveBins_CountsEachBinCorrectly;
begin
  FPlot.SetHistogramData([1, 2, 2, 3, 7, 8], 2);

  const CountSeries = FPlot.Series[0];

  Assert.AreEqual<TArray<Double>>([1, 3, 0, 1, 1], CountSeries.Values);
end;

procedure THistogramBinningTests.SetHistogramData_EmptyMiddleBin_GetsZeroCount;
begin
  FPlot.SetHistogramData([1, 2, 2, 3, 7, 8], 2);

  const CountSeries = FPlot.Series[0];

  Assert.AreEqual<Double>(0, CountSeries.Values[2]);
end;

procedure THistogramBinningTests.SetHistogramData_CategoriesAreLowerBinBoundsFormatted;
begin
  FPlot.SetHistogramData([1, 2, 2, 3, 7, 8], 2);

  const Expected: TArray<string> = ['0', '2', '4', '6', '8'];
  Assert.AreEqual(Length(Expected), Length(FPlot.Categories), 'Category count mismatch');
  for var Index := 0 to High(Expected) do
  begin
    Assert.AreEqual(Expected[Index], FPlot.Categories[Index],
      Format('Category at index %d mismatch', [Index]));
  end;
end;

procedure THistogramBinningTests.SetHistogramData_SetsChartKindToHistogram;
begin
  FPlot.SetHistogramData([1, 2, 3], 1);

  Assert.AreEqual<TChartKind>(TChartKind.Histogram, FPlot.Kind);
end;

procedure THistogramBinningTests.SetHistogramData_ValueAtBinLowerBound_FallsIntoThatBin;
begin
  FPlot.SetHistogramData([2, 2], 2);

  const CountSeries = FPlot.Series[0];

  Assert.AreEqual(1, Length(CountSeries.Values));
  Assert.AreEqual<Double>(2, CountSeries.Values[0]);
  Assert.AreEqual('2', FPlot.Categories[0]);
end;

procedure THistogramBinningTests.SetHistogramData_ReplacesExistingSeriesWithSingleCountSeries;
begin
  FPlot.AddSeries('Existing', [1, 2, 3]);

  FPlot.SetHistogramData([1, 2, 3], 1);

  Assert.AreEqual(1, FPlot.Series.Count);
  Assert.AreEqual('Count', FPlot.Series[0].Name);
end;

end.
