{
    Will serve static content and DWS dynamic content via http.sys
    kernel mode high-performance HTTP server (available since XP SP2).
    See http://blog.synopse.info/post/2011/03/11/HTTP-server-using-fast-http.sys-kernel-mode-server
    WARNING: you need to first register the server URI and port to the http.sys stack.
    That is, run the application at least once as administrator.

    The executable can be run either as an application or as service.

    Sample based on official mORMot's samples
    SQLite3\Samples\09 - HttpApi web server\HttpApiServer.dpr
    SQLite3\Samples\10 - Background Http service

    Synopse mORMot framework. Copyright (C) 2012 Arnaud Bouchez
      Synopse Informatique - http://synopse.info

    Original tri-license: MPL 1.1/GPL 2.0/LGPL 2.1

    You would need at least the following files from mORMot framework
    to be available in your project path:
    - SynCommons.pas
    - Synopse.inc
    - SynLZ.pas
    - SynZip.pas
    - SynWinWock.pas
    - mORMotService.pas
    http://synopse.info/fossil/wiki?name=Downloads

}
program DWSWebServer;

{$SetPEFlags $0001}

{$IFNDEF VER200} // delphi 2009
   {$WEAKLINKRTTI ON}
   {$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$ENDIF}

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  mORMotService,
  dwsWindowsService,
  dwsJSON,
  dwsXPlatform,
  DSimpleDWScript,
  UHttpSys2WebServer in 'UHttpSys2WebServer.pas',
  dwsDatabaseLibModule in '..\..\Libraries\DatabaseLib\dwsDatabaseLibModule.pas' {dwsDatabaseLib: TDataModule},
  dwsSynSQLiteDatabase in '..\..\Libraries\DatabaseLib\dwsSynSQLiteDatabase.pas',
  dwsSynODBCDatabase in '..\..\Libraries\DatabaseLib\dwsSynODBCDatabase.pas',
  dwsSynOleDBDatabase in '..\..\Libraries\DatabaseLib\dwsSynOleDBDatabase.pas',
  dwsDatabase in '..\..\Libraries\DatabaseLib\dwsDatabase.pas',
  dwsGUIDDatabase in '..\..\Libraries\DatabaseLib\dwsGUIDDatabase.pas';

type
   TWebServerHttpService = class(TdwsWindowsService)
      public
         Server: THttpSys2WebServer;

         procedure DoStart(Sender: TService);
         procedure DoStop(Sender: TService);

         constructor Create(aOptions : TdwsJSONValue); override;
         destructor Destroy; override;

         class function DefaultServiceOptions : String; override;
   end;

{ TWebServerHttpService }

constructor TWebServerHttpService.Create(aOptions : TdwsJSONValue);
begin
   inherited;

   OnStart := DoStart;
   OnStop := DoStop;
   OnResume := DoStart;
   OnPause := DoStop;
end;

destructor TWebServerHttpService.Destroy;
begin
  DoStop(nil);
  inherited;
end;

// DefaultServiceOptions
//
class function TWebServerHttpService.DefaultServiceOptions : String;
begin
   Result :=
      '{'
         // Windows service name
         +'"Name": "DWSServer",'
         // Windows service display name
         +'"DisplayName": "DWScript WebServer",'
         // Windows service description
         +'"Description": "DWScript WebServer Service"'
      +'}';
end;

procedure TWebServerHttpService.DoStart(Sender: TService);
var
   wwwPath : TdwsJSONValue;
   basePath : String;
begin
  if Server<>nil then
    DoStop(nil); // should never happen

   wwwPath:=Options['Server']['WWWPath'];
   if wwwPath.ValueType=jvtString then
      basePath:=wwwPath.AsString;

   // default to subfolder 'www' of where the exe is placed
   if basePath='' then
      basePath:=ExtractFilePath(ParamStr(0))+'www';

   Server:=THttpSys2WebServer.Create(basePath, Options);
end;

procedure TWebServerHttpService.DoStop(Sender: TService);
begin
   if Server=nil then
      exit;
   FreeAndNil(Server);
end;

var
   optionsFileName : String;
   options : TdwsJSONValue;
   service : TWebServerHttpService;
begin
   if Win32MajorVersion<6 then begin
      writeln('This program requires Windows 2008 or Vista');
      exit;
   end;

   SetDecimalSeparator('.');

   optionsFileName:=ExtractFilePath(ParamStr(0))+'options.json';
   if FileExists(optionsFileName) then
      options:=TdwsJSONValue.ParseFile(optionsFileName)
   else options:=TdwsJSONObject.Create;
   service:=TWebServerHttpService.Create(options);
   try
      if ParamCount<>0 then begin
         service.ExecuteCommandLineParameters;
         Exit;
      end;

      if service.LaunchedBySCM then begin

         // started as service
         ServicesRun;

      end else begin

         // started as application
         service.DoStart(service);

         writeln('Server is now running on');
         if service.Server.Port>0 then
            writeln('http://localhost:', service.Server.Port, '/');
         if service.Server.SSLPort>0 then
            writeln('https://localhost:', service.Server.SSLPort, '/');
         writeln;
         writeln('Press [Enter] to quit');
         readln;

      end;
   finally
      service.Free;
      options.Free;
   end;
end.
