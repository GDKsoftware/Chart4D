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
unit VclCheck.Form.Host;

/// <summary>
/// The form the VclCheck checks host a <c>TChart4D</c> on. It is never shown: the control
/// builds its hit map while it paints, and <c>PaintTo</c> drives the same paint path a
/// visible window would. The form is borderless, so its client area is its whole bounds
/// and <c>PaintTo</c> output pixel-aligns exactly with the chart control's own content.
/// Every check creates its own instance, so each one starts from an empty chart.
/// </summary>

interface

uses
  System.Classes,
  Vcl.Forms,
  Chart4D.VCL;

type
  /// <summary>An offscreen host for one chart control, laid out in the DFM.</summary>
  TFormHost = class(TForm)
    Chart: TChart4D;
  end;

implementation

{$R *.dfm}

end.
