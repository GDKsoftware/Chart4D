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
  Chart4D.VCL in '..\..\Source\VCL\Chart4D.VCL.pas';

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
/// Compares two same-format bitmaps row by row. Used to prove the back buffer cache
/// through the pixels it produces rather than through a render counter.
/// </summary>
function BitmapsAreIdentical(const Left, Right: TBitmap): Boolean;
begin
  Result := (Left.Width = Right.Width) and (Left.Height = Right.Height);
  if not Result then
    Exit;

  const RowBytes = Left.Width * 4;
  for var Y := 0 to Left.Height - 1 do
  begin
    if not CompareMem(Left.ScanLine[Y], Right.ScanLine[Y], RowBytes) then
      Exit(False);
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
