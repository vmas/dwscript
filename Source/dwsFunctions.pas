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
{                                   }
{**********************************************************************}
unit dwsFunctions;

{$I dws.inc}

interface

uses
  Classes, SysUtils, dwsExprs, dwsSymbols, dwsStrings, dwsTokenizer,
  dwsOperators, dwsUtils, dwsUnitSymbols;

type

   TIdwsUnitFlag = (ufImplicitUse, ufOwnsSymbolTable);
   TIdwsUnitFlags = set of TIdwsUnitFlag;

   // Interface for units
   IdwsUnit = interface
      ['{8D534D12-4C6B-11D5-8DCB-0000216D9E86}']
      function GetUnitName : String;
      function GetUnitTable(systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                            operators : TOperators) : TUnitSymbolTable;
      function GetDependencies : TStrings;
      function GetUnitFlags : TIdwsUnitFlags;
      function GetDeprecatedMessage : String;
   end;

   TIdwsUnitList = class (TSimpleList<IdwsUnit>)
      public
         function IndexOfName(const unitName : String) : Integer;
         function IndexOf(const aUnit : IdwsUnit) : Integer;
         procedure AddUnits(list : TIdwsUnitList);
         function FindDuplicateUnitName : String;
   end;

   TEmptyFunc = class sealed (TInterfacedSelfObject, ICallable)
      public
         procedure Call(exec: TdwsProgramExecution; func: TFuncSymbol);
         procedure InitSymbol(Symbol: TSymbol);
         procedure InitExpression(Expr: TExprBase);
   end;

   TFunctionPrototype = class(TInterfacedSelfObject)
      private
         FFuncSymbol : TFuncSymbol;
      public
         procedure InitSymbol(Symbol: TSymbol); virtual;
         procedure InitExpression(Expr: TExprBase); virtual;
         procedure Call(exec: TdwsProgramExecution; func: TFuncSymbol); virtual; abstract;
         property FuncSymbol : TFuncSymbol read FFuncSymbol;
   end;

   TAnonymousFunction = class(TFunctionPrototype, IUnknown, ICallable)
      public
         constructor Create(FuncSym: TFuncSymbol);
         procedure Call(exec: TdwsProgramExecution; func: TFuncSymbol); override;
         procedure Execute(info : TProgramInfo); virtual; abstract;
   end;

   TInternalFunctionFlag = (iffStateLess, iffOverloaded, iffDeprecated, iffStaticMethod);
   TInternalFunctionFlags = set of TInternalFunctionFlag;

   TInternalFunction = class(TFunctionPrototype, IUnknown, ICallable)
      public
         constructor Create(table : TSymbolTable; const funcName : String;
                            const params : TParamArray; const funcType : String;
                            const flags : TInternalFunctionFlags;
                            compositeSymbol : TCompositeTypeSymbol;
                            const helperName : String); overload; virtual;
         constructor Create(table : TSymbolTable; const funcName : String;
                            const params : array of String; const funcType : String;
                            const flags : TInternalFunctionFlags = [];
                            compositeSymbol : TCompositeTypeSymbol = nil;
                            const helperName : String = ''); overload;
         procedure Call(exec : TdwsProgramExecution; func : TFuncSymbol); override;
         procedure Execute(info : TProgramInfo); virtual; abstract;
   end;
   TInternalFunctionClass = class of TInternalFunction;

   TAnonymousMethod = class(TFunctionPrototype, IUnknown, ICallable)
      public
         constructor Create(MethSym: TMethodSymbol);
         procedure Call(exec: TdwsProgramExecution; func: TFuncSymbol); override;
         procedure Execute(info : TProgramInfo; var ExternalObject: TObject); virtual; abstract;
   end;

   TInternalBaseMethod = class(TFunctionPrototype, IUnknown, ICallable)
      public
         constructor Create(methKind : TMethodKind; attributes : TMethodAttributes;
                            const methName : String; const methParams : array of String;
                            const methType : String; cls : TCompositeTypeSymbol;
                            aVisibility : TdwsVisibility;
                            table : TSymbolTable;
                            overloaded : Boolean = False);
   end;

   TInternalMethod = class(TInternalBaseMethod)
      public
         procedure Call(exec : TdwsProgramExecution; func : TFuncSymbol); override;
         procedure Execute(info : TProgramInfo; var externalObject : TObject); virtual; abstract;
   end;

   TInternalStaticMethod = class (TInternalBaseMethod)
      public
         procedure Call(exec : TdwsProgramExecution; func : TFuncSymbol); override;
         procedure Execute(info : TProgramInfo); virtual; abstract;
   end;

   TInternalRecordMethod = class(TInternalFunction)
      public
         constructor Create(methKind : TMethodKind; attributes : TMethodAttributes;
                            const methName : String; const methParams : array of String;
                            const methType : String; rec : TRecordSymbol;
                            aVisibility : TdwsVisibility;
                            table : TSymbolTable;
                            overloaded : Boolean = False);
   end;

   TInternalInitProc = procedure (systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                                  unitTable : TSymbolTable; operators : TOperators);
   TSymbolsRegistrationProc = procedure (systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                                         unitTable : TSymbolTable);
   TOperatorsRegistrationProc = procedure (systemTable : TSystemSymbolTable; unitTable : TSymbolTable;
                                           operators : TOperators);

   TInternalAbsHandler = function (FProg : TdwsProgram; argExpr : TTypedExpr) : TTypedExpr;
   TInternalSqrHandler = function (FProg : TdwsProgram; argExpr : TTypedExpr) : TTypedExpr;

   TInternalUnit = class(TObject, IdwsUnit)
      private
         FDependencies : TStrings;
         FSymbolsRegistrationProcs : array of TSymbolsRegistrationProc;
         FOperatorsRegistrationProcs : array of TOperatorsRegistrationProc;
         FRegisteredInternalFunctions : TList;
         FStaticSymbols : Boolean;
         FStaticTable : IStaticSymbolTable; // static symbols
         FStaticSystemTable : TSystemSymbolTable;
         FAbsHandlers : array of TInternalAbsHandler;
         FCriticalSection : TFixedCriticalSection;

      protected
         procedure SetStaticSymbols(const Value: Boolean);
         function _AddRef : Integer; stdcall;
         function _Release : Integer; stdcall;
         function QueryInterface({$ifdef FPC}constref{$else}const{$endif} IID: TGUID; out Obj): HResult; stdcall;
         function GetDependencies : TStrings;
         function GetUnitName : String;
         function GetDeprecatedMessage : String;

         procedure InitUnitTable(systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                                 unitTable : TSymbolTable);
         function GetUnitTable(systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                               operators : TOperators) : TUnitSymbolTable;
         function GetUnitFlags : TIdwsUnitFlags;

      public
         constructor Create;
         destructor Destroy; override;

         procedure Lock;
         procedure UnLock;

         procedure AddInternalFunction(rif : Pointer);
         procedure AddSymbolsRegistrationProc(proc : TSymbolsRegistrationProc);
         procedure AddOperatorsRegistrationProc(proc : TOperatorsRegistrationProc);

         procedure AddAbsHandler(const handler : TInternalAbsHandler);
         function HandleAbs(prog : TdwsProgram; argExpr : TTypedExpr) : TTypedExpr;

         procedure InitStaticSymbols(systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                                     operators : TOperators);
         procedure ReleaseStaticSymbols;

         property StaticTable : IStaticSymbolTable read FStaticTable;
         property StaticSymbols : Boolean read FStaticSymbols write SetStaticSymbols;
   end;

   TSourceUnit = class(TInterfacedObject, IdwsUnit)
      private
         FDependencies : TStrings;
         FSymbol : TUnitMainSymbol;

      protected

      public
         constructor Create(const unitName : String; rootTable : TSymbolTable;
                            unitSyms : TUnitMainSymbols);
         destructor Destroy; override;

         function GetUnitName : String;
         function GetUnitTable(systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                               operators : TOperators) : TUnitSymbolTable;
         function GetDependencies : TStrings;
         function GetUnitFlags : TIdwsUnitFlags;
         function GetDeprecatedMessage : String;

         property Symbol : TUnitMainSymbol read FSymbol write FSymbol;
   end;

procedure RegisterInternalFunction(InternalFunctionClass: TInternalFunctionClass;
      const FuncName: String; const FuncParams: array of String;
      const FuncType: String; const flags : TInternalFunctionFlags = [];
      const helperName : String = '');
procedure RegisterInternalProcedure(InternalFunctionClass: TInternalFunctionClass;
      const FuncName: String; const FuncParams: array of String);

procedure RegisterInternalSymbolsProc(proc : TSymbolsRegistrationProc);
procedure RegisterInternalOperatorsProc(proc : TOperatorsRegistrationProc);

function dwsInternalUnit : TInternalUnit;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

uses System.SyncObjs,
     dwsCompilerUtils;

var
   vInternalUnit : TInternalUnit;

// dwsInternalUnit
//
function dwsInternalUnit : TInternalUnit;
begin
   if not Assigned(vInternalUnit) then
      vInternalUnit:=TInternalUnit.Create;
   Result:=vInternalUnit;
end;

// RegisterInternalSymbolsProc
//
procedure RegisterInternalSymbolsProc(proc : TSymbolsRegistrationProc);
begin
   dwsInternalUnit.AddSymbolsRegistrationProc(proc);
end;

// RegisterInternalOperatorsProc
//
procedure RegisterInternalOperatorsProc(proc : TOperatorsRegistrationProc);
begin
   dwsInternalUnit.AddOperatorsRegistrationProc(proc);
end;

// ConvertFuncParams
//
function ConvertFuncParams(const funcParams : array of String) : TParamArray;

   procedure ParamSpecifier(c : Char; paramRec : PParamRec);
   begin
      paramRec.IsVarParam:=(c='@');
      paramRec.IsConstParam:=(c='&');
      paramRec.ParamName:=Copy(paramRec.ParamName, 2, MaxInt)
   end;

   procedure ParamDefaultValue(p : Integer; paramRec : PParamRec);
   begin
      SetLength(paramRec.DefaultValue, 1);
      paramRec.DefaultValue[0]:=Trim(Copy(paramRec.ParamName, p+1, MaxInt));
      paramRec.HasDefaultValue:=True;
      paramRec.ParamName:=Trim(Copy(paramRec.ParamName, 1, p-1));
   end;

var
   x, p : Integer;
   c : Char;
   paramRec : PParamRec;
begin
   SetLength(Result, Length(funcParams) div 2);
   x:=0;
   while x<Length(funcParams)-1 do begin
      paramRec:=@Result[x div 2];

      paramRec.ParamName:=funcParams[x];
      c:=#0;
      if paramRec.ParamName<>'' then
         c:=paramRec.ParamName[1];

      case c of
         '@','&':
            ParamSpecifier(c, paramRec);
      else
         paramRec.IsVarParam:=False;
         paramRec.IsConstParam:=False;
      end;

      p:=Pos('=', paramRec.ParamName);
      if p>0 then
         ParamDefaultValue(p, paramRec);

      paramRec.ParamType:=funcParams[x+1];

      Inc(x, 2);
   end;
end;

type
   TRegisteredInternalFunction = record
      InternalFunctionClass : TInternalFunctionClass;
      FuncName, HelperName : String;
      FuncParams : TParamArray;
      FuncType : String;
      Flags : TInternalFunctionFlags;
   end;
   PRegisteredInternalFunction = ^TRegisteredInternalFunction;

// RegisterInternalFunction
//
procedure RegisterInternalFunction(internalFunctionClass : TInternalFunctionClass;
                                   const funcName : String;
                                   const funcParams : array of String;
                                   const funcType : String;
                                   const flags : TInternalFunctionFlags = [];
                                   const helperName : String = '');
var
   rif : PRegisteredInternalFunction;
begin
   New(rif);
   rif.InternalFunctionClass:=internalFunctionClass;
   rif.FuncName:=FuncName;
   rif.Flags:=flags;
   rif.FuncParams:=ConvertFuncParams(funcParams);
   rif.FuncType:=funcType;
   rif.HelperName:=helperName;

   dwsInternalUnit.AddInternalFunction(rif);
end;

// RegisterInternalProcedure
//
procedure RegisterInternalProcedure(InternalFunctionClass: TInternalFunctionClass;
      const FuncName: String; const FuncParams: array of String);
begin
   RegisterInternalFunction(InternalFunctionClass, FuncName, FuncParams, '');
end;

{ TEmptyFunc }

procedure TEmptyFunc.Call(exec: TdwsProgramExecution; func: TFuncSymbol);
begin
end;

procedure TEmptyFunc.InitSymbol(Symbol: TSymbol);
begin
end;

procedure TEmptyFunc.InitExpression(Expr: TExprBase);
begin
end;

{ TFunctionPrototype }

procedure TFunctionPrototype.InitSymbol(Symbol: TSymbol);
begin
end;

procedure TFunctionPrototype.InitExpression(Expr: TExprBase);
begin
end;

// ------------------
// ------------------ TInternalFunction ------------------
// ------------------

constructor TInternalFunction.Create(table : TSymbolTable; const funcName : String;
                                     const params : TParamArray; const funcType : String;
                                     const flags : TInternalFunctionFlags;
                                     compositeSymbol : TCompositeTypeSymbol;
                                     const helperName : String);
var
   sym: TFuncSymbol;
begin
   sym:=TFuncSymbol.Generate(table, funcName, params, funcType);
   sym.Params.AddParent(table);
   sym.Executable:=ICallable(Self);
   sym.IsStateless:=(iffStateLess in flags);
   sym.IsOverloaded:=(iffOverloaded in flags);
   if iffDeprecated in flags then
      sym.DeprecatedMessage:=SYS_INTEGER;
   FFuncSymbol:=sym;
   table.AddSymbol(sym);

   if helperName<>'' then
      TdwsCompilerUtils.AddProcHelper(helperName, table, sym, nil);
end;

// Create
//
constructor TInternalFunction.Create(table: TSymbolTable; const funcName : String;
                                     const params : array of String; const funcType : String;
                                     const flags : TInternalFunctionFlags = [];
                                     compositeSymbol : TCompositeTypeSymbol = nil;
                                     const helperName : String = '');
begin
   Create(table,
          funcName, ConvertFuncParams(params), funcType,
          flags,
          compositeSymbol, helperName);
end;

// Call
//
procedure TInternalFunction.Call(exec : TdwsProgramExecution; func : TFuncSymbol);
var
   info : TProgramInfo;
begin
   info:=exec.AcquireProgramInfo(func);
   try
      Execute(info);
   finally
      exec.ReleaseProgramInfo(info);
   end;
end;

// ------------------
// ------------------ TInternalBaseMethod ------------------
// ------------------

// Create
//
constructor TInternalBaseMethod.Create(methKind: TMethodKind; attributes: TMethodAttributes;
                                       const methName: String; const methParams: array of String;
                                       const methType: String; cls: TCompositeTypeSymbol;
                                       aVisibility : TdwsVisibility;
                                       table: TSymbolTable;
                                       overloaded : Boolean = False);
var
   sym : TMethodSymbol;
   params : TParamArray;
begin
   params:=ConvertFuncParams(methParams);

   sym:=TMethodSymbol.Generate(table, methKind, attributes, methName, Params,
                               methType, cls, aVisibility, overloaded);
   sym.Params.AddParent(table);
   sym.Executable := ICallable(Self);
   sym.ExternalName := methName;
   FFuncSymbol := sym;

   // Add method to its class
   cls.AddMethod(sym);
end;

// ------------------
// ------------------ TInternalMethod ------------------
// ------------------

// Call
//
procedure TInternalMethod.Call(exec: TdwsProgramExecution; func: TFuncSymbol);
var
   scriptObj : IScriptObj;
   extObj : TObject;
   info : TProgramInfo;
begin
   info:=exec.AcquireProgramInfo(func);
   try
      scriptObj:=Info.Vars[SYS_SELF].ScriptObj;
      if Assigned(scriptObj) then begin
         info.ScriptObj := scriptObj;
         extObj := scriptObj.ExternalObject;
         try
            Execute(info, extObj);
         finally
            scriptObj.ExternalObject := extObj;
            info.ScriptObj := nil;
         end;
      end else begin
         // Class methods or method calls on nil-object-references
         extObj := nil;
         Execute(info, extObj);
      end;
   finally
      exec.ReleaseProgramInfo(info);
   end;
end;

// ------------------
// ------------------ TInternalStaticMethod ------------------
// ------------------

procedure TInternalStaticMethod.Call(exec: TdwsProgramExecution; func: TFuncSymbol);
var
   info : TProgramInfo;
begin
   info:=exec.AcquireProgramInfo(func);
   try
      Execute(info);
   finally
      exec.ReleaseProgramInfo(info);
   end;
end;

// ------------------
// ------------------ TInternalRecordMethod ------------------
// ------------------

// Create
//
constructor TInternalRecordMethod.Create(methKind : TMethodKind; attributes : TMethodAttributes;
                            const methName : String; const methParams : array of String;
                            const methType : String; rec : TRecordSymbol;
                            aVisibility : TdwsVisibility;
                            table : TSymbolTable;
                            overloaded : Boolean = False);
var
   sym : TMethodSymbol;
   params : TParamArray;
begin
   params:=ConvertFuncParams(methParams);

   sym:=TMethodSymbol.Generate(table, methKind, attributes, methName, Params,
                               methType, rec, aVisibility, overloaded);
   sym.Params.AddParent(table);
   sym.Executable := ICallable(Self);
   FFuncSymbol := sym;

   // Add method to its class
   rec.AddMethod(sym);
end;

// ------------------
// ------------------ TAnonymousFunction ------------------
// ------------------


constructor TAnonymousFunction.Create(FuncSym: TFuncSymbol);
begin
   FuncSym.Executable := ICallable(Self);
end;

// Call
//
procedure TAnonymousFunction.Call(exec: TdwsProgramExecution; func: TFuncSymbol);
var
   info : TProgramInfo;
begin
   info:=exec.AcquireProgramInfo(func);
   try
      Execute(info);
   finally
      exec.ReleaseProgramInfo(info);
   end;
end;

{ TAnonymousMethod }

constructor TAnonymousMethod.Create(MethSym: TMethodSymbol);
begin
   MethSym.Executable := ICallable(Self);
end;

procedure TAnonymousMethod.Call(exec: TdwsProgramExecution; func: TFuncSymbol);
var
   info : TProgramInfo;
   scriptObj : IScriptObj;
   extObj : TObject;
begin
   info:=exec.AcquireProgramInfo(func);
   try
      scriptObj:=info.Vars[SYS_SELF].ScriptObj;

      if Assigned(scriptObj) then begin
         info.ScriptObj := scriptObj;
         extObj := scriptObj.ExternalObject;
         try
            Execute(info, extObj);
         finally
            scriptObj.ExternalObject := extObj;
         end;
      end else begin
         // Class methods or method calls on nil-object-references
         extObj := nil;
         Execute(info, extObj);
      end;
   finally
      exec.ReleaseProgramInfo(info);
   end;
end;

// ------------------
// ------------------ TInternalUnit ------------------
// ------------------

// Create
//
constructor TInternalUnit.Create;
begin
   FDependencies:=TStringList.Create;
   FRegisteredInternalFunctions:=TList.Create;
   FStaticSymbols:=True;
   FCriticalSection:=TFixedCriticalSection.Create;
end;

// Destroy
//
destructor TInternalUnit.Destroy;
var
   i : Integer;
   rif : PRegisteredInternalFunction;
begin
   ReleaseStaticSymbols;
   FDependencies.Free;
   for i:=0 to FRegisteredInternalFunctions.Count - 1 do begin
      rif:=PRegisteredInternalFunction(FRegisteredInternalFunctions[i]);
      Dispose(rif);
   end;
   FRegisteredInternalFunctions.Free;
   FCriticalSection.Free;
   inherited;
end;

// Lock
//
procedure TInternalUnit.Lock;
begin
   FCriticalSection.Enter;
end;

// UnLock
//
procedure TInternalUnit.UnLock;
begin
   FCriticalSection.Leave;
end;

// AddSymbolsRegistrationProc
//
procedure TInternalUnit.AddSymbolsRegistrationProc(proc : TSymbolsRegistrationProc);
var
   n : Integer;
begin
   n:=Length(FSymbolsRegistrationProcs);
   SetLength(FSymbolsRegistrationProcs, n+1);
   FSymbolsRegistrationProcs[n]:=proc;
end;

// AddOperatorsRegistrationProc
//
procedure TInternalUnit.AddOperatorsRegistrationProc(proc : TOperatorsRegistrationProc);
var
   n : Integer;
begin
   n:=Length(FOperatorsRegistrationProcs);
   SetLength(FOperatorsRegistrationProcs, n+1);
   FOperatorsRegistrationProcs[n]:=proc;
end;

// AddAbsHandler
//
procedure TInternalUnit.AddAbsHandler(const handler : TInternalAbsHandler);
var
   n : Integer;
begin
   n:=Length(FAbsHandlers);
   SetLength(FAbsHandlers, n+1);
   FAbsHandlers[n]:=handler;
end;

// HandleAbs
//
function TInternalUnit.HandleAbs(prog : TdwsProgram; argExpr : TTypedExpr) : TTypedExpr;
var
   i : Integer;
begin
   Result:=nil;
   for i:=0 to High(FAbsHandlers) do begin
      Result:=FAbsHandlers[i](prog, argExpr);
      if Result<>nil then Exit;
   end;
   argExpr.Free;
end;

// AddInternalFunction
//
procedure TInternalUnit.AddInternalFunction(rif: Pointer);
begin
   FRegisteredInternalFunctions.Add(rif);
end;

// _AddRef
//
function TInternalUnit._AddRef : Integer;
begin
   Result:=-1;
end;

// GetDependencies
//
function TInternalUnit.GetDependencies: TStrings;
begin
   Result:=FDependencies;
end;

// GetUnitName
//
function TInternalUnit.GetUnitName : String;
begin
   Result:=SYS_INTERNAL;
end;

// GetDeprecatedMessage
//
function TInternalUnit.GetDeprecatedMessage : String;
begin
   Result:='';
end;

// InitStaticSymbols
//
procedure TInternalUnit.InitStaticSymbols(
   systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols; operators : TOperators);
begin
   if FStaticTable=nil then begin
      FStaticSystemTable:=systemTable;
      FStaticTable:=TStaticSymbolTable.Create(systemTable);
      try
         InitUnitTable(systemTable, unitSyms, FStaticTable.SymbolTable);
      except
         ReleaseStaticSymbols;
         raise;
      end;
   end;
end;

// ReleaseStaticSymbols
//
procedure TInternalUnit.ReleaseStaticSymbols;
begin
   FStaticSystemTable:=nil;
   FStaticTable:=nil;
end;

// GetUnitTable
//
function TInternalUnit.GetUnitTable(systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                                    operators : TOperators) : TUnitSymbolTable;
var
   i : Integer;
begin
   Lock;
   try
      if FStaticSystemTable<>systemTable then
         ReleaseStaticSymbols;

      if StaticSymbols then begin
         InitStaticSymbols(systemTable, unitSyms, operators);
         Result:=TLinkedSymbolTable.Create(FStaticTable.SymbolTable);
      end else begin
         Result:=TUnitSymbolTable.Create(SystemTable);
         try
            InitUnitTable(systemTable, unitSyms, Result);
         except
            Result.Free;
            raise;
         end;
      end;

      for i:=0 to High(FOperatorsRegistrationProcs) do
         FOperatorsRegistrationProcs[i](systemTable, Result, operators);
   finally
      UnLock;
   end;
end;

// GetUnitFlags
//
function TInternalUnit.GetUnitFlags : TIdwsUnitFlags;
begin
   Result:=[ufImplicitUse];
end;

// InitUnitTable
//
procedure TInternalUnit.InitUnitTable(systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                                      unitTable : TSymbolTable);
var
   i : Integer;
   rif : PRegisteredInternalFunction;
begin
   for i := 0 to High(FSymbolsRegistrationProcs) do
      FSymbolsRegistrationProcs[i](systemTable, unitSyms, unitTable);

   for i := 0 to FRegisteredInternalFunctions.Count - 1 do begin
      rif := PRegisteredInternalFunction(FRegisteredInternalFunctions[i]);
      try
         rif.InternalFunctionClass.Create(unitTable, rif^.FuncName, rif^.FuncParams,
                                          rif^.FuncType, rif^.Flags, nil, rif^.HelperName);
      except
         on e: Exception do
            raise Exception.CreateFmt('AddInternalFunctions failed on %s'#13#10'%s',
                                      [rif.FuncName, e.Message]);
      end;
   end;
end;

function TInternalUnit.QueryInterface({$ifdef FPC}constref{$else}const{$endif} IID: TGUID; out Obj): HResult;
begin
  Result := 0;
end;

function TInternalUnit._Release: Integer;
begin
  Result := -1;
end;

procedure TInternalUnit.SetStaticSymbols(const Value: Boolean);
begin
  FStaticSymbols := Value;
  if not FStaticSymbols then
    ReleaseStaticSymbols;
end;

// ------------------
// ------------------ TIdwsUnitList ------------------
// ------------------

// IndexOf (name)
//
function TIdwsUnitList.IndexOfName(const unitName : String) : Integer;
begin
   for Result:=0 to Count-1 do
      if SameText(Items[Result].GetUnitName, unitName) then
         Exit;
   Result:=-1;
end;

// AddUnits
//
procedure TIdwsUnitList.AddUnits(list : TIdwsUnitList);
var
   i : Integer;
begin
   for i:=0 to list.Count-1 do
      Add(list[i]);
end;

// FindDuplicateUnitName
//
function TIdwsUnitList.FindDuplicateUnitName : String;
var
   i : Integer;
begin
   // Check for duplicate unit names
   for i:=0 to Count-1 do begin
      Result:=Items[i].GetUnitName;
      if IndexOfName(Result)<>i then
         Exit;
   end;
   Result:='';
end;

// IndexOf (IdwsUnit)
//
function TIdwsUnitList.IndexOf(const aUnit : IdwsUnit) : Integer;
begin
   for Result:=0 to Count-1 do
      if Items[Result]=aUnit then
         Exit;
   Result:=-1;
end;


// ------------------
// ------------------ TSourceUnit ------------------
// ------------------

// Create
//
constructor TSourceUnit.Create(const unitName : String; rootTable : TSymbolTable;
                               unitSyms : TUnitMainSymbols);
var
   ums : TUnitMainSymbol;
   ust : TUnitSymbolTable;
begin
   inherited Create;
   FDependencies:=TStringList.Create;
   ust:=TUnitSymbolTable.Create(nil, rootTable.AddrGenerator);
   FSymbol:=TUnitMainSymbol.Create(unitName, ust, unitSyms);
   ust.UnitMainSymbol:=FSymbol;

   FSymbol.CreateInterfaceTable;

   unitSyms.Find(SYS_SYSTEM).ReferenceInSymbolTable(FSymbol.InterfaceTable, True);
   unitSyms.Find(SYS_INTERNAL).ReferenceInSymbolTable(FSymbol.InterfaceTable, True);

   ums:=unitSyms.Find(SYS_DEFAULT);
   if ums<>nil then
      ums.ReferenceInSymbolTable(FSymbol.InterfaceTable, True);
end;

// Destroy
//
destructor TSourceUnit.Destroy;
begin
   FDependencies.Free;
   inherited;
end;

// GetUnitName
//
function TSourceUnit.GetUnitName : String;
begin
   Result:=Symbol.Name;
end;

// GetUnitTable
//
function TSourceUnit.GetUnitTable(systemTable : TSystemSymbolTable; unitSyms : TUnitMainSymbols;
                                  operators : TOperators) : TUnitSymbolTable;
begin
   Result:=(Symbol.Table as TUnitSymbolTable);
end;

// GetDependencies
//
function TSourceUnit.GetDependencies : TStrings;
begin
   Result:=FDependencies;
end;

// GetUnitFlags
//
function TSourceUnit.GetUnitFlags : TIdwsUnitFlags;
begin
   Result:=[ufOwnsSymbolTable];
end;

// GetDeprecatedMessage
//
function TSourceUnit.GetDeprecatedMessage : String;
begin
   Result:=Symbol.DeprecatedMessage;
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

finalization

   vInternalUnit.Free;
   vInternalUnit:=nil;

end.
