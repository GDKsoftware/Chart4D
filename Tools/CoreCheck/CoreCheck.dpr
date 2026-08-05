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
program CoreCheck;

/// <summary>
/// Console smoke test that compiles every Chart4D core unit and exercises a handful
/// of public APIs to catch dependency and compilation regressions early.
/// </summary>

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  Chart4D.Types in '..\..\Source\Chart4D.Types.pas',
  Chart4D.Consts in '..\..\Source\Chart4D.Consts.pas',
  Chart4D.Style in '..\..\Source\Chart4D.Style.pas',
  Chart4D.Series in '..\..\Source\Chart4D.Series.pas',
  Chart4D.Axis in '..\..\Source\Chart4D.Axis.pas',
  Chart4D.Canvas.Interfaces in '..\..\Source\Chart4D.Canvas.Interfaces.pas',
  Chart4D.Plot in '..\..\Source\Chart4D.Plot.pas',
  Chart4D.Renderer in '..\..\Source\Chart4D.Renderer.pas',
  Chart4D.Tooltip in '..\..\Source\Chart4D.Tooltip.pas';

type
  /// <summary>
  /// A no-op <c>IChartCanvas</c> that only measures text plausibly, used to exercise
  /// <c>TChartRenderer</c> end to end without a real graphics backend.
  /// </summary>
  TNullChartCanvas = class(TInterfacedObject, IChartCanvas)
  public
    procedure FillBackground(const Width, Height: Single; const Color: TAlphaColor);
    procedure DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                       const StrokeWidth: Single; const Dashed: Boolean);
    procedure DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                           const StrokeWidth: Single);
    procedure FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
    procedure FillRect(const Bounds: TRectF; const Color: TAlphaColor);
    procedure FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
    procedure DrawText(const X, Y: Single; const Text: string;
                       const TextStyle: TChartTextStyle;
                       const AlignH: TTextAlignH; const AlignV: TTextAlignV);
    function MeasureText(const Text: string;
                         const TextStyle: TChartTextStyle): TSizeF;
    procedure DrawImage(const FilePath: string; const Bounds: TRectF);
  end;

procedure TNullChartCanvas.FillBackground(const Width, Height: Single; const Color: TAlphaColor);
begin
end;

procedure TNullChartCanvas.DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                                    const StrokeWidth: Single; const Dashed: Boolean);
begin
end;

procedure TNullChartCanvas.DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                                        const StrokeWidth: Single);
begin
end;

procedure TNullChartCanvas.FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
begin
end;

procedure TNullChartCanvas.FillRect(const Bounds: TRectF; const Color: TAlphaColor);
begin
end;

procedure TNullChartCanvas.FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
begin
end;

procedure TNullChartCanvas.DrawText(const X, Y: Single; const Text: string;
                                    const TextStyle: TChartTextStyle;
                                    const AlignH: TTextAlignH; const AlignV: TTextAlignV);
begin
end;

function TNullChartCanvas.MeasureText(const Text: string;
                                      const TextStyle: TChartTextStyle): TSizeF;
begin
  Result := TSizeF.Create(Length(Text) * TextStyle.Size * 0.6, TextStyle.Size * 1.2);
end;

procedure TNullChartCanvas.DrawImage(const FilePath: string; const Bounds: TRectF);
begin
end;

procedure CheckRenderer;
var
  Canvas: IChartCanvas;
begin
  Canvas := TNullChartCanvas.Create;

  const LinePlot = TChartPlot.Create;
  try
    LinePlot.Title := 'Life expectancy';
    LinePlot.Subtitle := 'Selected countries, 1952-2007';
    LinePlot.Source := 'Source: Gapminder';
    LinePlot.Categories := ['1952', '1972', '1992', '2007'];
    LinePlot.AddSeries('Netherlands', [72.1, 73.2, 77.4, 79.8]);
    LinePlot.AddSeries('Belgium', [68.0, 71.1, 76.0, 79.4]);
    LinePlot.AddHorizontalLine(75, ChartTextDark, True);
    LinePlot.AddTextAnnotation(1, 80, 'Peak', ChartTextDark);
    TChartRenderer.Render(LinePlot, Canvas, 640, 450);
    Writeln('TChartRenderer (Line): OK');
  finally
    LinePlot.Free;
  end;

  const AreaPlot = TChartPlot.Create;
  try
    AreaPlot.Kind := TChartKind.Area;
    AreaPlot.Categories := ['Q1', 'Q2', 'Q3', 'Q4'];
    AreaPlot.AddSeries('Revenue', [10, 12, 9, 15]);
    TChartRenderer.Render(AreaPlot, Canvas, 640, 450);
    Writeln('TChartRenderer (Area): OK');
  finally
    AreaPlot.Free;
  end;

  const BarPlot = TChartPlot.Create;
  try
    BarPlot.Kind := TChartKind.Bar;
    BarPlot.Categories := ['A', 'B', 'C'];
    BarPlot.AddSeries('Count', [3, -2, 5]);
    TChartRenderer.Render(BarPlot, Canvas, 640, 450);
    Writeln('TChartRenderer (Bar): OK');
  finally
    BarPlot.Free;
  end;

  const GroupedBarPlot = TChartPlot.Create;
  try
    GroupedBarPlot.Kind := TChartKind.GroupedBar;
    GroupedBarPlot.Categories := ['2020', '2021', '2022'];
    GroupedBarPlot.AddSeries('North', [4, 5, 6]);
    GroupedBarPlot.AddSeries('South', [3, 4, 4.5]);
    TChartRenderer.Render(GroupedBarPlot, Canvas, 640, 450);
    Writeln('TChartRenderer (GroupedBar): OK');
  finally
    GroupedBarPlot.Free;
  end;

  const StackedBarPlot = TChartPlot.Create;
  try
    StackedBarPlot.Kind := TChartKind.StackedBar;
    StackedBarPlot.StackMode := TStackMode.Proportions;
    StackedBarPlot.Categories := ['2020', '2021'];
    StackedBarPlot.AddSeries('North', [4, 5]);
    StackedBarPlot.AddSeries('South', [3, 4]);
    TChartRenderer.Render(StackedBarPlot, Canvas, 640, 450);
    Writeln('TChartRenderer (StackedBar, Proportions): OK');
  finally
    StackedBarPlot.Free;
  end;

  const HistogramPlot = TChartPlot.Create;
  try
    HistogramPlot.SetHistogramData([1, 2, 2, 3, 7, 8], 2);
    TChartRenderer.Render(HistogramPlot, Canvas, 640, 450);
    Writeln('TChartRenderer (Histogram): OK');
  finally
    HistogramPlot.Free;
  end;

  const DumbbellPlot = TChartPlot.Create;
  try
    DumbbellPlot.Categories := ['Alpha', 'Beta', 'Gamma'];
    DumbbellPlot.AddDumbbellSeries([10, 20, 15], [25, 22, 30]);
    DumbbellPlot.Source := 'Source: Internal';
    TChartRenderer.Render(DumbbellPlot, Canvas, 640, 450);
    Writeln('TChartRenderer (Dumbbell): OK');
  finally
    DumbbellPlot.Free;
  end;

  const HorizontalGroupedPlot = TChartPlot.Create;
  try
    HorizontalGroupedPlot.Kind := TChartKind.GroupedBar;
    HorizontalGroupedPlot.Orientation := TChartOrientation.Horizontal;
    HorizontalGroupedPlot.LegendPosition := TLegendPosition.Right;
    HorizontalGroupedPlot.Categories := ['North', 'South', 'East', 'West'];
    HorizontalGroupedPlot.AddSeries('2021', [4, 5, 3, 6]);
    HorizontalGroupedPlot.AddSeries('2022', [5, 4, 4, 7]);
    TChartRenderer.Render(HorizontalGroupedPlot, Canvas, 640, 450);
    Writeln('TChartRenderer (GroupedBar, Horizontal, Legend Right): OK');
  finally
    HorizontalGroupedPlot.Free;
  end;

  const XYLinePlot = TChartPlot.Create;
  try
    XYLinePlot.LegendPosition := TLegendPosition.Bottom;
    XYLinePlot.AddLineSeries('Netherlands', [1952, 1972, 1992, 2007], [72.1, 73.2, 77.4, 79.8]);
    XYLinePlot.AddLineSeries('Belgium', [1952, 1972, 1992, 2007], [68.0, 71.1, 76.0, 79.4]);
    XYLinePlot.AddSegment(1960, 70, 1990, 75);
    XYLinePlot.AddArrow(1970, 75, 1980, 78);
    XYLinePlot.AddVerticalLine(1990, ChartTextDark);
    TChartRenderer.Render(XYLinePlot, Canvas, 640, 450);
    Writeln('TChartRenderer (Line, explicit XValues, Legend Bottom, annotations): OK');
  finally
    XYLinePlot.Free;
  end;

  const StackedValuesPlot = TChartPlot.Create;
  try
    StackedValuesPlot.Kind := TChartKind.StackedBar;
    StackedValuesPlot.Categories := ['2020', '2021'];
    StackedValuesPlot.LegendReversed := True;
    StackedValuesPlot.AddSeries('North', [4, 5]);
    StackedValuesPlot.AddSeries('South', [3, 4]);
    StackedValuesPlot.AddSeries('West', [2, 1]);
    TChartRenderer.Render(StackedValuesPlot, Canvas, 640, 450);
    Writeln('TChartRenderer (StackedBar, Values, LegendReversed): OK');
  finally
    StackedValuesPlot.Free;
  end;

  const MismatchPlot = TChartPlot.Create;
  try
    MismatchPlot.Kind := TChartKind.Bar;
    MismatchPlot.Categories := ['A', 'B'];
    MismatchPlot.AddSeries('Count', [1, 2, 3]);

    var RaisedExpectedException := False;
    try
      TChartRenderer.Render(MismatchPlot, Canvas, 640, 450);
    except
      on E: EChart4DException do
        RaisedExpectedException := True;
    end;

    if not RaisedExpectedException then
      raise EChart4DException.Create('TChartRenderer did not raise on mismatched category/value counts');
    Writeln('TChartRenderer (mismatch guard): OK');
  finally
    MismatchPlot.Free;
  end;
end;

procedure CheckTooltip;
var
  Canvas: IChartCanvas;
begin
  Canvas := TNullChartCanvas.Create;

  const BarPlot = TChartPlot.Create;
  try
    BarPlot.Kind := TChartKind.Bar;
    BarPlot.Categories := ['A', 'B', 'C'];
    BarPlot.AddSeries('Count', [3, 2, 5]);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(BarPlot, Canvas, 640, 450, HitMap);

    const HasOneTargetPerCategory = (Length(HitMap) = 3);
    if not HasOneTargetPerCategory then
      raise EChart4DException.Create('TChartRenderer HitMap overload did not produce one target per bar');

    var Info: TChartHitInfo;
    const FoundTarget = TChartTooltip.FindTarget(HitMap, HitMap[1].Bounds.CenterPoint.X, HitMap[1].Bounds.CenterPoint.Y, Info);
    if not FoundTarget then
      raise EChart4DException.Create('TChartTooltip.FindTarget did not find a target at a bar center');

    TChartTooltip.Draw(Canvas, BarPlot.Style, Info, 640, 450);
    Writeln('TChartTooltip (Bar hit map, FindTarget, Draw): OK');
  finally
    BarPlot.Free;
  end;
end;

begin
  try
    const Style = TChartStyle.Default;
    const HasEditorialTitleSize = (Style.TitleFontSize = 28);
    if not HasEditorialTitleSize then
      raise EChart4DException.Create('TChartStyle.Default.TitleFontSize mismatch');
    Writeln('TChartStyle.Default: OK (FontName=', Style.FontName, ')');

    const Breaks = TAxisScale.NiceBreaks(0, 85);
    const HasFiveBreaks = (Length(Breaks) = 5);
    if not HasFiveBreaks then
      raise EChart4DException.Create('TAxisScale.NiceBreaks(0, 85) mismatch');
    Writeln('TAxisScale.NiceBreaks(0, 85): OK (', Length(Breaks), ' breaks)');

    const Plot = TChartPlot.Create;
    try
      Plot.Title := 'Life expectancy';
      Plot.AddSeries('Netherlands', [78.5, 79.1, 80.2]);

      const HasOneSeries = (Plot.Series.Count = 1);
      if not HasOneSeries then
        raise EChart4DException.Create('TChartPlot series count mismatch');

      const FirstSeriesColor = Plot.SeriesColor(0);
      Writeln('TChartPlot: OK (series=', Plot.Series.Count, ', color=$', IntToHex(FirstSeriesColor, 8), ')');
    finally
      Plot.Free;
    end;

    CheckRenderer;
    CheckTooltip;

    Writeln('CoreCheck: all checks passed');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln('CoreCheck FAILED: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
