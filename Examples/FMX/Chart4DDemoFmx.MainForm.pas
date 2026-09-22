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
unit Chart4DDemoFmx.MainForm;

/// <summary>
/// The Chart4D FMX demo main form: a chart switcher driving a single <c>TChart4D</c>
/// control, with the explanation and the source code of the selected example beside it,
/// and a PNG export button. The layout lives in the FMX file, including the chart control,
/// which comes off the Chart4D palette page.
///
/// The examples themselves live in <c>Chart4DDemo.Catalog</c>, which the VCL demo uses
/// too, so this unit only decides how they are presented.
/// </summary>

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.StdCtrls,
  FMX.ListBox,
  FMX.Memo,
  FMX.Memo.Types,
  FMX.ScrollBox,
  FMX.Layouts,
  FMX.Dialogs,
  Chart4D.Types,
  Chart4D.Consts,
  Chart4D.Axis,
  Chart4D.Plot,
  Chart4D.FMX,
  Chart4DDemo.Catalog;

type
  /// <summary>
  /// The demo's main form. Rebuilds the chart's plot from the shared catalogue whenever
  /// the selection changes.
  /// </summary>
  TMainForm = class(TForm)
    LayoutToolbar: TLayout;
    ComboBoxSample: TComboBox;
    ButtonExportPng: TButton;
    LayoutSide: TLayout;
    LabelExplanation: TLabel;
    MemoCode: TMemo;
    SplitterSide: TSplitter;
    Chart: TChart4D;
    SaveDialogPng: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure ComboBoxSampleChange(Sender: TObject);
    procedure ButtonExportPngClick(Sender: TObject);

  private
    FSamples: TArray<TDemoSample>;
    FLogoFilePath: string;

    function ResolveLogoFilePath: string;
    procedure PopulateSampleItems;
    procedure ApplySelectedSample;
  end;

implementation

{$R *.fmx}

uses
  System.IOUtils;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FSamples := TDemoCatalog.Samples;
  FLogoFilePath := ResolveLogoFilePath;

  PopulateSampleItems;
  ComboBoxSample.ItemIndex := 0;
  ApplySelectedSample;
end;

/// <summary>
/// Finds the repository's own mark, so the publication footer shows a logo the way a
/// published chart would. Returns an empty string when it is missing, which simply leaves
/// the footer without a logo.
/// </summary>
function TMainForm.ResolveLogoFilePath: string;
begin
  const ExecutableDir = TPath.GetDirectoryName(ParamStr(0));
  const Candidate = TPath.Combine(ExecutableDir, '..\..\..\..\assets\chart4d-mark-64.png');

  const LogoExists = TFile.Exists(Candidate);
  if not LogoExists then
    Exit('');

  Result := TPath.GetFullPath(Candidate);
end;

procedure TMainForm.PopulateSampleItems;
begin
  for var Sample in FSamples do
  begin
    ComboBoxSample.Items.Add(Sample.Name);
  end;
end;

procedure TMainForm.ComboBoxSampleChange(Sender: TObject);
begin
  ApplySelectedSample;
end;

procedure TMainForm.ButtonExportPngClick(Sender: TObject);
begin
  const WasConfirmed = SaveDialogPng.Execute;
  if not WasConfirmed then
    Exit;

  Chart.SaveToPng(SaveDialogPng.FileName);
end;

procedure TMainForm.ApplySelectedSample;
begin
  const HasSelection = (ComboBoxSample.ItemIndex >= 0) and
                       (ComboBoxSample.ItemIndex <= High(FSamples));
  if not HasSelection then
    Exit;

  const Sample = FSamples[ComboBoxSample.ItemIndex];
  const Plot = Chart.Plot;

  Plot.ClearSeries;
  Plot.ClearAnnotations;
  Plot.Categories := [];
  Plot.Kind := TChartKind.Line;
  Plot.Orientation := TChartOrientation.Vertical;
  Plot.StackMode := TStackMode.Values;
  Plot.LegendPosition := TLegendPosition.Top;
  Plot.LegendReversed := False;
  Plot.ValueLabels := TValueLabelMode.None;
  Plot.HighlightedSeriesIndex := NoHighlightedSeries;
  Plot.DonutCenterText := '';
  Plot.Title := '';
  Plot.Subtitle := '';
  Plot.Source := TDemoCatalog.DefaultSource;
  Plot.LogoFilePath := FLogoFilePath;
  Plot.XAxis := TAxisOptions.Default;
  Plot.YAxis := TAxisOptions.Default;

  Sample.Build(Plot);

  LabelExplanation.Text := Sample.Explanation;
  MemoCode.Text := Sample.Code;
end;

end.
