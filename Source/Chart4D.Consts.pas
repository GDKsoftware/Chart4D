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
unit Chart4D.Consts;

/// <summary>
/// Shared constants and error message resource strings used across the Chart4D core
/// units.
/// </summary>

interface

const
  /// <summary>Default PNG export width in pixels, at the 640x450 reference size.</summary>
  DefaultExportWidth = 640;
  /// <summary>Default PNG export height in pixels, at the 640x450 reference size.</summary>
  DefaultExportHeight = 450;

  /// <summary>
  /// Sample text measured to get a fixed per-font-size line height, so a block of stacked
  /// lines has even spacing regardless of which lines happen to contain descenders. Shared
  /// by the renderer's wrapped title/subtitle blocks and by the tooltip's line box.
  /// </summary>
  LineHeightSampleText = 'Xg';

resourcestring
  /// <summary>Raised when a histogram bin width is not strictly positive.</summary>
  SBinWidthMustBePositive = 'Histogram bin width must be greater than 0, got %g';
  /// <summary>Raised when histogram data is empty, which would leave the chart a series without values.</summary>
  SHistogramValuesEmpty = 'Histogram data requires at least one value';
  /// <summary>Raised when a series' values array length does not match the category count.</summary>
  SSeriesValueCountMismatch = 'Series "%s" has %d value(s) but the chart has %d categor%s';
  /// <summary>Raised when a line/area series has mismatched X and Y value counts.</summary>
  SXYValueCountMismatch = 'Series "%s" has %d X value(s) but %d Y value(s)';
  /// <summary>
  /// Raised when a dumbbell, range or arrow series has mismatched start and end value
  /// counts. The first argument names the chart kind.
  /// </summary>
  SPairedValueCountMismatch = '%s series has %d start value(s) but %d end value(s)';
  /// <summary>Raised when a plot with no series is exported through an explicit entry point such as <c>SaveToPng</c>.</summary>
  SNoSeriesToRender = 'The chart has no series to render';
  /// <summary>Raised when a series has no values at all, leaving the value axis nothing to compute a range from.</summary>
  SSeriesHasNoValues = 'Series "%s" has no values';
  /// <summary>Raised when a series value is NaN, which no axis can place.</summary>
  SSeriesValueIsNaN = 'Series "%s" has a NaN value at index %d';
  /// <summary>Raised when a manual axis range is reversed (minimum above maximum).</summary>
  SReversedAxisRange = 'Axis range is reversed: minimum %g is greater than maximum %g';
  /// <summary>Raised when a logarithmic value axis is fed a value that is not strictly positive.</summary>
  SLogAxisRequiresPositiveValues = 'Logarithmic value axis requires every value to be greater than 0, got %g';
  /// <summary>Raised when a logarithmic axis base is not strictly greater than 1.</summary>
  SLogBaseMustExceedOne = 'Logarithmic axis base must be greater than 1, got %g';
  /// <summary>Raised when <c>TChartPlot.SeriesColor</c> is asked for an index outside the series list.</summary>
  SSeriesColorIndexOutOfRange = 'Series index %d is out of range: the chart has %d series';
  /// <summary>Raised when <c>TChartPlot.CategoryColor</c> is asked for a negative index.</summary>
  SCategoryColorIndexNegative = 'Category index must not be negative, got %d';
  /// <summary>Raised when a range-band series has mismatched low and high value counts.</summary>
  SBandValueCountMismatch = 'Band series "%s" has %d low value(s) but %d high value(s)';
  /// <summary>Raised when a scatter series' <c>Sizes</c> length does not match its <c>Values</c> length.</summary>
  SSeriesSizeCountMismatch = 'Series "%s" has %d value(s) but %d size(s)';
  /// <summary>Raised when a Pie/Donut plot does not have exactly one series.</summary>
  SPieRequiresSingleSeries = 'Pie/Donut charts require exactly one series, got %d';
  /// <summary>Raised when a Pie/Donut series has a negative value.</summary>
  SPieValuesMustBeNonNegative = 'Pie/Donut values must not be negative, got %g';
  /// <summary>Raised when <c>TChartRenderer.Render</c> is called with a nil plot.</summary>
  SRenderPlotRequired = 'TChartRenderer.Render requires a non-nil Plot';
  /// <summary>Raised when <c>TChartRenderer.Render</c> is called with a nil canvas.</summary>
  SRenderCanvasRequired = 'TChartRenderer.Render requires a non-nil Canvas';
  /// <summary>Raised when a text alignment value outside <c>TTextAlignH</c> is resolved.</summary>
  SUnsupportedTextAlignH = 'Unsupported horizontal text alignment: %d';
  /// <summary>Raised when a text alignment value outside <c>TTextAlignV</c> is resolved.</summary>
  SUnsupportedTextAlignV = 'Unsupported vertical text alignment: %d';
  /// <summary>Raised when no PNG encoder is registered with the imaging back end.</summary>
  SPngEncoderNotFound = 'No PNG image encoder is available on this system';
  /// <summary>Raised when writing a chart PNG to disk fails.</summary>
  SFailedToSavePng = 'Failed to save chart PNG to "%s" (GDI+ status %d)';

implementation

end.
