unit dwsDatabaseLibModule;

interface

uses
  SysUtils, Classes, Masks,
  dwsStrings, dwsUtils, dwsExprList, dwsXPlatform,
  dwsComp, dwsExprs, dwsSymbols, dwsStack, dwsDatabase, dwsJSON, dwsErrors;

type

  TdwsDatabaseLib = class(TDataModule)
    dwsDatabase: TdwsUnit;
    procedure dwsDatabaseClassesDataBaseConstructorsCreateEval(
      Info: TProgramInfo; var ExtObject: TObject);
    procedure dwsDatabaseClassesDataBaseCleanUp(ExternalObject: TObject);
    procedure dwsDatabaseClassesDataBaseMethodsBeginTransactionEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataBaseMethodsCommitEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataBaseMethodsInTransactionEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataBaseMethodsExecEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataBaseMethodsQueryEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataBaseMethodsRollbackEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsEofEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsNextEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsFieldCountEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataFieldMethodsNameEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataFieldMethodsDataTypeEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataFieldMethodsAsStringEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsGetFieldEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsAsStringByNameEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsAsIntegerByIndexEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsAsIntegerByNameEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsAsFloatByIndexEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsAsFloatByNameEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsAsStringByIndexEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataFieldMethodsIsNullEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataFieldMethodsAsIntegerEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataFieldMethodsAsFloatEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataFieldMethodsAsBooleanEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsFieldByNameEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsIndexOfFieldEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataFieldMethodsDeclaredTypeEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsStepEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsStringifyEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsStringifyAllEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsFindFieldEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataBaseMethodsVersionInfoTextEval(
      Info: TProgramInfo; ExtObject: TObject);
    function dwsDatabaseFunctionsBlobParameterFastEval(
      const args: TExprBaseListExec): Variant;
    procedure dwsDatabaseClassesDataFieldMethodsAsBlobEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsAsBlobByNameEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataSetMethodsAsBlobByIndexEval(Info: TProgramInfo;
      ExtObject: TObject);
    procedure dwsDatabaseClassesDataBasePoolMethodsAcquireEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
    procedure dwsDatabaseClassesDataBasePoolMethodsReleaseEval(
      Info: TProgramInfo; ExtObject: TObject);
    procedure dwsDatabaseClassesDataBasePoolMethodsCleanupEval(
      Info: TProgramInfo; ExtObject: TObject);
  private
    { Private declarations }
    procedure SetScript(aScript : TDelphiWebScript);
    procedure RaiseDBException(Info: TProgramInfo; const msg : String);

  public
    { Public declarations }
    procedure CleanupDataBasePool(const filter : String = '*');

    property Script : TDelphiWebScript write SetScript;
  end;

implementation

{$R *.dfm}

resourcestring
   FIELD_NOT_FOUND = 'Field ''%s'' not found';

type
   TDataBase = class
      Intf : IdwsDataBase;
   end;

   TDataSet = class
      Intf : IdwsDataSet;
      FirstDone : Boolean;
      function IndexOfField(const aName : String) : Integer;
      function FieldByName(Info : TProgramInfo) : IdwsDataField;
      function Step : Boolean;
      class procedure WriteValueToJSON(wr : TdwsJSONWriter; const fld : IdwsDataField); static;
      procedure WriteToJSON(wr : TdwsJSONWriter);
      function Stringify : String;
      function StringifyAll : String;
   end;

   TDataField = class
      Intf : IdwsDataField;
   end;

var
   vPools : TSimpleNameObjectHash<TSimpleQueue<IdwsDataBase>>;
   vPoolsCS : TMultiReadSingleWrite;
   vPoolsCount : Integer;

// IndexOfField
//
function TDataSet.IndexOfField(const aName : String) : Integer;
begin
   for Result:=0 to Intf.FieldCount-1 do
      if UnicodeSameText(Intf.Fields[Result].Name, aName) then Exit;
   Result:=-1;
end;

// FieldByName
//
function TDataSet.FieldByName(Info : TProgramInfo) : IdwsDataField;
var
   fieldName : String;
   index : Integer;
begin
   fieldName:=Info.ParamAsString[0];
   index:=IndexOfField(fieldName);
   if index>=0 then
      Result:=Intf.GetField(index)
   else raise Exception.CreateFmt('Unknown field "%s"', [fieldName]);
end;

// Step
//
function TDataSet.Step : Boolean;
begin
   if FirstDone then
      Intf.Next
   else FirstDone:=True;
   Result:=not Intf.EOF;
end;

// WriteValueToJSON
//
class procedure TDataSet.WriteValueToJSON(wr : TdwsJSONWriter; const fld : IdwsDataField);
begin
   case fld.DataType of
      dftInteger : wr.WriteInteger(fld.AsInteger);
      dftFloat : wr.WriteNumber(fld.AsFloat);
      dftString, dftBlob : wr.WriteString(fld.AsString);
      dftBoolean : wr.WriteBoolean(fld.AsBoolean);
      dftDateTime : wr.WriteDate(fld.AsFloat);
   else
      wr.WriteNull;
   end;
end;

// WriteToJSON
//
procedure TDataSet.WriteToJSON(wr : TdwsJSONWriter);
var
   i : Integer;
   fld : IdwsDataField;
begin
   wr.BeginObject;
   for i:=0 to Intf.FieldCount-1 do begin
      fld:=intf.Fields[i];
      wr.WriteName(fld.Name);
      WriteValueToJSON(wr, fld);
   end;
   wr.EndObject;
end;

// Stringify
//
function TDataSet.Stringify : String;
var
   wr : TdwsJSONWriter;
begin
   wr:=TdwsJSONWriter.Create(nil);
   try
      WriteToJSON(wr);
      Result:=wr.ToString;
   finally
      wr.Free;
   end;
end;

// StringifyAll
//
function TDataSet.StringifyAll : String;
var
   wr : TdwsJSONWriter;
begin
   wr:=TdwsJSONWriter.Create(nil);
   try
      wr.BeginArray;
      while not Intf.EOF do begin
         WriteToJSON(wr);
         Intf.Next;
      end;
      wr.EndArray;
      Result:=wr.ToString;
   finally
      wr.Free;
   end;
end;

procedure TdwsDatabaseLib.DataModuleCreate(Sender: TObject);
begin
   vPoolsCS.BeginWrite;
   if vPoolsCount=0 then
      vPools:=TSimpleNameObjectHash<TSimpleQueue<IdwsDataBase>>.Create;
   Inc(vPoolsCount);
   vPoolsCS.EndWrite;
end;

procedure TdwsDatabaseLib.DataModuleDestroy(Sender: TObject);
begin
   vPoolsCS.BeginWrite;
   Dec(vPoolsCount);
   if vPoolsCount=0 then begin
      vPools.Clean;
      vPools.Free;
      vPools:=nil;
   end;
   vPoolsCS.EndWrite;
end;

// SetScript
//
procedure TdwsDatabaseLib.SetScript(aScript : TDelphiWebScript);
begin
   dwsDatabase.Script:=aScript;
end;

// RaiseDBException
//
procedure TdwsDatabaseLib.RaiseDBException(Info: TProgramInfo; const msg : String);
var
   exceptObj : IScriptObj;
begin
   exceptObj:=Info.Vars['EDBException'].Method[SYS_TOBJECT_CREATE].Call([msg]).ScriptObj;
   (exceptObj.ExternalObject as TdwsExceptionContext).Skip(1); // temporary constructor expression
   Info.RaiseExceptObj(msg, exceptObj);
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBasePoolMethodsAcquireEval(
  Info: TProgramInfo; ExtObject: TObject);
var
   name : String;
   db : IdwsDataBase;
   dbo : TDataBase;
   q : TSimpleQueue<IdwsDataBase>;
   obj : TScriptObjInstance;
begin
   name:=Info.ParamAsString[0];
   vPoolsCS.BeginWrite;
   try
      q:=vPools[name];
      if q<>nil then
         q.Pull(db);
   finally
      vPoolsCS.EndWrite;
   end;
   if Assigned(db) then begin
      obj:=TScriptObjInstance.Create(Info.FuncSym.Typ as TClassSymbol, Info.Execution);
      dbo:=TDataBase.Create;
      obj.ExternalObject:=dbo;
      dbo.Intf:=db;
      Info.ResultAsVariant:=IScriptObj(obj);
   end else Info.ResultAsVariant:=IScriptObj(nil);
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBasePoolMethodsReleaseEval(
  Info: TProgramInfo; ExtObject: TObject);
var
   name, checkRelease : String;
   obj : TObject;
   nb : Integer;
   db : IdwsDataBase;
   q : TSimpleQueue<IdwsDataBase>;
begin
   name:=Info.ParamAsString[0];
   obj:=Info.ParamAsObject[1];
   if obj is TDataBase then begin
      db:=TDataBase(obj).Intf;
      checkRelease:=db.CanReleaseToPool;
      if checkRelease<>'' then begin
         checkRelease:='Releasing to pool not allowed: '+checkRelease;
         RaiseDBException(Info, checkRelease);
      end;
   end;
   nb:=Info.ParamAsInteger[2];
   Info.ParamAsVariant[1]:=IUnknown(nil);
   vPoolsCS.BeginWrite;
   try
      q:=vPools[name];
      if q=nil then begin
         if db=nil then Exit;
         q:=TSimpleQueue<IdwsDataBase>.Create;
         vPools[name]:=q;
      end;
      if db<>nil then
         q.Push(db);
      while q.Count>nb do
         q.Pull(db);
   finally
      vPoolsCS.EndWrite;
   end;
end;

procedure TdwsDatabaseLib.CleanupDataBasePool(const filter : String = '*');
var
   i : Integer;
   mask : TMask;
   q, detached : TSimpleQueue<IdwsDataBase>;
   db : IdwsDataBase;
begin
   detached:=TSimpleQueue<IdwsDataBase>.Create;
   mask:=TMask.Create(filter);
   try
      vPoolsCS.BeginWrite;
      try
         for i:=0 to vPools.Capacity-1 do begin
            q:=vPools.BucketObject[i];
            if q=nil then continue;
            if mask.Matches(vPools.BucketName[i]) then begin
               while q.Pull(db) do
                  detached.Push(db);
            end;
            if q.Count=0 then begin
               q.Free;
               vPools.BucketObject[i]:=nil;
            end;
         end;
      finally
         vPoolsCS.EndWrite;
      end;
      while detached.Pull(db) do ;
   finally
      mask.Free;
      detached.Free;
   end;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBasePoolMethodsCleanupEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   CleanupDataBasePool(Info.ParamAsString[0]);
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseCleanUp(
  ExternalObject: TObject);
begin
   ExternalObject.Free;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseConstructorsCreateEval(
  Info: TProgramInfo; var ExtObject: TObject);
var
   db : IdwsDataBase;
   scriptObj : IScriptObj;
   dynArray : TScriptDynamicArray;
begin
   scriptObj:=Info.Vars['parameters'].ScriptObj;
   dynArray:=(scriptObj.GetSelf as TScriptDynamicArray);
   db:=TdwsDatabase.CreateDataBase(Info.ParamAsString[0], dynArray.ToStringArray);

   ExtObject:=TDataBase.Create;
   TDataBase(ExtObject).Intf:=db;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseMethodsBeginTransactionEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   (ExtObject as TDataBase).Intf.BeginTransaction;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseMethodsCommitEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   (ExtObject as TDataBase).Intf.Commit;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseMethodsExecEval(
  Info: TProgramInfo; ExtObject: TObject);
var
   scriptObj : IScriptObj;
   dynArray : TScriptDynamicArray;
begin
   scriptObj:=Info.Vars['parameters'].ScriptObj;
   dynArray:=(scriptObj.GetSelf as TScriptDynamicArray);

   (ExtObject as TDataBase).Intf.Exec(Info.ParamAsString[0], dynArray.AsData);
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseMethodsInTransactionEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsBoolean:=(ExtObject as TDataBase).Intf.InTransaction;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseMethodsQueryEval(
  Info: TProgramInfo; ExtObject: TObject);
var
   scriptObj : IScriptObj;
   dynArray : TScriptDynamicArray;
   ids : IdwsDataSet;
   dbo : TDataBase;
   dataFieldConstructor : IInfo;
   dataSetInfo, dataFieldInfo : IInfo;
   dataSet : TDataSet;
   dataFieldsInfo : IInfo;
   dataFieldsArray : TScriptDynamicArray;
   dataFieldObj : TDataField;
   i : Integer;
begin
   scriptObj:=Info.Vars['parameters'].ScriptObj;
   dynArray:=(scriptObj.GetSelf as TScriptDynamicArray);

   dbo:=(ExtObject as TDataBase);
   ids:=dbo.Intf.Query(Info.ParamAsString[0], dynArray.AsData);

   dataSetInfo:=Info.Vars['DataSet'].Method['Create'].Call;

   dataSet:=TDataSet.Create;
   dataSet.Intf:=ids;

   dataSetInfo.ExternalObject:=dataSet;

   dataFieldsInfo:=dataSetInfo.Member['FFields'];
   dataFieldsArray:=(dataFieldsInfo.ScriptObj.GetSelf as TScriptDynamicArray);
   dataFieldsArray.ArrayLength:=ids.FieldCount;

   dataFieldConstructor:=Info.Vars['DataField'].Method['Create'];
   for i:=0 to ids.FieldCount-1 do begin
      dataFieldInfo:=dataFieldConstructor.Call;
      dataFieldObj:=TDataField.Create;
      dataFieldObj.Intf:=ids.Fields[i];
      dataFieldInfo.ExternalObject:=dataFieldObj;
      dataFieldsArray.AsData[i]:=dataFieldInfo.Value;
   end;

   Info.ResultAsVariant:=dataSetInfo.Value;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseMethodsRollbackEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   (ExtObject as TDataBase).Intf.Rollback;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataBaseMethodsVersionInfoTextEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsString:=(ExtObject as TDataBase).Intf.VersionInfoText;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsAsBlobEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsDataString:=(ExtObject as TDataField).Intf.AsBlob;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsAsBooleanEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsBoolean:=(ExtObject as TDataField).Intf.AsBoolean;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsAsFloatEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsFloat:=(ExtObject as TDataField).Intf.AsFloat;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsAsIntegerEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsInteger:=(ExtObject as TDataField).Intf.AsInteger;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsAsStringEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsString:=(ExtObject as TDataField).Intf.AsString;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsDataTypeEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsInteger:=Ord((ExtObject as TDataField).Intf.DataType);
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsDeclaredTypeEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsString:=(ExtObject as TDataField).Intf.DeclaredType;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsIsNullEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsBoolean:=(ExtObject as TDataField).Intf.AsBoolean;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataFieldMethodsNameEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsString:=(ExtObject as TDataField).Intf.Name;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsAsStringByNameEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsString:=(ExtObject as TDataSet).FieldByName(Info).AsString;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsAsStringByIndexEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsString:=(ExtObject as TDataSet).Intf.GetField(Info.ParamAsInteger[0]).AsString;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsAsIntegerByNameEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsInteger:=(ExtObject as TDataSet).FieldByName(Info).AsInteger;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsAsIntegerByIndexEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsInteger:=(ExtObject as TDataSet).Intf.GetField(Info.ParamAsInteger[0]).AsInteger;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsAsBlobByNameEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsDataString:=(ExtObject as TDataSet).FieldByName(Info).AsBlob;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsAsBlobByIndexEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsDataString:=(ExtObject as TDataSet).Intf.GetField(Info.ParamAsInteger[0]).AsBlob;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsAsFloatByNameEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsFloat:=(ExtObject as TDataSet).FieldByName(Info).AsFloat;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsAsFloatByIndexEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsFloat:=(ExtObject as TDataSet).Intf.GetField(Info.ParamAsInteger[0]).AsFloat;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsEofEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsBoolean:=(ExtObject as TDataSet).Intf.Eof;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsFieldByNameEval(
  Info: TProgramInfo; ExtObject: TObject);
var
   fieldName : String;
   fieldsInfo : IInfo;
   index : Integer;
begin
   fieldName:=Info.ParamAsString[0];
   index:=(ExtObject as TDataSet).IndexOfField(fieldName);
   if index<0 then
      RaiseDBException(Info, Format(FIELD_NOT_FOUND, [fieldName]))
   else begin
      fieldsInfo:=Info.Vars['FFields'];
      Info.ResultAsVariant:=fieldsInfo.Element([index]).Value;
   end;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsFindFieldEval(
  Info: TProgramInfo; ExtObject: TObject);
var
   fieldsInfo : IInfo;
   index : Integer;
begin
   index:=(ExtObject as TDataSet).IndexOfField(Info.ParamAsString[0]);
   if index<0 then
      Info.ResultAsVariant:=IUnknown(nil)
   else begin
      fieldsInfo:=Info.Vars['FFields'];
      Info.ResultAsVariant:=fieldsInfo.Element([index]).Value;
   end;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsFieldCountEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsInteger:=(ExtObject as TDataSet).Intf.FieldCount;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsGetFieldEval(
  Info: TProgramInfo; ExtObject: TObject);
var
   fieldsInfo : IInfo;
   index : Integer;
begin
   fieldsInfo:=Info.Vars['FFields'];
   index:=Info.ParamAsInteger[0];
   Info.ResultAsVariant:=fieldsInfo.Element([index]).Value;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsIndexOfFieldEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsInteger:=(ExtObject as TDataSet).IndexOfField(Info.ParamAsString[0]);
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsNextEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   (ExtObject as TDataSet).Intf.Next;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsStepEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsBoolean:=(ExtObject as TDataSet).Step;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsStringifyAllEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsString:=(ExtObject as TDataSet).StringifyAll;
end;

procedure TdwsDatabaseLib.dwsDatabaseClassesDataSetMethodsStringifyEval(
  Info: TProgramInfo; ExtObject: TObject);
begin
   Info.ResultAsString:=(ExtObject as TDataSet).Stringify;
end;

function TdwsDatabaseLib.dwsDatabaseFunctionsBlobParameterFastEval(
  const args: TExprBaseListExec): Variant;
begin
   Result:=args.AsDataString[0];
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   vPoolsCS:=TMultiReadSingleWrite.Create;

finalization

   vPoolsCS.Free;
   vPoolsCS:=nil;

end.
