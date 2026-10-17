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
unit Chart4D.FMX.Register;

/// <summary>
/// Puts <c>TChart4D</c> on the Chart4D page of the FireMonkey component palette, and makes
/// sure a form holding one uses the units its event handlers need. Compiled into the
/// design-time package only.
/// </summary>

interface

uses
  System.Classes,
  DesignIntf,
  DesignEditors;

type
  /// <summary>
  /// Adds the units that declare the parameter types of <c>TChart4D</c>'s events to the
  /// uses clause of a form that holds the control. The form designer adds only the unit of
  /// the control itself, so without this a handler created from the Object Inspector for
  /// <c>OnDataPointHover</c> or <c>OnAfterRender</c> would not compile.
  /// </summary>
  TChart4DSelectionEditor = class(TSelectionEditor)
  public
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

procedure Register;

implementation

uses
  Chart4D.FMX;

procedure Register;
begin
  RegisterComponents('Chart4D', [TChart4D]);
  RegisterSelectionEditor(TChart4D, TChart4DSelectionEditor);
end;

procedure TChart4DSelectionEditor.RequiresUnits(Proc: TGetStrProc);
begin
  inherited RequiresUnits(Proc);
  Proc('Chart4D.Types');
  Proc('Chart4D.Canvas.Interfaces');
end;

end.
