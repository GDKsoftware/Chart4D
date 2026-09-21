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
unit Chart4D.View;

/// <summary>
/// The framework-neutral part of showing a plot on screen: when a render is still valid,
/// which data point is hovered, when to fire <c>OnDataPointHover</c>, when to ask for a
/// repaint, and when to draw the tooltip. RTL-only, so the VCL and FMX adapters share one
/// implementation and an application can paint a plot on a canvas it already owns.
/// </summary>

interface

uses
  System.Classes,
  Chart4D.Types,
  Chart4D.Canvas.Interfaces,
  Chart4D.Hover,
  Chart4D.Plot;

type
  /// <summary>
  /// Shows a <c>TChartPlot</c> on a surface the caller owns. The view decides when the
  /// last render is stale, keeps the hit map of that render for hover tracking, and draws
  /// the hover tooltip as an overlay. It holds no pixels: the caller keeps the rendered
  /// image (typically a back buffer) and copies it to the screen between
  /// <c>Render</c> and <c>DrawOverlay</c>.
  /// </summary>
  TChartView = class
  private
    FPlot: TChartPlot;
    FHover: TChartHoverState;
    FOnDataPointHover: TChartHoverEvent;
    FOnRepaintRequest: TNotifyEvent;
    FIsRenderValid: Boolean;
    FRenderedWidth: Single;
    FRenderedHeight: Single;

    procedure PlotChanged(Sender: TObject);
    procedure HoverChanged;
    procedure RequestRepaint;
    function GetShowTooltips: Boolean;
    procedure SetShowTooltips(const Value: Boolean);
    function GetHasOverlay: Boolean;

  public
    /// <summary>
    /// Creates a view on <c>Plot</c> and assigns <c>Plot.OnChanged</c>, so every plot
    /// mutation invalidates the last render and requests a repaint. The view does not
    /// own <c>Plot</c>, which must outlive it. Tooltips are shown by default.
    /// </summary>
    constructor Create(const Plot: TChartPlot);
    /// <summary>
    /// Destroys the view and clears <c>Plot.OnChanged</c> when it still points at this
    /// view. Leaves the plot itself alone.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Returns <c>True</c> when a <c>Render</c> at <c>Width</c> x <c>Height</c> would draw:
    /// the plot changed, <c>Invalidate</c> was called, the size differs from the last
    /// render, or nothing was rendered yet. Lets a caller skip preparing its surface.
    /// </summary>
    function NeedsRender(const Width, Height: Single): Boolean;

    /// <summary>
    /// Renders the plot onto <c>Canvas</c> at <c>Width</c> x <c>Height</c> pixels and keeps
    /// the hit map for hover tracking, but only when <c>NeedsRender</c> is <c>True</c>;
    /// otherwise draws nothing, because the caller's surface still holds the last render.
    /// </summary>
    /// <exception cref="EChart4DException">Raised by <c>TChartRenderer</c> for invalid plot input.</exception>
    procedure Render(const Canvas: IChartCanvas; const Width, Height: Single);

    /// <summary>
    /// Draws the hover highlight and tooltip onto <c>Canvas</c> when <c>HasOverlay</c> is
    /// <c>True</c>, and nothing otherwise. Call it after copying the rendered image to the
    /// screen, on the screen canvas, so the tooltip never ends up in the cached render.
    /// </summary>
    procedure DrawOverlay(const Canvas: IChartCanvas; const Width, Height: Single);

    /// <summary>
    /// Marks the last render as stale without requesting a repaint, for a caller whose
    /// surface lost its content.
    /// </summary>
    procedure Invalidate;

    /// <summary>
    /// Hit-tests the pointer at <c>(X, Y)</c> against the last render. When the hovered
    /// data point changed, fires <c>OnDataPointHover</c> and then <c>OnRepaintRequest</c>.
    /// </summary>
    procedure MouseMove(const X, Y: Single);

    /// <summary>
    /// Clears the hovered data point, for when the pointer leaves the surface. When
    /// something was hovered, fires <c>OnDataPointHover</c> with <c>HasHit = False</c> and
    /// then <c>OnRepaintRequest</c>.
    /// </summary>
    procedure MouseLeave;

    /// <summary>The plot this view shows. Not owned.</summary>
    property Plot: TChartPlot read FPlot;
    /// <summary>Whether hovering a data point highlights it and shows a tooltip. Default <c>True</c>.</summary>
    property ShowTooltips: Boolean read GetShowTooltips write SetShowTooltips;
    /// <summary>Whether <c>DrawOverlay</c> currently draws anything: tooltips shown and a data point hovered.</summary>
    property HasOverlay: Boolean read GetHasOverlay;
    /// <summary>
    /// Fired when the hovered data point changes, including when the pointer leaves every
    /// target. <c>Sender</c> is the view.
    /// </summary>
    property OnDataPointHover: TChartHoverEvent read FOnDataPointHover write FOnDataPointHover;
    /// <summary>
    /// Fired when the surface should be repainted: after a plot change and after a hover
    /// change. Map it to the framework's own repaint, such as <c>Invalidate</c> in the VCL
    /// or <c>Repaint</c> in FMX. <c>Sender</c> is the view.
    /// </summary>
    property OnRepaintRequest: TNotifyEvent read FOnRepaintRequest write FOnRepaintRequest;
  end;

implementation

uses
  Chart4D.Renderer,
  Chart4D.Tooltip;

constructor TChartView.Create(const Plot: TChartPlot);
begin
  inherited Create;
  FPlot := Plot;
  FPlot.OnChanged := PlotChanged;
  FHover := TChartHoverState.Create;
end;

destructor TChartView.Destroy;
begin
  const PlotStillNotifiesThisView = (TMethod(FPlot.OnChanged).Data = Pointer(Self));
  if PlotStillNotifiesThisView then
    FPlot.OnChanged := nil;

  FHover.Free;
  inherited Destroy;
end;

function TChartView.GetShowTooltips: Boolean;
begin
  Result := FHover.Enabled;
end;

procedure TChartView.SetShowTooltips(const Value: Boolean);
begin
  FHover.Enabled := Value;
end;

function TChartView.GetHasOverlay: Boolean;
begin
  Result := FHover.IsVisible;
end;

function TChartView.NeedsRender(const Width, Height: Single): Boolean;
begin
  const SizeChanged = (FRenderedWidth <> Width) or (FRenderedHeight <> Height);
  Result := (not FIsRenderValid) or SizeChanged;
end;

procedure TChartView.Render(const Canvas: IChartCanvas; const Width, Height: Single);
begin
  if not NeedsRender(Width, Height) then
    Exit;

  var HitMap: TArray<TChartHitTarget>;
  TChartRenderer.Render(FPlot, Canvas, Width, Height, HitMap);
  FHover.HitMap := HitMap;

  FRenderedWidth := Width;
  FRenderedHeight := Height;
  FIsRenderValid := True;
end;

procedure TChartView.DrawOverlay(const Canvas: IChartCanvas; const Width, Height: Single);
begin
  if not FHover.IsVisible then
    Exit;

  TChartTooltip.Draw(Canvas, FPlot.Style, FHover.Info, Width, Height, FPlot.YAxis.LocaleName);
end;

procedure TChartView.Invalidate;
begin
  FIsRenderValid := False;
end;

procedure TChartView.MouseMove(const X, Y: Single);
begin
  if FHover.MoveTo(X, Y) then
    HoverChanged;
end;

procedure TChartView.MouseLeave;
begin
  if FHover.Leave then
    HoverChanged;
end;

procedure TChartView.PlotChanged(Sender: TObject);
begin
  Invalidate;
  RequestRepaint;
end;

procedure TChartView.HoverChanged;
begin
  if Assigned(FOnDataPointHover) then
    FOnDataPointHover(Self, FHover.Info);

  RequestRepaint;
end;

procedure TChartView.RequestRepaint;
begin
  if Assigned(FOnRepaintRequest) then
    FOnRepaintRequest(Self);
end;

end.
