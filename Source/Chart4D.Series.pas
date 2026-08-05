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
unit Chart4D.Series;

/// <summary>
/// A single named data series of a chart, holding its values and its own optional
/// color override.
/// </summary>

interface

uses
  System.UITypes;

type
  /// <summary>
  /// A named data series. <c>Values</c> holds the primary Y values for every chart
  /// kind. <c>XValues</c> is used by <c>Line</c>/<c>Area</c>/<c>Scatter</c> series with
  /// explicit X coordinates. <c>EndValues</c> is used by <c>Dumbbell</c>/<c>Range</c>/
  /// <c>Arrow</c> series to hold the second end of each data point, and by range-band
  /// series to hold the high bound.
  /// </summary>
  TChartSeries = class
  private
    FName: string;
    FColor: TAlphaColor;
    FValues: TArray<Double>;
    FXValues: TArray<Double>;
    FEndValues: TArray<Double>;
    FSizes: TArray<Double>;
    FIsRangeBand: Boolean;

  public
    /// <summary>
    /// Creates a series with the given name and no values.
    /// </summary>
    constructor Create(const Name: string);

    /// <summary>The series name, shown in the legend.</summary>
    property Name: string read FName write FName;
    /// <summary>The series color, or 0 to use the automatic palette color.</summary>
    property Color: TAlphaColor read FColor write FColor;
    /// <summary>The primary values of the series.</summary>
    property Values: TArray<Double> read FValues write FValues;
    /// <summary>The X coordinates of the series, used by <c>Line</c>, <c>Area</c> and <c>Scatter</c> charts.</summary>
    property XValues: TArray<Double> read FXValues write FXValues;
    /// <summary>
    /// The second end of every data point, used by <c>Dumbbell</c>, <c>Range</c> and
    /// <c>Arrow</c> charts, and, as the high bound, by range-band series.
    /// </summary>
    property EndValues: TArray<Double> read FEndValues write FEndValues;
    /// <summary>
    /// Per-point sizes of a <c>Scatter</c> series, used only by that kind. Empty (default)
    /// draws every point at a uniform radius; a non-empty array, which must have the same
    /// length as <c>Values</c>, turns the series into an area-proportional bubble series.
    /// </summary>
    property Sizes: TArray<Double> read FSizes write FSizes;
    /// <summary>
    /// Whether this series is an uncertainty/range band on a <c>Line</c>/<c>Area</c> plot:
    /// <c>Values</c> is the low bound and <c>EndValues</c> the high bound at each point,
    /// drawn as a shaded region behind the other series instead of a line. Default
    /// <c>False</c>, in which case the series draws as an ordinary <c>Line</c> or <c>Area</c>.
    /// </summary>
    property IsRangeBand: Boolean read FIsRangeBand write FIsRangeBand;
  end;

implementation

constructor TChartSeries.Create(const Name: string);
begin
  inherited Create;
  FName := Name;
  FColor := 0;
  FIsRangeBand := False;
end;

end.
