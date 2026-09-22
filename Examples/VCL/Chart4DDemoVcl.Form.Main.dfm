object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Chart4D VCL Demo'
  ClientHeight = 680
  ClientWidth = 1560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object PanelToolbar: TPanel
    Left = 0
    Top = 0
    Width = 1560
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object ComboBoxSample: TComboBox
      Left = 8
      Top = 4
      Width = 260
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = ComboBoxSampleChange
    end
    object ButtonExportPng: TButton
      Left = 276
      Top = 4
      Width = 120
      Height = 25
      Caption = 'Export PNG'
      TabOrder = 1
      OnClick = ButtonExportPngClick
    end
  end
  object PanelSide: TPanel
    Left = 800
    Top = 40
    Width = 760
    Height = 640
    Align = alRight
    BevelOuter = bvNone
    Padding.Left = 12
    Padding.Top = 12
    Padding.Right = 12
    Padding.Bottom = 12
    TabOrder = 1
    OnResize = PanelSideResize
    object LabelExplanation: TLabel
      AlignWithMargins = True
      Left = 12
      Top = 12
      Width = 736
      Height = 13
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 12
      Align = alTop
      AutoSize = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      WordWrap = True
      ExplicitWidth = 3
    end
    object MemoCode: TMemo
      Left = 12
      Top = 37
      Width = 736
      Height = 591
      Align = alClient
      Color = clWhite
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
    end
  end
  object SplitterSide: TSplitter
    Left = 796
    Top = 40
    Width = 4
    Height = 640
    Align = alRight
    ExplicitLeft = 800
  end
  object Chart: TChart4D
    Left = 0
    Top = 40
    Width = 796
    Height = 640
    Align = alClient
  end
  object SaveDialogPng: TSaveDialog
    DefaultExt = 'png'
    FileName = 'chart4d-export.png'
    Filter = 'PNG image (*.png)|*.png'
    Left = 440
    Top = 96
  end
end
