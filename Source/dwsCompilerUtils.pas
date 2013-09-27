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
{    Copyright Creative IT.                                            }
{    Current maintainer: Eric Grange                                   }
{                                                                      }
{**********************************************************************}
unit dwsCompilerUtils;

{$I dws.inc}

interface

uses
   SysUtils,
   dwsErrors, dwsStrings, dwsXPlatform,
   dwsSymbols, dwsUnitSymbols,
   dwsExprs, dwsCoreExprs, dwsConstExprs, dwsMethodExprs, dwsMagicExprs;

type

   TdwsCompilerUtils = class
      public
         class procedure AddProcHelper(const name : UnicodeString;
                                       table : TSymbolTable; func : TFuncSymbol;
                                       unitSymbol : TUnitMainSymbol); static;
   end;

function CreateFuncExpr(prog : TdwsProgram; funcSym: TFuncSymbol;
                        const scriptObj : IScriptObj; structSym : TCompositeTypeSymbol;
                        forceStatic : Boolean = False) : TFuncExprBase;
function CreateMethodExpr(prog: TdwsProgram; meth: TMethodSymbol; var expr : TTypedExpr; RefKind: TRefKind;
                          const scriptPos: TScriptPos; ForceStatic : Boolean = False) : TFuncExprBase;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

type
   TCheckAbstractClassConstruction = class (TErrorMessage)
      FClassSym : TClassSymbol;
      constructor Create(msgs: TdwsMessageList; const text : UnicodeString; const p : TScriptPos;
                         classSym : TClassSymbol); overload;
      function IsValid : Boolean; override;
   end;

// Create
//
constructor TCheckAbstractClassConstruction.Create(msgs: TdwsMessageList; const text : UnicodeString; const p : TScriptPos;
                                                   classSym : TClassSymbol);
begin
   FClassSym:=classSym;
   inherited Create(msgs, UnicodeFormat(MSG_Error, [text]), p);
end;

// IsValid
//
function TCheckAbstractClassConstruction.IsValid : Boolean;
begin
   Result:=FClassSym.IsAbstract and (MessageList.State=mlsCompleted);
end;

// CreateFuncExpr
//
function CreateFuncExpr(prog : TdwsProgram; funcSym: TFuncSymbol;
                        const scriptObj : IScriptObj; structSym : TCompositeTypeSymbol;
                        forceStatic : Boolean = False) : TFuncExprBase;
var
   instanceExpr : TTypedExpr;
begin
   if FuncSym is TMethodSymbol then begin
      if Assigned(scriptObj) then begin
         instanceExpr:=TConstExpr.Create(Prog, structSym, scriptObj);
         Result:=CreateMethodExpr(prog, TMethodSymbol(funcSym),
                                  instanceExpr, rkObjRef, cNullPos, ForceStatic)
      end else if structSym<>nil then begin
         instanceExpr:=TConstExpr.Create(prog, (structSym as TClassSymbol).MetaSymbol, Int64(structSym));
         Result:=CreateMethodExpr(prog, TMethodSymbol(funcSym),
                                  instanceExpr, rkClassOfRef, cNullPos, ForceStatic)
      end else begin
         // static method
         structSym:=TMethodSymbol(funcSym).StructSymbol;
         if structSym is TStructuredTypeSymbol then begin
            instanceExpr:=TConstExpr.Create(prog, TStructuredTypeSymbol(structSym).MetaSymbol, Int64(structSym));
            Result:=CreateMethodExpr(prog, TMethodSymbol(funcSym),
                                     instanceExpr, rkClassOfRef, cNullPos, ForceStatic)
         end else begin
            Result:=nil;
            Assert(False, 'TODO');
         end;
      end;
   end else if funcSym is TMagicFuncSymbol then begin
      Result:=TMagicFuncExpr.CreateMagicFuncExpr(prog, cNullPos, TMagicFuncSymbol(funcSym));
   end else begin
      Result:=TFuncSimpleExpr.Create(prog, cNullPos, funcSym);
   end;
end;

// CreateMethodExpr
//
function CreateMethodExpr(prog: TdwsProgram; meth: TMethodSymbol; var expr: TTypedExpr; RefKind: TRefKind;
                          const scriptPos: TScriptPos; ForceStatic : Boolean = False) : TFuncExprBase;
var
   helper : THelperSymbol;
   internalFunc : TInternalMagicFunction;
   classSymbol : TClassSymbol;
begin
   // Create the correct TExpr for a method symbol
   Result := nil;

   if meth is TMagicMethodSymbol then begin

      if meth is TMagicStaticMethodSymbol then begin
         FreeAndNil(expr);
         internalFunc:=TMagicStaticMethodSymbol(meth).InternalFunction;
         Result:=internalFunc.MagicFuncExprClass.Create(prog, scriptPos, meth, internalFunc);
      end else Assert(False, 'not supported yet');

   end else if meth.StructSymbol is TInterfaceSymbol then begin

      if meth.Name<>'' then
         Result:=TMethodInterfaceExpr.Create(prog, scriptPos, meth, expr)
      else begin
         Result:=TMethodInterfaceAnonymousExpr.Create(prog, scriptPos, meth, expr);
      end;

   end else if meth.StructSymbol is TClassSymbol then begin

      if meth.IsStatic then begin

         Result:=TFuncSimpleExpr.Create(prog, scriptPos, meth);
         expr.Free;
         Exit;

      end else if (expr.Typ is TClassOfSymbol) then begin

         if expr.IsConstant then begin
            classSymbol:=TClassOfSymbol(expr.Typ).TypClassSymbol;
            if classSymbol.IsAbstract then begin
               if meth.Kind=fkConstructor then
                  TCheckAbstractClassConstruction.Create(prog.CompileMsgs, RTE_InstanceOfAbstractClass, scriptPos, classSymbol)
               else TCheckAbstractClassConstruction.Create(prog.CompileMsgs, CPE_AbstractClassUsage, scriptPos, classSymbol);
            end;
         end;

      end;
      if (not meth.IsClassMethod) and meth.StructSymbol.IsStatic then
         prog.CompileMsgs.AddCompilerErrorFmt(scriptPos, CPE_ClassIsStaticNoInstantiation, [meth.StructSymbol.Name]);

      // Return the right expression
      case meth.Kind of
         fkFunction, fkProcedure, fkMethod, fkLambda:
            if meth.IsClassMethod then begin
               if not ForceStatic and meth.IsVirtual then
                  Result := TClassMethodVirtualExpr.Create(prog, scriptPos, meth, expr)
               else Result := TClassMethodStaticExpr.Create(prog, scriptPos, meth, expr)
            end else begin
               if RefKind<>rkObjRef then
                  prog.CompileMsgs.AddCompilerError(scriptPos, CPE_StaticMethodExpected)
               else if expr.Typ is TClassOfSymbol then
                  prog.CompileMsgs.AddCompilerError(scriptPos, CPE_ClassMethodExpected);
               if not ForceStatic and meth.IsVirtual then
                  Result := TMethodVirtualExpr.Create(prog, scriptPos, meth, expr)
               else Result := TMethodStaticExpr.Create(prog, scriptPos, meth, expr);
            end;
         fkConstructor:
            if RefKind = rkClassOfRef then begin
               if not ForceStatic and meth.IsVirtual then
                  Result := TConstructorVirtualExpr.Create(prog, scriptPos, meth, expr)
               else if meth = prog.Root.TypDefaultConstructor then
                  Result := TConstructorStaticDefaultExpr.Create(prog, scriptPos, meth, expr)
               else Result := TConstructorStaticExpr.Create(prog, scriptPos, meth, expr);
            end else begin
               if not ((prog is TdwsProcedure) and (TdwsProcedure(prog).Func.Kind=fkConstructor)) then
                  prog.CompileMsgs.AddCompilerWarning(scriptPos, CPE_UnexpectedConstructor);
               if not ForceStatic and meth.IsVirtual then
                  Result := TConstructorVirtualObjExpr.Create(prog, scriptPos, meth, expr)
               else Result := TConstructorStaticObjExpr.Create(prog, scriptPos, meth, expr);
            end;
         fkDestructor:
            begin
               if RefKind<>rkObjRef then
                  prog.CompileMsgs.AddCompilerError(scriptPos, CPE_UnexpectedDestructor);
               if not ForceStatic and meth.IsVirtual then
                  Result := TDestructorVirtualExpr.Create(prog, scriptPos, meth, expr)
               else Result := TDestructorStaticExpr.Create(prog, scriptPos, meth, expr)
            end;
      else
         Assert(False);
      end;

   end else if meth.StructSymbol is TRecordSymbol then begin

      if meth.IsClassMethod then begin

         Result:=TFuncSimpleExpr.Create(prog, scriptPos, meth);
         expr.Free;

      end else begin

         Result:=TRecordMethodExpr.Create(prog, scriptPos, meth);
         Result.AddArg(expr);

      end;

   end else if meth.StructSymbol is THelperSymbol then begin

      helper:=THelperSymbol(meth.StructSymbol);
      if     meth.IsClassMethod
         and (   (helper.ForType.ClassType=TInterfaceSymbol)
              or meth.IsStatic
              or not (   (helper.ForType is TStructuredTypeSymbol)
                      or (helper.ForType is TStructuredTypeMetaSymbol))) then begin

         Result:=TFuncSimpleExpr.Create(prog, scriptPos, meth);
         expr.Free;

      end else begin

         Result:=THelperMethodExpr.Create(prog, scriptPos, meth);
         if expr<>nil then
            Result.AddArg(expr);

      end;

   end else Assert(False);

   expr:=nil;
end;

// ------------------
// ------------------ TdwsCompilerUtils ------------------
// ------------------

// AddProcHelper
//
class procedure TdwsCompilerUtils.AddProcHelper(const name : UnicodeString;
                                                table : TSymbolTable; func : TFuncSymbol;
                                                unitSymbol : TUnitMainSymbol);
var
   helper : THelperSymbol;
   param : TParamSymbol;
   meth : TAliasMethodSymbol;
   i : Integer;
   sym : TSymbol;
begin
   param:=func.Params[0];

   // find a local anonymous helper for the 1st parameter's type
   helper:=nil;
   for sym in table do begin
      if     (sym.Name='')
         and (sym.ClassType=THelperSymbol)
         and (THelperSymbol(sym).ForType=param.Typ) then begin
         helper:=THelperSymbol(sym);
         Break;
      end;
   end;

   // create anonymous helper if necessary
   if helper=nil then begin
      helper:=THelperSymbol.Create('', unitSymbol, param.Typ, table.Count);
      table.AddSymbol(helper);
   end;

   // create helper method symbol
   meth:=TAliasMethodSymbol.Create(name, func.Kind, helper, cvPublic, False);
   meth.SetIsStatic;
   if func.IsOverloaded then
      meth.IsOverloaded:=True;
   meth.Typ:=func.Typ;
   for i:=0 to func.Params.Count-1 do
      meth.Params.AddSymbol(func.Params[i].Clone);
   meth.Alias:=func;
   helper.AddMethod(meth);
end;

end.
