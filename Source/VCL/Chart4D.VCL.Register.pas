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
unit Chart4D.VCL.Register;

/// <summary>
/// Puts <c>TChart4D</c> on the Chart4D page of the VCL component palette. Compiled into
/// the design-time package only.
/// </summary>

interface

procedure Register;

implementation

uses
  System.Classes,
  Chart4D.VCL;

procedure Register;
begin
  RegisterComponents('Chart4D', [TChart4D]);
end;

end.
