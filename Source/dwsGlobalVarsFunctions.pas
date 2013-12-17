{**********************************************************************}
{                                                                      }
{    "The contents of this file are subject to the Mozilla Public      }
{    License Version 1.1 (the "License"); you may not use this         }
{    file except in compliance with the License. You may obtain        }
{    a copy of the License at http://www.mozilla.org/MPL/              }
{                                                                      }
{    Software distributed under the License is distributed on an       }
{    "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express       }
{    or implied. See the License for the specific language             }
{    governing rights and limitations under the License.               }
{                                                                      }
{    The Initial Developer of the Original Code is Matthias            }
{    Ackermann. For other initial contributors, see contributors.txt   }
{    Subsequent portions Copyright Creative IT.                        }
{                                                                      }
{    Current maintainer: Eric Grange                                   }
{                                                                      }
{**********************************************************************}
{: GlobalVariables for DWS<p>

   This unit implements global variables functions, that allow scripts to read
   and write to variables across a script's context.<br>
   Details:<ul>
   <li>Variables can be declared and read from any script, or from Delphi code
   <li>Read/Write access is thread-safe
   <li>Variables names are <b>case sensitive</b>
   </ul><p>

   The global vars can be saved/restored as a whole from Delphi code (delphi
   code only as of now, mainly for security reasons) to a file, string or stream.
}
unit dwsGlobalVarsFunctions;

{$I dws.inc}

interface

uses
   Variants, Windows, Classes, SysUtils, Masks,
   dwsXPlatform, dwsUtils, dwsStrings, dwsExprList, dwsConstExprs,
   dwsFunctions, dwsExprs, dwsSymbols, dwsMagicExprs;

type

   TReadGlobalVarFunc = class(TInternalMagicVariantFunction)
      function DoEvalAsVariant(const args : TExprBaseListExec) : Variant; override;
   end;

   TReadGlobalVarDefFunc = class(TInternalMagicVariantFunction)
      function DoEvalAsVariant(const args : TExprBaseListExec) : Variant; override;
   end;

   TTryReadGlobalVarFunc = class(TInternalMagicBoolFunction)
      function DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean; override;
   end;

   TWriteGlobalVarFunc = class(TInternalMagicBoolFunction)
      function DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean; override;
   end;

   TIncrementGlobalVarFunc = class(TInternalMagicIntFunction)
      function DoEvalAsInteger(const args : TExprBaseListExec) : Int64; override;
   end;

   TDeleteGlobalVarFunc = class(TInternalMagicBoolFunction)
      function DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean; override;
   end;

   TCleanupGlobalVarsFunc = class(TInternalMagicProcedure)
      procedure DoEvalProc(const args : TExprBaseListExec); override;
   end;

   TGlobalVarsNamesFunc = class(TInternalMagicVariantFunction)
      function DoEvalAsVariant(const args : TExprBaseListExec) : Variant; override;
   end;

   TGlobalVarsNamesCommaText = class(TInternalMagicStringFunction)
      procedure DoEvalAsString(const args : TExprBaseListExec; var Result : UnicodeString); override;
   end;

   TSaveGlobalVarsToString = class(TInternalMagicStringFunction)
      procedure DoEvalAsString(const args : TExprBaseListExec; var Result : UnicodeString); override;
   end;

   TLoadGlobalVarsFromString = class(TInternalFunction)
      procedure Execute(info : TProgramInfo); override;
   end;

   TGlobalQueuePushFunc = class(TInternalMagicIntFunction)
      function DoEvalAsInteger(const args : TExprBaseListExec) : Int64; override;
   end;

   TGlobalQueueInsertFunc = class(TInternalMagicIntFunction)
      function DoEvalAsInteger(const args : TExprBaseListExec) : Int64; override;
   end;

   TGlobalQueuePullFunc = class(TInternalMagicBoolFunction)
      function DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean; override;
   end;

   TGlobalQueuePopFunc = class(TInternalMagicBoolFunction)
      function DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean; override;
   end;

   TCleanupGlobalQueuesFunc = class(TInternalMagicProcedure)
      procedure DoEvalProc(const args : TExprBaseListExec); override;
   end;

   TdwsGlobalVarsFunctions = class(TComponent)
   end;

   EGlobalVarError = class (Exception)
   end;

{: Directly write a global var.<p> }
function WriteGlobalVar(const aName: UnicodeString; const aValue: Variant) : Boolean;
{: Directly read a global var.<p> }
function ReadGlobalVar(const aName: UnicodeString): Variant; inline;
function TryReadGlobalVar(const aName: UnicodeString; var value: Variant): Boolean;
{: Directly read a global var, using a default value if variable does not exists.<p> }
function ReadGlobalVarDef(const aName: UnicodeString; const aDefault: Variant): Variant; inline;
{: Increments an integer global var. If not an integer, conversion is attempted.<p>
   Returns the value after the incrementation }
function IncrementGlobalVar(const aName : UnicodeString; const delta : Int64) : Int64;
{: Delete specified global var if it exists. }
function DeleteGlobalVar(const aName : UnicodeString) : Boolean;
{: Resets all global vars.<p> }
procedure CleanupGlobalVars;

{: Save current global vars and their values to a UnicodeString. }
function SaveGlobalVarsToString : RawByteString;
{: Load global vars and their values to a file. }
procedure LoadGlobalVarsFromString(const srcString : RawByteString);
{: Save current global vars and their values to a file. }
procedure SaveGlobalVarsToFile(const destFileName : UnicodeString);
{: Load global vars and their values to a file. }
procedure LoadGlobalVarsFromFile(const srcFileName : UnicodeString);
{: Save current global vars and their values to a file. }
procedure SaveGlobalVarsToStream(destStream : TStream);
{: Load global vars and their values to a file. }
procedure LoadGlobalVarsFromStream(srcStream : TStream);

{: CommaText of the names of all global vars. }
procedure CollectGlobalVarsNames(const filter : String; dest : TStrings);
{: CommaText of the names of all global vars. }
function GlobalVarsNamesCommaText : UnicodeString;

{: Push to global queue and return count (after push) }
function GlobalQueuePush(const aName : String; const aValue : Variant) : Integer;
{: Insert to global queue and return count (after insert) }
function GlobalQueueInsert(const aName : String; const aValue : Variant) : Integer;
function GlobalQueuePull(const aName : String; var aValue : Variant) : Boolean;
function GlobalQueuePop(const aName : String; var aValue : Variant) : Boolean;
procedure CleanupGlobalQueues;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

type

   TGlobalVar = class(TObject)
      private
         Value: Variant;

         procedure WriteToFiler(writer: TWriter; const Name : UnicodeString);
         procedure ReadFromFiler(reader: TReader; var Name : UnicodeString);
   end;

   TNameGlobalVarHash = TSimpleNameObjectHash<TGlobalVar>;

   TGlobalQueue = TSimpleQueue<Variant>;

   TNameGlobalQueueHash = class(TSimpleNameObjectHash<TGlobalQueue>)
      function GetOrCreate(const aName : String) : TGlobalQueue;
   end;

var
   vGlobalVarsCS : TMultiReadSingleWrite;
   vGlobalVars : TNameGlobalVarHash;
   vGlobalVarsNamesCache : UnicodeString;
   vGlobalQueuesCS : TMultiReadSingleWrite;
   vGlobalQueues : TNameGlobalQueueHash;

const
   cGlobalVarsFiles : AnsiString = 'GBF 2.0';

// WriteGlobalVar
//
function WriteGlobalVar(const aName : UnicodeString; const aValue : Variant) : Boolean;
var
   gv : TGlobalVar;
begin
   vGlobalVarsCS.BeginWrite;
   try
      gv:=vGlobalVars.Objects[aName];
      if gv=nil then begin
         gv:=TGlobalVar.Create;
         vGlobalVars.Objects[aName]:=gv;
         gv.Value:=aValue;
         vGlobalVarsNamesCache:='';
         Result:=True;
      end else begin
         Result:=(VarType(gv.Value)<>VarType(aValue)) or (gv.Value<>aValue);
         if Result then
            gv.Value:=aValue;
      end;
   finally
      vGlobalVarsCS.EndWrite;
   end;
end;

// ReadGlobalVarDef
//
function ReadGlobalVarDef(const aName : UnicodeString; const aDefault : Variant) : Variant;
begin
   if not TryReadGlobalVar(aName, Result) then
      Result:=aDefault;
end;

// IncrementGlobalVar
//
function IncrementGlobalVar(const aName : UnicodeString; const delta : Int64) : Int64;
var
   gv : TGlobalVar;
begin
   vGlobalVarsCS.BeginWrite;
   try
      gv:=vGlobalVars.Objects[aName];
      if gv=nil then begin
         vGlobalVarsNamesCache:='';
         gv:=TGlobalVar.Create;
         vGlobalVars.Objects[aName]:=gv;
         gv.Value:=delta;
         Result:=delta;
      end else begin
         Result:=delta+gv.Value;
         gv.Value:=Result;
      end;
   finally
      vGlobalVarsCS.EndWrite;
   end;
end;

// ReadGlobalVar
//
function ReadGlobalVar(const aName : UnicodeString) : Variant;
begin
   // Result (empty) is our default value when calling...
   if not TryReadGlobalVar(aName, Result) then
      VarClear(Result);
end;

// TryReadGlobalVar
//
function TryReadGlobalVar(const aName: UnicodeString; var value: Variant): Boolean;
var
   gv : TGlobalVar;
begin
   vGlobalVarsCS.BeginRead;
   try
      gv:=vGlobalVars.Objects[aName];
      if gv<>nil then begin
         value:=gv.Value;
         Result:=True;
      end else Result:=False;
   finally
      vGlobalVarsCS.EndRead;
   end;
end;

// DeleteGlobalVar
//
function DeleteGlobalVar(const aName : UnicodeString) : Boolean;
var
   gv : TGlobalVar;
begin
   vGlobalVarsCS.BeginWrite;
   try
      gv:=vGlobalVars.Objects[aName];
      if gv<>nil then begin
         gv.Free;
         vGlobalVars.Objects[aName]:=nil;
         vGlobalVarsNamesCache:='';
         Result:=True;
      end else Result:=False;
   finally
      vGlobalVarsCS.EndWrite;
   end;
end;

// CleanupGlobalVars
//
procedure CleanupGlobalVars;
begin
   vGlobalVarsCS.BeginWrite;
   try
      vGlobalVars.Clean;
      vGlobalVarsNamesCache:='';
   finally
      vGlobalVarsCS.EndWrite;
   end;
end;

// SaveGlobalVarsToString
//
function SaveGlobalVarsToString : RawByteString;
var
   wobs : TWriteOnlyBlockStream;
begin
   wobs:=TWriteOnlyBlockStream.Create;
   try
      SaveGlobalVarsToStream(wobs);
      Result:=wobs.ToRawBytes;
   finally
      wobs.Free;
   end;
end;

// LoadGlobalVarsFromString
//
procedure LoadGlobalVarsFromString(const srcString : RawByteString);
var
  ms : TMemoryStream;
begin
   if srcString='' then
      CleanupGlobalVars
   else begin
      ms:=TMemoryStream.Create;
      try
         ms.SetSize(Length(srcString));
         Move(srcString[1], ms.Memory^, Length(srcString));
         LoadGlobalVarsFromStream(ms);
      finally
         ms.Free;
      end;
   end;
end;

procedure SaveGlobalVarsToFile(const destFileName : UnicodeString);
var
   fs : TFileStream;
begin
   fs:=TFileStream.Create(destFileName, fmCreate);
   try
      SaveGlobalVarsToStream(fs);
   finally
      fs.Free;
   end;
end;

procedure LoadGlobalVarsFromFile(const srcFileName : UnicodeString);
var
   fs : TFileStream;
begin
   fs:=TFileStream.Create(srcFileName, fmOpenRead+fmShareDenyWrite);
   try
      LoadGlobalVarsFromStream(fs);
   finally
      fs.Free;
   end;
end;

// SaveGlobalVarsToStream
//
procedure SaveGlobalVarsToStream(destStream : TStream);
var
   i : Integer;
   writer : TWriter;
   gv : TGlobalVar;
   list : TStringList;
begin
   list:=TStringList.Create;
   writer:=TWriter.Create(destStream, 16384);
   try
      writer.Write(cGlobalVarsFiles[1], Length(cGlobalVarsFiles));
      writer.WriteListBegin;

      vGlobalVarsCS.BeginRead;
      try
         vGlobalVars.Enumerate(list);
         for i:=0 to list.Count-1 do begin
            gv:=TGlobalVar(list.Objects[i]);
            if gv<>nil then
               gv.WriteToFiler(writer, list[i]);
         end;
      finally
         vGlobalVarsCS.EndRead;
      end;

      writer.WriteListEnd;
   finally
      writer.Free;
      list.Free;
   end;
end;

// LoadGlobalVarsFromStream
//
procedure LoadGlobalVarsFromStream(srcStream : TStream);
var
   reader : TReader;
   fileTag : AnsiString;
   name : UnicodeString;
   gv : TGlobalVar;
begin
   reader:=TReader.Create(srcStream, 16384);
   try
      SetLength(fileTag, Length(cGlobalVarsFiles));
      if (srcStream.Size-srcStream.Position)>=Length(cGlobalVarsFiles) then
         reader.Read(fileTag[1], Length(cGlobalVarsFiles))
      else fileTag:='';
      if fileTag<>cGlobalVarsFiles then
         raise EGlobalVarError.Create('Invalid file tag');

      vGlobalVarsCS.BeginWrite;
      try
         vGlobalVars.Clean;
         vGlobalVarsNamesCache:='';

         reader.ReadListBegin;
         while not reader.EndOfList do begin
            gv:=TGlobalVar.Create;
            gv.ReadFromFiler(reader, name);
            vGlobalVars.AddObject(name, gv);
         end;
         reader.ReadListEnd;

         vGlobalVarsNamesCache:='';
      finally
         vGlobalVarsCS.EndWrite;
      end;
   finally
      reader.Free;
   end;
end;

// CollectGlobalVarsNames
//
procedure CollectGlobalVarsNames(const filter : String; dest : TStrings);
var
   list : TStringList;
   mask : TMask;
   item : String;
begin
   mask:=TMask.Create(filter);
   list:=TStringList.Create;
   try
      list.CommaText:=GlobalVarsNamesCommaText;
      for item in list do begin
         if mask.Matches(item) then
            dest.Add(item);
      end;
   finally
      list.Free;
      mask.Free;
   end;
end;

// GlobalVarsNamesCommaText
//
function GlobalVarsNamesCommaText : UnicodeString;
var
   i : Integer;
   list : TStringList;
begin
   vGlobalVarsCS.BeginWrite;
   try
      if vGlobalVarsNamesCache='' then begin
         list:=TStringList.Create;
         try
            vGlobalVars.Enumerate(list);
            for i:=list.Count-1 downto 0 do begin
               if list.Objects[i]=nil then
                  list.Delete(i);
            end;
            vGlobalVarsNamesCache:=list.CommaText;
         finally
            list.Free;
         end;
      end;
      Result:=vGlobalVarsNamesCache;
   finally
      vGlobalVarsCS.EndWrite;
   end;
end;

// GetOrCreate
//
function TNameGlobalQueueHash.GetOrCreate(const aName : String) : TGlobalQueue;
begin
   Result:=Objects[aName];
   if Result=nil then begin
      Result:=TGlobalQueue.Create;
      Objects[aName]:=Result;
   end;
end;

// GlobalQueuePush
//
function GlobalQueuePush(const aName : String; const aValue : Variant) : Integer;
var
   gq : TGlobalQueue;
begin
   vGlobalQueuesCS.BeginWrite;
   try
      gq:=vGlobalQueues.GetOrCreate(aName);
      gq.Push(aValue);
      Result:=gq.Count;
   finally
      vGlobalQueuesCS.EndWrite;
   end;
end;

// GlobalQueueInsert
//
function GlobalQueueInsert(const aName : String; const aValue : Variant) : Integer;
var
   gq : TGlobalQueue;
begin
   vGlobalQueuesCS.BeginWrite;
   try
      gq:=vGlobalQueues.GetOrCreate(aName);
      gq.Insert(aValue);
      Result:=gq.Count;
   finally
      vGlobalQueuesCS.EndWrite;
   end;
end;

// GlobalQueuePull
//
function GlobalQueuePull(const aName : String; var aValue : Variant) : Boolean;
var
   gq : TGlobalQueue;
begin
   vGlobalQueuesCS.BeginWrite;
   try
      gq:=vGlobalQueues.Objects[aName];
      if gq<>nil then
         Result:=gq.Pull(aValue)
      else Result:=False;
   finally
      vGlobalQueuesCS.EndWrite;
   end;
end;

// GlobalQueuePop
//
function GlobalQueuePop(const aName : String; var aValue : Variant) : Boolean;
var
   gq : TGlobalQueue;
begin
   vGlobalQueuesCS.BeginWrite;
   try
      gq:=vGlobalQueues.Objects[aName];
      if gq<>nil then
         Result:=gq.Pop(aValue)
      else Result:=False;
   finally
      vGlobalQueuesCS.EndWrite;
   end;
end;

// CleanupGlobalQueues
//
procedure CleanupGlobalQueues;
begin
   vGlobalQueuesCS.BeginWrite;
   try
      vGlobalQueues.Clean;
   finally
      vGlobalQueuesCS.EndWrite;
   end;
end;

// WriteVariant
//
procedure WriteVariant(writer: TWriter; const value: Variant);

   procedure WriteValue(const value: TValueType);
   begin
      writer.Write(value, SizeOf(value));
   end;

begin
   case VarType(Value) of
      varInt64 :
         writer.WriteInteger(PVarData(@value).VInt64);
      varUString :
         {$ifdef FPC}
         writer.WriteString(UnicodeString(PVarData(@value).VString));
         {$else}
         writer.WriteString(UnicodeString(PVarData(@value).VUString));
         {$endif}
      varDouble :
         writer.WriteFloat(PVarData(@value).VDouble);
      varBoolean :
         writer.WriteBoolean(PVarData(@value).VBoolean);
      varEmpty :
         WriteValue(vaNil);
      varNull :
         WriteValue(vaNull);
      varByte, varSmallInt, varInteger :
         writer.WriteInteger(value);
      varString, varOleStr :
         writer.WriteString(value);
      varSingle :
         writer.WriteSingle(value);
      varCurrency :
         writer.WriteCurrency(value);
      varDate :
         writer.WriteDate(value);
   else
      try
         writer.WriteString(Value);
      except
         raise EWriteError.Create('Streaming not supported');
      end;
   end;
end;

// ReadVariant
//
function ReadVariant(reader: TReader): Variant;

  function ReadValue: TValueType;
  begin
    reader.Read(Result, SizeOf(Result));
  end;

const
   {$ifdef FPC}
   cValTtoVarT: array[TValueType] of Integer = (
      varNull, varError, varByte, varSmallInt, varInteger, varDouble,
      varString, varError, varBoolean, varBoolean, varError, varError, varString,
      varEmpty, varError, varSingle, varCurrency, varDate, varOleStr,
      varUInt64, varString, varDouble{$ifdef FPC}, varQWord{$endif}
    );
   {$else}
   cValTtoVarT: array[TValueType] of Integer = (
      varNull, varError, varByte, varSmallInt, varInteger, varDouble,
      varUString, varError, varBoolean, varBoolean, varError, varError, varUString,
      varEmpty, varError, varSingle, varCurrency, varDate, varOleStr,
      varUInt64, varUString, varDouble{$ifdef FPC}, varQWord{$endif}
    );
   {$endif}

var
  valType: TValueType;
begin
  valType := reader.NextValue;
  case valType of
    vaNil, vaNull:
      begin
        if ReadValue = vaNil then
          VarClear(Result)
        else
          Result := NULL;
      end;
    vaInt8: TVarData(Result).VByte := Byte(reader.ReadInteger);
    vaInt16: TVarData(Result).VSmallint := Smallint(reader.ReadInteger);
    vaInt32: TVarData(Result).VInteger := reader.ReadInteger;
    vaInt64: TVarData(Result).VInt64 := reader.ReadInt64;
    vaExtended: TVarData(Result).VDouble := reader.ReadFloat;
    vaSingle: TVarData(Result).VSingle := reader.ReadSingle;
    vaCurrency: TVarData(Result).VCurrency := reader.ReadCurrency;
    vaDate: TVarData(Result).VDate := reader.ReadDate;
    vaString, vaLString, vaUTF8String:
       Result := UnicodeString(reader.ReadString);
    vaWString: Result := reader.ReadString;
    vaFalse, vaTrue:
       TVarData(Result).VBoolean := (reader.ReadValue = vaTrue);
  else
    raise EReadError.Create('Invalid variant stream');
  end;
  TVarData(Result).VType := cValTtoVarT[ValType];
end;

{ TGlobalVar }

procedure TGlobalVar.WriteToFiler(writer: TWriter; const Name : UnicodeString);
begin
   writer.WriteString(Name);
   dwsGlobalVarsFunctions.WriteVariant(writer, Value);
end;

procedure TGlobalVar.ReadFromFiler(reader: TReader; var Name : UnicodeString);
begin
   Name:=reader.ReadString;
   Value:=dwsGlobalVarsFunctions.ReadVariant(reader);
end;

{ TReadGlobalVarFunc }

function TReadGlobalVarFunc.DoEvalAsVariant(const args : TExprBaseListExec) : Variant;
begin
   if not TryReadGlobalVar(args.AsString[0], Result) then
      VarClear(Result);
end;

{ TReadGlobalVarDefFunc }

function TReadGlobalVarDefFunc.DoEvalAsVariant(const args : TExprBaseListExec) : Variant;
begin
   if not TryReadGlobalVar(args.AsString[0], Result) then
      args.ExprBase[1].EvalAsVariant(args.Exec, Result);
end;

{ TTryReadGlobalVarFunc }

function TTryReadGlobalVarFunc.DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean;
var
   v : Variant;
begin
   Result:=TryReadGlobalVar(args.AsString[0], v);
   if Result then
      args.ExprBase[1].AssignValue(args.Exec, v);
end;

{ TWriteGlobalVarFunc }

function TWriteGlobalVarFunc.DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean;
begin
   Result:=WriteGlobalVar(args.AsString[0], args.ExprBase[1].Eval(args.Exec));
end;

{ TIncrementGlobalVarFunc }

function TIncrementGlobalVarFunc.DoEvalAsInteger(const args : TExprBaseListExec) : Int64;
begin
   Result:=IncrementGlobalVar(args.AsString[0], args.AsInteger[1]);
end;

{ TDeleteGlobalVarFunc }

function TDeleteGlobalVarFunc.DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean;
begin
   Result:=DeleteGlobalVar(args.AsString[0]);
end;

{ TCleanupGlobalVarsFunc }

procedure TCleanupGlobalVarsFunc.DoEvalProc(const args : TExprBaseListExec);
begin
   CleanupGlobalVars;
end;

// ------------------
// ------------------ TGlobalVarsNamesFunc ------------------
// ------------------

// DoEvalAsVariant
//
function TGlobalVarsNamesFunc.DoEvalAsVariant(const args : TExprBaseListExec) : Variant;
var
   sl : TStringList;
   newArray : TScriptDynamicArray;
   i : Integer;
begin
   sl:=TStringList.Create;
   try
      CollectGlobalVarsNames(args.AsString[0], sl);
      newArray:=TScriptDynamicArray.CreateNew((args.Exec as TdwsProgramExecution).Prog.SystemTable.SymbolTable.TypString);
      Result:=IScriptObj(newArray);
      newArray.ArrayLength:=sl.Count;
      for i:=0 to newArray.ArrayLength-1 do
         newArray.AsString[i]:=sl[i];
   finally
      sl.Free;
   end;
end;

{ TGlobalVarsNamesCommaText }

procedure TGlobalVarsNamesCommaText.DoEvalAsString(const args : TExprBaseListExec; var Result : UnicodeString);
begin
   Result:=GlobalVarsNamesCommaText;
end;

{ TSaveGlobalVarsToString }

// DoEvalAsString
//
procedure TSaveGlobalVarsToString.DoEvalAsString(const args : TExprBaseListExec; var Result : UnicodeString);
begin
   Result:=RawByteStringToScriptString(SaveGlobalVarsToString);
end;

{ TLoadGlobalVarsFromString }

procedure TLoadGlobalVarsFromString.Execute;
begin
   LoadGlobalVarsFromString(Info.ValueAsDataString['s']);
end;

// ------------------
// ------------------ TGlobalQueuePushFunc ------------------
// ------------------

// DoEvalAsInteger
//
function TGlobalQueuePushFunc.DoEvalAsInteger(const args : TExprBaseListExec) : Int64;
begin
   Result:=GlobalQueuePush(args.AsString[0], args.ExprBase[1].Eval(args.Exec));
end;

// ------------------
// ------------------ TGlobalQueueInsertFunc ------------------
// ------------------

// DoEvalAsInteger
//
function TGlobalQueueInsertFunc.DoEvalAsInteger(const args : TExprBaseListExec) : Int64;
begin
   Result:=GlobalQueueInsert(args.AsString[0], args.ExprBase[1].Eval(args.Exec));
end;

// ------------------
// ------------------ TGlobalQueuePullFunc ------------------
// ------------------

// DoEvalAsBoolean
//
function TGlobalQueuePullFunc.DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean;
var
   v : Variant;
begin
   Result:=GlobalQueuePull(args.AsString[0], v);
   if Result then
      args.ExprBase[1].AssignValue(args.Exec, v);
end;

// ------------------
// ------------------ TGlobalQueuePopFunc ------------------
// ------------------

// DoEvalAsBoolean
//
function TGlobalQueuePopFunc.DoEvalAsBoolean(const args : TExprBaseListExec) : Boolean;
var
   v : Variant;
begin
   Result:=GlobalQueuePop(args.AsString[0], v);
   if Result then
      args.ExprBase[1].AssignValue(args.Exec, v);
end;

// ------------------
// ------------------ TCleanupGlobalQueuesFunc ------------------
// ------------------

// DoEvalProc
//
procedure TCleanupGlobalQueuesFunc.DoEvalProc(const args : TExprBaseListExec);
begin
   CleanupGlobalQueues;
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   vGlobalVarsCS:=TMultiReadSingleWrite.Create;
   vGlobalVars:=TNameGlobalVarHash.Create;
   vGlobalQueuesCS:=TMultiReadSingleWrite.Create;
   vGlobalQueues:=TNameGlobalQueueHash.Create;

   RegisterInternalFunction(TReadGlobalVarFunc, 'ReadGlobalVar', ['n', SYS_STRING], SYS_VARIANT);
   RegisterInternalFunction(TReadGlobalVarDefFunc, 'ReadGlobalVarDef', ['n', SYS_STRING, 'd', SYS_VARIANT], SYS_VARIANT);
   RegisterInternalBoolFunction(TTryReadGlobalVarFunc, 'TryReadGlobalVar', ['n', SYS_STRING, '@v', SYS_VARIANT]);
   RegisterInternalBoolFunction(TWriteGlobalVarFunc, 'WriteGlobalVar', ['n', SYS_STRING, 'v', SYS_VARIANT]);
   RegisterInternalIntFunction(TIncrementGlobalVarFunc, 'IncrementGlobalVar', ['n', SYS_STRING, 'i=1', SYS_INTEGER]);
   RegisterInternalBoolFunction(TDeleteGlobalVarFunc, 'DeleteGlobalVar', ['n', SYS_STRING]);
   RegisterInternalProcedure(TCleanupGlobalVarsFunc, 'CleanupGlobalVars', []);
   RegisterInternalStringFunction(TGlobalVarsNamesCommaText, 'GlobalVarsNamesCommaText', []);
   RegisterInternalFunction(TGlobalVarsNamesFunc, 'GlobalVarsNames', ['filter', SYS_STRING], 'array of string');
   RegisterInternalStringFunction(TSaveGlobalVarsToString, 'SaveGlobalVarsToString', []);
   RegisterInternalProcedure(TLoadGlobalVarsFromString, 'LoadGlobalVarsFromString', ['s', SYS_STRING]);

   RegisterInternalIntFunction(TGlobalQueuePushFunc, 'GlobalQueuePush', ['n', SYS_STRING, 'v', SYS_VARIANT]);
   RegisterInternalIntFunction(TGlobalQueueInsertFunc, 'GlobalQueueInsert', ['n', SYS_STRING, 'v', SYS_VARIANT]);
   RegisterInternalBoolFunction(TGlobalQueuePullFunc, 'GlobalQueuePull', ['n', SYS_STRING, '@v', SYS_VARIANT]);
   RegisterInternalBoolFunction(TGlobalQueuePopFunc, 'GlobalQueuePop', ['n', SYS_STRING, '@v', SYS_VARIANT]);
   RegisterInternalProcedure(TCleanupGlobalQueuesFunc, 'CleanupGlobalQueues', []);

finalization

   CleanupGlobalVars;
   vGlobalVarsCS.Free;
   vGlobalVarsCS:=nil;
   vGlobalVars.Clean;
   vGlobalVars.Free;
   vGlobalVars:=nil;

   CleanupGlobalQueues;
   vGlobalQueuesCS.Free;
   vGlobalQueuesCS:=nil;
   vGlobalQueues.Clean;
   vGlobalQueues.Free;
   vGlobalQueues:=nil;
  
end.
