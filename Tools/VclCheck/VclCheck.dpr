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
program VclCheck;

/// <summary>
/// Console smoke test that compiles the VCL/GDI+ adapter, renders a small line
/// chart with <c>TChart4D</c>, and exports it to a PNG file in the system temp
/// folder to catch rendering and export regressions early. Also renders a headless
/// hover tooltip onto an offscreen <c>TGPBitmap</c>, simulating a hit against the hit
/// map produced by the public render overload, so the tooltip path can be visually
/// verified without opening a window.
/// </summary>

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
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
  Chart4D.Preview in '..\..\Source\Chart4D.Preview.pas',
  Chart4D.VCL in '..\..\Source\VCL\Chart4D.VCL.pas';

type
  { SetDesigning is protected on TComponent; a descendant declaration is the usual way to
    put a component in the state the form designer would put it in. }
  TComponentDesignCrack = class(TComponent);

procedure ExportSampleChart(const ExportPath: string);
begin
  const Chart = TChart4D.Create(nil);
  try
    Chart.Plot.Title := 'Life expectancy';
    Chart.Plot.Subtitle := 'Selected countries, 1960-2020';
    Chart.Plot.Source := 'Source: World Bank';
    Chart.Plot.Categories := ['1960', '1980', '2000', '2020'];
    Chart.Plot.AddSeries('Netherlands', [73.4, 75.7, 78.0, 81.4]);
    Chart.Plot.AddSeries('Belgium', [69.7, 73.2, 77.7, 80.7]);

    Chart.SaveToPng(ExportPath);
  finally
    Chart.Free;
  end;
end;

procedure BuildTooltipSamplePlot(const Plot: TChartPlot);
begin
  Plot.Kind := TChartKind.Bar;
  Plot.Title := 'Life expectancy';
  Plot.Subtitle := 'Selected countries, 2020';
  Plot.Categories := ['Netherlands', 'Belgium', 'Portugal', 'Spain'];
  Plot.AddSeries('Years', [81.4, 80.7, 81.3, 82.2]);
end;

type
  /// <summary>
  /// Exposes the control's protected mouse entry points, so the hover chain from a mouse
  /// move through the hit test, the hover state and the repaint can be driven without a
  /// visible window or an OS-level mouse. Only the delivery of a real mouse message is
  /// out of reach this way, which is the one link the VCL itself owns.
  /// </summary>
  TDrivableChart = class(TChart4D)
  public
    procedure SimulateMouseMove(const X, Y: Integer);
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

procedure THoverRecorder.HandleHover(Sender: TObject; const Info: TChartHitInfo);
begin
  FLastInfo := Info;
  Inc(FEventCount);
end;

procedure TDrivableChart.SimulateMouseMove(const X, Y: Integer);
begin
  MouseMove([], X, Y);
end;

procedure TDrivableChart.SimulateMouseLeave;
begin
  var Message: TMessage;
  Message := Default(TMessage);
  Message.Msg := CM_MOUSELEAVE;
  CMMouseLeave(Message);
end;

/// <summary>
/// Drives the real hover chain of the control and asserts that it reports the data point
/// under the pointer, and reports leaving it. Hit-target coordinates come from the public
/// render overload at the same size as the control, so the pixel geometry matches.
/// </summary>
procedure VerifyControlHoverChain;
begin
  { The control builds its hit map while it paints, so the check has to make it paint.
    A form that is never shown is enough: PaintTo drives the same paint path a visible
    window would, including the graphic control on it. }
  const Form = TForm.CreateNew(nil);
  try
    Form.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    const Chart = TDrivableChart.Create(Form);
    Chart.Parent := Form;
    BuildTooltipSamplePlot(Chart.Plot);
    Chart.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    const PaintTarget = TBitmap.Create;
    try
      PaintTarget.SetSize(DefaultExportWidth, DefaultExportHeight);
      Form.PaintTo(PaintTarget.Canvas, 0, 0);
    finally
      PaintTarget.Free;
    end;

    var HitMap: TArray<TChartHitTarget>;
    const Bitmap = TGPBitmap.Create(DefaultExportWidth, DefaultExportHeight, PixelFormat32bppARGB);
    try
      const Graphics = TGPGraphics.Create(Bitmap);
      try
        const ChartCanvas: IChartCanvas = TGdiPlusChartCanvas.Create(Graphics);
        TChartRenderer.Render(Chart.Plot, ChartCanvas, DefaultExportWidth, DefaultExportHeight, HitMap);
      finally
        Graphics.Free;
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

      const Target = HitMap[High(HitMap)];
      const HoverPoint = Target.Bounds.CenterPoint;
      Chart.SimulateMouseMove(Round(HoverPoint.X), Round(HoverPoint.Y));

      if Recorder.EventCount <> 1 then
        raise EChart4DException.CreateFmt(
          'hovering a bar should fire OnDataPointHover once, but it fired %d times', [Recorder.EventCount]);
      if not Recorder.LastInfo.HasHit then
        raise EChart4DException.Create('hovering a bar reported no hit');
      if Recorder.LastInfo.CategoryLabel <> Target.Info.CategoryLabel then
        raise EChart4DException.CreateFmt(
          'hovering reported category "%s" but the target under the pointer is "%s"',
          [Recorder.LastInfo.CategoryLabel, Target.Info.CategoryLabel]);

      Writeln(Format('VclCheck: hovering a bar reports %s = %s',
                     [Recorder.LastInfo.CategoryLabel,
                      TAxisScale.FormatValue(Recorder.LastInfo.Value, False)]));

      { Moving inside the same bar must not fire again: the control only reports changes. }
      Chart.SimulateMouseMove(Round(HoverPoint.X), Round(HoverPoint.Y) + 1);
      if Recorder.EventCount <> 1 then
        raise EChart4DException.CreateFmt(
          'moving within the same target should not fire again, but the event fired %d times',
          [Recorder.EventCount]);

      Chart.SimulateMouseLeave;
      if Recorder.EventCount <> 2 then
        raise EChart4DException.CreateFmt(
          'leaving the control should fire OnDataPointHover once more, but it fired %d times',
          [Recorder.EventCount]);
      if Recorder.LastInfo.HasHit then
        raise EChart4DException.Create('leaving the control still reported a hit');

      Writeln('VclCheck: leaving the control clears the hover state');
    finally
      Recorder.Free;
    end;
  finally
    Form.Free;
  end;
end;

/// <summary>
/// Compares the color channels of two <c>pf32bit</c> bitmaps pixel by pixel. Used to prove
/// the back buffer cache through the pixels it produces rather than through a render
/// counter. The alpha byte is ignored because GDI and GDI+ leave it undefined when drawing
/// into a 32-bit DIB through an HDC: it depends on the bitmap's prior contents and the
/// Windows version, not on what was drawn.
/// </summary>
function BitmapsAreIdentical(const Left, Right: TBitmap): Boolean;
const
  ColorChannelsMask = $00FFFFFF;
begin
  Result := (Left.Width = Right.Width) and (Left.Height = Right.Height);
  if not Result then
    Exit;

  for var Y := 0 to Left.Height - 1 do
  begin
    var LeftPixel: PCardinal := Left.ScanLine[Y];
    var RightPixel: PCardinal := Right.ScanLine[Y];
    for var X := 0 to Left.Width - 1 do
    begin
      if (LeftPixel^ and ColorChannelsMask) <> (RightPixel^ and ColorChannelsMask) then
        Exit(False);
      Inc(LeftPixel);
      Inc(RightPixel);
    end;
  end;
end;

/// <summary>
/// Proves the VCL control caches its render through observable pixels.
/// <c>TChartSeries.Values</c> writes straight to its field with no change notification, so
/// assigning it directly changes what a fresh render would draw without telling the
/// control anything: a cached repaint must stay byte-identical to the pixels captured
/// before the assignment. A real mutator, which does fire <c>OnChanged</c>, must invalidate
/// the cache and change what is painted; a resize must do the same, proven by comparing
/// the resized repaint against an independent render at that size.
/// </summary>
procedure VerifyBackBufferCaching;
begin
  const Form = TForm.CreateNew(nil);
  try
    { A borderless form's client area is its whole bounds, so PaintTo output pixel-aligns
      exactly with the chart control's own content; that is what lets the resize check
      below compare it directly against an independent render at the same size. }
    Form.BorderStyle := bsNone;
    Form.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    const Chart = TChart4D.Create(Form);
    Chart.Parent := Form;
    Chart.Plot.Kind := TChartKind.Bar;
    Chart.Plot.Title := 'Life expectancy';
    Chart.Plot.Categories := ['Netherlands', 'Belgium', 'France', 'Germany'];
    const Series = Chart.Plot.AddSeries('2020', [81.4, 80.7, 82.2, 81.0]);
    Chart.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    const PaintTarget = TBitmap.Create;
    try
      PaintTarget.PixelFormat := pf32bit;
      PaintTarget.SetSize(DefaultExportWidth, DefaultExportHeight);
      Form.PaintTo(PaintTarget.Canvas, 0, 0);

      const BaselineRender = TBitmap.Create;
      try
        BaselineRender.Assign(PaintTarget);

        Series.Values := [70.0, 70.0, 70.0, 70.0];
        Form.PaintTo(PaintTarget.Canvas, 0, 0);
        if not BitmapsAreIdentical(BaselineRender, PaintTarget) then
          raise EChart4DException.Create(
            'assigning Values without firing OnChanged should reuse the cached render, but the pixels changed');

        Writeln('VclCheck: mutating series Values silently reuses the cached render (pixels unchanged)');

        Chart.Plot.AddSeries('2021', [81.5, 80.8, 82.3, 81.1]);
        Form.PaintTo(PaintTarget.Canvas, 0, 0);
        if BitmapsAreIdentical(BaselineRender, PaintTarget) then
          raise EChart4DException.Create(
            'adding a series fires OnChanged and should invalidate the cached render, but the pixels are unchanged');

        Writeln('VclCheck: a real plot mutation invalidates the cache and repaints');
      finally
        BaselineRender.Free;
      end;

      const NewWidth = DefaultExportWidth + 10;
      Chart.SetBounds(0, 0, NewWidth, DefaultExportHeight);
      Form.SetBounds(0, 0, NewWidth, DefaultExportHeight);
      PaintTarget.SetSize(NewWidth, DefaultExportHeight);
      Form.PaintTo(PaintTarget.Canvas, 0, 0);

      const ExpectedRender = TBitmap.Create;
      try
        ExpectedRender.PixelFormat := pf32bit;
        ExpectedRender.SetSize(NewWidth, DefaultExportHeight);

        const Graphics = TGPGraphics.Create(ExpectedRender.Canvas.Handle);
        try
          const ChartCanvas: IChartCanvas = TGdiPlusChartCanvas.Create(Graphics);
          TChartRenderer.Render(Chart.Plot, ChartCanvas, NewWidth, DefaultExportHeight);
        finally
          Graphics.Free;
        end;

        if not BitmapsAreIdentical(ExpectedRender, PaintTarget) then
          raise EChart4DException.Create(
            'resizing the control should invalidate the cache and re-render at the new size, but the ' +
            'repaint does not match an independent render at that size');

        Writeln('VclCheck: resizing the control invalidates the cache and re-renders at the new size');
      finally
        ExpectedRender.Free;
      end;
    finally
      PaintTarget.Free;
    end;
  finally
    Form.Free;
  end;
end;

/// <summary>
/// Counts the pixels of <c>Target</c> inside <c>Bounds</c> whose color channels differ from
/// the pixel of <c>Reference</c> at the same offset within <c>Bounds</c>. The alpha byte is
/// ignored for the reason given at <c>BitmapsAreIdentical</c>.
/// </summary>
function CountRegionDifferences(const Target: TBitmap; const Bounds: TRect; const Reference: TBitmap): Integer;
const
  ColorChannelsMask = $00FFFFFF;
begin
  Result := 0;
  for var Y := 0 to Bounds.Height - 1 do
  begin
    var TargetPixel: PCardinal := Target.ScanLine[Bounds.Top + Y];
    Inc(TargetPixel, Bounds.Left);
    var ReferencePixel: PCardinal := Reference.ScanLine[Y];
    for var X := 0 to Bounds.Width - 1 do
    begin
      if (TargetPixel^ and ColorChannelsMask) <> (ReferencePixel^ and ColorChannelsMask) then
        Inc(Result);
      Inc(TargetPixel);
      Inc(ReferencePixel);
    end;
  end;
end;

/// <summary>Counts the pixels of <c>Target</c> outside <c>Bounds</c> that no longer hold <c>MarkerColor</c>.</summary>
function CountChangedPixelsOutside(const Target: TBitmap; const Bounds: TRect; const MarkerColor: TColor): Integer;
const
  ColorChannelsMask = $00FFFFFF;
begin
  { The marker is a color whose red and blue channels are equal, so its TColor value and
    its pf32bit pixel value are the same despite the reversed channel order. }
  Result := 0;
  for var Y := 0 to Target.Height - 1 do
  begin
    var Pixel: PCardinal := Target.ScanLine[Y];
    for var X := 0 to Target.Width - 1 do
    begin
      const IsOutside = not Bounds.Contains(TPoint.Create(X, Y));
      if IsOutside and ((Pixel^ and ColorChannelsMask) <> Cardinal(MarkerColor)) then
        Inc(Result);
      Inc(Pixel);
    end;
  end;
end;

/// <summary>
/// Proves that <c>TChartPainter</c> paints into bounds away from the canvas origin. The same
/// painter paints once at the origin of a bitmap of the chart's size and once into offset
/// bounds on a larger bitmap filled with a marker color. The offset region must match the
/// origin paint pixel for pixel, at rest and with the tooltip showing, which proves the
/// back buffer copy and the overlay translation; nothing outside the bounds may change.
/// Pointer positions are canvas coordinates, so hovering the offset target must find it
/// and moving outside the bounds must count as leaving. The hovered point is the last one
/// of a line chart, whose tooltip is pushed against the right edge of the chart, so the
/// check also covers a tooltip border that would otherwise stroke across the bounds.
/// </summary>
procedure VerifyPainterBounds;
const
  OffsetX = 70;
  OffsetY = 40;
  MarkerColor = clFuchsia;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Title := 'Life expectancy';
    Plot.Subtitle := 'Selected countries, 1960-2020';
    Plot.Categories := ['1960', '1980', '2000', '2020'];
    Plot.AddSeries('Netherlands', [73.5, 75.8, 78.0, 81.4]);
    Plot.AddSeries('Portugal', [61.2, 71.0, 76.4, 80.8]);
    const Bounds = TRect.Create(OffsetX, OffsetY, OffsetX + DefaultExportWidth, OffsetY + DefaultExportHeight);

    var HitMap: TArray<TChartHitTarget>;
    const HitMapBitmap = TGPBitmap.Create(DefaultExportWidth, DefaultExportHeight, PixelFormat32bppARGB);
    try
      const Graphics = TGPGraphics.Create(HitMapBitmap);
      try
        const ChartCanvas: IChartCanvas = TGdiPlusChartCanvas.Create(Graphics);
        TChartRenderer.Render(Plot, ChartCanvas, DefaultExportWidth, DefaultExportHeight, HitMap);
      finally
        Graphics.Free;
      end;
    finally
      HitMapBitmap.Free;
    end;

    const Painter = TChartPainter.Create(Plot);
    const Recorder = THoverRecorder.Create;
    const Reference = TBitmap.Create;
    const Target = TBitmap.Create;
    try
      Painter.View.OnDataPointHover := Recorder.HandleHover;
      Reference.PixelFormat := pf32bit;
      Reference.SetSize(DefaultExportWidth, DefaultExportHeight);
      Target.PixelFormat := pf32bit;
      Target.SetSize(Bounds.Right + OffsetX, Bounds.Bottom + OffsetY);

      Painter.Paint(Reference.Canvas, DefaultExportWidth, DefaultExportHeight);
      Target.Canvas.Brush.Color := MarkerColor;
      Target.Canvas.FillRect(TRect.Create(0, 0, Target.Width, Target.Height));
      Painter.Paint(Target.Canvas, Bounds);

      var DifferingPixels := CountRegionDifferences(Target, Bounds, Reference);
      if DifferingPixels <> 0 then
        raise EChart4DException.CreateFmt(
          'painting into offset bounds should reproduce the origin paint, but %d pixels differ', [DifferingPixels]);
      var ChangedOutside := CountChangedPixelsOutside(Target, Bounds, MarkerColor);
      if ChangedOutside <> 0 then
        raise EChart4DException.CreateFmt(
          'painting into offset bounds changed %d pixels outside those bounds', [ChangedOutside]);

      Writeln('VclCheck: the painter paints into offset bounds and leaves the rest of the canvas alone');

      const HoveredTarget = HitMap[High(HitMap)];
      const HoverX = OffsetX + Round(HoveredTarget.Center.X);
      const HoverY = OffsetY + Round(HoveredTarget.Center.Y);
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
        Painter.Paint(Reference.Canvas, DefaultExportWidth, DefaultExportHeight);
        if BitmapsAreIdentical(RestingReference, Reference) then
          raise EChart4DException.Create('hovering a bar should draw a tooltip, but the origin paint is unchanged');
      finally
        RestingReference.Free;
      end;

      Target.Canvas.FillRect(TRect.Create(0, 0, Target.Width, Target.Height));
      Painter.Paint(Target.Canvas, Bounds);

      DifferingPixels := CountRegionDifferences(Target, Bounds, Reference);
      if DifferingPixels <> 0 then
        raise EChart4DException.CreateFmt(
          'the tooltip in offset bounds should match the one at the origin, but %d pixels differ', [DifferingPixels]);
      ChangedOutside := CountChangedPixelsOutside(Target, Bounds, MarkerColor);
      if ChangedOutside <> 0 then
        raise EChart4DException.CreateFmt(
          'the tooltip in offset bounds changed %d pixels outside those bounds', [ChangedOutside]);

      Writeln('VclCheck: hovering in offset bounds reports the target and draws its tooltip at the offset');

      Painter.MouseMove(OffsetX - 1, HoverY);
      if (Recorder.EventCount <> 2) or Recorder.LastInfo.HasHit then
        raise EChart4DException.Create('moving outside the painted bounds should report leaving the chart');

      Writeln('VclCheck: moving outside the painted bounds counts as leaving the chart');

      var RaisedOnNegativeSize := False;
      try
        Painter.Paint(Target.Canvas, TRect.Create(OffsetX, OffsetY, OffsetX - 1, OffsetY + 1));
      except
        on E: EChart4DException do
          RaisedOnNegativeSize := True;
      end;
      if not RaisedOnNegativeSize then
        raise EChart4DException.Create('painting into bounds of negative width should raise');

      Writeln('VclCheck: painting into bounds of negative size raises');
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

function SimulateHover(const HitMap: TArray<TChartHitTarget>): TChartHitInfo;
begin
  const HasHitTargets = (Length(HitMap) > 0);
  if not HasHitTargets then
    raise EChart4DException.Create('No hit targets produced for the tooltip sample chart');

  const SimulatedTarget = HitMap[Length(HitMap) div 2];
  const SimulatedPoint = SimulatedTarget.Bounds.CenterPoint;
  const FoundHit = TChartTooltip.FindTarget(HitMap, SimulatedPoint.X, SimulatedPoint.Y, Result);
  if not FoundHit then
    raise EChart4DException.Create('Simulated hover position did not hit any target');
end;

procedure ExportTooltipSample(const ExportPath: string);
begin
  const Plot = TChartPlot.Create;
  try
    BuildTooltipSamplePlot(Plot);

    const Bitmap = TGPBitmap.Create(DefaultExportWidth, DefaultExportHeight, PixelFormat32bppARGB);
    try
      const Graphics = TGPGraphics.Create(Bitmap);
      try
        const ChartCanvas: IChartCanvas = TGdiPlusChartCanvas.Create(Graphics);

        var HitMap: TArray<TChartHitTarget>;
        TChartRenderer.Render(Plot, ChartCanvas, DefaultExportWidth, DefaultExportHeight, HitMap);

        const HoverInfo = SimulateHover(HitMap);
        TChartTooltip.Draw(ChartCanvas, Plot.Style, HoverInfo, DefaultExportWidth, DefaultExportHeight);
      finally
        Graphics.Free;
      end;

      TChart4DPng.Save(Bitmap, ExportPath);
    finally
      Bitmap.Free;
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
  const FileIsLargeEnough = (FileSize > 1024);
  if not FileIsLargeEnough then
    raise EChart4DException.CreateFmt('PNG file is too small (%d bytes): %s', [FileSize, ExportPath]);

  Writeln('VclCheck: PNG exported to ', ExportPath, ' (', FileSize, ' bytes)');
end;

/// <summary>
/// Every published property must survive being written to a DFM stream and read back,
/// which is what the form designer does. A default() clause that does not match the value
/// the plot starts out with would drop the property from the stream and load the wrong
/// value without saying anything.
/// </summary>
procedure VerifyPublishedPropertiesRoundTrip;
begin
  const Stream = TMemoryStream.Create;
  try
    const Saved = TChart4D.Create(nil);
    try
      Saved.Name := 'SavedChart';
      Saved.Kind := TChartKind.StackedBar;
      Saved.Title := 'Almost everyone is online';
      Saved.Subtitle := 'Share of the population using the internet';
      Saved.Source := 'Source: World Bank';
      Saved.Orientation := TChartOrientation.Horizontal;
      Saved.StackMode := TStackMode.Proportions;
      Saved.LegendPosition := TLegendPosition.Bottom;
      Saved.LegendReversed := True;
      Saved.ValueLabels := TValueLabelMode.Extremes;
      Saved.HighlightedSeriesIndex := 1;
      Saved.DonutCenterText := '91%';
      Saved.ShowTooltips := False;

      Stream.WriteComponent(Saved);
    finally
      Saved.Free;
    end;

    Stream.Position := 0;

    const Loaded = TChart4D.Create(nil);
    try
      Stream.ReadComponent(Loaded);

      if Loaded.Kind <> TChartKind.StackedBar then
        raise EChart4DException.Create('Kind did not survive the DFM round trip');
      if Loaded.Title <> 'Almost everyone is online' then
        raise EChart4DException.Create('Title did not survive the DFM round trip');
      if Loaded.Subtitle <> 'Share of the population using the internet' then
        raise EChart4DException.Create('Subtitle did not survive the DFM round trip');
      if Loaded.Source <> 'Source: World Bank' then
        raise EChart4DException.Create('Source did not survive the DFM round trip');
      if Loaded.Orientation <> TChartOrientation.Horizontal then
        raise EChart4DException.Create('Orientation did not survive the DFM round trip');
      if Loaded.StackMode <> TStackMode.Proportions then
        raise EChart4DException.Create('StackMode did not survive the DFM round trip');
      if Loaded.LegendPosition <> TLegendPosition.Bottom then
        raise EChart4DException.Create('LegendPosition did not survive the DFM round trip');
      if not Loaded.LegendReversed then
        raise EChart4DException.Create('LegendReversed did not survive the DFM round trip');
      if Loaded.ValueLabels <> TValueLabelMode.Extremes then
        raise EChart4DException.Create('ValueLabels did not survive the DFM round trip');
      if Loaded.HighlightedSeriesIndex <> 1 then
        raise EChart4DException.Create('HighlightedSeriesIndex did not survive the DFM round trip');
      if Loaded.DonutCenterText <> '91%' then
        raise EChart4DException.Create('DonutCenterText did not survive the DFM round trip');
      if Loaded.ShowTooltips then
        raise EChart4DException.Create('ShowTooltips did not survive the DFM round trip');

      Writeln('VclCheck: every published property survives a DFM round trip');
    finally
      Loaded.Free;
    end;
  finally
    Stream.Free;
  end;
end;

/// <summary>
/// An empty chart draws nothing at run time and a sample chart at design time, so the two
/// renders must differ. That sample is what puts a recognisable chart on the form while
/// the developer is still deciding what data to feed it.
/// </summary>
procedure VerifyDesignTimePreview;
begin
  const Form = TForm.CreateNew(nil);
  try
    Form.BorderStyle := bsNone;
    Form.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    const Chart = TChart4D.Create(Form);
    Chart.Parent := Form;
    Chart.SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);

    const RuntimeRender = TBitmap.Create;
    try
      RuntimeRender.PixelFormat := pf32bit;
      RuntimeRender.SetSize(DefaultExportWidth, DefaultExportHeight);
      Form.PaintTo(RuntimeRender.Canvas, 0, 0);

      const DesignRender = TBitmap.Create;
      try
        DesignRender.PixelFormat := pf32bit;
        DesignRender.SetSize(DefaultExportWidth, DefaultExportHeight);

        TComponentDesignCrack(Chart).SetDesigning(True);
        Chart.Invalidate;
        Form.PaintTo(DesignRender.Canvas, 0, 0);

        const RendersTheSame = BitmapsAreIdentical(RuntimeRender, DesignRender);
        if RendersTheSame then
          raise EChart4DException.Create('An empty chart rendered the same at design time as at run time: the sample preview never drew');

        Writeln('VclCheck: design-time preview renders a sample chart');
      finally
        DesignRender.Free;
      end;
    finally
      RuntimeRender.Free;
    end;
  finally
    Form.Free;
  end;
end;

begin
  try
    const ExportPath = TPath.Combine(TPath.GetTempPath, 'Chart4DVclCheck.png');
    const TooltipExportPath = TPath.Combine(TPath.GetTempPath, 'Chart4DVclTooltip.png');

    ExportSampleChart(ExportPath);
    VerifyExportedFile(ExportPath);

    ExportTooltipSample(TooltipExportPath);
    VerifyExportedFile(TooltipExportPath);

    VerifyControlHoverChain;
    VerifyBackBufferCaching;
    VerifyPainterBounds;
    VerifyDesignTimePreview;
    VerifyPublishedPropertiesRoundTrip;

    Writeln('VclCheck: all checks passed');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln('VclCheck FAILED: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
