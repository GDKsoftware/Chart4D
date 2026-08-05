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
unit Chart4D.FMX;

/// <summary>
/// The FireMonkey adapter: <c>TFmxChartCanvas</c> implements <c>IChartCanvas</c> on top
/// of <c>FMX.Graphics.TCanvas</c>, and <c>TChart4D</c> is the FMX control that owns a
/// <c>TChartPlot</c>, repaints on <c>OnChanged</c>, and exports PNG files.
/// </summary>

interface

uses
  System.Types,
  System.UITypes,
  System.Classes,
  System.SysUtils,
  System.Math,
  System.Math.Vectors,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.TextLayout,
  Chart4D.Types,
  Chart4D.Consts,
  Chart4D.Canvas.Interfaces,
  Chart4D.Hover,
  Chart4D.Plot,
  Chart4D.Renderer,
  Chart4D.Tooltip;

type
  /// <summary>
  /// <c>IChartCanvas</c> implemented on top of an <c>FMX.Graphics.TCanvas</c>. Text is
  /// measured and drawn through <c>TTextLayout</c>, dashed strokes use
  /// <c>TStrokeDash.Dash</c>, and polylines/polygons use <c>TPathData</c> and the
  /// canvas' native polygon fill.
  /// </summary>
  TFmxChartCanvas = class(TInterfacedObject, IChartCanvas)
  private
    FCanvas: FMX.Graphics.TCanvas;

    procedure ConfigureTextLayout(const Layout: TTextLayout; const Text: string;
                                  const TextStyle: TChartTextStyle);
    procedure ApplyStroke(const Color: TAlphaColor; const StrokeWidth: Single; const Dashed: Boolean);
    procedure ApplyFill(const Color: TAlphaColor);
    function BuildPolylinePath(const Points: TArray<TPointF>): TPathData;
    function TryLoadBitmap(const Bitmap: TBitmap; const FilePath: string): Boolean;

  public
    /// <summary>Creates a chart canvas that draws on the given FMX canvas.</summary>
    constructor Create(const Canvas: FMX.Graphics.TCanvas);

    /// <summary>Fills a <c>Width</c> x <c>Height</c> rectangle at the origin with a solid color.</summary>
    procedure FillBackground(const Width, Height: Single; const Color: TAlphaColor);
    /// <summary>Draws a single straight line, optionally dashed.</summary>
    procedure DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                       const StrokeWidth: Single; const Dashed: Boolean);
    /// <summary>Draws a connected sequence of line segments.</summary>
    procedure DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                           const StrokeWidth: Single);
    /// <summary>Fills a closed polygon defined by its vertices.</summary>
    procedure FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
    /// <summary>Fills an axis-aligned rectangle.</summary>
    procedure FillRect(const Bounds: TRectF; const Color: TAlphaColor);
    /// <summary>Fills a circle given its center and radius.</summary>
    procedure FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
    /// <summary>Draws text anchored at <c>(X, Y)</c> according to <c>AlignH</c>/<c>AlignV</c>.</summary>
    procedure DrawText(const X, Y: Single; const Text: string;
                       const TextStyle: TChartTextStyle;
                       const AlignH: TTextAlignH; const AlignV: TTextAlignV);
    /// <summary>Measures the size a piece of text would occupy in the given style.</summary>
    function MeasureText(const Text: string;
                         const TextStyle: TChartTextStyle): TSizeF;
    /// <summary>Draws an image loaded from <c>FilePath</c>, aspect-fit inside <c>Bounds</c>, right-aligned.</summary>
    procedure DrawImage(const FilePath: string; const Bounds: TRectF);
  end;

  /// <summary>
  /// An FMX control that owns a <c>TChartPlot</c> and renders it with
  /// <c>TChartRenderer</c> through <c>TFmxChartCanvas</c>. Repaints itself whenever the
  /// plot changes, tracks the hovered data point on mouse move, and can export the
  /// current plot to a PNG file at any size (never including the hover tooltip).
  /// </summary>
  TChart4D = class(TControl)
  private
    FPlot: TChartPlot;
    FHover: TChartHoverState;
    FOnDataPointHover: TChartHoverEvent;
    FBackBuffer: TBitmap;
    FBackBufferValid: Boolean;

    procedure RenderForExport(const Canvas: FMX.Graphics.TCanvas; const Width, Height: Single);
    procedure EnsureBackBuffer;
    procedure DrawTooltipOverlay;
    procedure PlotChanged(Sender: TObject);
    procedure HoverChanged;
    function GetShowTooltips: Boolean;
    procedure SetShowTooltips(const Value: Boolean);

  protected
    /// <summary>
    /// Re-renders the plot into <c>FBackBuffer</c> and refreshes the stored hit map.
    /// Called only when the buffer is invalid.
    /// </summary>
    procedure RenderChartToBackBuffer;
    /// <summary>Blits the cached back buffer, re-rendering it first only when the plot
    /// or the control size has changed, then draws the hover tooltip on top.</summary>
    procedure Paint; override;
    /// <summary>Invalidates the buffered chart render when the control size changes.</summary>
    procedure Resize; override;
    /// <summary>Hit-tests the stored hit map and updates the hover state.</summary>
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    /// <summary>Clears the hover state when the pointer leaves the control.</summary>
    procedure DoMouseLeave; override;

  public
    /// <summary>Creates the control with an empty, owned <c>TChartPlot</c>.</summary>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Destroys the control and its owned plot.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Renders the owned plot into an offscreen bitmap of <c>Width</c> x <c>Height</c>
    /// pixels and saves it as a PNG file at <c>FilePath</c>. Never draws the hover
    /// tooltip.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when the plot has no series to export.</exception>
    procedure SaveToPng(const FilePath: string;
                        const Width: Integer = DefaultExportWidth;
                        const Height: Integer = DefaultExportHeight);

    /// <summary>The owned chart data and configuration.</summary>
    property Plot: TChartPlot read FPlot;
    /// <summary>Whether the hover tooltip is drawn during <c>Paint</c>. Default <c>True</c>.</summary>
    property ShowTooltips: Boolean read GetShowTooltips write SetShowTooltips;
    /// <summary>Fired when the hovered data point changes, including when the pointer leaves every target.</summary>
    property OnDataPointHover: TChartHoverEvent read FOnDataPointHover write FOnDataPointHover;
  end;

implementation

resourcestring
  SFailedToBeginScene = 'Failed to begin an FMX scene on the export bitmap for "%s"';
  SFailedToBeginBackBufferScene = 'Failed to begin an FMX scene on the control''s back buffer';

constructor TFmxChartCanvas.Create(const Canvas: FMX.Graphics.TCanvas);
begin
  inherited Create;
  FCanvas := Canvas;
end;

procedure TFmxChartCanvas.FillBackground(const Width, Height: Single; const Color: TAlphaColor);
begin
  ApplyFill(Color);
  FCanvas.FillRect(RectF(0, 0, Width, Height), 1.0);
end;

procedure TFmxChartCanvas.DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                                   const StrokeWidth: Single; const Dashed: Boolean);
begin
  ApplyStroke(Color, StrokeWidth, Dashed);
  FCanvas.DrawLine(PointF(X1, Y1), PointF(X2, Y2), 1.0);
end;

procedure TFmxChartCanvas.DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                                       const StrokeWidth: Single);
begin
  const HasEnoughPoints = (Length(Points) >= 2);
  if not HasEnoughPoints then
    Exit;

  const Path = BuildPolylinePath(Points);
  try
    ApplyStroke(Color, StrokeWidth, False);
    FCanvas.DrawPath(Path, 1.0);
  finally
    Path.Free;
  end;
end;

procedure TFmxChartCanvas.FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
begin
  const HasEnoughPoints = (Length(Points) >= 3);
  if not HasEnoughPoints then
    Exit;

  ApplyFill(Color);
  FCanvas.FillPolygon(TPolygon(Points), 1.0);
end;

procedure TFmxChartCanvas.FillRect(const Bounds: TRectF; const Color: TAlphaColor);
begin
  ApplyFill(Color);
  FCanvas.FillRect(Bounds, 1.0);
end;

procedure TFmxChartCanvas.FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
begin
  const Bounds = RectF(CenterX - Radius, CenterY - Radius, CenterX + Radius, CenterY + Radius);

  ApplyFill(Color);
  FCanvas.FillEllipse(Bounds, 1.0);
end;

procedure TFmxChartCanvas.DrawText(const X, Y: Single; const Text: string;
                                   const TextStyle: TChartTextStyle;
                                   const AlignH: TTextAlignH; const AlignV: TTextAlignV);
begin
  const Layout = TTextLayoutManager.DefaultTextLayout.Create(FCanvas);
  try
    ConfigureTextLayout(Layout, Text, TextStyle);

    const Size = TSizeF.Create(Layout.TextWidth, Layout.TextHeight);
    Layout.TopLeft := TChartTextAlign.ResolveOrigin(X, Y, Size, AlignH, AlignV);
    Layout.RenderLayout(FCanvas);
  finally
    Layout.Free;
  end;
end;

function TFmxChartCanvas.MeasureText(const Text: string;
                                     const TextStyle: TChartTextStyle): TSizeF;
begin
  const Layout = TTextLayoutManager.DefaultTextLayout.Create(FCanvas);
  try
    ConfigureTextLayout(Layout, Text, TextStyle);
    Result := TSizeF.Create(Layout.TextWidth, Layout.TextHeight);
  finally
    Layout.Free;
  end;
end;

procedure TFmxChartCanvas.DrawImage(const FilePath: string; const Bounds: TRectF);
begin
  const HasFilePath = not FilePath.IsEmpty;
  if not HasFilePath then
    Exit;

  const Bitmap = TBitmap.Create;
  try
    const LoadSucceeded = TryLoadBitmap(Bitmap, FilePath);
    const HasValidSize = (Bitmap.Width > 0) and (Bitmap.Height > 0);
    const CanDraw = (LoadSucceeded and HasValidSize);
    if not CanDraw then
      Exit;

    const DestRect = TChartImageFit.Fit(Bitmap.Width, Bitmap.Height, Bounds);
    const SrcRect = RectF(0, 0, Bitmap.Width, Bitmap.Height);
    FCanvas.DrawBitmap(Bitmap, SrcRect, DestRect, 1.0);
  finally
    Bitmap.Free;
  end;
end;

procedure TFmxChartCanvas.ConfigureTextLayout(const Layout: TTextLayout; const Text: string;
                                              const TextStyle: TChartTextStyle);
begin
  Layout.BeginUpdate;
  try
    Layout.WordWrap := False;
    Layout.Text := Text;
    Layout.Color := TextStyle.Color;
    Layout.Font.Family := TextStyle.FontName;
    Layout.Font.Size := TextStyle.Size;

    var FontStyle: TFontStyles := [];
    if TextStyle.Bold then
      FontStyle := [TFontStyle.fsBold];
    Layout.Font.Style := FontStyle;
  finally
    Layout.EndUpdate;
  end;
end;

procedure TFmxChartCanvas.ApplyStroke(const Color: TAlphaColor; const StrokeWidth: Single; const Dashed: Boolean);
begin
  FCanvas.Stroke.Kind := TBrushKind.Solid;
  FCanvas.Stroke.Color := Color;
  FCanvas.Stroke.Thickness := StrokeWidth;

  var DashKind := TStrokeDash.Solid;
  if Dashed then
    DashKind := TStrokeDash.Dash;
  FCanvas.Stroke.Dash := DashKind;
end;

procedure TFmxChartCanvas.ApplyFill(const Color: TAlphaColor);
begin
  FCanvas.Fill.Kind := TBrushKind.Solid;
  FCanvas.Fill.Color := Color;
end;

function TFmxChartCanvas.BuildPolylinePath(const Points: TArray<TPointF>): TPathData;
begin
  Result := TPathData.Create;

  const HasPoints = (Length(Points) > 0);
  if not HasPoints then
    Exit;

  Result.MoveTo(Points[0]);
  for var Index := 1 to High(Points) do
  begin
    Result.LineTo(Points[Index]);
  end;
end;

function TFmxChartCanvas.TryLoadBitmap(const Bitmap: TBitmap; const FilePath: string): Boolean;
begin
  Result := True;
  try
    Bitmap.LoadFromFile(FilePath);
  except
    on E: Exception do
      Result := False;
  end;
end;

constructor TChart4D.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPlot := TChartPlot.Create;
  FPlot.OnChanged := PlotChanged;
  FHover := TChartHoverState.Create;
  HitTest := True;
  FBackBuffer := TBitmap.Create;
  SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);
end;

destructor TChart4D.Destroy;
begin
  FHover.Free;
  FBackBuffer.Free;
  FPlot.Free;
  inherited Destroy;
end;

function TChart4D.GetShowTooltips: Boolean;
begin
  Result := FHover.Enabled;
end;

procedure TChart4D.SetShowTooltips(const Value: Boolean);
begin
  FHover.Enabled := Value;
end;

procedure TChart4D.Paint;
begin
  EnsureBackBuffer;
  Canvas.DrawBitmap(FBackBuffer, RectF(0, 0, FBackBuffer.Width, FBackBuffer.Height),
                    RectF(0, 0, Width, Height), 1.0);
  DrawTooltipOverlay;
end;

procedure TChart4D.Resize;
begin
  inherited Resize;
  FBackBufferValid := False;
end;

procedure TChart4D.EnsureBackBuffer;
begin
  const SizeChanged = (FBackBuffer.Width <> Round(Width)) or (FBackBuffer.Height <> Round(Height));
  if SizeChanged then
  begin
    FBackBuffer.SetSize(Round(Width), Round(Height));
    FBackBufferValid := False;
  end;

  if not FBackBufferValid then
  begin
    RenderChartToBackBuffer;
    FBackBufferValid := True;
  end;
end;

procedure TChart4D.RenderChartToBackBuffer;
begin
  const SceneStarted = FBackBuffer.Canvas.BeginScene;
  if not SceneStarted then
    raise EChart4DException.Create(SFailedToBeginBackBufferScene);

  try
    const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(FBackBuffer.Canvas);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(FPlot, ChartCanvas, Width, Height, HitMap);
    FHover.HitMap := HitMap;
  finally
    FBackBuffer.Canvas.EndScene;
  end;
end;

procedure TChart4D.DrawTooltipOverlay;
begin
  if not FHover.IsVisible then
    Exit;

  const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(Canvas);
  TChartTooltip.Draw(ChartCanvas, FPlot.Style, FHover.Info, Width, Height, FPlot.YAxis.LocaleName);
end;

procedure TChart4D.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited MouseMove(Shift, X, Y);

  if FHover.MoveTo(X, Y) then
    HoverChanged;
end;

procedure TChart4D.DoMouseLeave;
begin
  inherited DoMouseLeave;

  if FHover.Leave then
    HoverChanged;
end;

procedure TChart4D.SaveToPng(const FilePath: string;
                             const Width: Integer = DefaultExportWidth;
                             const Height: Integer = DefaultExportHeight);
begin
  const HasNoSeries = (FPlot.Series.Count = 0);
  if HasNoSeries then
    raise EChart4DException.Create(SNoSeriesToRender);

  const Bitmap = TBitmap.Create(Width, Height);
  try
    const SceneStarted = Bitmap.Canvas.BeginScene;
    if not SceneStarted then
      raise EChart4DException.CreateFmt(SFailedToBeginScene, [FilePath]);

    try
      RenderForExport(Bitmap.Canvas, Width, Height);
    finally
      Bitmap.Canvas.EndScene;
    end;

    Bitmap.SaveToFile(FilePath);
  finally
    Bitmap.Free;
  end;
end;

procedure TChart4D.PlotChanged(Sender: TObject);
begin
  FBackBufferValid := False;
  Repaint;
end;

procedure TChart4D.RenderForExport(const Canvas: FMX.Graphics.TCanvas; const Width, Height: Single);
begin
  const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(Canvas);
  TChartRenderer.Render(FPlot, ChartCanvas, Width, Height);
end;

procedure TChart4D.HoverChanged;
begin
  if Assigned(FOnDataPointHover) then
    FOnDataPointHover(Self, FHover.Info);

  Repaint;
end;

end.
