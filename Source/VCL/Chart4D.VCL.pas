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
unit Chart4D.VCL;

/// <summary>
/// The VCL adapter: a GDI+ backed <c>IChartCanvas</c> implementation and the
/// <c>TChart4D</c> graphic control that owns a <c>TChartPlot</c>, repaints on
/// <c>OnChanged</c>, and exports PNG snapshots.
/// </summary>

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  Vcl.Controls,
  Vcl.Graphics,
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Math,
  Chart4D.Types,
  Chart4D.Consts,
  Chart4D.Canvas.Interfaces,
  Chart4D.Hover,
  Chart4D.Plot,
  Chart4D.Renderer,
  Chart4D.Tooltip;

type
  /// <summary>
  /// An <c>IChartCanvas</c> implementation backed by GDI+ (<c>Winapi.GDIPOBJ</c>),
  /// with antialiasing and pixel-unit fonts enabled on the wrapped
  /// <c>TGPGraphics</c>.
  /// </summary>
  TGdiPlusChartCanvas = class(TInterfacedObject, IChartCanvas)
  private const
    MaxTextLayoutExtent: Single = 10000;

  private
    FGraphics: TGPGraphics;

    function ToGpPoints(const Points: TArray<TPointF>): TArray<TGPPointF>;
    function ToGpRect(const Bounds: TRectF): TGPRectF;
    function CreateFont(const TextStyle: TChartTextStyle): TGPFont;
    function CreateMeasureFormat: TGPStringFormat;
    function MeasureTextSize(const Text: string; const Font: TGPFont;
                             const Format: TGPStringFormat): TSizeF;

  public
    /// <summary>
    /// Wraps <c>Graphics</c> and enables antialiasing (<c>SmoothingModeAntiAlias</c>)
    /// and grid-fit antialiased text rendering. <c>Graphics</c> stays owned by the
    /// caller.
    /// </summary>
    constructor Create(const Graphics: TGPGraphics);

    /// <summary>See <see cref="IChartCanvas.FillBackground"/>.</summary>
    procedure FillBackground(const Width, Height: Single; const Color: TAlphaColor);
    /// <summary>See <see cref="IChartCanvas.DrawLine"/>.</summary>
    procedure DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                       const StrokeWidth: Single; const Dashed: Boolean);
    /// <summary>See <see cref="IChartCanvas.DrawPolyline"/>.</summary>
    procedure DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                           const StrokeWidth: Single);
    /// <summary>See <see cref="IChartCanvas.FillPolygon"/>.</summary>
    procedure FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
    /// <summary>See <see cref="IChartCanvas.FillRect"/>.</summary>
    procedure FillRect(const Bounds: TRectF; const Color: TAlphaColor);
    /// <summary>See <see cref="IChartCanvas.FillCircle"/>.</summary>
    procedure FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
    /// <summary>See <see cref="IChartCanvas.DrawText"/>.</summary>
    procedure DrawText(const X, Y: Single; const Text: string;
                       const TextStyle: TChartTextStyle;
                       const AlignH: TTextAlignH; const AlignV: TTextAlignV);
    /// <summary>See <see cref="IChartCanvas.MeasureText"/>.</summary>
    function MeasureText(const Text: string; const TextStyle: TChartTextStyle): TSizeF;
    /// <summary>See <see cref="IChartCanvas.DrawImage"/>.</summary>
    procedure DrawImage(const FilePath: string; const Bounds: TRectF);
  end;

  /// <summary>
  /// Saves a GDI+ bitmap as a PNG file. Split out of <c>TChart4D</c> so that anything
  /// holding a <c>TGPBitmap</c>, including the repository's own render-check tools, can
  /// write a chart PNG through the same encoder lookup instead of repeating it.
  /// </summary>
  TChart4DPng = class
  public
    /// <summary>
    /// Returns the CLSID of the system's PNG encoder.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when no PNG encoder is registered.</exception>
    class function EncoderClsid: TGUID; static;

    /// <summary>
    /// Writes <c>Bitmap</c> to <c>FilePath</c> as a PNG file.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when the encoder is missing or the write fails.</exception>
    class procedure Save(const Bitmap: TGPBitmap; const FilePath: string); static;
  end;

  /// <summary>
  /// A VCL graphic control that owns a <c>TChartPlot</c>, renders it with
  /// <c>TChartRenderer</c> on top of GDI+, repaints on every plot change, and can
  /// export the current plot to a PNG file at an arbitrary size. Also tracks the mouse
  /// to highlight the nearest data point and show an in-chart tooltip.
  /// </summary>
  TChart4D = class(TGraphicControl)
  private
    FPlot: TChartPlot;
    FHover: TChartHoverState;
    FOnDataPointHover: TChartHoverEvent;
    FBackBuffer: TBitmap;
    FBackBufferValid: Boolean;

    procedure RenderForExport(const Graphics: TGPGraphics; const Width, Height: Single);
    procedure EnsureBackBuffer;
    procedure DrawTooltipOverlay;
    procedure PlotChanged(Sender: TObject);
    procedure HoverChanged;
    function GetShowTooltips: Boolean;
    procedure SetShowTooltips(const Value: Boolean);

  protected
    /// <summary>Renders the current plot into the back buffer.</summary>
    procedure RenderChartToBackBuffer;
    /// <summary>Blits the cached back buffer, re-rendering it first only when the plot
    /// or the control size has changed, then draws the hover tooltip on top.</summary>
    procedure Paint; override;
    /// <summary>Invalidates the buffered chart render when the control size changes.</summary>
    procedure Resize; override;
    /// <summary>Hit-tests the stored hit map and updates the hover state.</summary>
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    /// <summary>Clears the hover state when the pointer leaves the control.</summary>
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;

  public
    /// <summary>
    /// Creates the control with an owned, empty <c>TChartPlot</c> and the default
    /// 640x450 export size. Tooltips are shown by default.
    /// </summary>
    constructor Create(AOwner: TComponent); override;
    /// <summary>Destroys the control and its owned plot.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Renders the current plot into a <c>TGPBitmap</c> of <c>Width</c> x
    /// <c>Height</c> pixels and saves it as a PNG file at <c>FilePath</c>. Never draws
    /// the hover tooltip.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when the plot has no series to export.</exception>
    procedure SaveToPng(const FilePath: string;
                        const Width: Integer = DefaultExportWidth;
                        const Height: Integer = DefaultExportHeight);

    /// <summary>The owned chart data and configuration.</summary>
    property Plot: TChartPlot read FPlot;
    /// <summary>Whether hovering a data point highlights it and shows a tooltip. Default <c>True</c>.</summary>
    property ShowTooltips: Boolean read GetShowTooltips write SetShowTooltips;
    /// <summary>Fired when the hovered data point changes, including when the pointer leaves every target.</summary>
    property OnDataPointHover: TChartHoverEvent read FOnDataPointHover write FOnDataPointHover;
  published
    property Align;
    property Anchors;
    property Visible;
  end;

implementation

{ TGdiPlusChartCanvas }

constructor TGdiPlusChartCanvas.Create(const Graphics: TGPGraphics);
begin
  inherited Create;
  FGraphics := Graphics;
  FGraphics.SetSmoothingMode(SmoothingModeAntiAlias);
  FGraphics.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);
end;

procedure TGdiPlusChartCanvas.FillBackground(const Width, Height: Single; const Color: TAlphaColor);
begin
  FillRect(TRectF.Create(0, 0, Width, Height), Color);
end;

procedure TGdiPlusChartCanvas.DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                                       const StrokeWidth: Single; const Dashed: Boolean);
begin
  const Pen = TGPPen.Create(TGPColor(Color), StrokeWidth);
  try
    if Dashed then
      Pen.SetDashStyle(DashStyleDash);

    FGraphics.DrawLine(Pen, X1, Y1, X2, Y2);
  finally
    Pen.Free;
  end;
end;

procedure TGdiPlusChartCanvas.DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                                           const StrokeWidth: Single);
begin
  const HasEnoughPoints = (Length(Points) >= 2);
  if not HasEnoughPoints then
    Exit;

  const GpPoints = ToGpPoints(Points);
  const Pen = TGPPen.Create(TGPColor(Color), StrokeWidth);
  try
    FGraphics.DrawLines(Pen, PGPPointF(@GpPoints[0]), Length(GpPoints));
  finally
    Pen.Free;
  end;
end;

procedure TGdiPlusChartCanvas.FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
begin
  const HasEnoughPoints = (Length(Points) >= 3);
  if not HasEnoughPoints then
    Exit;

  const GpPoints = ToGpPoints(Points);
  const Brush = TGPSolidBrush.Create(TGPColor(Color));
  try
    FGraphics.FillPolygon(Brush, PGPPointF(@GpPoints[0]), Length(GpPoints));
  finally
    Brush.Free;
  end;
end;

procedure TGdiPlusChartCanvas.FillRect(const Bounds: TRectF; const Color: TAlphaColor);
begin
  const Brush = TGPSolidBrush.Create(TGPColor(Color));
  try
    FGraphics.FillRectangle(Brush, ToGpRect(Bounds));
  finally
    Brush.Free;
  end;
end;

procedure TGdiPlusChartCanvas.FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
begin
  const Brush = TGPSolidBrush.Create(TGPColor(Color));
  try
    FGraphics.FillEllipse(Brush, CenterX - Radius, CenterY - Radius, Radius * 2, Radius * 2);
  finally
    Brush.Free;
  end;
end;

procedure TGdiPlusChartCanvas.DrawText(const X, Y: Single; const Text: string;
                                       const TextStyle: TChartTextStyle;
                                       const AlignH: TTextAlignH; const AlignV: TTextAlignV);
begin
  const HasText = not Text.IsEmpty;
  if not HasText then
    Exit;

  const Font = CreateFont(TextStyle);
  try
    const Format = CreateMeasureFormat;
    try
      const Size = MeasureTextSize(Text, Font, Format);
      const Origin = TChartTextAlign.ResolveOrigin(X, Y, Size, AlignH, AlignV);
      const Brush = TGPSolidBrush.Create(TGPColor(TextStyle.Color));
      try
        FGraphics.DrawString(Text, Length(Text), Font, MakePoint(Origin.X, Origin.Y), Format, Brush);
      finally
        Brush.Free;
      end;
    finally
      Format.Free;
    end;
  finally
    Font.Free;
  end;
end;

function TGdiPlusChartCanvas.MeasureText(const Text: string; const TextStyle: TChartTextStyle): TSizeF;
begin
  const Font = CreateFont(TextStyle);
  try
    const Format = CreateMeasureFormat;
    try
      Result := MeasureTextSize(Text, Font, Format);
    finally
      Format.Free;
    end;
  finally
    Font.Free;
  end;
end;

procedure TGdiPlusChartCanvas.DrawImage(const FilePath: string; const Bounds: TRectF);
begin
  const HasFilePath = not FilePath.IsEmpty;
  if not HasFilePath then
    Exit;

  const Bitmap = TGPBitmap.Create(FilePath);
  try
    const LoadSucceeded = (Bitmap.GetLastStatus = Ok);
    const HasValidSize = (Bitmap.GetWidth > 0) and (Bitmap.GetHeight > 0);
    const CanDraw = (LoadSucceeded and HasValidSize);
    if not CanDraw then
      Exit;

    const FittedBounds = TChartImageFit.Fit(Bitmap.GetWidth, Bitmap.GetHeight, Bounds);
    FGraphics.DrawImage(Bitmap, ToGpRect(FittedBounds));
  finally
    Bitmap.Free;
  end;
end;

function TGdiPlusChartCanvas.ToGpPoints(const Points: TArray<TPointF>): TArray<TGPPointF>;
begin
  SetLength(Result, Length(Points));
  for var Index := 0 to High(Points) do
  begin
    Result[Index] := MakePoint(Points[Index].X, Points[Index].Y);
  end;
end;

function TGdiPlusChartCanvas.ToGpRect(const Bounds: TRectF): TGPRectF;
begin
  Result := MakeRect(Bounds.Left, Bounds.Top, Bounds.Width, Bounds.Height);
end;

function TGdiPlusChartCanvas.CreateFont(const TextStyle: TChartTextStyle): TGPFont;
begin
  var Style: Winapi.GDIPAPI.TFontStyle := FontStyleRegular;
  if TextStyle.Bold then
    Style := FontStyleBold;

  Result := TGPFont.Create(TextStyle.FontName, TextStyle.Size, Style, UnitPixel);
end;

function TGdiPlusChartCanvas.CreateMeasureFormat: TGPStringFormat;
begin
  Result := TGPStringFormat.Create(TGPStringFormat.GenericTypographic);
end;

function TGdiPlusChartCanvas.MeasureTextSize(const Text: string; const Font: TGPFont;
                                             const Format: TGPStringFormat): TSizeF;
begin
  var Size: TGPSizeF;
  FGraphics.MeasureString(Text, Length(Text), Font, MakeSize(MaxTextLayoutExtent, MaxTextLayoutExtent),
                          Format, Size);
  Result := TSizeF.Create(Size.Width, Size.Height);
end;

{ TChart4DPng }

class function TChart4DPng.EncoderClsid: TGUID;
begin
  var EncoderCount: UINT := 0;
  var BufferSize: UINT := 0;
  GdipGetImageEncodersSize(EncoderCount, BufferSize);

  const HasEncoders = (BufferSize > 0);
  if not HasEncoders then
    raise EChart4DException.Create(SPngEncoderNotFound);

  var Buffer: TBytes;
  SetLength(Buffer, BufferSize);
  const Encoders = PImageCodecInfo(@Buffer[0]);

  var CurrentEncoder := Encoders;
  GdipGetImageEncoders(EncoderCount, BufferSize, Encoders);
  for var Index := 0 to Integer(EncoderCount) - 1 do
  begin
    const IsPngEncoder = SameText(CurrentEncoder.MimeType, 'image/png');
    if IsPngEncoder then
      Exit(CurrentEncoder.Clsid);

    Inc(CurrentEncoder);
  end;

  raise EChart4DException.Create(SPngEncoderNotFound);
end;

class procedure TChart4DPng.Save(const Bitmap: TGPBitmap; const FilePath: string);
begin
  const SaveStatus = Bitmap.Save(FilePath, EncoderClsid);
  const SaveSucceeded = (SaveStatus = Ok);
  if not SaveSucceeded then
    raise EChart4DException.CreateFmt(SFailedToSavePng, [FilePath, Ord(SaveStatus)]);
end;

{ TChart4D }

constructor TChart4D.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];

  FPlot := TChartPlot.Create;
  FPlot.OnChanged := PlotChanged;
  FHover := TChartHoverState.Create;
  FBackBuffer := TBitmap.Create;
  FBackBuffer.PixelFormat := pf32bit;
  Width := DefaultExportWidth;
  Height := DefaultExportHeight;
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

procedure TChart4D.SaveToPng(const FilePath: string;
                             const Width: Integer = DefaultExportWidth;
                             const Height: Integer = DefaultExportHeight);
begin
  const HasNoSeries = (FPlot.Series.Count = 0);
  if HasNoSeries then
    raise EChart4DException.Create(SNoSeriesToRender);

  const Bitmap = TGPBitmap.Create(Width, Height, PixelFormat32bppARGB);
  try
    const Graphics = TGPGraphics.Create(Bitmap);
    try
      RenderForExport(Graphics, Width, Height);
    finally
      Graphics.Free;
    end;

    TChart4DPng.Save(Bitmap, FilePath);
  finally
    Bitmap.Free;
  end;
end;

procedure TChart4D.Paint;
begin
  EnsureBackBuffer;
  Canvas.Draw(0, 0, FBackBuffer);
  DrawTooltipOverlay;
end;

procedure TChart4D.Resize;
begin
  FBackBufferValid := False;
  inherited Resize;
end;

procedure TChart4D.EnsureBackBuffer;
begin
  const SizeChanged = (FBackBuffer.Width <> Width) or (FBackBuffer.Height <> Height);
  if SizeChanged then
  begin
    FBackBuffer.SetSize(Width, Height);
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
  const Graphics = TGPGraphics.Create(FBackBuffer.Canvas.Handle);
  try
    const ChartCanvas: IChartCanvas = TGdiPlusChartCanvas.Create(Graphics);

    var HitMap: TArray<TChartHitTarget>;
    TChartRenderer.Render(FPlot, ChartCanvas, Width, Height, HitMap);
    FHover.HitMap := HitMap;
  finally
    Graphics.Free;
  end;
end;

procedure TChart4D.DrawTooltipOverlay;
begin
  if not FHover.IsVisible then
    Exit;

  const Graphics = TGPGraphics.Create(Canvas.Handle);
  try
    const ChartCanvas: IChartCanvas = TGdiPlusChartCanvas.Create(Graphics);
    TChartTooltip.Draw(ChartCanvas, FPlot.Style, FHover.Info, Width, Height, FPlot.YAxis.LocaleName);
  finally
    Graphics.Free;
  end;
end;

procedure TChart4D.RenderForExport(const Graphics: TGPGraphics; const Width, Height: Single);
begin
  const ChartCanvas: IChartCanvas = TGdiPlusChartCanvas.Create(Graphics);
  TChartRenderer.Render(FPlot, ChartCanvas, Width, Height);
end;

procedure TChart4D.PlotChanged(Sender: TObject);
begin
  FBackBufferValid := False;
  Invalidate;
end;

procedure TChart4D.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);

  if FHover.MoveTo(X, Y) then
    HoverChanged;
end;

procedure TChart4D.CMMouseLeave(var Message: TMessage);
begin
  inherited;

  if FHover.Leave then
    HoverChanged;
end;

procedure TChart4D.HoverChanged;
begin
  if Assigned(FOnDataPointHover) then
    FOnDataPointHover(Self, FHover.Info);

  Invalidate;
end;

end.
