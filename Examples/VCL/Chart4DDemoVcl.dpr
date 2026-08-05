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
program Chart4DDemoVcl;

/// <summary>
/// VCL demo application for Chart4D: lets the user switch between the examples in the
/// shared catalogue (<c>Chart4DDemo.Catalog</c>), showing each one's explanation and
/// source code beside the rendered chart, with a PNG export button. The main form is
/// built entirely in code (<c>TForm.CreateNew</c>, no DFM).
/// </summary>

{$R ..\..\assets\Chart4D.res}

uses
  Vcl.Forms,
  Chart4D.Types in '..\..\Source\Chart4D.Types.pas',
  Chart4D.Consts in '..\..\Source\Chart4D.Consts.pas',
  Chart4D.Style in '..\..\Source\Chart4D.Style.pas',
  Chart4D.Series in '..\..\Source\Chart4D.Series.pas',
  Chart4D.Axis in '..\..\Source\Chart4D.Axis.pas',
  Chart4D.Canvas.Interfaces in '..\..\Source\Chart4D.Canvas.Interfaces.pas',
  Chart4D.Plot in '..\..\Source\Chart4D.Plot.pas',
  Chart4D.Renderer in '..\..\Source\Chart4D.Renderer.pas',
  Chart4D.VCL in '..\..\Source\VCL\Chart4D.VCL.pas',
  Chart4DDemo.Catalog in '..\Common\Chart4DDemo.Catalog.pas',
  Chart4DDemoVcl.Form.Main in 'Chart4DDemoVcl.Form.Main.pas';

var
  MainForm: TFormMain;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, MainForm);
  Application.Run;
end.
