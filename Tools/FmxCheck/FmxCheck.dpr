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
program FmxCheck;

/// <summary>
/// Console smoke test for the FMX adapter: builds a chart in a <c>TChart4D</c> control
/// and exports it to a PNG file in the system temp folder, to catch adapter and
/// dependency regressions early. Also renders a headless hover tooltip onto an offscreen
/// bitmap, simulating a hit against the hit map produced by the renderer, so the tooltip
/// path can be visually verified without opening a window. Two rendering regression
/// checks guard against canvas-state bugs: one renders onto a deliberately polluted
/// canvas (brush kinds set to <c>None</c>, as styled controls leave behind on a shared
/// form canvas) and asserts by pixel count that the series line still draws; the other
/// captures the real control paint path via <c>MakeScreenshot</c> and asserts the same.
/// FMX works in console applications as long as no form is created or shown.
/// </summary>

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.Math,
  System.Types,
  System.UITypes,
  FMX.Graphics,
  Chart4D.Types in '..\..\Source\Chart4D.Types.pas',
  Chart4D.Consts in '..\..\Source\Chart4D.Consts.pas',
  Chart4D.Style in '..\..\Source\Chart4D.Style.pas',
  Chart4D.Series in '..\..\Source\Chart4D.Series.pas',
  Chart4D.Axis in '..\..\Source\Chart4D.Axis.pas',
  Chart4D.Canvas.Interfaces in '..\..\Source\Chart4D.Canvas.Interfaces.pas',
  Chart4D.Plot in '..\..\Source\Chart4D.Plot.pas',
  Chart4D.Renderer in '..\..\Source\Chart4D.Renderer.pas',
  Chart4D.Tooltip in '..\..\Source\Chart4D.Tooltip.pas',
  Chart4D.Hover in '..\..\Source\Chart4D.Hover.pas',
  Chart4D.View in '..\..\Source\Chart4D.View.pas',
  Chart4D.FMX in '..\..\Source\FMX\Chart4D.FMX.pas',
  Chart4DDemo.Catalog in '..\..\Examples\Common\Chart4DDemo.Catalog.pas';

procedure ExportSampleChart(const ExportPath: string);
begin
  const Chart = TChart4D.Create(nil);
  try
    Chart.Plot.Title := 'Life expectancy';
    Chart.Plot.Subtitle := 'Selected countries, 1960-2020';
    Chart.Plot.Source := 'Source: World Bank';
    Chart.Plot.Categories := ['1960', '1980', '2000', '2020'];
    Chart.Plot.AddSeries('Netherlands', [73.4, 75.7, 78.0, 81.4]);
    Chart.Plot.AddSeries('Portugal', [64.0, 71.2, 76.3, 81.3]);

    Chart.SaveToPng(ExportPath);
  finally
    Chart.Free;
  end;
end;

procedure BuildTooltipSamplePlot(const Plot: TChartPlot);
begin
  Plot.Title := 'Life expectancy';
  Plot.Subtitle := 'Selected countries, 1960-2020';
  Plot.Categories := ['1960', '1980', '2000', '2020'];
  Plot.AddSeries('Netherlands', [73.5, 75.8, 78.0, 81.4]);
  Plot.AddSeries('Portugal', [61.2, 71.0, 76.4, 80.8]);
end;

function SimulateHover(const HitMap: TArray<TChartHitTarget>): TChartHitInfo;
begin
  const HasHitTargets = (Length(HitMap) > 0);
  if not HasHitTargets then
    raise EChart4DException.Create('No hit targets produced for the tooltip sample chart');

  const SimulatedTarget = HitMap[Length(HitMap) div 2];
  const FoundHit = TChartTooltip.FindTarget(HitMap, SimulatedTarget.Center.X, SimulatedTarget.Center.Y, Result);
  if not FoundHit then
    raise EChart4DException.Create('Simulated hover position did not hit any target');
end;

procedure ExportTooltipSample(const ExportPath: string);
begin
  const Plot = TChartPlot.Create;
  try
    BuildTooltipSamplePlot(Plot);

    const Bitmap = TBitmap.Create(DefaultExportWidth, DefaultExportHeight);
    try
      const SceneStarted = Bitmap.Canvas.BeginScene;
      if not SceneStarted then
        raise EChart4DException.CreateFmt('Failed to begin an FMX scene for the tooltip render "%s"', [ExportPath]);

      try
        const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(Bitmap.Canvas);

        var HitMap: TArray<TChartHitTarget>;
        TChartRenderer.Render(Plot, ChartCanvas, DefaultExportWidth, DefaultExportHeight, HitMap);

        const HoverInfo = SimulateHover(HitMap);
        TChartTooltip.Draw(ChartCanvas, Plot.Style, HoverInfo, DefaultExportWidth, DefaultExportHeight);
      finally
        Bitmap.Canvas.EndScene;
      end;

      Bitmap.SaveToFile(ExportPath);
    finally
      Bitmap.Free;
    end;
  finally
    Plot.Free;
  end;
end;

procedure BuildLineSamplePlot(const Plot: TChartPlot);
begin
  Plot.Kind := TChartKind.Line;
  Plot.Title := 'Life expectancy';
  Plot.Subtitle := 'Netherlands, 1960-2020';
  Plot.AddLineSeries('Netherlands', [1960, 1980, 2000, 2020],
                     [73.5, 75.8, 78.0, 81.4]);
end;

function CountPixelsWithColor(const Bitmap: TBitmap; const Color: TAlphaColor): Integer;
begin
  Result := 0;

  var BitmapData: TBitmapData;
  const Mapped = Bitmap.Map(TMapAccess.Read, BitmapData);
  if not Mapped then
    raise EChart4DException.Create('Could not map the bitmap for pixel verification');

  try
    for var Y := 0 to Bitmap.Height - 1 do
    begin
      for var X := 0 to Bitmap.Width - 1 do
      begin
        const PixelMatches = (BitmapData.GetPixel(X, Y) = Color);
        if PixelMatches then
          Inc(Result);
      end;
    end;
  finally
    Bitmap.Unmap(BitmapData);
  end;
end;

procedure VerifySeriesLinePixels(const Bitmap: TBitmap; const CheckName: string);
const
  MinimumSeriesPixels = 50;
begin
  const SeriesPixelCount = CountPixelsWithColor(Bitmap, ChartBlue);
  const SeriesLineIsVisible = (SeriesPixelCount >= MinimumSeriesPixels);
  if not SeriesLineIsVisible then
    raise EChart4DException.CreateFmt(
      '%s: expected at least %d series-colored pixels but found %d; the chart strokes did not render',
      [CheckName, MinimumSeriesPixels, SeriesPixelCount]);

  Writeln(Format('FmxCheck: %s draws the series line (%d pixels)', [CheckName, SeriesPixelCount]));
end;

procedure VerifyPollutedCanvasRender;
begin
  const Plot = TChartPlot.Create;
  try
    BuildLineSamplePlot(Plot);

    const Bitmap = TBitmap.Create(DefaultExportWidth, DefaultExportHeight);
    try
      const SceneStarted = Bitmap.Canvas.BeginScene;
      if not SceneStarted then
        raise EChart4DException.Create('Failed to begin an FMX scene for the polluted-canvas check');

      try
        Bitmap.Canvas.Stroke.Kind := TBrushKind.None;
        Bitmap.Canvas.Fill.Kind := TBrushKind.None;
        Bitmap.Canvas.Stroke.Thickness := 0;
        Bitmap.Canvas.Stroke.Dash := TStrokeDash.Dot;

        const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(Bitmap.Canvas);
        TChartRenderer.Render(Plot, ChartCanvas, DefaultExportWidth, DefaultExportHeight);
      finally
        Bitmap.Canvas.EndScene;
      end;

      VerifySeriesLinePixels(Bitmap, 'polluted-canvas render');
    finally
      Bitmap.Free;
    end;
  finally
    Plot.Free;
  end;
end;

procedure VerifyControlScreenshot(const ExportPath: string);
begin
  const Chart = TChart4D.Create(nil);
  try
    BuildLineSamplePlot(Chart.Plot);
    Chart.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    const Screenshot = Chart.MakeScreenshot;
    try
      VerifySeriesLinePixels(Screenshot, 'control MakeScreenshot');
      Screenshot.SaveToFile(ExportPath);
    finally
      Screenshot.Free;
    end;
  finally
    Chart.Free;
  end;
end;

/// <summary>Turns an example name into a file name that needs no quoting.</summary>
function FileNameFor(const SampleName: string): string;
begin
  Result := LowerCase(SampleName);
  Result := Result.Replace(' ', '-', [rfReplaceAll]);
  Result := Result.Replace('(', '', [rfReplaceAll]);
  Result := Result.Replace(')', '', [rfReplaceAll]);
end;

/// <summary>
/// Counts pixels whose channels differ enough to be a palette colour rather than white,
/// black or grey, so text and gridlines do not mask a series that failed to draw.
/// </summary>
function CountColoredPixels(const Bitmap: TBitmap): Integer;
const
  MinimumChannelSpread = 30;
begin
  Result := 0;

  var BitmapData: TBitmapData;
  const Mapped = Bitmap.Map(TMapAccess.Read, BitmapData);
  if not Mapped then
    raise EChart4DException.Create('Could not map the bitmap for pixel verification');

  try
    for var Y := 0 to Bitmap.Height - 1 do
    begin
      for var X := 0 to Bitmap.Width - 1 do
      begin
        const Pixel = TAlphaColorRec(BitmapData.GetPixel(X, Y));
        const Highest = Max(Pixel.R, Max(Pixel.G, Pixel.B));
        const Lowest = Min(Pixel.R, Min(Pixel.G, Pixel.B));
        const IsColored = (Highest - Lowest) >= MinimumChannelSpread;
        if IsColored then
          Inc(Result);
      end;
    end;
  finally
    Bitmap.Unmap(BitmapData);
  end;
end;

/// <summary>
/// Counts non-background pixels on the outermost rows and columns, which must be zero:
/// nothing may be clipped by the canvas edge.
/// </summary>
function CountBorderInkPixels(const Bitmap: TBitmap): Integer;
const
  BackgroundThreshold = 250;
begin
  Result := 0;

  var BitmapData: TBitmapData;
  const Mapped = Bitmap.Map(TMapAccess.Read, BitmapData);
  if not Mapped then
    raise EChart4DException.Create('Could not map the bitmap for pixel verification');

  try
    for var Y := 0 to Bitmap.Height - 1 do
    begin
      for var X := 0 to Bitmap.Width - 1 do
      begin
        const IsBorder = (X = 0) or (Y = 0) or (X = Bitmap.Width - 1) or (Y = Bitmap.Height - 1);
        if not IsBorder then
          Continue;

        const Pixel = TAlphaColorRec(BitmapData.GetPixel(X, Y));
        const IsInk = (Pixel.R < BackgroundThreshold) or
                      (Pixel.G < BackgroundThreshold) or
                      (Pixel.B < BackgroundThreshold);
        if IsInk then
          Inc(Result);
      end;
    end;
  finally
    Bitmap.Unmap(BitmapData);
  end;
end;

/// <summary>
/// Renders every example from the shared demo catalogue through the real FMX adapter and
/// asserts that each one puts palette-coloured ink on the bitmap and nothing on its
/// outermost pixels. A chart that compiles and silently draws nothing is the failure mode
/// this adapter already had once. Drawing the same catalogue the demos present means this
/// coverage grows or shrinks with the catalogue itself, rather than a second, hand-kept
/// sample set that can drift away from what a user actually sees.
/// </summary>
procedure VerifyEveryChartKindDraws(const OutputDir: string);
const
  MinimumColoredPixels = 200;
begin
  for var Sample in TDemoCatalog.Samples do
  begin
    const Chart = TChart4D.Create(nil);
    try
      Chart.Plot.Source := TDemoCatalog.DefaultSource;
      Sample.Build(Chart.Plot);

      Chart.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);
      const Screenshot = Chart.MakeScreenshot;
      try
        const ColoredPixels = CountColoredPixels(Screenshot);
        const DrewSomething = (ColoredPixels >= MinimumColoredPixels);
        if not DrewSomething then
          raise EChart4DException.CreateFmt(
            'kind %s: expected at least %d palette-colored pixels but found %d; it drew nothing',
            [Sample.Name, MinimumColoredPixels, ColoredPixels]);

        const BorderInk = CountBorderInkPixels(Screenshot);
        const StaysInsideBounds = (BorderInk = 0);
        if not StaysInsideBounds then
          raise EChart4DException.CreateFmt(
            'kind %s: %d ink pixels on the outermost rows or columns; something is clipped by the canvas edge',
            [Sample.Name, BorderInk]);

        Screenshot.SaveToFile(TPath.Combine(OutputDir, Format('fmx-%s.png', [FileNameFor(Sample.Name)])));
        Writeln(Format('FmxCheck: kind %-25s draws (%5d colored pixels, %d border ink)',
                       [Sample.Name, ColoredPixels, BorderInk]));
      finally
        Screenshot.Free;
      end;
    finally
      Chart.Free;
    end;
  end;
end;

type
  /// <summary>
  /// Exposes the control's protected mouse entry points, so the hover chain from a mouse
  /// move through the hit test, the hover state and the repaint can be driven without a
  /// visible window or an OS-level mouse.
  /// </summary>
  TDrivableChart = class(TChart4D)
  public
    procedure SimulateMouseMove(const X, Y: Single);
    procedure SimulateMouseLeave;
  end;

  /// <summary>Records what <c>OnDataPointHover</c> reported, and how often.</summary>
  THoverRecorder = class
  private
    FLastInfo: TChartHitInfo;
    FEventCount: Integer;
  public
    procedure HandleHover(Sender: TObject; const Info: TChartHitInfo);

    property LastInfo: TChartHitInfo read FLastInfo;
    property EventCount: Integer read FEventCount;
  end;

procedure TDrivableChart.SimulateMouseMove(const X, Y: Single);
begin
  MouseMove([], X, Y);
end;

procedure TDrivableChart.SimulateMouseLeave;
begin
  DoMouseLeave;
end;

procedure THoverRecorder.HandleHover(Sender: TObject; const Info: TChartHitInfo);
begin
  FLastInfo := Info;
  Inc(FEventCount);
end;

/// <summary>
/// Counts pixels that differ between two renders of the same chart at the same size.
/// Comparing whole renders is immune to antialiasing, unlike matching an exact colour:
/// a tooltip border is one pixel wide and never lands on its nominal colour.
/// </summary>
function CountDifferingPixels(const Left, Right: TBitmap): Integer;
begin
  Result := 0;

  const SameSize = (Left.Width = Right.Width) and (Left.Height = Right.Height);
  if not SameSize then
    raise EChart4DException.Create('Cannot compare renders of different sizes');

  var LeftData, RightData: TBitmapData;
  if not Left.Map(TMapAccess.Read, LeftData) then
    raise EChart4DException.Create('Could not map the first bitmap for comparison');

  try
    if not Right.Map(TMapAccess.Read, RightData) then
      raise EChart4DException.Create('Could not map the second bitmap for comparison');

    try
      for var Y := 0 to Left.Height - 1 do
      begin
        for var X := 0 to Left.Width - 1 do
        begin
          const PixelsDiffer = (LeftData.GetPixel(X, Y) <> RightData.GetPixel(X, Y));
          if PixelsDiffer then
            Inc(Result);
        end;
      end;
    finally
      Right.Unmap(RightData);
    end;
  finally
    Left.Unmap(LeftData);
  end;
end;

/// <summary>
/// Drives the real hover chain and proves it end to end: the control reports the data
/// point under the pointer, the repaint that follows actually changes what the control
/// paints, and leaving restores the resting render exactly. <c>MakeScreenshot</c> runs the
/// same paint path a visible window would, so the pixel evidence comes from the control.
/// </summary>
procedure VerifyControlHoverChain(const OutputDir: string);
const
  MinimumTooltipPixels = 200;
begin
  const Chart = TDrivableChart.Create(nil);
  try
    Chart.Plot.Kind := TChartKind.Bar;
    Chart.Plot.Title := 'Life expectancy';
    Chart.Plot.Subtitle := 'Selected countries, 2020';
    Chart.Plot.Categories := ['Netherlands', 'Belgium', 'France', 'Germany'];
    Chart.Plot.AddSeries('2020', [81.4, 80.7, 82.2, 81.0]);
    Chart.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    var HitMap: TArray<TChartHitTarget>;
    const Bitmap = TBitmap.Create(DefaultExportWidth, DefaultExportHeight);
    try
      const SceneStarted = Bitmap.Canvas.BeginScene;
      if not SceneStarted then
        raise EChart4DException.Create('Failed to begin an FMX scene for the hover check');

      try
        const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(Bitmap.Canvas);
        TChartRenderer.Render(Chart.Plot, ChartCanvas, DefaultExportWidth, DefaultExportHeight, HitMap);
      finally
        Bitmap.Canvas.EndScene;
      end;
    finally
      Bitmap.Free;
    end;

    const HasTargets = (Length(HitMap) > 0);
    if not HasTargets then
      raise EChart4DException.Create('The sample chart produced no hit targets to hover over');

    const Recorder = THoverRecorder.Create;
    try
      Chart.OnDataPointHover := Recorder.HandleHover;

      const Resting = Chart.MakeScreenshot;
      try
        const Target = HitMap[High(HitMap)];
        const HoverPoint = Target.Bounds.CenterPoint;
        Chart.SimulateMouseMove(HoverPoint.X, HoverPoint.Y);

        if Recorder.EventCount <> 1 then
          raise EChart4DException.CreateFmt(
            'hovering a bar should fire OnDataPointHover once, but it fired %d times', [Recorder.EventCount]);
        if not Recorder.LastInfo.HasHit then
          raise EChart4DException.Create('hovering a bar reported no hit');
        if Recorder.LastInfo.CategoryLabel <> Target.Info.CategoryLabel then
          raise EChart4DException.CreateFmt(
            'hovering reported category "%s" but the target under the pointer is "%s"',
            [Recorder.LastInfo.CategoryLabel, Target.Info.CategoryLabel]);

        const Hovered = Chart.MakeScreenshot;
        try
          const ChangedPixels = CountDifferingPixels(Resting, Hovered);
          const TooltipIsDrawn = (ChangedPixels >= MinimumTooltipPixels);
          if not TooltipIsDrawn then
            raise EChart4DException.CreateFmt(
              'hovering reported a hit but the repaint changed only %d pixels, so no tooltip was drawn',
              [ChangedPixels]);

          Hovered.SaveToFile(TPath.Combine(OutputDir, 'fmx-hover.png'));
          Writeln(Format('FmxCheck: hovering a bar reports %s = %s and repaints the tooltip (%d pixels changed)',
                         [Recorder.LastInfo.CategoryLabel,
                          TAxisScale.FormatValue(Recorder.LastInfo.Value, False), ChangedPixels]));
        finally
          Hovered.Free;
        end;

        Chart.SimulateMouseLeave;
        if Recorder.EventCount <> 2 then
          raise EChart4DException.CreateFmt(
            'leaving the control should fire OnDataPointHover once more, but it fired %d times',
            [Recorder.EventCount]);
        if Recorder.LastInfo.HasHit then
          raise EChart4DException.Create('leaving the control still reported a hit');

        const Left = Chart.MakeScreenshot;
        try
          const RemainingDifference = CountDifferingPixels(Resting, Left);
          const TooltipIsGone = (RemainingDifference = 0);
          if not TooltipIsGone then
            raise EChart4DException.CreateFmt(
              'leaving the control left %d pixels different from the resting render',
              [RemainingDifference]);
        finally
          Left.Free;
        end;

        Writeln('FmxCheck: leaving the control clears the tooltip and restores the resting render');
      finally
        Resting.Free;
      end;
    finally
      Recorder.Free;
    end;
  finally
    Chart.Free;
  end;
end;

/// <summary>
/// Proves the FMX control caches its render through observable pixels.
/// <c>TChartSeries.Values</c> writes straight to its field with no change notification, so
/// assigning it directly changes what a fresh render would draw without telling the
/// control anything: a cached screenshot must stay pixel-identical to one captured before
/// the assignment. A real mutator, which does fire <c>OnChanged</c>, must invalidate the
/// cache and change what is painted; a resize must do the same, proven by comparing the
/// resized screenshot against an independent render at that size.
/// </summary>
procedure VerifyBackBufferCaching;
begin
  const Chart = TChart4D.Create(nil);
  try
    Chart.Plot.Kind := TChartKind.Bar;
    Chart.Plot.Title := 'Life expectancy';
    Chart.Plot.Categories := ['Netherlands', 'Belgium', 'France', 'Germany'];
    const Series = Chart.Plot.AddSeries('2020', [81.4, 80.7, 82.2, 81.0]);
    Chart.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    const BaselineShot = Chart.MakeScreenshot;
    try
      Series.Values := [70.0, 70.0, 70.0, 70.0];
      const SilentShot = Chart.MakeScreenshot;
      try
        const ChangedPixels = CountDifferingPixels(BaselineShot, SilentShot);
        if ChangedPixels <> 0 then
          raise EChart4DException.CreateFmt(
            'assigning Values without firing OnChanged should reuse the cached render, but %d pixels changed',
            [ChangedPixels]);

        Writeln('FmxCheck: mutating series Values silently reuses the cached render (pixels unchanged)');
      finally
        SilentShot.Free;
      end;

      Chart.Plot.AddSeries('2021', [81.5, 80.8, 82.3, 81.1]);
      const MutatedShot = Chart.MakeScreenshot;
      try
        const ChangedPixels = CountDifferingPixels(BaselineShot, MutatedShot);
        if ChangedPixels = 0 then
          raise EChart4DException.Create(
            'adding a series fires OnChanged and should invalidate the cached render, but no pixels changed');

        Writeln('FmxCheck: a real plot mutation invalidates the cache and repaints');
      finally
        MutatedShot.Free;
      end;
    finally
      BaselineShot.Free;
    end;

    const NewWidth = DefaultExportWidth + 10;
    Chart.SetBounds(0, 0, NewWidth, DefaultExportHeight);
    const ResizedShot = Chart.MakeScreenshot;
    try
      const ExpectedRender = TBitmap.Create(NewWidth, DefaultExportHeight);
      try
        const SceneStarted = ExpectedRender.Canvas.BeginScene;
        if not SceneStarted then
          raise EChart4DException.Create('Failed to begin an FMX scene for the resize-cache check');

        try
          const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(ExpectedRender.Canvas);
          TChartRenderer.Render(Chart.Plot, ChartCanvas, NewWidth, DefaultExportHeight);
        finally
          ExpectedRender.Canvas.EndScene;
        end;

        const ChangedPixels = CountDifferingPixels(ExpectedRender, ResizedShot);
        if ChangedPixels <> 0 then
          raise EChart4DException.CreateFmt(
            'resizing the control should invalidate the cache and re-render at the new size, but %d pixels ' +
            'differ from an independent render at that size', [ChangedPixels]);

        Writeln('FmxCheck: resizing the control invalidates the cache and re-renders at the new size');
      finally
        ExpectedRender.Free;
      end;
    finally
      ResizedShot.Free;
    end;
  finally
    Chart.Free;
  end;
end;

/// <summary>
/// Whether two colors are equal up to a rounding step per channel. Under a translated
/// canvas matrix FMX rasterises the same antialiased shape with an occasional
/// one-level difference in a channel; a misplaced shape differs by far more.
/// </summary>
function ColorsMatchWithinRounding(const Left, Right: TAlphaColor): Boolean;
const
  MaxChannelDifference = 2;
begin
  const LeftColor = TAlphaColorRec(Left);
  const RightColor = TAlphaColorRec(Right);
  Result := (Abs(LeftColor.A - RightColor.A) <= MaxChannelDifference) and
            (Abs(LeftColor.R - RightColor.R) <= MaxChannelDifference) and
            (Abs(LeftColor.G - RightColor.G) <= MaxChannelDifference) and
            (Abs(LeftColor.B - RightColor.B) <= MaxChannelDifference);
end;

/// <summary>
/// Counts the pixels of <c>Target</c> inside <c>Bounds</c> that differ, beyond rounding,
/// from the pixel of <c>Reference</c> at the same offset within <c>Bounds</c>, and the
/// pixels outside <c>Bounds</c> that no longer hold <c>MarkerColor</c> exactly.
/// </summary>
procedure CountOffsetPaintDifferences(const Target: TBitmap; const Bounds: TRect; const Reference: TBitmap;
                                      const MarkerColor: TAlphaColor;
                                      out DifferingInside, ChangedOutside: Integer);
begin
  DifferingInside := 0;
  ChangedOutside := 0;

  var TargetData, ReferenceData: TBitmapData;
  if not Target.Map(TMapAccess.Read, TargetData) then
    raise EChart4DException.Create('Could not map the offset paint for comparison');

  try
    if not Reference.Map(TMapAccess.Read, ReferenceData) then
      raise EChart4DException.Create('Could not map the origin paint for comparison');

    try
      for var Y := 0 to Target.Height - 1 do
      begin
        for var X := 0 to Target.Width - 1 do
        begin
          const Pixel = TargetData.GetPixel(X, Y);
          const IsInside = Bounds.Contains(TPoint.Create(X, Y));
          if IsInside and not ColorsMatchWithinRounding(Pixel, ReferenceData.GetPixel(X - Bounds.Left, Y - Bounds.Top)) then
            Inc(DifferingInside);
          if (not IsInside) and (Pixel <> MarkerColor) then
            Inc(ChangedOutside);
        end;
      end;
    finally
      Reference.Unmap(ReferenceData);
    end;
  finally
    Target.Unmap(TargetData);
  end;
end;

/// <summary>Paints <c>Painter</c> into <c>Bounds</c> on <c>Bitmap</c>, inside a scene, after filling the bitmap with <c>FillColor</c>.</summary>
procedure PaintInScene(const Painter: TChartPainter; const Bitmap: TBitmap; const Bounds: TRectF;
                       const FillColor: TAlphaColor);
begin
  const SceneStarted = Bitmap.Canvas.BeginScene;
  if not SceneStarted then
    raise EChart4DException.Create('Failed to begin an FMX scene for the painter bounds check');

  try
    Bitmap.Canvas.Clear(FillColor);
    Painter.Paint(Bitmap.Canvas, Bounds);
  finally
    Bitmap.Canvas.EndScene;
  end;
end;

/// <summary>
/// Proves that <c>TChartPainter</c> paints into bounds away from the canvas origin. The same
/// painter paints once at the origin of a bitmap of the chart's size and once into offset
/// bounds on a larger bitmap filled with a marker color. The offset region must match the
/// origin paint pixel for pixel, at rest and with the tooltip showing, which proves the
/// back buffer copy and the overlay translation; nothing outside the bounds may change.
/// Pointer positions are canvas coordinates, so hovering the offset target must find it
/// and moving outside the bounds must count as leaving.
/// </summary>
procedure VerifyPainterBounds;
const
  OffsetX = 70;
  OffsetY = 40;
  MarkerColor = TAlphaColors.Fuchsia;
begin
  const Plot = TChartPlot.Create;
  try
    BuildTooltipSamplePlot(Plot);
    const Bounds = TRect.Create(OffsetX, OffsetY, OffsetX + DefaultExportWidth, OffsetY + DefaultExportHeight);
    const OriginBounds = RectF(0, 0, DefaultExportWidth, DefaultExportHeight);

    var HitMap: TArray<TChartHitTarget>;
    const HitMapBitmap = TBitmap.Create(DefaultExportWidth, DefaultExportHeight);
    try
      const SceneStarted = HitMapBitmap.Canvas.BeginScene;
      if not SceneStarted then
        raise EChart4DException.Create('Failed to begin an FMX scene for the painter bounds check');

      try
        const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(HitMapBitmap.Canvas);
        TChartRenderer.Render(Plot, ChartCanvas, DefaultExportWidth, DefaultExportHeight, HitMap);
      finally
        HitMapBitmap.Canvas.EndScene;
      end;
    finally
      HitMapBitmap.Free;
    end;

    const Painter = TChartPainter.Create(Plot);
    const Recorder = THoverRecorder.Create;
    const Reference = TBitmap.Create(DefaultExportWidth, DefaultExportHeight);
    const Target = TBitmap.Create(Bounds.Right + OffsetX, Bounds.Bottom + OffsetY);
    try
      Painter.View.OnDataPointHover := Recorder.HandleHover;

      PaintInScene(Painter, Reference, OriginBounds, MarkerColor);
      PaintInScene(Painter, Target, TRectF.Create(Bounds), MarkerColor);

      var DifferingPixels, ChangedOutside: Integer;
      CountOffsetPaintDifferences(Target, Bounds, Reference, MarkerColor, DifferingPixels, ChangedOutside);
      if DifferingPixels <> 0 then
        raise EChart4DException.CreateFmt(
          'painting into offset bounds should reproduce the origin paint, but %d pixels differ', [DifferingPixels]);
      if ChangedOutside <> 0 then
        raise EChart4DException.CreateFmt(
          'painting into offset bounds changed %d pixels outside those bounds', [ChangedOutside]);

      Writeln('FmxCheck: the painter paints into offset bounds and leaves the rest of the canvas alone');

      const HoveredTarget = HitMap[High(HitMap)];
      var TargetPoint := HoveredTarget.Bounds.CenterPoint;
      const IsCircularTarget = (HoveredTarget.Radius > 0);
      if IsCircularTarget then
        TargetPoint := HoveredTarget.Center;

      const HoverX = OffsetX + TargetPoint.X;
      const HoverY = OffsetY + TargetPoint.Y;
      Painter.MouseMove(HoverX, HoverY);
      if (Recorder.EventCount <> 1) or (not Recorder.LastInfo.HasHit) then
        raise EChart4DException.CreateFmt(
          'hovering the offset target should report one hit, but %d events fired', [Recorder.EventCount]);
      if Recorder.LastInfo.CategoryLabel <> HoveredTarget.Info.CategoryLabel then
        raise EChart4DException.CreateFmt(
          'hovering at the offset reported category "%s" but the target there is "%s"',
          [Recorder.LastInfo.CategoryLabel, HoveredTarget.Info.CategoryLabel]);

      const RestingReference = TBitmap.Create;
      try
        RestingReference.Assign(Reference);
        PaintInScene(Painter, Reference, OriginBounds, MarkerColor);
        if CountDifferingPixels(RestingReference, Reference) = 0 then
          raise EChart4DException.Create('hovering a bar should draw a tooltip, but the origin paint is unchanged');
      finally
        RestingReference.Free;
      end;

      PaintInScene(Painter, Target, TRectF.Create(Bounds), MarkerColor);
      CountOffsetPaintDifferences(Target, Bounds, Reference, MarkerColor, DifferingPixels, ChangedOutside);
      if DifferingPixels <> 0 then
        raise EChart4DException.CreateFmt(
          'the tooltip in offset bounds should match the one at the origin, but %d pixels differ', [DifferingPixels]);
      if ChangedOutside <> 0 then
        raise EChart4DException.CreateFmt(
          'the tooltip in offset bounds changed %d pixels outside those bounds', [ChangedOutside]);

      Writeln('FmxCheck: hovering in offset bounds reports the target and draws its tooltip at the offset');

      Painter.MouseMove(OffsetX - 1, HoverY);
      if (Recorder.EventCount <> 2) or Recorder.LastInfo.HasHit then
        raise EChart4DException.Create('moving outside the painted bounds should report leaving the chart');

      Writeln('FmxCheck: moving outside the painted bounds counts as leaving the chart');

      var RaisedOnNegativeSize := False;
      try
        PaintInScene(Painter, Target, RectF(OffsetX, OffsetY, OffsetX - 1, OffsetY + 1), MarkerColor);
      except
        on E: EChart4DException do
          RaisedOnNegativeSize := True;
      end;
      if not RaisedOnNegativeSize then
        raise EChart4DException.Create('painting into bounds of negative width should raise');

      Writeln('FmxCheck: painting into bounds of negative size raises');
    finally
      Target.Free;
      Reference.Free;
      Recorder.Free;
      Painter.Free;
    end;
  finally
    Plot.Free;
  end;
end;

procedure VerifyExportedFile(const ExportPath: string);
begin
  const FileWasCreated = TFile.Exists(ExportPath);
  if not FileWasCreated then
    raise EChart4DException.CreateFmt('Expected PNG file was not created at %s', [ExportPath]);

  const FileSize = TFile.GetSize(ExportPath);
  const FileIsNonEmpty = (FileSize > 0);
  if not FileIsNonEmpty then
    raise EChart4DException.CreateFmt('Exported PNG file at %s is empty', [ExportPath]);

  Writeln('FmxCheck: PNG exported to ', ExportPath, ' (', FileSize, ' bytes)');
end;

begin
  try
    const ExportPath = TPath.Combine(TPath.GetTempPath, 'Chart4DFmxCheck.png');
    const TooltipExportPath = TPath.Combine(TPath.GetTempPath, 'Chart4DFmxTooltip.png');

    ExportSampleChart(ExportPath);
    VerifyExportedFile(ExportPath);

    ExportTooltipSample(TooltipExportPath);
    VerifyExportedFile(TooltipExportPath);

    VerifyPollutedCanvasRender;

    const ControlShotPath = TPath.Combine(TPath.GetTempPath, 'Chart4DFmxControl.png');
    VerifyControlScreenshot(ControlShotPath);
    VerifyExportedFile(ControlShotPath);

    var OutputDir := GetCurrentDir;
    const HasOutputParam = (ParamCount >= 1);
    if HasOutputParam then
      OutputDir := ParamStr(1);
    VerifyEveryChartKindDraws(OutputDir);
    VerifyControlHoverChain(OutputDir);
    VerifyBackBufferCaching;
    VerifyPainterBounds;

    Writeln('FmxCheck: all checks passed');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln('FmxCheck FAILED: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
