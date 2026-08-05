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
program Chart4D.Tests;

/// <summary>
/// DUnitX console runner for the Chart4D core test suite.
/// </summary>

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  Chart4D.Tests.RecordingCanvas in 'Chart4D.Tests.RecordingCanvas.pas',
  Chart4D.Axis.Tests in 'Chart4D.Axis.Tests.pas',
  Chart4D.Mapper.Tests in 'Chart4D.Mapper.Tests.pas',
  Chart4D.Plot.Tests in 'Chart4D.Plot.Tests.pas',
  Chart4D.Histogram.Tests in 'Chart4D.Histogram.Tests.pas',
  Chart4D.Renderer.Tests in 'Chart4D.Renderer.Tests.pas',
  Chart4D.Invariants.Tests in 'Chart4D.Invariants.Tests.pas',
  Chart4D.Hover.Tests in 'Chart4D.Hover.Tests.pas',
  Chart4D.Style.Tests in 'Chart4D.Style.Tests.pas',
  Chart4D.Tooltip.Tests in 'Chart4D.Tooltip.Tests.pas',
  Chart4D.ValueLabels.Tests in 'Chart4D.ValueLabels.Tests.pas',
  Chart4D.Catalog.Tests in 'Chart4D.Catalog.Tests.pas',
  Chart4DDemo.Catalog in '..\Examples\Common\Chart4DDemo.Catalog.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;

begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;

    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);

    Results := Runner.Execute;
    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    System.Write('Done.. press <Enter> key to quit.');
    System.Readln;
    {$ENDIF}
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_ERRORS;
    end;
  end;
end.
