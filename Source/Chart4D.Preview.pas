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
unit Chart4D.Preview;

interface

uses
  Chart4D.Plot;

type
  /// <summary>
  /// Builds the sample chart the VCL and FMX controls draw at design time, when the
  /// plot they own has no series of its own yet. The settings the developer made in
  /// the Object Inspector are carried over, so the preview shows the title, the kind
  /// and the legend they are working on, with data that fits that kind.
  /// </summary>
  TChartPreview = class
  private
    class procedure CopySettings(const Settings, Preview: TChartPlot); static;
    class procedure AddCategorySeries(const Preview: TChartPlot); static;
    class procedure AddScatterSeries(const Preview: TChartPlot); static;
    class procedure AddSpanSeries(const Preview: TChartPlot); static;

  public
    /// <summary>
    /// Clears <c>Preview</c>, copies every setting from <c>Settings</c> into it and fills
    /// it with sample data for the chart kind that was copied.
    /// </summary>
    class procedure FillFrom(const Settings, Preview: TChartPlot); static;
  end;

implementation

uses
  Chart4D.Types;

const
  CategoryLabels: TArray<string> = ['2019', '2021', '2023', '2025'];
  FirstValues: TArray<Double> = [12, 18, 15, 24];
  SecondValues: TArray<Double> = [8, 11, 14, 19];
  ScatterXValues: TArray<Double> = [1, 2, 3, 4, 5];
  ScatterValues: TArray<Double> = [2, 4, 3, 6, 5];
  SpanStartValues: TArray<Double> = [10, 14, 12, 18];
  SpanEndValues: TArray<Double> = [16, 20, 15, 24];
  FirstSeriesName = 'Series 1';
  SecondSeriesName = 'Series 2';

class procedure TChartPreview.FillFrom(const Settings, Preview: TChartPlot);
begin
  Preview.ClearSeries;
  CopySettings(Settings, Preview);

  case Preview.Kind of
    TChartKind.Scatter:
      AddScatterSeries(Preview);
    TChartKind.Dumbbell,
    TChartKind.Range,
    TChartKind.Arrow:
      AddSpanSeries(Preview);
  else
    AddCategorySeries(Preview);
  end;
end;

class procedure TChartPreview.CopySettings(const Settings, Preview: TChartPlot);
begin
  Preview.Kind := Settings.Kind;
  Preview.Title := Settings.Title;
  Preview.Subtitle := Settings.Subtitle;
  Preview.Source := Settings.Source;

  Preview.Style := Settings.Style;
  Preview.XAxis := Settings.XAxis;
  Preview.YAxis := Settings.YAxis;

  Preview.Orientation := Settings.Orientation;
  Preview.StackMode := Settings.StackMode;
  Preview.LegendPosition := Settings.LegendPosition;
  Preview.LegendReversed := Settings.LegendReversed;
  Preview.ValueLabels := Settings.ValueLabels;
  Preview.SegmentLabels := Settings.SegmentLabels;
  Preview.SegmentLabelDecimals := Settings.SegmentLabelDecimals;
  Preview.DonutCenterText := Settings.DonutCenterText;
end;

class procedure TChartPreview.AddCategorySeries(const Preview: TChartPlot);
begin
  Preview.Categories := CategoryLabels;
  Preview.AddSeries(FirstSeriesName, FirstValues);

  const NeedsSecondSeries = (Preview.Kind in [TChartKind.GroupedBar, TChartKind.StackedBar]);
  if NeedsSecondSeries then
    Preview.AddSeries(SecondSeriesName, SecondValues);
end;

class procedure TChartPreview.AddScatterSeries(const Preview: TChartPlot);
begin
  const Series = Preview.AddSeries(FirstSeriesName, ScatterValues);
  Series.XValues := ScatterXValues;
end;

class procedure TChartPreview.AddSpanSeries(const Preview: TChartPlot);
begin
  Preview.Categories := CategoryLabels;

  const Series = Preview.AddSeries(FirstSeriesName, SpanStartValues);
  Series.EndValues := SpanEndValues;
end;

end.
