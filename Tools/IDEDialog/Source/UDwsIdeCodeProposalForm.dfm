object DwsIdeCodeProposalForm: TDwsIdeCodeProposalForm
  Left = 0
  Top = 0
  BorderStyle = bsToolWindow
  Caption = 'DwsIdeCodeProposalForm'
  ClientHeight = 314
  ClientWidth = 645
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ListBox1: TListBox
    Left = 0
    Top = 0
    Width = 645
    Height = 314
    Align = alClient
    ItemHeight = 13
    TabOrder = 0
    TabWidth = 40
    OnDblClick = ListBox1DblClick
  end
end
