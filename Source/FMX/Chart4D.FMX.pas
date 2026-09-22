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
/// of <c>FMX.Graphics.TCanvas</c>, <c>TChartPainter</c> paints a plot through a back
/// buffer onto any FMX canvas, and <c>TChart4D</c> is the FMX control that owns a
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
  Chart4D.Plot,
  Chart4D.Preview,
  Chart4D.Renderer,
  Chart4D.View;

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
  /// Paints a <c>TChartPlot</c> onto an FMX canvas the caller owns, such as the canvas of
  /// a <c>TPaintBox</c> or of a custom control. Keeps the rendered chart in an offscreen
  /// <c>TBitmap</c> so a repaint only re-renders when the plot or the size changed, and
  /// draws the hover tooltip on top. The framework-neutral decisions live in the owned
  /// <c>TChartView</c>.
  /// </summary>
  TChartPainter = class
  private
    FView: TChartView;
    FBackBuffer: TBitmap;
    FPaintedBounds: TRectF;

    procedure ResizeBackBuffer(const Width, Height: Single);
    procedure DrawOverlay(const TargetCanvas: FMX.Graphics.TCanvas; const Bounds: TRectF);

  public
    /// <summary>
    /// Creates a painter for <c>Plot</c>. The painter does not own <c>Plot</c>, which must
    /// outlive it, and takes over <c>Plot.OnChanged</c> (see <c>TChartView.Create</c>).
    /// </summary>
    constructor Create(const Plot: TChartPlot);
    /// <summary>Destroys the painter, its view and its back buffer, but not the plot.</summary>
    destructor Destroy; override;

    /// <summary>
    /// Paints the plot at <c>Width</c> x <c>Height</c> with its top-left corner at the
    /// origin of <c>TargetCanvas</c>. Same as <c>Paint</c> with bounds
    /// <c>(0, 0, Width, Height)</c>.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when <c>Width</c> or <c>Height</c> is
    /// negative, or when a scene cannot be started on the back buffer.</exception>
    procedure Paint(const TargetCanvas: FMX.Graphics.TCanvas; const Width, Height: Single); overload;
    /// <summary>
    /// Paints the plot into <c>Bounds</c> on <c>TargetCanvas</c>, which must be inside a
    /// scene (as it is during a control's <c>Paint</c> or a <c>TPaintBox.OnPaint</c>), laid
    /// out for the size of <c>Bounds</c>: resizes the back buffer, re-renders it when the view
    /// says so, copies it into <c>Bounds</c>, then draws the hover tooltip there. Remembers
    /// <c>Bounds</c>, so <c>MouseMove</c> takes <c>TargetCanvas</c> coordinates.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when <c>Bounds</c> has a negative width or
    /// height, or when a scene cannot be started on the back buffer.</exception>
    procedure Paint(const TargetCanvas: FMX.Graphics.TCanvas; const Bounds: TRectF); overload;
    /// <summary>
    /// Renders the plot into the back buffer at <c>Width</c> x <c>Height</c> now, even when
    /// the last render is still valid, and refreshes the hit map.
    /// </summary>
    /// <exception cref="EChart4DException">Raised when a scene cannot be started on the back buffer.</exception>
    procedure RenderToBackBuffer(const Width, Height: Single);
    /// <summary>
    /// Passes a pointer move on to the view. <c>X</c> and <c>Y</c> are in the coordinates of
    /// the canvas last painted on; a position outside the last painted bounds counts as
    /// leaving the chart.
    /// </summary>
    procedure MouseMove(const X, Y: Single);
    /// <summary>Passes the pointer leaving the painted area on to the view.</summary>
    procedure MouseLeave;

    /// <summary>
    /// The owned view: <c>ShowTooltips</c>, <c>OnDataPointHover</c>, and the
    /// <c>OnRepaintRequest</c> the caller maps to <c>Repaint</c>.
    /// </summary>
    property View: TChartView read FView;
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
    FPainter: TChartPainter;
    FDesignPlot: TChartPlot;
    FDesignPainter: TChartPainter;
    FOnDataPointHover: TChartHoverEvent;

    procedure RenderForExport(const Canvas: FMX.Graphics.TCanvas; const Width, Height: Single);
    procedure ViewDataPointHover(Sender: TObject; const Info: TChartHitInfo);
    procedure ViewRepaintRequest(Sender: TObject);
    function GetShowTooltips: Boolean;
    procedure SetShowTooltips(const Value: Boolean);
    function GetTitle: string;
    procedure SetTitle(const Value: string);
    function GetSubtitle: string;
    procedure SetSubtitle(const Value: string);
    function GetSource: string;
    procedure SetSource(const Value: string);
    function GetKind: TChartKind;
    procedure SetKind(const Value: TChartKind);
    function GetOrientation: TChartOrientation;
    procedure SetOrientation(const Value: TChartOrientation);
    function GetStackMode: TStackMode;
    procedure SetStackMode(const Value: TStackMode);
    function GetLegendPosition: TLegendPosition;
    procedure SetLegendPosition(const Value: TLegendPosition);
    function GetLegendReversed: Boolean;
    procedure SetLegendReversed(const Value: Boolean);
    function GetValueLabels: TValueLabelMode;
    procedure SetValueLabels(const Value: TValueLabelMode);
    function GetHighlightedSeriesIndex: Integer;
    procedure SetHighlightedSeriesIndex(const Value: Integer);
    function GetDonutCenterText: string;
    procedure SetDonutCenterText(const Value: string);
    /// <summary>
    /// The painter for the design-time sample chart, created on first use and kept for
    /// the lifetime of the control. Its plot is refilled from the developer's own plot on
    /// every call, so the preview follows what they change in the Object Inspector.
    /// </summary>
    function DesignPreviewPainter: TChartPainter;

  protected
    /// <summary>
    /// Re-renders the plot into the painter's back buffer and refreshes the stored hit
    /// map. <c>Paint</c> does this on its own whenever the buffer is invalid.
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
  published
    /// <summary>The chart kind. Mirrors <c>Plot.Kind</c>.</summary>
    property Kind: TChartKind read GetKind write SetKind default TChartKind.Line;
    /// <summary>The bold headline above the chart. Mirrors <c>Plot.Title</c>.</summary>
    property Title: string read GetTitle write SetTitle;
    /// <summary>The line under the title that says what is measured. Mirrors <c>Plot.Subtitle</c>.</summary>
    property Subtitle: string read GetSubtitle write SetSubtitle;
    /// <summary>The source credit in the footer. Mirrors <c>Plot.Source</c>.</summary>
    property Source: string read GetSource write SetSource;
    /// <summary>The direction categories run in. Mirrors <c>Plot.Orientation</c>.</summary>
    property Orientation: TChartOrientation read GetOrientation write SetOrientation
      default TChartOrientation.Vertical;
    /// <summary>How a stacked bar chart combines its series. Mirrors <c>Plot.StackMode</c>.</summary>
    property StackMode: TStackMode read GetStackMode write SetStackMode default TStackMode.Values;
    /// <summary>Where the legend is drawn. Mirrors <c>Plot.LegendPosition</c>.</summary>
    property LegendPosition: TLegendPosition read GetLegendPosition write SetLegendPosition
      default TLegendPosition.Top;
    /// <summary>Whether the legend lists its entries in reverse. Mirrors <c>Plot.LegendReversed</c>.</summary>
    property LegendReversed: Boolean read GetLegendReversed write SetLegendReversed default False;
    /// <summary>Which data points carry a value label. Mirrors <c>Plot.ValueLabels</c>.</summary>
    property ValueLabels: TValueLabelMode read GetValueLabels write SetValueLabels
      default TValueLabelMode.None;
    /// <summary>The series drawn in full colour while the rest is muted, or -1 for none. Mirrors <c>Plot.HighlightedSeriesIndex</c>.</summary>
    property HighlightedSeriesIndex: Integer read GetHighlightedSeriesIndex
      write SetHighlightedSeriesIndex default NoHighlightedSeries;
    /// <summary>The text in the hole of a donut chart. Mirrors <c>Plot.DonutCenterText</c>.</summary>
    property DonutCenterText: string read GetDonutCenterText write SetDonutCenterText;
    /// <summary>Whether the hover tooltip is drawn during <c>Paint</c>. Default <c>True</c>.</summary>
    property ShowTooltips: Boolean read GetShowTooltips write SetShowTooltips default True;

    property Align;
    property Anchors;
    property ClipChildren;
    property Cursor;
    property Enabled;
    property Height;
    property HitTest;
    property Margins;
    property Opacity;
    property Padding;
    property Position;
    property RotationAngle;
    property RotationCenter;
    property Scale;
    property Size;
    property Visible;
    property Width;

    /// <summary>Fired when the hovered data point changes, including when the pointer leaves every target.</summary>
    property OnDataPointHover: TChartHoverEvent read FOnDataPointHover write FOnDataPointHover;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
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

constructor TChartPainter.Create(const Plot: TChartPlot);
begin
  inherited Create;
  FView := TChartView.Create(Plot);
  FBackBuffer := TBitmap.Create;
end;

destructor TChartPainter.Destroy;
begin
  FBackBuffer.Free;
  FView.Free;
  inherited Destroy;
end;

procedure TChartPainter.Paint(const TargetCanvas: FMX.Graphics.TCanvas; const Width, Height: Single);
begin
  Paint(TargetCanvas, RectF(0, 0, Width, Height));
end;

procedure TChartPainter.Paint(const TargetCanvas: FMX.Graphics.TCanvas; const Bounds: TRectF);
begin
  const HasNegativeSize = (Bounds.Width < 0) or (Bounds.Height < 0);
  if HasNegativeSize then
    raise EChart4DException.CreateFmt(SPaintBoundsNegativeSize, [Bounds.Width, Bounds.Height]);

  FPaintedBounds := Bounds;
  ResizeBackBuffer(Bounds.Width, Bounds.Height);

  if FView.NeedsRender(Bounds.Width, Bounds.Height) then
    RenderToBackBuffer(Bounds.Width, Bounds.Height);

  TargetCanvas.DrawBitmap(FBackBuffer, RectF(0, 0, FBackBuffer.Width, FBackBuffer.Height), Bounds, 1.0);
  DrawOverlay(TargetCanvas, Bounds);
end;

procedure TChartPainter.RenderToBackBuffer(const Width, Height: Single);
begin
  ResizeBackBuffer(Width, Height);
  FView.Invalidate;

  const SceneStarted = FBackBuffer.Canvas.BeginScene;
  if not SceneStarted then
    raise EChart4DException.Create(SFailedToBeginBackBufferScene);

  try
    const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(FBackBuffer.Canvas);
    FView.Render(ChartCanvas, Width, Height);
  finally
    FBackBuffer.Canvas.EndScene;
  end;
end;

procedure TChartPainter.MouseMove(const X, Y: Single);
begin
  { Hit targets such as line points have a radius, so a pointer just outside the chart
    could still hit one; outside the bounds is outside the chart, whatever it is near. }
  const IsInsideChart = FPaintedBounds.Contains(PointF(X, Y));
  if not IsInsideChart then
  begin
    FView.MouseLeave;
    Exit;
  end;

  FView.MouseMove(X - FPaintedBounds.Left, Y - FPaintedBounds.Top);
end;

procedure TChartPainter.MouseLeave;
begin
  FView.MouseLeave;
end;

procedure TChartPainter.ResizeBackBuffer(const Width, Height: Single);
begin
  const BufferWidth = Round(Width);
  const BufferHeight = Round(Height);
  const SizeChanged = (FBackBuffer.Width <> BufferWidth) or (FBackBuffer.Height <> BufferHeight);
  if not SizeChanged then
    Exit;

  FBackBuffer.SetSize(BufferWidth, BufferHeight);
  FView.Invalidate;
end;

procedure TChartPainter.DrawOverlay(const TargetCanvas: FMX.Graphics.TCanvas; const Bounds: TRectF);
begin
  if not FView.HasOverlay then
    Exit;

  const SavedState = TargetCanvas.SaveState;
  try
    { A tooltip pushed against the chart edge strokes its border across that edge; on a
      canvas shared with other content that half pixel must not land outside Bounds. }
    TargetCanvas.IntersectClipRect(Bounds);
    TargetCanvas.MultiplyMatrix(TMatrix.CreateTranslation(Bounds.Left, Bounds.Top));
    const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(TargetCanvas);
    FView.DrawOverlay(ChartCanvas, Bounds.Width, Bounds.Height);
  finally
    TargetCanvas.RestoreState(SavedState);
  end;
end;

constructor TChart4D.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPlot := TChartPlot.Create;
  FPainter := TChartPainter.Create(FPlot);
  FPainter.View.OnDataPointHover := ViewDataPointHover;
  FPainter.View.OnRepaintRequest := ViewRepaintRequest;
  HitTest := True;
  SetBounds(0, 0, DefaultExportWidth, DefaultExportHeight);
end;

destructor TChart4D.Destroy;
begin
  FDesignPainter.Free;
  FDesignPlot.Free;
  FPainter.Free;
  FPlot.Free;
  inherited Destroy;
end;

function TChart4D.GetShowTooltips: Boolean;
begin
  Result := FPainter.View.ShowTooltips;
end;

procedure TChart4D.SetShowTooltips(const Value: Boolean);
begin
  FPainter.View.ShowTooltips := Value;
end;

function TChart4D.GetTitle: string;
begin
  Result := FPlot.Title;
end;

procedure TChart4D.SetTitle(const Value: string);
begin
  FPlot.Title := Value;
end;

function TChart4D.GetSubtitle: string;
begin
  Result := FPlot.Subtitle;
end;

procedure TChart4D.SetSubtitle(const Value: string);
begin
  FPlot.Subtitle := Value;
end;

function TChart4D.GetSource: string;
begin
  Result := FPlot.Source;
end;

procedure TChart4D.SetSource(const Value: string);
begin
  FPlot.Source := Value;
end;

function TChart4D.GetKind: TChartKind;
begin
  Result := FPlot.Kind;
end;

procedure TChart4D.SetKind(const Value: TChartKind);
begin
  FPlot.Kind := Value;
end;

function TChart4D.GetOrientation: TChartOrientation;
begin
  Result := FPlot.Orientation;
end;

procedure TChart4D.SetOrientation(const Value: TChartOrientation);
begin
  FPlot.Orientation := Value;
end;

function TChart4D.GetStackMode: TStackMode;
begin
  Result := FPlot.StackMode;
end;

procedure TChart4D.SetStackMode(const Value: TStackMode);
begin
  FPlot.StackMode := Value;
end;

function TChart4D.GetLegendPosition: TLegendPosition;
begin
  Result := FPlot.LegendPosition;
end;

procedure TChart4D.SetLegendPosition(const Value: TLegendPosition);
begin
  FPlot.LegendPosition := Value;
end;

function TChart4D.GetLegendReversed: Boolean;
begin
  Result := FPlot.LegendReversed;
end;

procedure TChart4D.SetLegendReversed(const Value: Boolean);
begin
  FPlot.LegendReversed := Value;
end;

function TChart4D.GetValueLabels: TValueLabelMode;
begin
  Result := FPlot.ValueLabels;
end;

procedure TChart4D.SetValueLabels(const Value: TValueLabelMode);
begin
  FPlot.ValueLabels := Value;
end;

function TChart4D.GetHighlightedSeriesIndex: Integer;
begin
  Result := FPlot.HighlightedSeriesIndex;
end;

procedure TChart4D.SetHighlightedSeriesIndex(const Value: Integer);
begin
  FPlot.HighlightedSeriesIndex := Value;
end;

function TChart4D.GetDonutCenterText: string;
begin
  Result := FPlot.DonutCenterText;
end;

procedure TChart4D.SetDonutCenterText(const Value: string);
begin
  FPlot.DonutCenterText := Value;
end;

function TChart4D.DesignPreviewPainter: TChartPainter;
begin
  const NeedsCreating = (FDesignPlot = nil);
  if NeedsCreating then
  begin
    FDesignPlot := TChartPlot.Create;
    FDesignPainter := TChartPainter.Create(FDesignPlot);
  end;

  TChartPreview.FillFrom(FPlot, FDesignPlot);
  Result := FDesignPainter;
end;

procedure TChart4D.Paint;
begin
  const ShowsSamplePreview = ((csDesigning in ComponentState) and (FPlot.Series.Count = 0));
  if ShowsSamplePreview then
  begin
    DesignPreviewPainter.Paint(Canvas, Width, Height);
    Exit;
  end;

  FPainter.Paint(Canvas, Width, Height);
end;

procedure TChart4D.Resize;
begin
  inherited Resize;
  FPainter.View.Invalidate;
end;

procedure TChart4D.RenderChartToBackBuffer;
begin
  FPainter.RenderToBackBuffer(Width, Height);
end;

procedure TChart4D.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited MouseMove(Shift, X, Y);
  FPainter.MouseMove(X, Y);
end;

procedure TChart4D.DoMouseLeave;
begin
  inherited DoMouseLeave;
  FPainter.MouseLeave;
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

procedure TChart4D.RenderForExport(const Canvas: FMX.Graphics.TCanvas; const Width, Height: Single);
begin
  const ChartCanvas: IChartCanvas = TFmxChartCanvas.Create(Canvas);
  TChartRenderer.Render(FPlot, ChartCanvas, Width, Height);
end;

procedure TChart4D.ViewDataPointHover(Sender: TObject; const Info: TChartHitInfo);
begin
  if Assigned(FOnDataPointHover) then
    FOnDataPointHover(Self, Info);
end;

procedure TChart4D.ViewRepaintRequest(Sender: TObject);
begin
  Repaint;
end;

end.
