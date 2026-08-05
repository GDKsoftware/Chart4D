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
unit Chart4D.Tests.RecordingCanvas;

/// <summary>
/// A test double for <c>IChartCanvas</c> that records every drawing call as a
/// <c>TCanvasCall</c> in an ordered list, so a test fixture can assert on what
/// <c>Chart4D.Renderer</c> drew without a real graphics backend.
/// </summary>

interface

uses
  System.Generics.Collections,
  System.Types,
  System.UITypes,
  Chart4D.Canvas.Interfaces,
  Chart4D.Types;

{$SCOPEDENUMS ON}
type
  /// <summary>The <c>IChartCanvas</c> method a recorded <c>TCanvasCall</c> came from.</summary>
  TCanvasCallKind = (FillBackground, DrawLine, DrawPolyline, FillPolygon, FillRect,
    FillCircle, DrawText, DrawImage);

  /// <summary>
  /// A single recorded <c>IChartCanvas</c> call. Only the fields relevant to
  /// <c>Kind</c> are meaningful; the rest keep their default value.
  /// </summary>
  TCanvasCall = record
    /// <summary>Which <c>IChartCanvas</c> method produced this call.</summary>
    Kind: TCanvasCallKind;
    /// <summary>The surface width, for <c>FillBackground</c>.</summary>
    Width: Single;
    /// <summary>The surface height, for <c>FillBackground</c>.</summary>
    Height: Single;
    /// <summary>The line start X, for <c>DrawLine</c>.</summary>
    X1: Single;
    /// <summary>The line start Y, for <c>DrawLine</c>.</summary>
    Y1: Single;
    /// <summary>The line end X, for <c>DrawLine</c>.</summary>
    X2: Single;
    /// <summary>The line end Y, for <c>DrawLine</c>.</summary>
    Y2: Single;
    /// <summary>The draw/fill color, for every call kind.</summary>
    Color: TAlphaColor;
    /// <summary>The stroke width, for <c>DrawLine</c> and <c>DrawPolyline</c>.</summary>
    StrokeWidth: Single;
    /// <summary>Whether the line is dashed, for <c>DrawLine</c>.</summary>
    Dashed: Boolean;
    /// <summary>The vertices, for <c>DrawPolyline</c> and <c>FillPolygon</c>.</summary>
    Points: TArray<TPointF>;
    /// <summary>The bounds, for <c>FillRect</c> and <c>DrawImage</c>.</summary>
    Bounds: TRectF;
    /// <summary>The circle center X, for <c>FillCircle</c>.</summary>
    CenterX: Single;
    /// <summary>The circle center Y, for <c>FillCircle</c>.</summary>
    CenterY: Single;
    /// <summary>The circle radius, for <c>FillCircle</c>.</summary>
    Radius: Single;
    /// <summary>The anchor X, for <c>DrawText</c>.</summary>
    TextX: Single;
    /// <summary>The anchor Y, for <c>DrawText</c>.</summary>
    TextY: Single;
    /// <summary>The drawn text, for <c>DrawText</c>.</summary>
    Text: string;
    /// <summary>The text style, for <c>DrawText</c>.</summary>
    TextStyle: TChartTextStyle;
    /// <summary>The horizontal alignment, for <c>DrawText</c>.</summary>
    AlignH: TTextAlignH;
    /// <summary>The vertical alignment, for <c>DrawText</c>.</summary>
    AlignV: TTextAlignV;
    /// <summary>The image file path, for <c>DrawImage</c>.</summary>
    FilePath: string;
  end;

  /// <summary>
  /// An <c>IChartCanvas</c> implementation that records every call instead of drawing,
  /// so <c>Chart4D.Renderer.Tests</c> can assert on the sequence and content of the
  /// calls a render pass produced.
  /// </summary>
  TRecordingCanvas = class(TInterfacedObject, IChartCanvas)
  private
    FCalls: TList<TCanvasCall>;

    procedure RecordCall(const Call: TCanvasCall);

  public
    /// <summary>Creates a canvas with an empty call list.</summary>
    constructor Create;
    /// <summary>Destroys the canvas and its recorded call list.</summary>
    destructor Destroy; override;

    /// <summary>Records a <c>FillBackground</c> call.</summary>
    procedure FillBackground(const Width, Height: Single; const Color: TAlphaColor);
    /// <summary>Records a <c>DrawLine</c> call.</summary>
    procedure DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                       const StrokeWidth: Single; const Dashed: Boolean);
    /// <summary>Records a <c>DrawPolyline</c> call.</summary>
    procedure DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                           const StrokeWidth: Single);
    /// <summary>Records a <c>FillPolygon</c> call.</summary>
    procedure FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
    /// <summary>Records a <c>FillRect</c> call.</summary>
    procedure FillRect(const Bounds: TRectF; const Color: TAlphaColor);
    /// <summary>Records a <c>FillCircle</c> call.</summary>
    procedure FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
    /// <summary>Records a <c>DrawText</c> call.</summary>
    procedure DrawText(const X, Y: Single; const Text: string;
                       const TextStyle: TChartTextStyle;
                       const AlignH: TTextAlignH; const AlignV: TTextAlignV);
    /// <summary>Returns a plausible size without recording a call, so layout math stays stable.</summary>
    function MeasureText(const Text: string;
                         const TextStyle: TChartTextStyle): TSizeF;
    /// <summary>Records a <c>DrawImage</c> call.</summary>
    procedure DrawImage(const FilePath: string; const Bounds: TRectF);

    /// <summary>Returns every recorded call of the given <c>Kind</c>, in call order.</summary>
    function CallsOfKind(const Kind: TCanvasCallKind): TArray<TCanvasCall>;
    /// <summary>Returns the number of recorded calls of the given <c>Kind</c>.</summary>
    function CountOfKind(const Kind: TCanvasCallKind): Integer;
    /// <summary>Returns the number of recorded calls of the given <c>Kind</c> with the given <c>Color</c>.</summary>
    function CountOfColor(const Kind: TCanvasCallKind; const Color: TAlphaColor): Integer;
    /// <summary>Returns whether any <c>DrawText</c> call drew exactly <c>Text</c>.</summary>
    function HasTextEqualTo(const Text: string): Boolean;

    /// <summary>Every call recorded so far, in call order.</summary>
    property Calls: TList<TCanvasCall> read FCalls;
  end;
{$SCOPEDENUMS OFF}

implementation

constructor TRecordingCanvas.Create;
begin
  inherited Create;
  FCalls := TList<TCanvasCall>.Create;
end;

destructor TRecordingCanvas.Destroy;
begin
  FCalls.Free;
  inherited Destroy;
end;

procedure TRecordingCanvas.RecordCall(const Call: TCanvasCall);
begin
  FCalls.Add(Call);
end;

procedure TRecordingCanvas.FillBackground(const Width, Height: Single; const Color: TAlphaColor);
begin
  var Call := Default(TCanvasCall);
  Call.Kind := TCanvasCallKind.FillBackground;
  Call.Width := Width;
  Call.Height := Height;
  Call.Color := Color;
  RecordCall(Call);
end;

procedure TRecordingCanvas.DrawLine(const X1, Y1, X2, Y2: Single; const Color: TAlphaColor;
                                    const StrokeWidth: Single; const Dashed: Boolean);
begin
  var Call := Default(TCanvasCall);
  Call.Kind := TCanvasCallKind.DrawLine;
  Call.X1 := X1;
  Call.Y1 := Y1;
  Call.X2 := X2;
  Call.Y2 := Y2;
  Call.Color := Color;
  Call.StrokeWidth := StrokeWidth;
  Call.Dashed := Dashed;
  RecordCall(Call);
end;

procedure TRecordingCanvas.DrawPolyline(const Points: TArray<TPointF>; const Color: TAlphaColor;
                                        const StrokeWidth: Single);
begin
  var Call := Default(TCanvasCall);
  Call.Kind := TCanvasCallKind.DrawPolyline;
  Call.Points := Points;
  Call.Color := Color;
  Call.StrokeWidth := StrokeWidth;
  RecordCall(Call);
end;

procedure TRecordingCanvas.FillPolygon(const Points: TArray<TPointF>; const Color: TAlphaColor);
begin
  var Call := Default(TCanvasCall);
  Call.Kind := TCanvasCallKind.FillPolygon;
  Call.Points := Points;
  Call.Color := Color;
  RecordCall(Call);
end;

procedure TRecordingCanvas.FillRect(const Bounds: TRectF; const Color: TAlphaColor);
begin
  var Call := Default(TCanvasCall);
  Call.Kind := TCanvasCallKind.FillRect;
  Call.Bounds := Bounds;
  Call.Color := Color;
  RecordCall(Call);
end;

procedure TRecordingCanvas.FillCircle(const CenterX, CenterY, Radius: Single; const Color: TAlphaColor);
begin
  var Call := Default(TCanvasCall);
  Call.Kind := TCanvasCallKind.FillCircle;
  Call.CenterX := CenterX;
  Call.CenterY := CenterY;
  Call.Radius := Radius;
  Call.Color := Color;
  RecordCall(Call);
end;

procedure TRecordingCanvas.DrawText(const X, Y: Single; const Text: string;
                                    const TextStyle: TChartTextStyle;
                                    const AlignH: TTextAlignH; const AlignV: TTextAlignV);
begin
  var Call := Default(TCanvasCall);
  Call.Kind := TCanvasCallKind.DrawText;
  Call.TextX := X;
  Call.TextY := Y;
  Call.Text := Text;
  Call.TextStyle := TextStyle;
  Call.AlignH := AlignH;
  Call.AlignV := AlignV;
  Call.Color := TextStyle.Color;
  RecordCall(Call);
end;

function TRecordingCanvas.MeasureText(const Text: string;
                                      const TextStyle: TChartTextStyle): TSizeF;
begin
  Result := TSizeF.Create(Length(Text) * TextStyle.Size * 0.6, TextStyle.Size * 1.2);
end;

procedure TRecordingCanvas.DrawImage(const FilePath: string; const Bounds: TRectF);
begin
  var Call := Default(TCanvasCall);
  Call.Kind := TCanvasCallKind.DrawImage;
  Call.FilePath := FilePath;
  Call.Bounds := Bounds;
  RecordCall(Call);
end;

function TRecordingCanvas.CallsOfKind(const Kind: TCanvasCallKind): TArray<TCanvasCall>;
begin
  Result := [];
  for var Call in FCalls do
  begin
    if Call.Kind = Kind then
      Result := Result + [Call];
  end;
end;

function TRecordingCanvas.CountOfKind(const Kind: TCanvasCallKind): Integer;
begin
  Result := Length(CallsOfKind(Kind));
end;

function TRecordingCanvas.CountOfColor(const Kind: TCanvasCallKind; const Color: TAlphaColor): Integer;
begin
  Result := 0;
  for var Call in CallsOfKind(Kind) do
  begin
    if Call.Color = Color then
      Inc(Result);
  end;
end;

function TRecordingCanvas.HasTextEqualTo(const Text: string): Boolean;
begin
  Result := False;
  for var Call in CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    if Call.Text = Text then
      Exit(True);
  end;
end;

end.
