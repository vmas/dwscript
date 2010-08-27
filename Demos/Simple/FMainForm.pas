unit FMainForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, dwsComp, Menus, ExtCtrls, StdCtrls, dwsVCLGUIFunctions, dwsExprs,
  dwsCompiler;

type
  TMainForm = class(TForm)
    MESourceCode: TMemo;
    Splitter1: TSplitter;
    MainMenu: TMainMenu;
    MEResult: TMemo;
    MILoad: TMenuItem;
    MISave: TMenuItem;
    MIRun: TMenuItem;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    DelphiWebScript: TDelphiWebScript;
    dwsGUIFunctions: TdwsGUIFunctions;
    procedure MILoadClick(Sender: TObject);
    procedure MISaveClick(Sender: TObject);
    procedure MIRunClick(Sender: TObject);
  private
    { Déclarations privées }
    FFileName : String;
  public
    { Déclarations publiques }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.MILoadClick(Sender: TObject);
begin
   OpenDialog.FileName:=FFileName;
   if OpenDialog.Execute then begin
      FFileName:=OpenDialog.FileName;
      MESourceCode.Lines.LoadFromFile(FFileName);
      Caption:='Simple - '+FFileName;
   end;
end;

procedure TMainForm.MISaveClick(Sender: TObject);
begin
   SaveDialog.FileName:=FFileName;
   if SaveDialog.Execute then begin
      FFileName:=SaveDialog.FileName;
      MESourceCode.Lines.SaveToFile(FFileName);
      Caption:='Simple - '+FFileName;
   end;
end;

procedure TMainForm.MIRunClick(Sender: TObject);
var
   prog : TdwsProgram;
begin
   prog:=DelphiWebScript.Compile(MESourceCode.Lines.Text);
   try
      if prog.Msgs.Count>0 then
         MEResult.Lines.Text:=prog.Msgs.AsInfo
      else begin
         MEResult.Clear;
         try
            prog.Execute;
            MEResult.Lines.Text:=(prog.Result as TdwsDefaultResult).Text;
         except
            on E: Exception do begin
               MEResult.Lines.Text:=E.ClassName+': '+E.Message;
            end;
         end;
      end;
   finally
      prog.Free;
   end;
end;

end.
