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
/// and a PNG export button. Built entirely in code, without a form resource stream.
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
  FMX.Forms,
  FMX.StdCtrls,
  FMX.ListBox,
  FMX.Memo,
  FMX.Memo.Types,
  FMX.ScrollBox,
  FMX.Layouts,
  FMX.Dialogs,
  Chart4D.Types,
  Chart4D.Axis,
  Chart4D.Plot,
  Chart4D.FMX,
  Chart4DDemo.Catalog;

type
  /// <summary>
  /// The demo's main form, built entirely in code (no associated FMX resource stream).
  /// </summary>
  TMainForm = class(TForm)
  private
    FToolbar: TLayout;
    FSampleCombo: TComboBox;
    FExportButton: TButton;
    FSidePanel: TLayout;
    FExplanationLabel: TLabel;
    FCodeMemo: TMemo;
    FSplitter: TSplitter;
    FChart: TChart4D;
    FSaveDialogPng: TSaveDialog;
    FSamples: TArray<TDemoSample>;
    FLogoFilePath: string;

    function ResolveLogoFilePath: string;
    procedure CreateLayout;
    procedure CreateSampleCombo;
    procedure CreateExportButton;
    procedure CreateSidePanel;
    procedure CreateChart;
    procedure CreateSaveDialog;
    procedure SampleComboChange(Sender: TObject);
    procedure ApplySelectedSample;
    procedure ExportButtonClick(Sender: TObject);

  public
    /// <summary>Creates the form and its controls without loading a form resource.</summary>
    constructor Create(Owner: TComponent); override;
  end;

implementation

uses
  System.IOUtils;

const
  ToolbarHeight = 48;
  SidePanelWidth = 760;
  SidePanelPadding = 12;

constructor TMainForm.Create(Owner: TComponent);
begin
  inherited CreateNew(Owner);
  Caption := 'Chart4D FMX Demo';
  SetBounds(0, 0, 1560, 700);
  Position := TFormPosition.ScreenCenter;

  FSamples := TDemoCatalog.Samples;
  FLogoFilePath := ResolveLogoFilePath;

  CreateLayout;
  CreateSampleCombo;
  CreateExportButton;
  CreateSidePanel;
  CreateChart;
  CreateSaveDialog;

  FSampleCombo.ItemIndex := 0;
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

procedure TMainForm.CreateLayout;
begin
  FToolbar := TLayout.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align := TAlignLayout.Top;
  FToolbar.Height := ToolbarHeight;
end;

procedure TMainForm.CreateSampleCombo;
begin
  FSampleCombo := TComboBox.Create(Self);
  FSampleCombo.Parent := FToolbar;
  FSampleCombo.Position.X := 12;
  FSampleCombo.Position.Y := 8;
  FSampleCombo.Width := 280;

  for var Sample in FSamples do
  begin
    FSampleCombo.Items.Add(Sample.Name);
  end;

  FSampleCombo.OnChange := SampleComboChange;
end;

procedure TMainForm.CreateExportButton;
begin
  FExportButton := TButton.Create(Self);
  FExportButton.Parent := FToolbar;
  FExportButton.Position.X := 304;
  FExportButton.Position.Y := 8;
  FExportButton.Width := 120;
  FExportButton.Text := 'Export PNG';
  FExportButton.OnClick := ExportButtonClick;
end;

procedure TMainForm.CreateSidePanel;
begin
  FSidePanel := TLayout.Create(Self);
  FSidePanel.Parent := Self;
  FSidePanel.Align := TAlignLayout.Right;
  FSidePanel.Width := SidePanelWidth;
  FSidePanel.Padding.Rect := RectF(SidePanelPadding, SidePanelPadding,
                                   SidePanelPadding, SidePanelPadding);

  { AutoSize lets the label shrink to the text it actually holds, so a short explanation
    does not reserve a block of empty panel that the code could have used. }
  FExplanationLabel := TLabel.Create(Self);
  FExplanationLabel.Parent := FSidePanel;
  FExplanationLabel.Align := TAlignLayout.Top;
  FExplanationLabel.AutoSize := True;
  FExplanationLabel.Margins.Bottom := SidePanelPadding;
  FExplanationLabel.StyledSettings := FExplanationLabel.StyledSettings - [TStyledSetting.Size];
  FExplanationLabel.TextSettings.Font.Size := 13;
  FExplanationLabel.TextSettings.WordWrap := True;
  FExplanationLabel.TextSettings.VertAlign := TTextAlign.Leading;

  FCodeMemo := TMemo.Create(Self);
  FCodeMemo.Parent := FSidePanel;
  FCodeMemo.Align := TAlignLayout.Client;
  FCodeMemo.ReadOnly := True;
  FCodeMemo.StyledSettings := FCodeMemo.StyledSettings - [TStyledSetting.Family, TStyledSetting.Size];
  FCodeMemo.TextSettings.Font.Family := 'Consolas';
  FCodeMemo.TextSettings.Font.Size := 12;
  FCodeMemo.TextSettings.WordWrap := False;

  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := TAlignLayout.Right;
  FSplitter.Width := 4;
end;

procedure TMainForm.CreateChart;
begin
  FChart := TChart4D.Create(Self);
  FChart.Parent := Self;
  FChart.Align := TAlignLayout.Client;
end;

procedure TMainForm.CreateSaveDialog;
begin
  FSaveDialogPng := TSaveDialog.Create(Self);
  FSaveDialogPng.Filter := 'PNG image (*.png)|*.png';
  FSaveDialogPng.DefaultExt := 'png';
  FSaveDialogPng.FileName := 'chart4d-export.png';
end;

procedure TMainForm.SampleComboChange(Sender: TObject);
begin
  ApplySelectedSample;
end;

procedure TMainForm.ApplySelectedSample;
begin
  const HasSelection = (FSampleCombo.ItemIndex >= 0) and
                       (FSampleCombo.ItemIndex <= High(FSamples));
  if not HasSelection then
    Exit;

  const Sample = FSamples[FSampleCombo.ItemIndex];
  const Plot = FChart.Plot;

  Plot.ClearSeries;
  Plot.ClearAnnotations;
  Plot.Categories := [];
  Plot.Kind := TChartKind.Line;
  Plot.Orientation := TChartOrientation.Vertical;
  Plot.StackMode := TStackMode.Values;
  Plot.LegendPosition := TLegendPosition.Top;
  Plot.LegendReversed := False;
  Plot.ValueLabels := TValueLabelMode.None;
  Plot.HighlightedSeriesIndex := -1;
  Plot.DonutCenterText := '';
  Plot.Title := '';
  Plot.Subtitle := '';
  Plot.Source := TDemoCatalog.DefaultSource;
  Plot.LogoFilePath := FLogoFilePath;
  Plot.XAxis := TAxisOptions.Default;
  Plot.YAxis := TAxisOptions.Default;

  Sample.Build(Plot);

  FExplanationLabel.Text := Sample.Explanation;
  FCodeMemo.Text := Sample.Code;
end;

procedure TMainForm.ExportButtonClick(Sender: TObject);
begin
  const WasConfirmed = FSaveDialogPng.Execute;
  if not WasConfirmed then
    Exit;

  FChart.SaveToPng(FSaveDialogPng.FileName);
end;

end.
