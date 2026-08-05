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
unit Chart4D.Canvas.Interfaces;

/// <summary>
/// The drawing surface abstraction that the renderer targets. Framework adapters
/// (<c>Chart4D.VCL</c>, <c>Chart4D.FMX</c>) implement <c>IChartCanvas</c> so
/// <c>Chart4D.Renderer</c> stays RTL-only.
/// </summary>

interface

uses
  System.Types,
  System.UITypes,
  Chart4D.Types;

type
  /// <summary>
  /// The font, size, weight, and color used to draw a piece of text.
  /// </summary>
  TChartTextStyle = record
    /// <summary>The font family name.</summary>
    FontName: string;
    /// <summary>The font size in pixels.</summary>
    Size: Single;
    /// <summary>Whether the text is drawn bold.</summary>
    Bold: Boolean;
    /// <summary>The text color.</summary>
    Color: TAlphaColor;

    /// <summary>
    /// Creates a text style from the given font, size, weight, and color.
    /// </summary>
    class function Create(const FontName: string; const Size: Single;
                          const Bold: Boolean; const Color: TAlphaColor): TChartTextStyle; static;
  end;

  /// <summary>
  /// A drawing surface that <c>Chart4D.Renderer</c> uses to render a chart. Framework
  /// adapters implement this interface on top of GDI+, FMX, or another canvas.
  /// </summary>
  IChartCanvas = interface
    ['{5B1FA4C2-14B6-4610-AFD5-AAF5CAB4AAE5}']

    /// <summary>Fills the entire drawing surface with a solid color.</summary>
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
    /// <summary>
    /// Draws text anchored at <c>(X, Y)</c> according to <c>AlignH</c>/<c>AlignV</c>,
    /// e.g. <c>AlignH = Left</c>, <c>AlignV = Top</c> means <c>(X, Y)</c> is the
    /// top-left of the text box.
    /// </summary>
    procedure DrawText(const X, Y: Single; const Text: string;
                       const TextStyle: TChartTextStyle;
                       const AlignH: TTextAlignH; const AlignV: TTextAlignV);
    /// <summary>Measures the size a piece of text would occupy in the given style.</summary>
    function MeasureText(const Text: string;
                         const TextStyle: TChartTextStyle): TSizeF;
    /// <summary>
    /// Draws an image loaded from <c>FilePath</c>, scaled uniformly (aspect fit)
    /// inside <c>Bounds</c>, right-aligned within it.
    /// </summary>
    procedure DrawImage(const FilePath: string; const Bounds: TRectF);
  end;

  /// <summary>
  /// Turns an anchor point plus a measured text size into the top-left corner the text
  /// box has to be drawn at. The single source of truth for the alignment convention of
  /// <c>IChartCanvas.DrawText</c>, shared by every adapter and by the renderer's label
  /// boxes, so an adapter can never disagree with the layout the renderer assumed.
  /// </summary>
  TChartTextAlign = class
  public
    /// <summary>
    /// Returns the top-left corner of a text box of <c>Size</c> anchored at
    /// <c>(X, Y)</c> under <c>AlignH</c>/<c>AlignV</c>.
    /// </summary>
    /// <exception cref="EChart4DException">
    /// Raised when <c>AlignH</c> or <c>AlignV</c> is outside its enumeration.
    /// </exception>
    class function ResolveOrigin(const X, Y: Single; const Size: TSizeF;
                                 const AlignH: TTextAlignH; const AlignV: TTextAlignV): TPointF; static;
  end;

  /// <summary>
  /// The aspect-fit placement rule for <c>IChartCanvas.DrawImage</c>: scale uniformly to
  /// fit inside the bounds, then right-align horizontally and centre vertically. Shared by
  /// every adapter so the footer logo lands in the same place on each back end.
  /// </summary>
  TChartImageFit = class
  public
    /// <summary>
    /// Returns the rectangle an image of <c>ImageWidth</c> x <c>ImageHeight</c> is drawn
    /// into inside <c>Bounds</c>, or an empty rectangle at the bounds' top-left when the
    /// image has no positive size.
    /// </summary>
    class function Fit(const ImageWidth, ImageHeight: Single; const Bounds: TRectF): TRectF; static;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Chart4D.Consts;

class function TChartTextStyle.Create(const FontName: string; const Size: Single;
                                      const Bold: Boolean; const Color: TAlphaColor): TChartTextStyle;
begin
  Result.FontName := FontName;
  Result.Size := Size;
  Result.Bold := Bold;
  Result.Color := Color;
end;

class function TChartTextAlign.ResolveOrigin(const X, Y: Single; const Size: TSizeF;
                                             const AlignH: TTextAlignH; const AlignV: TTextAlignV): TPointF;
begin
  var OriginX: Single;
  case AlignH of
    TTextAlignH.Left   : OriginX := X;
    TTextAlignH.Center : OriginX := X - Size.Width / 2;
    TTextAlignH.Right  : OriginX := X - Size.Width;
  else
    raise EChart4DException.CreateFmt(SUnsupportedTextAlignH, [Ord(AlignH)]);
  end;

  var OriginY: Single;
  case AlignV of
    TTextAlignV.Top    : OriginY := Y;
    TTextAlignV.Middle : OriginY := Y - Size.Height / 2;
    TTextAlignV.Bottom : OriginY := Y - Size.Height;
  else
    raise EChart4DException.CreateFmt(SUnsupportedTextAlignV, [Ord(AlignV)]);
  end;

  Result := TPointF.Create(OriginX, OriginY);
end;

class function TChartImageFit.Fit(const ImageWidth, ImageHeight: Single; const Bounds: TRectF): TRectF;
begin
  const HasValidImageSize = (ImageWidth > 0) and (ImageHeight > 0);
  if not HasValidImageSize then
    Exit(TRectF.Create(Bounds.Left, Bounds.Top, Bounds.Left, Bounds.Top));

  const Scale = Min(Bounds.Width / ImageWidth, Bounds.Height / ImageHeight);
  const ScaledWidth = ImageWidth * Scale;
  const ScaledHeight = ImageHeight * Scale;

  const Left = Bounds.Right - ScaledWidth;
  const Top = Bounds.Top + (Bounds.Height - ScaledHeight) / 2;

  Result := TRectF.Create(Left, Top, Left + ScaledWidth, Top + ScaledHeight);
end;

end.
