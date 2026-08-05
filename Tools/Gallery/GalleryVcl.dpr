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
program GalleryVcl;

/// <summary>
/// Renders every example from the shared demo catalogue to a PNG via the VCL (GDI+)
/// backend, for visual inspection of the editorial style. Because it draws the same
/// catalogue the demos present, what comes out here is exactly what a user sees when
/// running a demo, rather than a second set of samples that can drift apart from it.
/// Output goes to the directory given as the first command line parameter (default: the
/// current directory).
/// </summary>

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.DateUtils,
  System.UITypes,
  Chart4D.Types in '..\..\Source\Chart4D.Types.pas',
  Chart4D.Consts in '..\..\Source\Chart4D.Consts.pas',
  Chart4D.Style in '..\..\Source\Chart4D.Style.pas',
  Chart4D.Series in '..\..\Source\Chart4D.Series.pas',
  Chart4D.Axis in '..\..\Source\Chart4D.Axis.pas',
  Chart4D.Canvas.Interfaces in '..\..\Source\Chart4D.Canvas.Interfaces.pas',
  Chart4D.Plot in '..\..\Source\Chart4D.Plot.pas',
  Chart4D.Renderer in '..\..\Source\Chart4D.Renderer.pas',
  Chart4D.VCL in '..\..\Source\VCL\Chart4D.VCL.pas',
  Chart4DDemo.Catalog in '..\..\Examples\Common\Chart4DDemo.Catalog.pas';

/// <summary>Turns an example name into a file name that needs no quoting.</summary>
function FileNameFor(const SampleName: string): string;
begin
  Result := LowerCase(SampleName);
  Result := Result.Replace(' ', '-', [rfReplaceAll]);
  Result := Result.Replace('(', '', [rfReplaceAll]);
  Result := Result.Replace(')', '', [rfReplaceAll]);
  Result := Result + '.png';
end;

procedure ExportSample(const OutputDir: string; const Sample: TDemoSample);
begin
  const Chart = TChart4D.Create(nil);
  try
    Chart.Plot.Source := TDemoCatalog.DefaultSource;
    Sample.Build(Chart.Plot);

    const FilePath = TPath.Combine(OutputDir, FileNameFor(Sample.Name));
    Chart.SaveToPng(FilePath);
    Writeln(Format('Exported %s', [FilePath]));
  finally
    Chart.Free;
  end;
end;

begin
  try
    var OutputDir := GetCurrentDir;
    const HasOutputParam = (ParamCount >= 1);
    if HasOutputParam then
      OutputDir := ParamStr(1);

    for var Sample in TDemoCatalog.Samples do
    begin
      ExportSample(OutputDir, Sample);
    end;

    Writeln('Gallery export complete.');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln('Gallery export FAILED: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
