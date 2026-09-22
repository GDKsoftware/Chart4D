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
unit Chart4DDemoVcl.Form.Main;

/// <summary>
/// The Chart4D VCL demo main form: a chart switcher driving a single <c>TChart4D</c>
/// control, with the explanation and the source code of the selected example beside it,
/// and a PNG export button. The layout lives in the DFM, including the chart control,
/// which comes off the Chart4D palette page.
///
/// The examples themselves live in <c>Chart4DDemo.Catalog</c>, which the FMX demo uses
/// too, so this unit only decides how they are presented.
/// </summary>

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.Dialogs,
  Chart4D.Types,
  Chart4D.Consts,
  Chart4D.Axis,
  Chart4D.Style,
  Chart4D.VCL,
  Chart4DDemo.Catalog;

type
  /// <summary>
  /// The demo main form. Rebuilds the chart's plot from the shared catalogue whenever the
  /// selection changes.
  /// </summary>
  TFormMain = class(TForm)
    PanelToolbar: TPanel;
    ComboBoxSample: TComboBox;
    ButtonExportPng: TButton;
    PanelSide: TPanel;
    LabelExplanation: TLabel;
    MemoCode: TMemo;
    SplitterSide: TSplitter;
    Chart: TChart4D;
    SaveDialogPng: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure ComboBoxSampleChange(Sender: TObject);
    procedure ButtonExportPngClick(Sender: TObject);
    procedure PanelSideResize(Sender: TObject);

  private
    FSamples: TArray<TDemoSample>;
    FLogoFilePath: string;

    function ResolveLogoFilePath: string;
    procedure PopulateSampleItems;
    procedure ApplySelectedSample;
    procedure SizeExplanationToText;
  end;

implementation

{$R *.dfm}

uses
  Winapi.Windows,
  System.IOUtils;

procedure TFormMain.FormCreate(Sender: TObject);
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
function TFormMain.ResolveLogoFilePath: string;
begin
  const ExecutableDir = TPath.GetDirectoryName(ParamStr(0));
  const Candidate = TPath.Combine(ExecutableDir, '..\..\..\..\assets\chart4d-mark-64.png');

  const LogoExists = TFile.Exists(Candidate);
  if not LogoExists then
    Exit('');

  Result := TPath.GetFullPath(Candidate);
end;

procedure TFormMain.PopulateSampleItems;
begin
  for var Sample in FSamples do
  begin
    ComboBoxSample.Items.Add(Sample.Name);
  end;
end;

procedure TFormMain.ComboBoxSampleChange(Sender: TObject);
begin
  ApplySelectedSample;
end;

procedure TFormMain.ButtonExportPngClick(Sender: TObject);
begin
  const WasConfirmed = SaveDialogPng.Execute;
  if not WasConfirmed then
    Exit;

  Chart.SaveToPng(SaveDialogPng.FileName);
end;

procedure TFormMain.PanelSideResize(Sender: TObject);
begin
  SizeExplanationToText;
end;

procedure TFormMain.ApplySelectedSample;
begin
  const HasSelection = (ComboBoxSample.ItemIndex >= 0) and
                       (ComboBoxSample.ItemIndex <= High(FSamples));
  if not HasSelection then
    Exit;

  const Sample = FSamples[ComboBoxSample.ItemIndex];

  Chart.Plot.ClearSeries;
  Chart.Plot.ClearAnnotations;
  Chart.Plot.Categories := [];
  Chart.Plot.Kind := TChartKind.Line;
  Chart.Plot.Orientation := TChartOrientation.Vertical;
  Chart.Plot.StackMode := TStackMode.Values;
  Chart.Plot.LegendPosition := TLegendPosition.Top;
  Chart.Plot.LegendReversed := False;
  Chart.Plot.ValueLabels := TValueLabelMode.None;
  Chart.Plot.HighlightedSeriesIndex := NoHighlightedSeries;
  Chart.Plot.DonutCenterText := '';
  Chart.Plot.Title := '';
  Chart.Plot.Subtitle := '';
  Chart.Plot.Source := TDemoCatalog.DefaultSource;
  Chart.Plot.LogoFilePath := FLogoFilePath;
  Chart.Plot.XAxis := TAxisOptions.Default;
  Chart.Plot.YAxis := TAxisOptions.Default;

  Sample.Build(Chart.Plot);

  LabelExplanation.Caption := Sample.Explanation;
  SizeExplanationToText;
  MemoCode.Text := Sample.Code;
end;

/// <summary>
/// Gives the explanation exactly the height its wrapped text needs, so everything left
/// over goes to the code below it. Dragging the splitter changes the width, and therefore
/// the number of lines, which is why this runs on resize as well.
/// </summary>
procedure TFormMain.SizeExplanationToText;
begin
  const HasWidth = (LabelExplanation.Width > 0);
  if not HasWidth then
    Exit;

  Canvas.Font := LabelExplanation.Font;

  var TextBounds := TRect.Create(0, 0, LabelExplanation.Width, 0);
  DrawText(Canvas.Handle, PChar(LabelExplanation.Caption), -1, TextBounds,
           DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);

  LabelExplanation.Height := TextBounds.Height;
end;

end.
