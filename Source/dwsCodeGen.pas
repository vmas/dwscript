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
{    Eric Grange                                                       }
{                                                                      }
{**********************************************************************}
unit dwsCodeGen;

interface

uses Classes, SysUtils, dwsUtils, dwsSymbols, dwsExprs, dwsCoreExprs, dwsJSON,
   dwsStrings, dwsUnitSymbols;

   // experimental codegen support classes for DWScipt

type

   TdwsExprCodeGen = class;

   TdwsMappedSymbol = record
      Symbol : TSymbol;
      Name : String;
   end;

   TdwsMappedSymbolHash = class(TSimpleHash<TdwsMappedSymbol>)
      protected
         function SameItem(const item1, item2 : TdwsMappedSymbol) : Boolean; override;
         function GetItemHashCode(const item1 : TdwsMappedSymbol) : Integer; override;
   end;

   TdwsCodeGenSymbolScope = (cgssGlobal, cgssClass, cgssLocal);

   TdwsCodeGenSymbolMaps = class;

   TdwsCodeGenSymbolMap = class
      private
         FParent : TdwsCodeGenSymbolMap;
         FSymbol : TSymbol;
         FHash : TdwsMappedSymbolHash;
         FMaps : TdwsCodeGenSymbolMaps;
         FNames : TFastCompareStringList;
         FLookup : TdwsMappedSymbol;
         FReservedSymbol : TSymbol;
         FPrefix : String;

      protected
         function DoNeedUniqueName(symbol : TSymbol; tryCount : Integer; canObfuscate : Boolean) : String; virtual;

      public
         constructor Create(aParent : TdwsCodeGenSymbolMap; aSymbol : TSymbol);
         destructor Destroy; override;

         function SymbolToName(symbol : TSymbol) : String;
         function NameToSymbol(const name : String; scope : TdwsCodeGenSymbolScope) : TSymbol;

         procedure ReserveName(const name : String); inline;
         procedure ReserveExternalName(sym : TSymbol); inline;

         function MapSymbol(symbol : TSymbol; scope : TdwsCodeGenSymbolScope; canObfuscate : Boolean) : String;
         procedure ForgetSymbol(symbol : TSymbol);

         property Maps : TdwsCodeGenSymbolMaps read FMaps write FMaps;
         property Parent : TdwsCodeGenSymbolMap read FParent;
         property Prefix : String read FPrefix write FPrefix;
         property Symbol : TSymbol read FSymbol;
   end;

   TdwsCodeGenSymbolMaps = class(TObjectList<TdwsCodeGenSymbolMap>)
      private

      protected

      public
         function MapOf(symbol : TSymbol) : TdwsCodeGenSymbolMap;
   end;

   TdwsRegisteredCodeGen = class
      public
         Expr : TExprBaseClass;
         CodeGen : TdwsExprCodeGen;

         destructor Destroy; override;
   end;

   TdwsRegisteredCodeGenList = class(TSortedList<TdwsRegisteredCodeGen>)
      protected
         function Compare(const item1, item2 : TdwsRegisteredCodeGen) : Integer; override;
   end;

   TdwsCodeGenOption = (cgoNoRangeChecks, cgoNoCheckInstantiated, cgoNoCheckLoopStep,
                        cgoNoConditions, cgoNoInlineMagics, cgoObfuscate, cgoNoSourceLocations,
                        cgoOptimizeForSize, cgoSmartLink);
   TdwsCodeGenOptions = set of TdwsCodeGenOption;

   TdwsCodeGenOutputVerbosity = (cgovNone, cgovNormal, cgovVerbose);

   TdwsCodeGen = class
      private
         FCodeGenList : TdwsRegisteredCodeGenList;
         FOutput : TWriteOnlyBlockStream;
         FDependencies : TStringList;
         FFlushedDependencies : TStringList;
         FTempReg : TdwsRegisteredCodeGen;

         FLocalTable : TSymbolTable;
         FTableStack : TTightStack;

         FSymbolDictionary : TdwsSymbolDictionary;
         FSourceContextMap : TdwsSourceContextMap;

         FContext : TdwsProgram;
         FContextStack : TTightStack;

         FLocalVarSymbolMap : TStringList;
         FLocalVarSymbolMapStack : TTightStack;

         FSymbolMap : TdwsCodeGenSymbolMap;
         FSymbolMaps : TdwsCodeGenSymbolMaps;
         FSymbolMapStack : TTightStack;
         FMappedUnits : TTightList;

         FTempSymbolCounter : Integer;
         FCompiledClasses : TTightList;
         FCompiledUnits : TTightList;
         FIndent : Integer;
         FIndentString : String;
         FNeedIndent : Boolean;
         FIndentSize : Integer;
         FOptions : TdwsCodeGenOptions;
         FVerbosity : TdwsCodeGenOutputVerbosity;

      protected
         property SymbolDictionary : TdwsSymbolDictionary read FSymbolDictionary;

         procedure EnterContext(proc : TdwsProgram); virtual;
         procedure LeaveContext; virtual;

         function CreateSymbolMap(parentMap : TdwsCodeGenSymbolMap; symbol : TSymbol) : TdwsCodeGenSymbolMap; virtual;

         procedure EnterScope(symbol : TSymbol);
         procedure LeaveScope;
         function  EnterStructScope(struct : TStructuredTypeSymbol) : Integer;
         procedure LeaveScopes(n : Integer);
         function  IsScopeLevel(symbol : TSymbol) : Boolean;

         procedure RaiseUnknowExpression(expr : TExprBase);

         function  SmartLink(symbol : TSymbol) : Boolean; virtual;

         function  SmartLinkMethod(meth : TMethodSymbol) : Boolean; virtual;

         procedure SmartLinkFilterOutSourceContext(context : TdwsSourceContext);
         procedure SmartLinkFilterSymbolTable(table : TSymbolTable; var changed : Boolean); virtual;
         procedure SmartLinkFilterStructSymbol(structSymbol : TStructuredTypeSymbol; var changed : Boolean); virtual;
         procedure SmartLinkFilterInterfaceSymbol(intfSymbol : TInterfaceSymbol; var changed : Boolean); virtual;
         procedure SmartLinkFilterMemberFieldSymbol(fieldSymbol : TFieldSymbol; var changed : Boolean); virtual;

         procedure DoCompileRecordSymbol(rec : TRecordSymbol); virtual;
         procedure DoCompileClassSymbol(cls : TClassSymbol); virtual;
         procedure DoCompileFuncSymbol(func : TSourceFuncSymbol); virtual;
         procedure DoCompileUnitSymbol(un : TUnitMainSymbol); virtual;

         procedure MapStructuredSymbol(structSym : TStructuredTypeSymbol; canObfuscate : Boolean);

      public
         constructor Create; virtual;
         destructor Destroy; override;

         procedure RegisterCodeGen(expr : TExprBaseClass; codeGen : TdwsExprCodeGen);
         function  FindCodeGen(expr : TExprBase) : TdwsExprCodeGen;
         function  FindSymbolAtStackAddr(stackAddr, level : Integer) : TDataSymbol; deprecated;
         function  SymbolMappedName(sym : TSymbol; scope : TdwsCodeGenSymbolScope) : String; virtual;

         procedure Compile(expr : TExprBase);
         procedure CompileNoWrap(expr : TTypedExpr);
         procedure CompileValue(expr : TTypedExpr); virtual;

         procedure CompileSymbolTable(table : TSymbolTable); virtual;
         procedure CompileUnitSymbol(un : TUnitMainSymbol);
         procedure CompileEnumerationSymbol(enum : TEnumerationSymbol); virtual;
         procedure CompileFuncSymbol(func : TSourceFuncSymbol);
         procedure CompileConditions(func : TFuncSymbol; conditions : TSourceConditions;
                                     preConds : Boolean); virtual;
         procedure CompileRecordSymbol(rec : TRecordSymbol);
         procedure CompileClassSymbol(cls : TClassSymbol);
         procedure BeforeCompileProgram(table, systemTable : TSymbolTable; unitSyms : TUnitMainSymbols);
         procedure CompileProgram(const prog : IdwsProgram); virtual;
         procedure CompileProgramInSession(const prog : IdwsProgram); virtual;
         procedure CompileProgramBody(expr : TNoResultExpr); virtual;

         procedure BeginProgramSession(const prog : IdwsProgram); virtual;
         procedure EndProgramSession; virtual;

         procedure ReserveSymbolNames; virtual;
         procedure MapInternalSymbolNames(progTable, systemTable : TSymbolTable); virtual;
         procedure MapPrioritySymbolNames(table : TSymbolTable); virtual;
         procedure MapNormalSymbolNames(table : TSymbolTable); virtual;

         procedure CompileDependencies(destStream : TWriteOnlyBlockStream; const prog : IdwsProgram); virtual;
         procedure CompileResourceStrings(destStream : TWriteOnlyBlockStream; const prog : IdwsProgram); virtual;

         procedure WriteIndent;
         procedure Indent;
         procedure UnIndent;

         procedure WriteString(const s : String); overload;
         procedure WriteString(const c : Char); overload;
         procedure WriteStringLn(const s : String);
         procedure WriteLineEnd;
         procedure WriteStatementEnd; virtual;
         procedure WriteBlockBegin(const prefix : String); virtual;
         procedure WriteBlockEnd; virtual;
         procedure WriteBlockEndLn;

         procedure WriteSymbolName(sym : TSymbol; scope : TdwsCodeGenSymbolScope = cgssGlobal);

         procedure WriteSymbolVerbosity(sym : TSymbol); virtual;

         function LocationString(e : TExprBase) : String;
         function IncTempSymbolCounter : Integer;
         function GetNewTempSymbol : String; virtual;

         procedure WriteCompiledOutput(dest : TWriteOnlyBlockStream; const prog : IdwsProgram); virtual;
         function CompiledOutput(const prog : IdwsProgram) : String;
         procedure FushDependencies;

         procedure Clear; virtual;

         property Context : TdwsProgram read FContext;
         property LocalTable : TSymbolTable read FLocalTable write FLocalTable;
         property SymbolMap : TdwsCodeGenSymbolMap read FSymbolMap;

         property IndentSize : Integer read FIndentSize write FIndentSize;
         property Options : TdwsCodeGenOptions read FOptions write FOptions;
         property Verbosity : TdwsCodeGenOutputVerbosity read FVerbosity write FVerbosity;

         property Output : TWriteOnlyBlockStream read FOutput;
         property Dependencies : TStringList read FDependencies;
         property FlushedDependencies : TStringList read FFlushedDependencies;
   end;

   TdwsExprCodeGen = class abstract
      public
         procedure CodeGen(codeGen : TdwsCodeGen; expr : TExprBase); virtual;
         procedure CodeGenNoWrap(codeGen : TdwsCodeGen; expr : TTypedExpr); virtual;

         class function ExprIsConstantInteger(expr : TExprBase; value : Integer) : Boolean; static;
   end;

   TdwsGenericCodeGenType = (gcgExpression, gcgStatement);

   TdwsExprGenericCodeGen = class(TdwsExprCodeGen)
      private
         FTemplate : array of TVarRec;
         FCodeGenType : TdwsGenericCodeGenType;
         FUnWrapable : Boolean;
         FDependency : String;

      protected
         procedure DoCodeGen(codeGen : TdwsCodeGen; expr : TExprBase; start, stop : Integer);

      public
         constructor Create(const template : array of const;
                            codeGenType : TdwsGenericCodeGenType = gcgExpression;
                            const dependency : String = ''); overload;

         procedure CodeGen(codeGen : TdwsCodeGen; expr : TExprBase); override;
         procedure CodeGenNoWrap(codeGen : TdwsCodeGen; expr : TTypedExpr); override;
   end;

   ECodeGenException = class (Exception);
   ECodeGenUnknownExpression = class (ECodeGenException);
   ECodeGenUnsupportedSymbol = class (ECodeGenException);

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

// ------------------
// ------------------ TdwsRegisteredCodeGen ------------------
// ------------------

// Destroy
//
destructor TdwsRegisteredCodeGen.Destroy;
begin
   inherited;
   CodeGen.Free;
end;

// ------------------
// ------------------ TdwsRegisteredCodeGenList ------------------
// ------------------

// Compare
//
function TdwsRegisteredCodeGenList.Compare(const item1, item2 : TdwsRegisteredCodeGen) : Integer;
var
   i1, i2 : Integer;
begin
   i1:=NativeInt(item1.Expr);
   i2:=NativeInt(item2.Expr);
   if i1<i2 then
      Result:=-1
   else if i1=i2 then
      Result:=0
   else Result:=1;
end;

// ------------------
// ------------------ TdwsCodeGen ------------------
// ------------------

// Create
//
constructor TdwsCodeGen.Create;
begin
   inherited;
   FCodeGenList:=TdwsRegisteredCodeGenList.Create;
   FOutput:=TWriteOnlyBlockStream.Create;
   FDependencies:=TStringList.Create;
   FDependencies.Sorted:=True;
   FDependencies.Duplicates:=dupIgnore;
   FFlushedDependencies:=TStringList.Create;
   FFlushedDependencies.Sorted:=True;
   FFlushedDependencies.Duplicates:=dupIgnore;
   FTempReg:=TdwsRegisteredCodeGen.Create;
   FSymbolMaps:=TdwsCodeGenSymbolMaps.Create;
   FIndentSize:=3;
end;

// Destroy
//
destructor TdwsCodeGen.Destroy;
begin
   Clear;
   FSymbolMapStack.Free;
   FMappedUnits.Free;
   FSymbolMaps.Free;
   FTempReg.Free;
   FDependencies.Free;
   FFlushedDependencies.Free;
   FOutput.Free;
   FCodeGenList.Clean;
   FCodeGenList.Free;
   FTableStack.Free;
   FContextStack.Free;
   FCompiledClasses.Free;
   FCompiledUnits.Free;
   FLocalVarSymbolMapStack.Free;
   inherited;
end;

// RegisterCodeGen
//
procedure TdwsCodeGen.RegisterCodeGen(expr : TExprBaseClass; codeGen : TdwsExprCodeGen);
var
   reg : TdwsRegisteredCodeGen;
begin
   reg:=TdwsRegisteredCodeGen.Create;
   reg.Expr:=expr;
   reg.CodeGen:=codeGen;
   FCodeGenList.Add(reg);
end;

// FindCodeGen
//
function TdwsCodeGen.FindCodeGen(expr : TExprBase) : TdwsExprCodeGen;
var
   i : Integer;
begin
   FTempReg.Expr:=TExprBaseClass(expr.ClassType);
   if FCodeGenList.Find(FTempReg, i) then
      Result:=FCodeGenList.Items[i].CodeGen
   else Result:=nil;
end;

// FindSymbolAtStackAddr
//
function TdwsCodeGen.FindSymbolAtStackAddr(stackAddr, level : Integer) : TDataSymbol;
var
   i : Integer;
   funcSym : TFuncSymbol;
   dataSym : TDataSymbol;
begin
   if (Context is TdwsProcedure) then begin
      funcSym:=TdwsProcedure(Context).Func;
      Result:=funcSym.Result;
      if (Result<>nil) and (Result.StackAddr=stackAddr) then
         Exit;
   end;

   for i:=0 to FLocalVarSymbolMap.Count-1 do begin
      dataSym:=TDataSymbol(FLocalVarSymbolMap.Objects[i]);
      if (dataSym.StackAddr=stackAddr) and (dataSym.Level=level) then begin
         Result:=dataSym;
         Exit;
      end;
   end;

   if FLocalTable=nil then Exit(nil);
   Result:=FLocalTable.FindSymbolAtStackAddr(stackAddr, level);
end;

// SymbolMappedName
//
function TdwsCodeGen.SymbolMappedName(sym : TSymbol; scope : TdwsCodeGenSymbolScope) : String;
var
   i : Integer;
begin
   if sym is TFuncSymbol then begin
      if TFuncSymbol(sym).IsExternal then
         Exit(TFuncSymbol(sym).ExternalName);
      if (sym is TMethodSymbol) then begin
         while TMethodSymbol(sym).IsOverride do
            sym:=TMethodSymbol(sym).ParentMeth;
      end;
   end else if sym is TClassSymbol then begin
      if TClassSymbol(sym).IsExternal then
         Exit(sym.Name);
   end;
   Result:=FSymbolMap.SymbolToName(sym);
   if Result<>'' then Exit;
   for i:=0 to FSymbolMaps.Count-1 do begin
      Result:=FSymbolMaps[i].SymbolToName(sym);
      if Result<>'' then Exit;
   end;
   Result:=FSymbolMap.MapSymbol(sym, scope, True);
end;

// Clear
//
procedure TdwsCodeGen.Clear;
begin
   FOutput.Clear;
   FDependencies.Clear;
   FFlushedDependencies.Clear;

   FLocalTable:=nil;
   FTableStack.Clear;
   FContext:=nil;
   FContextStack.Clear;
   FCompiledClasses.Clear;
   FCompiledUnits.Clear;
   FMappedUnits.Clear;

   FSymbolMap:=nil;
   FSymbolMaps.Clear;
   EnterScope(nil);

   FIndent:=0;
   FIndentString:='';
   FNeedIndent:=False;

   FTempSymbolCounter:=0;
end;

// Compile
//
procedure TdwsCodeGen.Compile(expr : TExprBase);
var
   cg : TdwsExprCodeGen;
   oldTable : TSymbolTable;
begin
   if expr=nil then Exit;
   cg:=FindCodeGen(expr);
   if cg=nil then
      RaiseUnknowExpression(expr);

   if expr.InheritsFrom(TBlockExpr) then begin
      FTableStack.Push(FLocalTable);
      oldTable:=FLocalTable;
      FLocalTable:=TBlockExpr(expr).Table;
      try
         cg.CodeGen(Self, expr);
      finally
         FLocalTable:=oldTable;
         FTableStack.Pop;
      end;
   end else begin
      cg.CodeGen(Self, expr);
   end;
end;

// CompileNoWrap
//
procedure TdwsCodeGen.CompileNoWrap(expr : TTypedExpr);
var
   cg : TdwsExprCodeGen;
begin
   cg:=FindCodeGen(expr);
   if cg=nil then
      RaiseUnknowExpression(expr);

   cg.CodeGenNoWrap(Self, expr)
end;

// CompileValue
//
procedure TdwsCodeGen.CompileValue(expr : TTypedExpr);
begin
   Compile(expr);
end;

// CompileSymbolTable
//
procedure TdwsCodeGen.CompileSymbolTable(table : TSymbolTable);
var
   sym : TSymbol;
begin
   for sym in table do begin
      if sym is TSourceFuncSymbol then begin
         if sym.Name<>'' then
            CompileFuncSymbol(TSourceFuncSymbol(sym))
      end else if sym is TEnumerationSymbol then
         CompileEnumerationSymbol(TEnumerationSymbol(sym))
      else if sym is TRecordSymbol then
         CompileRecordSymbol(TRecordSymbol(sym))
      else if sym is TClassSymbol then begin
         if FCompiledClasses.IndexOf(sym)<0 then
            CompileClassSymbol(TClassSymbol(sym));
      end;
   end;
end;

// CompileUnitSymbol
//
procedure TdwsCodeGen.CompileUnitSymbol(un : TUnitMainSymbol);
begin
   if FCompiledUnits.IndexOf(un)>=0 then Exit;
   FCompiledUnits.Add(un);

   EnterScope(un);
   DoCompileUnitSymbol(un);
   LeaveScope;
end;

// DoCompileUnitSymbol
//
procedure TdwsCodeGen.DoCompileUnitSymbol(un : TUnitMainSymbol);
var
   oldTable : TSymbolTable;
begin
   CompileSymbolTable(un.Table);

   oldTable:=FLocalTable;
   FLocalTable:=un.ImplementationTable;
   try
      CompileSymbolTable(un.ImplementationTable);
   finally
      FLocalTable:=oldTable;
   end;
end;

// CompileEnumerationSymbol
//
procedure TdwsCodeGen.CompileEnumerationSymbol(enum : TEnumerationSymbol);
begin
   // nothing
end;

// CompileFuncSymbol
//
procedure TdwsCodeGen.CompileFuncSymbol(func : TSourceFuncSymbol);
var
   execSelf : TObject;
   proc : TdwsProcedure;
begin
   // nil executable means it's a function pointer type
   if func.Executable=nil then Exit;
   execSelf:=func.Executable.GetSelf;
   if not (execSelf is TdwsProcedure) then Exit;

   if (func.Name<>'') and not SmartLink(func) then Exit;

   proc:=TdwsProcedure(execSelf);

   EnterScope(func);
   EnterContext(proc);
   try
      DoCompileFuncSymbol(func);
   finally
      LeaveContext;
      LeaveScope;
   end;
end;

// DoCompileFuncSymbol
//
procedure TdwsCodeGen.DoCompileFuncSymbol(func : TSourceFuncSymbol);
var
   proc : TdwsProcedure;
begin
   proc:=(func.Executable.GetSelf as TdwsProcedure);

   if not (cgoNoConditions in Options) then
      CompileConditions(func, proc.PreConditions, True);

   Assert(func.SubExprCount=2);
   Compile(func.SubExpr[0]);
   Compile(func.SubExpr[1]);

   if not (cgoNoConditions in Options) then
      CompileConditions(func, proc.PostConditions, False);
end;

// CompileConditions
//
procedure TdwsCodeGen.CompileConditions(func : TFuncSymbol; conditions : TSourceConditions;
                                        preConds : Boolean);
begin
   // nothing
end;

// CompileRecordSymbol
//
procedure TdwsCodeGen.CompileRecordSymbol(rec : TRecordSymbol);
var
   changed : Boolean;
begin
   if rec.IsExternal then Exit;

   SmartLinkFilterStructSymbol(rec, changed);

   DoCompileRecordSymbol(rec);
end;

// CompileClassSymbol
//
procedure TdwsCodeGen.CompileClassSymbol(cls : TClassSymbol);
var
   changed : Boolean;
begin
   if cls.IsExternal then Exit;

   SmartLinkFilterStructSymbol(cls, changed);

   EnterScope(cls);
   try
      DoCompileClassSymbol(cls);
   finally
      LeaveScope;
   end;
end;

// BeforeCompileProgram
//
procedure TdwsCodeGen.BeforeCompileProgram(table, systemTable : TSymbolTable; unitSyms : TUnitMainSymbols);
var
   i : Integer;
   changed : Boolean;
begin
   ReserveSymbolNames;
   MapInternalSymbolNames(table, systemTable);

   if FSymbolDictionary<>nil then begin
      repeat
         changed:=False;
         for i:=0 to unitSyms.Count-1 do begin
            SmartLinkFilterSymbolTable(unitSyms[i].Table, changed);
            SmartLinkFilterSymbolTable(unitSyms[i].ImplementationTable, changed);
         end;
      until not changed;
   end;

   for i:=0 to unitSyms.Count-1 do
      MapPrioritySymbolNames(unitSyms[i].Table);

   MapPrioritySymbolNames(table);
   MapNormalSymbolNames(table);
end;

// DoCompileRecordSymbol
//
procedure TdwsCodeGen.DoCompileRecordSymbol(rec : TRecordSymbol);
begin
   // nothing by default
end;

// DoCompileClassSymbol
//
procedure TdwsCodeGen.DoCompileClassSymbol(cls : TClassSymbol);
begin
   if FCompiledClasses.IndexOf(cls.Parent)<0 then begin
      if     (cls.Parent.Name<>'TObject')
         and (cls.Parent.Name<>'Exception') then
         CompileClassSymbol(cls.Parent);
   end;
   FCompiledClasses.Add(cls);
end;

// CompileProgram
//
procedure TdwsCodeGen.CompileProgram(const prog : IdwsProgram);
var
   p : TdwsMainProgram;
begin
   p:=prog.ProgramObject;

   if (cgoSmartLink in Options) and (prog.SymbolDictionary.Count>0) then begin
      FSymbolDictionary:=prog.SymbolDictionary;
      FSourceContextMap:=prog.SourceContextMap;
   end;

   p.ResourceStringList.ComputeIndexes;

   BeginProgramSession(prog);
   try
      BeforeCompileProgram(prog.Table, p.SystemTable.SymbolTable, p.UnitMains);

      CompileProgramInSession(prog);
   finally
      EndProgramSession;
      FSymbolDictionary:=nil;
      FSourceContextMap:=nil;
   end;
end;

// CompileProgramInSession
//
procedure TdwsCodeGen.CompileProgramInSession(const prog : IdwsProgram);
var
   p : TdwsProgram;
   i : Integer;
begin
   p:=prog.ProgramObject;

   for i:=0 to p.UnitMains.Count-1 do
      CompileUnitSymbol(p.UnitMains[i]);

   CompileSymbolTable(p.Table);

   Compile(p.InitExpr);

   if not (p.Expr is TNullExpr) then
      CompileProgramBody(p.Expr);
end;

// BeginProgramSession
//
procedure TdwsCodeGen.BeginProgramSession(const prog : IdwsProgram);
var
   p : TdwsProgram;
begin
   if FSymbolMap=nil then
      EnterScope(nil);

   p:=prog.ProgramObject;
   EnterContext(p);
end;

// EndProgramSession
//
procedure TdwsCodeGen.EndProgramSession;
begin
   LeaveContext;
end;

// ReserveSymbolNames
//
procedure TdwsCodeGen.ReserveSymbolNames;
begin
   // nothing
end;

// MapStructuredSymbol
//
procedure TdwsCodeGen.MapStructuredSymbol(structSym : TStructuredTypeSymbol; canObfuscate : Boolean);
var
   sym : TSymbol;
   n : Integer;
   changed : Boolean;
begin
   if FSymbolMaps.MapOf(structSym)<>nil then Exit;

   SmartLinkFilterStructSymbol(structSym, changed);

   if structSym.Parent<>nil then
      MapStructuredSymbol(structSym.Parent, canObfuscate);

   if (structSym.UnitSymbol<>nil) and not IsScopeLevel(structSym.UnitSymbol) then begin
      EnterScope(structSym.UnitSymbol);
      SymbolMap.MapSymbol(structSym, cgssGlobal, canObfuscate);
      LeaveScope;
   end else SymbolMap.MapSymbol(structSym, cgssGlobal, canObfuscate);

   n:=EnterStructScope(structSym);
   if structSym is TRecordSymbol then begin
      for sym in structSym.Members do begin
         if (sym is TMethodSymbol) and (TMethodSymbol(sym).IsClassMethod) then
            SymbolMap.MapSymbol(sym, cgssGlobal, canObfuscate)
         else SymbolMap.MapSymbol(sym, cgssGlobal, canObfuscate);
      end;
   end else begin
      for sym in structSym.Members do
         SymbolMap.MapSymbol(sym, cgssGlobal, canObfuscate);
   end;
   LeaveScopes(n);
end;

// MapInternalSymbolNames
//
procedure TdwsCodeGen.MapInternalSymbolNames(progTable, systemTable : TSymbolTable);

   procedure MapSymbolTable(table : TSymbolTable);
   var
      i : Integer;
      sym : TSymbol;
   begin
      if table.ClassType=TLinkedSymbolTable then
         table:=TLinkedSymbolTable(table).ParentSymbolTable;
      for i:=0 to table.Count-1 do begin
         sym:=table.Symbols[i];
         if sym is TStructuredTypeSymbol then begin
            if (sym is TClassSymbol) or (sym is TRecordSymbol) then begin
               MapStructuredSymbol(TStructuredTypeSymbol(sym), False);
            end else if sym is TInterfaceSymbol then
               SymbolMap.MapSymbol(sym, cgssGlobal, False)
            else Assert(False);
         end else if sym is TFuncSymbol then
            SymbolMap.MapSymbol(sym, cgssGlobal, False)
         else if sym is TDataSymbol then
            SymbolMap.MapSymbol(sym, cgssGlobal, False);
      end;
   end;

var
   u : TUnitSymbol;
begin
   MapSymbolTable(systemTable);
   u:=TUnitSymbol(progTable.FindSymbol(SYS_INTERNAL, cvMagic, TUnitSymbol));
   if u<>nil then
      MapSymbolTable(u.Table);
   u:=TUnitSymbol(progTable.FindSymbol(SYS_DEFAULT, cvMagic, TUnitSymbol));
   if u<>nil then
      MapSymbolTable(u.Table);
end;

// MapPrioritySymbolNames
//
procedure TdwsCodeGen.MapPrioritySymbolNames(table : TSymbolTable);
var
   sym : TSymbol;
   unitSym : TUnitSymbol;
begin
   for sym in table do begin
      if sym is TUnitSymbol then begin
         unitSym:=TUnitSymbol(sym);
         if unitSym.Table is TStaticSymbolTable then
            MapPrioritySymbolNames(unitSym.Table);
      end else if sym is TClassSymbol then begin
         if TClassSymbol(sym).IsExternal then begin
            SymbolMap.ReserveExternalName(sym);
         end;
      end else if sym is TFuncSymbol then begin
         if TFuncSymbol(sym).IsExternal then
            SymbolMap.ReserveExternalName(sym);
      end;
   end;
end;

// MapNormalSymbolNames
//
procedure TdwsCodeGen.MapNormalSymbolNames(table : TSymbolTable);
var
   sym : TSymbol;
   unitSym : TUnitMainSymbol;
begin
   for sym in table do begin
      if sym is TUnitSymbol then begin
         unitSym:=TUnitSymbol(sym).Main;
         if unitSym=nil then continue;
         if not (unitSym.Table is TStaticSymbolTable) then begin
            if FMappedUnits.IndexOf(unitSym)<0 then begin
               FMappedUnits.Add(unitSym);
               EnterScope(unitSym);
               MapNormalSymbolNames(unitSym.Table);
               MapNormalSymbolNames(unitSym.ImplementationTable);
               LeaveScope;
            end;
         end;
      end else if (sym is TClassSymbol) or (sym is TRecordSymbol) then begin
         MapStructuredSymbol(TStructuredTypeSymbol(sym), True);
      end else if sym is TInterfaceSymbol then begin
         SymbolMap.MapSymbol(sym, cgssGlobal, True);
      end else if sym is TFuncSymbol then begin
         SymbolMap.MapSymbol(sym, cgssGlobal, True);
         if     (TFuncSymbol(sym).Executable<>nil)
            and (TFuncSymbol(sym).Executable.GetSelf is TdwsProcedure) then
            MapNormalSymbolNames((TFuncSymbol(sym).Executable.GetSelf as TdwsProcedure).Table);
      end else if sym is TDataSymbol then begin
         SymbolMap.MapSymbol(sym, cgssGlobal, True);
      end;
   end;
end;

// CompileProgramBody
//
procedure TdwsCodeGen.CompileProgramBody(expr : TNoResultExpr);
begin
   Compile(expr);
end;

// CompileDependencies
//
procedure TdwsCodeGen.CompileDependencies(destStream : TWriteOnlyBlockStream; const prog : IdwsProgram);
begin
   // nothing
end;

// CompileResourceStrings
//
procedure TdwsCodeGen.CompileResourceStrings(destStream : TWriteOnlyBlockStream; const prog : IdwsProgram);
begin
   // nothing
end;

// WriteIndent
//
procedure TdwsCodeGen.WriteIndent;
begin
   Output.WriteString(FIndentString);
end;

// Indent
//
procedure TdwsCodeGen.Indent;
begin
   Inc(FIndent);
   FIndentString:=StringOfChar(' ', FIndent*FIndentSize);
   FNeedIndent:=True;
end;

// UnIndent
//
procedure TdwsCodeGen.UnIndent;
begin
   Dec(FIndent);
   FIndentString:=StringOfChar(' ', FIndent*FIndentSize);
   FNeedIndent:=True;
end;

// WriteString
//
procedure TdwsCodeGen.WriteString(const s : String);
begin
   if FNeedIndent then begin
      WriteIndent;
      FNeedIndent:=False;
   end;
   Output.WriteString(s);
end;

// WriteString
//
procedure TdwsCodeGen.WriteString(const c : Char);
begin
   if FNeedIndent then begin
      WriteIndent;
      FNeedIndent:=False;
   end;
   Output.WriteChar(c);
end;

// WriteStringLn
//
procedure TdwsCodeGen.WriteStringLn(const s : String);
begin
   WriteString(s);
   WriteLineEnd;
end;

// WriteLineEnd
//
procedure TdwsCodeGen.WriteLineEnd;
begin
   Output.WriteString(#13#10);
   FNeedIndent:=True;
end;

// WriteStatementEnd
//
procedure TdwsCodeGen.WriteStatementEnd;
begin
   WriteStringLn(';');
end;

// WriteBlockBegin
//
procedure TdwsCodeGen.WriteBlockBegin(const prefix : String);
begin
   WriteString(prefix);
   WriteStringLn('{');
   Indent;
end;

// WriteBlockEnd
//
procedure TdwsCodeGen.WriteBlockEnd;
begin
   UnIndent;
   WriteString('}');
end;

// WriteBlockEndLn
//
procedure TdwsCodeGen.WriteBlockEndLn;
begin
   WriteBlockEnd;
   WriteLineEnd;
end;

// WriteSymbolName
//
procedure TdwsCodeGen.WriteSymbolName(sym : TSymbol; scope : TdwsCodeGenSymbolScope = cgssGlobal);
begin
   WriteString(SymbolMappedName(sym, scope));
end;

// WriteSymbolVerbosity
//
procedure TdwsCodeGen.WriteSymbolVerbosity(sym : TSymbol);
begin
   // nothing by default
end;

// LocationString
//
function TdwsCodeGen.LocationString(e : TExprBase) : String;
begin
   if Context is TdwsMainProgram then
      Result:=e.ScriptPos.AsInfo
   else Result:=' in '+e.ScriptLocation(Context);
end;

// IncTempSymbolCounter
//
function TdwsCodeGen.IncTempSymbolCounter : Integer;
begin
   Inc(FTempSymbolCounter);
   Result:=FTempSymbolCounter;
end;

// GetNewTempSymbol
//
function TdwsCodeGen.GetNewTempSymbol : String;
begin
   Inc(FTempSymbolCounter);
   Result:=IntToStr(FTempSymbolCounter);
end;

// WriteCompiledOutput
//
procedure TdwsCodeGen.WriteCompiledOutput(dest : TWriteOnlyBlockStream; const prog : IdwsProgram);
begin
   CompileResourceStrings(dest, prog);
   CompileDependencies(dest, prog);
   dest.WriteString(Output.ToString);
end;

// CompiledOutput
//
function TdwsCodeGen.CompiledOutput(const prog : IdwsProgram) : String;
var
   buf : TWriteOnlyBlockStream;
begin
   buf:=TWriteOnlyBlockStream.Create;
   try
      WriteCompiledOutput(buf, prog);
      Result:=buf.ToString;
   finally
      buf.Free;
   end;
end;

// FushDependencies
//
procedure TdwsCodeGen.FushDependencies;
begin
   FFlushedDependencies.Assign(FDependencies);
   FDependencies.Clear;
end;

// EnterContext
//
procedure TdwsCodeGen.EnterContext(proc : TdwsProgram);
var
   i : Integer;
   sym : TSymbol;
begin
   FTableStack.Push(FLocalTable);
   FContextStack.Push(FContext);
   FLocalTable:=proc.Table;
   FContext:=proc;

   FLocalVarSymbolMapStack.Push(FLocalVarSymbolMap);
   FLocalVarSymbolMap:=TStringList.Create;
   for i:=0 to FLocalTable.Count-1 do begin
      sym:=FLocalTable.Symbols[i];
      if sym is TDataSymbol then
         FLocalVarSymbolMap.AddObject(sym.Name, sym);
   end;
   proc.Expr.RecursiveEnumerateSubExprs(
      procedure (parent, expr : TExprBase; var abort : Boolean)
      var
         i, k, n : Integer;
         sym : TSymbol;
         locName : String;
      begin
         if not (expr is TBlockExpr) then Exit;
         for i:=0 to TBlockExpr(expr).Table.Count-1 do begin
            sym:=TBlockExpr(expr).Table.Symbols[i];
            if sym is TDataSymbol then begin
               if FLocalVarSymbolMap.IndexOf(sym.Name)>=0 then begin
                  n:=1;
                  repeat
                     locName:=Format('%s_%d', [sym.Name, n]);
                     k:=FLocalVarSymbolMap.IndexOf(locName);
                     Inc(n);
                  until k<0;
                  FLocalVarSymbolMap.AddObject(locName, sym);
                  //FSymbolMap.AddObject(locName, sym);
               end else begin
                  FLocalVarSymbolMap.AddObject(sym.Name, sym);
               end;
            end;
         end;
      end);
end;

// LeaveContext
//
procedure TdwsCodeGen.LeaveContext;
begin
   FLocalTable:=TSymbolTable(FTableStack.Peek);
   FTableStack.Pop;
   FContext:=TdwsProgram(FContextStack.Peek);
   FContextStack.Pop;

   FLocalVarSymbolMap.Free;
   FLocalVarSymbolMap:=TStringList(FLocalVarSymbolMapStack.Peek);
   FLocalVarSymbolMapStack.Pop;
end;

// CreateSymbolMap
//
function TdwsCodeGen.CreateSymbolMap(parentMap : TdwsCodeGenSymbolMap; symbol : TSymbol) : TdwsCodeGenSymbolMap;
begin
   Result:=TdwsCodeGenSymbolMap.Create(FSymbolMap, symbol);
end;

// EnterScope
//
procedure TdwsCodeGen.EnterScope(symbol : TSymbol);
var
   map : TdwsCodeGenSymbolMap;
begin
   FSymbolMapStack.Push(FSymbolMap);
   if symbol is TUnitSymbol then
      symbol:=TUnitSymbol(symbol).Main;
   map:=FSymbolMaps.MapOf(symbol);
   if map=nil then begin
      FSymbolMap:=CreateSymbolMap(FSymbolMap, symbol);
      FSymbolMap.Maps:=FSymbolMaps;
      FSymbolMaps.Add(FSymbolMap);
   end else begin
      map.FParent:=FSymbolMap;
      FSymbolMap:=map;
   end;
end;

// LeaveScope
//
procedure TdwsCodeGen.LeaveScope;
begin
   Assert(FSymbolMap<>nil);
   FSymbolMap.FParent:=nil;
   FSymbolMap:=TdwsCodeGenSymbolMap(FSymbolMapStack.Peek);
   FSymbolMapStack.Pop;
end;

// EnterStructScope
//
function TdwsCodeGen.EnterStructScope(struct : TStructuredTypeSymbol) : Integer;
begin
   if struct<>nil then begin
      Result:=EnterStructScope(struct.Parent)+1;
      EnterScope(struct);
   end else Result:=0;
end;

// LeaveScopes
//
procedure TdwsCodeGen.LeaveScopes(n : Integer);
begin
   while n>0 do begin
      LeaveScope;
      Dec(n);
   end;
end;

// IsScopeLevel
//
function TdwsCodeGen.IsScopeLevel(symbol : TSymbol) : Boolean;
var
   m : TdwsCodeGenSymbolMap;
begin
   m:=FSymbolMap;
   while m<>nil do begin
      if m.Symbol=symbol then Exit(True);
      m:=m.Parent;
   end;
   Result:=False;
end;

// RaiseUnknowExpression
//
procedure TdwsCodeGen.RaiseUnknowExpression(expr : TExprBase);
begin
   raise ECodeGenUnknownExpression.CreateFmt('%s: unknown expression class %s:%s',
                                             [ClassName, expr.ClassName, expr.ScriptLocation(Context)]);
end;

// SmartLink
//
function TdwsCodeGen.SmartLink(symbol : TSymbol): Boolean;

   function IsReferenced(symbol : TSymbol) : Boolean;
   var
      list : TSymbolPositionList;
   begin
      list:=FSymbolDictionary.FindSymbolPosList(symbol);
      Result:=(list<>nil) and (list.FindUsage(suReference)<>nil);
   end;

begin
   Result:=(FSymbolDictionary=nil) or IsReferenced(symbol);
end;

// SmartLinkMethod
//
//  TSub = class (TBase)
//
function TdwsCodeGen.SmartLinkMethod(meth : TMethodSymbol) : Boolean;
var
   i : Integer;
   symPos : TSymbolPositionList;
   lookup : TMethodSymbol;
   isUsed : Boolean;
begin
   Result:=SmartLink(meth);
   if Result then Exit;

   // interfaces aren't smart-linked yet
   if meth.IsInterfaced then Exit(True);
   // constructors/destructors aren't smart-linked yet
   if meth.Kind in [fkConstructor, fkDestructor] then Exit(True);
   // virtual class methods aren't smart-linked yet
   if meth.IsClassMethod and meth.IsVirtual then Exit(True);

   // regular resolution works for non-virtual methods
   if not meth.IsVirtual then Exit;

   // the virtual method should be included if itself or any
   // of its overrides are used
   // filtering of unused subclasses is assumed to have been made already
   for i:=0 to FSymbolDictionary.Count-1 do begin
      symPos:=FSymbolDictionary.Items[i];
      // only check methods
      if not (symPos.Symbol is TMethodSymbol) then continue;

      lookup:=TMethodSymbol(symPos.Symbol);
      // quick filter on vmt index
      if (not lookup.IsVirtual) or (lookup.VMTIndex<>meth.VMTIndex) then continue;

      // is it an override of our method?
      while (lookup<>meth) and (lookup<>nil) do begin
         lookup:=lookup.ParentMeth;
      end;
      if (lookup=nil) then continue;

      // is it used anywhere?
      isUsed:=(symPos.FindUsage(suReference)<>nil);
      lookup:=TMethodSymbol(symPos.Symbol);
      while (lookup<>nil) and (not isUsed) do begin
         isUsed:=   lookup.IsInterfaced
                 or (FSymbolDictionary.FindSymbolUsage(lookup, suReference)<>nil);
         lookup:=lookup.ParentMeth;
      end;

      if isUsed then Exit(True);
   end;
   Output.WriteString('// IGNORED: '+meth.StructSymbol.Name+'.'+meth.Name+#13#10);
   Result:=False;
end;

// SmartLinkFilterOutSourceContext
//
procedure TdwsCodeGen.SmartLinkFilterOutSourceContext(context : TdwsSourceContext);
begin
   FSymbolDictionary.RemoveInRange(context.StartPos, context.EndPos);
end;

// SmartLinkFilterSymbolTable
//
procedure TdwsCodeGen.SmartLinkFilterSymbolTable(table : TSymbolTable; var changed : Boolean);

   procedure RemoveReferencesInContextMap(symbol : TSymbol);
   begin
      if FSourceContextMap=nil then Exit;
      FSourceContextMap.EnumerateContextsOfSymbol(symbol, SmartLinkFilterOutSourceContext);
   end;

var
   sym : TSymbol;
   localChanged : Boolean;
   funcSym : TFuncSymbol;
begin
   if FSymbolDictionary=nil then Exit;

   repeat
      localChanged:=False;
      for sym in table do begin
         if sym is TStructuredTypeSymbol then begin

            if sym is TInterfaceSymbol then
               SmartLinkFilterInterfaceSymbol(TInterfaceSymbol(sym), localChanged)
            else SmartLinkFilterStructSymbol(TStructuredTypeSymbol(sym), localChanged);

         end else if sym is TFuncSymbol then begin

            funcSym:=TFuncSymbol(sym);
            if funcSym.IsExternal or funcSym.IsType then continue;
            if not SmartLink(funcSym) then begin
               if FSymbolDictionary.FindSymbolPosList(funcSym)<>nil then begin
                  RemoveReferencesInContextMap(funcSym);
                  FSymbolDictionary.Remove(funcSym);
                  localChanged:=True;
               end;
            end;

         end;
      end;
      changed:=changed or localChanged;
   until not localChanged;
end;

// SmartLinkFilterStructSymbol
//
procedure TdwsCodeGen.SmartLinkFilterStructSymbol(structSymbol : TStructuredTypeSymbol; var changed : Boolean);

   procedure RemoveReferencesInContextMap(symbol : TSymbol);
   begin
      if FSourceContextMap=nil then Exit;
      FSourceContextMap.EnumerateContextsOfSymbol(symbol, SmartLinkFilterOutSourceContext);
   end;

var
   i : Integer;
   member : TSymbol;
   method : TMethodSymbol;
   prop : TPropertySymbol;
   localChanged : Boolean;
   symPosList : TSymbolPositionList;
   symPos : TSymbolPosition;
   selfReferencedOnly, foundSelf : Boolean;
   srcContext : TdwsSourceContext;
begin
   if FSymbolDictionary=nil then Exit;

   symPosList:=FSymbolDictionary.FindSymbolPosList(structSymbol);
   if symPosList=nil then Exit;

   // remove unused field members
   for member in structSymbol.Members do begin
      if member is TFieldSymbol then begin
         if FSymbolDictionary.FindSymbolPosList(member)<>nil then
            SmartLinkFilterMemberFieldSymbol(TFieldSymbol(member), changed);
      end;
   end;

   // is symbol only referenced by its members?
   selfReferencedOnly:=True;
   for i:=0 to symPosList.Count-1 do begin
      symPos:=symPosList[i];
      if suReference in symPos.SymbolUsages then begin
         srcContext:=FSourceContextMap.FindContext(symPos.ScriptPos);
         foundSelf:=False;
         while srcContext<>nil do begin
            if srcContext.ParentSym=structSymbol then begin
               foundSelf:=True;
               Break;
            end;
            if     (srcContext.ParentSym is TMethodSymbol)
               and (TMethodSymbol(srcContext.ParentSym).StructSymbol=structSymbol) then begin
               foundSelf:=True;
               Break;
            end;
            srcContext:=srcContext.Parent;
         end;
         if not foundSelf then begin
            selfReferencedOnly:=False;
            Break;
         end;
      end;
   end;
   if selfReferencedOnly then begin
      FSymbolDictionary.Remove(structSymbol);
      RemoveReferencesInContextMap(structSymbol);
      for member in structSymbol.Members do begin
         RemoveReferencesInContextMap(member);
         FSymbolDictionary.Remove(member);
      end;
      changed:=True;
      Exit;
   end;

   // remove members cross-references
   repeat
      localChanged:=False;
      for member in structSymbol.Members do begin

         if member is TPropertySymbol then begin

            prop:=TPropertySymbol(member);
            if prop.Visibility=cvPublished then continue;

         end else if member is TMethodSymbol then begin

            method:=TMethodSymbol(member);
            if    method.IsVirtual or method.IsInterfaced
               or (method.Kind=fkConstructor) then continue;

         end else continue;

         if not SmartLink(member) then begin
            if FSymbolDictionary.FindSymbolPosList(member)<>nil then begin
               RemoveReferencesInContextMap(member);
               FSymbolDictionary.Remove(member);
               localChanged:=True;
            end;
         end;

      end;
      changed:=changed or localChanged;
   until not localChanged;
end;

// SmartLinkFilterInterfaceSymbol
//
procedure TdwsCodeGen.SmartLinkFilterInterfaceSymbol(intfSymbol : TInterfaceSymbol; var changed : Boolean);
var
   i : Integer;
   symPosList : TSymbolPositionList;
   symPos : TSymbolPosition;
begin
   if FSymbolDictionary=nil then Exit;

   symPosList:=FSymbolDictionary.FindSymbolPosList(intfSymbol);
   if symPosList=nil then Exit;

   for i:=0 to symPosList.Count-1 do begin
      symPos:=symPosList.Items[i];
      if symPos.SymbolUsages=[suDeclaration] then continue;
      Exit;
   end;

   FSymbolDictionary.Remove(intfSymbol);
end;

// SmartLinkFilterMemberFieldSymbol
//
procedure TdwsCodeGen.SmartLinkFilterMemberFieldSymbol(fieldSymbol : TFieldSymbol; var changed : Boolean);
var
   fieldType : TTypeSymbol;
   fieldDeclarationPos : TSymbolPosition;
   typeReferencePos : TSymbolPosition;
   typeReferencePosList : TSymbolPositionList;
   i : Integer;
begin
   if SmartLink(fieldSymbol) then Exit;

   fieldType:=fieldSymbol.Typ;

   fieldDeclarationPos:=FSymbolDictionary.FindSymbolUsage(fieldSymbol, suDeclaration);
   if fieldDeclarationPos<>nil then begin
      typeReferencePosList:=FSymbolDictionary.FindSymbolPosList(fieldType);
      if typeReferencePosList<>nil then begin
         for i:=0 to typeReferencePosList.Count-1 do begin
            typeReferencePos:=typeReferencePosList.Items[i];
            if     (typeReferencePos.SymbolUsages=[suReference])
               and (typeReferencePos.ScriptPos.SourceFile=fieldDeclarationPos.ScriptPos.SourceFile)
               and (typeReferencePos.ScriptPos.Line=fieldDeclarationPos.ScriptPos.Line)
               and (typeReferencePos.ScriptPos.Col>fieldDeclarationPos.ScriptPos.Col) then begin
               typeReferencePosList.Delete(i);
               Break;
            end;
         end;
      end;
      FSymbolDictionary.Remove(fieldSymbol);
      changed:=True;
   end;
end;

// ------------------
// ------------------ TdwsExprGenericCodeGen ------------------
// ------------------

// Create
//
constructor TdwsExprGenericCodeGen.Create(const template : array of const;
                                          codeGenType : TdwsGenericCodeGenType = gcgExpression;
                                          const dependency : String = '');
var
   i : Integer;
begin
   inherited Create;
   FCodeGenType:=codeGenType;
   SetLength(FTemplate, Length(template));
   for i:=0 to High(template) do
      FTemplate[i]:=template[i];
   if codeGenType<>gcgStatement then begin
      i:=High(template);
      FUnWrapable:=    (FTemplate[0].VType=vtWideChar) and (FTemplate[0].VWideChar='(')
                   and (FTemplate[i].VType=vtWideChar) and (FTemplate[i].VWideChar=')');
   end else FUnWrapable:=False;
   FDependency:=dependency;
end;

// CodeGen
//
procedure TdwsExprGenericCodeGen.CodeGen(codeGen : TdwsCodeGen; expr : TExprBase);
begin
   DoCodeGen(codeGen, expr, 0, High(FTemplate));
end;

// CodeGenNoWrap
//
procedure TdwsExprGenericCodeGen.CodeGenNoWrap(codeGen : TdwsCodeGen; expr : TTypedExpr);
begin
   if FUnWrapable then
      DoCodeGen(codeGen, expr, 1, High(FTemplate)-1)
   else DoCodeGen(codeGen, expr, 0, High(FTemplate));
end;

// DoCodeGen
//
procedure TdwsExprGenericCodeGen.DoCodeGen(codeGen : TdwsCodeGen; expr : TExprBase; start, stop : Integer);

   function IsBoundaryChar(var v : TVarRec) : Boolean;
   begin
      Result:=    (v.VType=vtWideChar)
              and (   (v.VWideChar='(')
                   or (v.VWideChar=',')
                   or (v.VWideChar=')'));
   end;

   function IsBlockEndChar(var v : TVarRec) : Boolean;
   begin
      Result:=    (v.VType=vtWideChar)
              and (v.VWideChar='}');
   end;

var
   i, idx : Integer;
   c : Char;
   item : TExprBase;
   noWrap : Boolean;
begin
   if FDependency<>'' then
      codeGen.Dependencies.Add(FDependency);
   for i:=start to stop do begin
      case FTemplate[i].VType of
         vtInteger : begin
            idx:=FTemplate[i].VInteger;
            if idx>=0 then begin
               item:=expr.SubExpr[idx];
               noWrap:=(item is TVarExpr) or (item is TFieldExpr);
               if not noWrap then begin
                  noWrap:=    (i>start) and IsBoundaryChar(FTemplate[i-1])
                          and (i<stop) and IsBoundaryChar(FTemplate[i+1])
                          and (item is TTypedExpr);
               end;
            end else begin
               item:=expr.SubExpr[-idx];
               noWrap:=True;
            end;
            if noWrap then
               codeGen.CompileNoWrap(TTypedExpr(item))
            else codeGen.Compile(item);
         end;
         vtUnicodeString :
            codeGen.WriteString(String(FTemplate[i].VUnicodeString));
         vtWideChar : begin
            c:=FTemplate[i].VWideChar;
            case c of
               #9 : begin
                  codeGen.WriteLineEnd;
                  codeGen.Indent;
               end;
               #8 : codeGen.UnIndent;
            else
               codeGen.WriteString(c);
            end;
         end;
      else
         Assert(False);
      end;
   end;
   if FCodeGenType=gcgStatement then begin
      if IsBlockEndChar(FTemplate[stop]) then
         codeGen.WriteLineEnd
      else codeGen.WriteStatementEnd;
   end;
end;

// ------------------
// ------------------ TdwsExprCodeGen ------------------
// ------------------

// CodeGen
//
procedure TdwsExprCodeGen.CodeGen(codeGen : TdwsCodeGen; expr : TExprBase);
begin
   if expr is TTypedExpr then begin
      codeGen.WriteString('(');
      CodeGenNoWrap(codeGen, TTypedExpr(expr));
      codeGen.WriteString(')');
   end;
end;

// CodeGenNoWrap
//
procedure TdwsExprCodeGen.CodeGenNoWrap(codeGen : TdwsCodeGen; expr : TTypedExpr);
begin
   Self.CodeGen(codeGen, expr);
end;

// ExprIsConstantInteger
//
class function TdwsExprCodeGen.ExprIsConstantInteger(expr : TExprBase; value : Integer) : Boolean;
begin
   Result:=    (expr<>nil)
           and (expr.ClassType=TConstIntExpr)
           and (expr.EvalAsInteger(nil)=value);
end;

// ------------------
// ------------------ TdwsMappedSymbolHash ------------------
// ------------------

// SameItem
//
function TdwsMappedSymbolHash.SameItem(const item1, item2 : TdwsMappedSymbol) : Boolean;
begin
   Result:=(item1.Symbol=item2.Symbol);
end;

// GetItemHashCode
//
function TdwsMappedSymbolHash.GetItemHashCode(const item1 : TdwsMappedSymbol) : Integer;
begin
   Result:=NativeInt(item1.Symbol);
   Result:=(Result shr 4) xor (Result shr 9);
end;

// ------------------
// ------------------ TdwsCodeGenSymbolMap ------------------
// ------------------

// Create
//
constructor TdwsCodeGenSymbolMap.Create(aParent : TdwsCodeGenSymbolMap; aSymbol : TSymbol);
begin
   inherited Create;
   FHash:=TdwsMappedSymbolHash.Create;
   FParent:=aParent;
   FSymbol:=aSymbol;
   FNames:=TFastCompareStringList.Create;
   FNames.Sorted:=True;
   FNames.Duplicates:=dupError;
   FReservedSymbol:=TSymbol.Create('', nil);
   if aSymbol is TUnitSymbol then
      FPrefix:=aSymbol.Name+'_';
end;

// Destroy
//
destructor TdwsCodeGenSymbolMap.Destroy;
begin
   FReservedSymbol.Free;
   FHash.Free;
   FNames.Free;
   inherited;
end;

// SymbolToName
//
function TdwsCodeGenSymbolMap.SymbolToName(symbol : TSymbol) : String;
begin
   FLookup.Symbol:=symbol;
   if FHash.Match(FLookup) then
      Result:=FLookup.Name
   else if Parent<>nil then
      Result:=Parent.SymbolToName(symbol)
   else Result:='';
end;

// ForgetSymbol
//
procedure TdwsCodeGenSymbolMap.ForgetSymbol(symbol : TSymbol);
begin
   FLookup.Symbol:=symbol;
   if not FHash.Extract(FLookup) then
      Assert(False)
   else FNames.Delete(FNames.IndexOfObject(symbol));
end;

// NameToSymbol
//
function TdwsCodeGenSymbolMap.NameToSymbol(const name : String; scope : TdwsCodeGenSymbolScope) : TSymbol;
var
   i : Integer;
   iter : TdwsCodeGenSymbolMap;
   skip : Boolean;
   rootMap : TdwsCodeGenSymbolMap;
begin
   i:=FNames.IndexOf(name);
   if i>=0 then
      Result:=TSymbol(FNames.Objects[i])
   else begin
      Result:=nil;
      case scope of
         cgssGlobal : if Parent<>nil then
            Result:=Parent.NameToSymbol(name, scope);
         cgssClass : begin
            if (Parent<>nil) and (Parent.Symbol is TClassSymbol) then
               Result:=Parent.NameToSymbol(name, scope)
            else if Parent<>nil then begin
               // check for root reserved names
               rootMap:=Parent;
               while rootMap.Parent<>nil do
                  rootMap:=rootMap.Parent;
               Result:=rootMap.NameToSymbol(name, cgssLocal);
            end;
         end;
      end;
      if (Result=nil) and (scope=cgssGlobal) then begin
         for i:=0 to Maps.Count-1 do begin
            iter:=Maps[i];
            repeat
               skip:=(iter=Self);
               iter:=iter.Parent;
            until (iter=nil) or skip;
            if not skip then begin
               Result:=Maps[i].NameToSymbol(name, cgssLocal);
               if Result<>nil then Break;
            end;
         end;
      end;
   end;
end;

// ReserveName
//
procedure TdwsCodeGenSymbolMap.ReserveName(const name : String);
begin
   FNames.AddObject(name, FReservedSymbol);
end;

// ReserveExternalName
//
procedure TdwsCodeGenSymbolMap.ReserveExternalName(sym : TSymbol);
var
   i : Integer;
   n : String;
begin
   if sym is TFuncSymbol then
      n:=TFuncSymbol(sym).ExternalName
   else n:=sym.Name;
   i:=FNames.IndexOf(n);
   if i<0 then
      FNames.AddObject(n, sym)
   else begin
      if (FNames.Objects[i]<>FReservedSymbol) and (FNames.Objects[i]<>sym) then
         raise ECodeGenException.CreateFmt('External symbol "%s" already defined', [sym.Name]);
      FNames.Objects[i]:=sym;
   end;
end;

// MapSymbol
//
function TdwsCodeGenSymbolMap.MapSymbol(symbol : TSymbol; scope : TdwsCodeGenSymbolScope; canObfuscate : Boolean) : String;

   function NewName : String;
   var
      i : Integer;
   begin
      i:=0;
      Result:=DoNeedUniqueName(symbol, i, canObfuscate);
      while NameToSymbol(Result, scope)<>nil do begin
         Inc(i);
         Result:=DoNeedUniqueName(symbol, i, canObfuscate);
      end;
      FNames.AddObject(Result, symbol);
      FLookup.Name:=Result;
      FLookup.Symbol:=symbol;
      FHash.Add(FLookup);
   end;

begin
   Result:=SymbolToName(symbol);
   if Result='' then
      Result:=NewName;
end;

// DoNeedUniqueName
//
function TdwsCodeGenSymbolMap.DoNeedUniqueName(symbol : TSymbol; tryCount : Integer; canObfuscate : Boolean) : String;
begin
   if symbol.Name='' then begin
      if tryCount=0 then
         Result:='a$'
      else Result:=Format('a$%d', [tryCount]);
   end else begin;
      if tryCount=0 then
         if Prefix='' then
            Result:=symbol.Name
         else Result:=Prefix+symbol.Name
      else Result:=Format('%s%s$%d', [Prefix, symbol.Name, tryCount]);
   end;
end;

// ------------------
// ------------------ TdwsCodeGenSymbolMaps ------------------
// ------------------

// MapOf
//
function TdwsCodeGenSymbolMaps.MapOf(symbol : TSymbol) : TdwsCodeGenSymbolMap;
var
   i : Integer;
begin
   for i:=0 to Count-1 do begin
      Result:=Items[i];
      if Result.Symbol=symbol then Exit;
   end;
   Result:=nil;
end;

end.
