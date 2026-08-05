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
/// and a PNG export button. Built entirely in code (<c>TForm.CreateNew</c>, no DFM).
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
  Chart4D.Axis,
  Chart4D.Style,
  Chart4D.VCL,
  Chart4DDemo.Catalog;

type
  /// <summary>
  /// The demo main form. Owns the <c>TChart4D</c> control and rebuilds its plot from the
  /// shared catalogue whenever the selection changes.
  /// </summary>
  TFormMain = class(TForm)
  private
    FPanelToolbar: TPanel;
    FComboBoxSample: TComboBox;
    FButtonExportPng: TButton;
    FSaveDialogPng: TSaveDialog;
    FPanelSide: TPanel;
    FLabelExplanation: TLabel;
    FMemoCode: TMemo;
    FSplitter: TSplitter;
    FChart: TChart4D;
    FSamples: TArray<TDemoSample>;
    FLogoFilePath: string;

    function ResolveLogoFilePath: string;
    procedure CreateToolbar;
    procedure CreateSidePanel;
    procedure CreateChart;
    procedure CreateSaveDialog;
    procedure PopulateSampleItems;
    procedure ComboBoxSampleChange(Sender: TObject);
    procedure ButtonExportPngClick(Sender: TObject);
    procedure ApplySelectedSample;
    procedure SizeExplanationToText;
    procedure PanelSideResize(Sender: TObject);

  public
    /// <summary>
    /// Builds the toolbar, the side panel, the chart control and the save dialog in code,
    /// then selects the first example. Creates the form without a DFM resource.
    /// </summary>
    constructor Create(Owner: TComponent); override;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils;

const
  ToolbarHeight = 40;
  ToolbarPadding = 8;
  ComboBoxWidth = 260;
  ButtonWidth = 120;
  SidePanelWidth = 760;
  SidePanelPadding = 12;

constructor TFormMain.Create(Owner: TComponent);
begin
  inherited CreateNew(Owner, 0);

  Caption := 'Chart4D VCL Demo';
  Position := poScreenCenter;
  ClientWidth := 1560;
  ClientHeight := 680;

  FSamples := TDemoCatalog.Samples;
  FLogoFilePath := ResolveLogoFilePath;

  CreateToolbar;
  CreateSidePanel;
  CreateChart;
  CreateSaveDialog;

  PopulateSampleItems;
  FComboBoxSample.ItemIndex := 0;
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

procedure TFormMain.CreateToolbar;
begin
  FPanelToolbar := TPanel.Create(Self);
  FPanelToolbar.Parent := Self;
  FPanelToolbar.Align := alTop;
  FPanelToolbar.Height := ToolbarHeight;
  FPanelToolbar.BevelOuter := bvNone;

  FComboBoxSample := TComboBox.Create(Self);
  FComboBoxSample.Parent := FPanelToolbar;
  FComboBoxSample.Style := csDropDownList;
  FComboBoxSample.Left := ToolbarPadding;
  FComboBoxSample.Top := ToolbarPadding div 2;
  FComboBoxSample.Width := ComboBoxWidth;
  FComboBoxSample.OnChange := ComboBoxSampleChange;

  FButtonExportPng := TButton.Create(Self);
  FButtonExportPng.Parent := FPanelToolbar;
  FButtonExportPng.Caption := 'Export PNG';
  FButtonExportPng.Left := FComboBoxSample.Left + ComboBoxWidth + ToolbarPadding;
  FButtonExportPng.Top := FComboBoxSample.Top;
  FButtonExportPng.Width := ButtonWidth;
  FButtonExportPng.OnClick := ButtonExportPngClick;
end;

procedure TFormMain.CreateSidePanel;
begin
  FPanelSide := TPanel.Create(Self);
  FPanelSide.Parent := Self;
  FPanelSide.Align := alRight;
  FPanelSide.Width := SidePanelWidth;
  FPanelSide.BevelOuter := bvNone;
  FPanelSide.Padding.SetBounds(SidePanelPadding, SidePanelPadding, SidePanelPadding, SidePanelPadding);

  { The height is measured in SizeExplanationToText rather than left to AutoSize, which
    wraps against a width the label does not have yet and ends up many times too tall. }
  FLabelExplanation := TLabel.Create(Self);
  FLabelExplanation.Parent := FPanelSide;
  FLabelExplanation.Align := alTop;
  FLabelExplanation.WordWrap := True;
  FLabelExplanation.AutoSize := False;
  FLabelExplanation.Margins.SetBounds(0, 0, 0, SidePanelPadding);
  FLabelExplanation.AlignWithMargins := True;
  FLabelExplanation.Font.Size := 10;

  FMemoCode := TMemo.Create(Self);
  FMemoCode.Parent := FPanelSide;
  FMemoCode.Align := alClient;
  FMemoCode.ReadOnly := True;
  FMemoCode.ScrollBars := ssBoth;
  FMemoCode.WordWrap := False;
  FMemoCode.Font.Name := 'Consolas';
  FMemoCode.Font.Size := 12;
  FMemoCode.Color := clWhite;

  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := alRight;
  FSplitter.Width := 4;

  FPanelSide.OnResize := PanelSideResize;
end;

/// <summary>
/// Gives the explanation exactly the height its wrapped text needs, so everything left
/// over goes to the code below it. Dragging the splitter changes the width, and therefore
/// the number of lines, which is why this runs on resize as well.
/// </summary>
procedure TFormMain.SizeExplanationToText;
begin
  const HasWidth = (FLabelExplanation.Width > 0);
  if not HasWidth then
    Exit;

  Canvas.Font := FLabelExplanation.Font;

  var TextBounds := TRect.Create(0, 0, FLabelExplanation.Width, 0);
  DrawText(Canvas.Handle, PChar(FLabelExplanation.Caption), -1, TextBounds,
           DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);

  FLabelExplanation.Height := TextBounds.Height;
end;

procedure TFormMain.PanelSideResize(Sender: TObject);
begin
  SizeExplanationToText;
end;

procedure TFormMain.CreateChart;
begin
  FChart := TChart4D.Create(Self);
  FChart.Parent := Self;
  FChart.Align := alClient;
end;

procedure TFormMain.CreateSaveDialog;
begin
  FSaveDialogPng := TSaveDialog.Create(Self);
  FSaveDialogPng.Filter := 'PNG image (*.png)|*.png';
  FSaveDialogPng.DefaultExt := 'png';
  FSaveDialogPng.FileName := 'chart4d-export.png';
end;

procedure TFormMain.PopulateSampleItems;
begin
  for var Sample in FSamples do
  begin
    FComboBoxSample.Items.Add(Sample.Name);
  end;
end;

procedure TFormMain.ComboBoxSampleChange(Sender: TObject);
begin
  ApplySelectedSample;
end;

procedure TFormMain.ButtonExportPngClick(Sender: TObject);
begin
  const WasConfirmed = FSaveDialogPng.Execute;
  if not WasConfirmed then
    Exit;

  FChart.SaveToPng(FSaveDialogPng.FileName);
end;

procedure TFormMain.ApplySelectedSample;
begin
  const HasSelection = (FComboBoxSample.ItemIndex >= 0) and
                       (FComboBoxSample.ItemIndex <= High(FSamples));
  if not HasSelection then
    Exit;

  const Sample = FSamples[FComboBoxSample.ItemIndex];

  FChart.Plot.ClearSeries;
  FChart.Plot.ClearAnnotations;
  FChart.Plot.Categories := [];
  FChart.Plot.Kind := TChartKind.Line;
  FChart.Plot.Orientation := TChartOrientation.Vertical;
  FChart.Plot.StackMode := TStackMode.Values;
  FChart.Plot.LegendPosition := TLegendPosition.Top;
  FChart.Plot.LegendReversed := False;
  FChart.Plot.ValueLabels := TValueLabelMode.None;
  FChart.Plot.HighlightedSeriesIndex := -1;
  FChart.Plot.DonutCenterText := '';
  FChart.Plot.Title := '';
  FChart.Plot.Subtitle := '';
  FChart.Plot.Source := TDemoCatalog.DefaultSource;
  FChart.Plot.LogoFilePath := FLogoFilePath;
  FChart.Plot.XAxis := TAxisOptions.Default;
  FChart.Plot.YAxis := TAxisOptions.Default;

  Sample.Build(FChart.Plot);

  FLabelExplanation.Caption := Sample.Explanation;
  SizeExplanationToText;
  FMemoCode.Text := Sample.Code;
end;

end.
