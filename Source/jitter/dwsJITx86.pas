{**************************************************************************}
{                                                                          }
{    This Source Code Form is subject to the terms of the Mozilla Public   }
{    License, v. 2.0. If a copy of the MPL was not distributed with this   }
{     file, You can obtain one at http://mozilla.org/MPL/2.0/.             }
{                                                                          }
{    Software distributed under the License is distributed on an           }
{    "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express           }
{    or implied. See the License for the specific language                 }
{    governing rights and limitations under the License.                   }
{                                                                          }
{    Copyright Eric Grange / Creative IT                                   }
{                                                                          }
{**************************************************************************}
unit dwsJITx86;

{$I ../dws.inc}

interface

{
   TODO:
   - range checking
}


uses
   Classes, SysUtils, Math, Windows,
   dwsExprs, dwsSymbols, dwsErrors, dwsUtils,
   dwsCoreExprs, dwsRelExprs, dwsMagicExprs, dwsConstExprs,
   dwsMathFunctions, dwsDataContext, dwsConvExprs,
   dwsJIT, dwsJITFixups, dwsJITAllocatorWin, dwsJITx86Intrinsics, dwsVMTOffsets;

type

   TRegisterStatus = record
      Contains : TObject;
      Lock : Integer;
   end;

   TFixupJump = class(TFixupTargeting)
      private
         FFlags : TboolFlags;

      protected
         function NearJump : Boolean;

      public
         constructor Create(flags : TboolFlags);

         function  GetSize : Integer; override;
         procedure Write(output : TWriteOnlyBlockStream); override;
   end;

   TFixupPreamble = class(TFixup)
      private
         FPreserveExecInEDI : Boolean;
         FTempSpaceOnStack : Integer;
         FAllocatedStackSpace : Integer;

      public
         function  GetSize : Integer; override;
         procedure Write(output : TWriteOnlyBlockStream); override;

         procedure NeedTempSpace(bytes : Integer);
         function AllocateStackSpace(bytes : Integer) : Integer;

         property PreserveExecInEDI : Boolean read FPreserveExecInEDI write FPreserveExecInEDI;
         property TempSpaceOnStack : Integer read FTempSpaceOnStack write FTempSpaceOnStack;
         property AllocatedStackSpace : Integer read FAllocatedStackSpace write FAllocatedStackSpace;
   end;

   TFixupPostamble = class(TFixup)
      private
         FPreamble : TFixupPreamble;

      public
         constructor Create(preamble : TFixupPreamble);

         function  GetSize : Integer; override;
         procedure Write(output : TWriteOnlyBlockStream); override;
   end;

   Tx86FixupLogicHelper = class helper for TFixupLogic
      function NewJump(flags : TboolFlags) : TFixupJump; overload;
      function NewJump(flags : TboolFlags; target : TFixup) : TFixupJump; overload;
      function NewJump(target : TFixup) : TFixupJump; overload;
      procedure NewConditionalJumps(flagsTrue : TboolFlags; targetTrue, targetFalse : TFixup);
   end;

   TdwsJITx86 = class (TdwsJIT)
      private
         FRegs : array [TxmmRegister] of TRegisterStatus;
         FXMMIter : TxmmRegister;
         FSavedXMM : TxmmRegisters;

         FPreamble : TFixupPreamble;
         FPostamble : TFixupPostamble;
         x86 : Tx86WriteOnlyStream;

         FAllocator : TdwsJITAllocatorWin;

         FAbsMaskPD : TdwsJITCodeBlock;
         FSignMaskPD : TdwsJITCodeBlock;
         FBufferBlock : TdwsJITCodeBlock;

      protected
         function CreateOutput : TWriteOnlyBlockStream; override;

         procedure StartJIT(expr : TExprBase; exitable : Boolean); override;
         procedure EndJIT; override;
         procedure EndFloatJIT(resultHandle : Integer); override;
         procedure EndIntegerJIT(resultHandle : Integer); override;

      public
         constructor Create; override;
         destructor Destroy; override;

         function  AllocXMMReg(expr : TExprBase; contains : TObject = nil) : TxmmRegister;
         procedure ReleaseXMMReg(reg : TxmmRegister);
         function  CurrentXMMReg(contains : TObject) : TxmmRegister;
         procedure ContainsXMMReg(reg : TxmmRegister; contains : TObject);
         procedure ResetXMMReg;
         procedure SaveXMMRegs;
         procedure RestoreXMMRegs;

         function StackAddrOfFloat(expr : TTypedExpr) : Integer;

         property Allocator : TdwsJITAllocatorWin read FAllocator write FAllocator;
         property AbsMaskPD : Pointer read FAbsMaskPD.Code;
         property SignMaskPD : Pointer read FSignMaskPD.Code;

         function CompileFloat(expr : TTypedExpr) : TxmmRegister; inline;
         procedure CompileAssignFloat(expr : TTypedExpr; source : TxmmRegister); inline;

         procedure CompileBoolean(expr : TTypedExpr; targetTrue, targetFalse : TFixup);

         function CompiledOutput : TdwsJITCodeBlock; override;

         procedure _xmm_reg_expr(op : TxmmOp; dest : TxmmRegister; expr : TTypedExpr);
         procedure _comisd_reg_expr(dest : TxmmRegister; expr : TTypedExpr);

         procedure _DoStep(expr : TExprBase);
         procedure _RangeCheck(expr : TExprBase; reg : TgpRegister;
                               delta, miniInclusive, maxiExclusive : Integer);
   end;

   TProgramExpr86 = class (TJITTedProgramExpr)
      public
         procedure EvalNoResult(exec : TdwsExecution); override;
   end;

   TFloatExpr86 = class (TJITTedFloatExpr)
      public
         function  EvalAsFloat(exec : TdwsExecution) : Double; override;
   end;

   TIntegerExpr86 = class (TJITTedIntegerExpr)
      public
         function  EvalAsInteger(exec : TdwsExecution) : Int64; override;
   end;

   TdwsJITter_x86 = class (TdwsJITter)
      private
         FJIT : TdwsJITx86;
         Fx86 : Tx86WriteOnlyStream;

      protected
         property jit : TdwsJITx86 read FJIT;
         property x86 : Tx86WriteOnlyStream read Fx86;

      public
         constructor Create(jit : TdwsJITx86);

         function CompileFloat(expr : TExprBase) : Integer; override; final;
         function DoCompileFloat(expr : TExprBase) : TxmmRegister; virtual;

         procedure CompileAssignFloat(expr : TTypedExpr; source : Integer); override; final;
         procedure DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister); virtual;

         procedure CompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override; final;
         procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); virtual;
   end;

   Tx86ConstFloat = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;
   Tx86ConstInt = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;

   Tx86InterpretedExpr = class (TdwsJITter_x86)
      procedure DoCallEval(expr : TExprBase; vmt : Integer);

      procedure CompileStatement(expr : TExprBase); override;

      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      procedure DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister); override;

      function CompileInteger(expr : TExprBase) : Integer; override;
      procedure CompileAssignInteger(expr : TTypedExpr; source : Integer); override;

      procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override;
   end;

   Tx86FloatVar = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      procedure DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister); override;
   end;
   Tx86IntVar = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      function CompileInteger(expr : TExprBase) : Integer; override;
      procedure CompileAssignInteger(expr : TTypedExpr; source : Integer); override;
   end;
   Tx86ObjectVar = class (TdwsJITter_x86)
      function CompileScriptObj(expr : TExprBase) : Integer; override;
   end;
   Tx86RecordVar = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      procedure DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister); override;
   end;
   Tx86VarParam = class (TdwsJITter_x86)
      class procedure CompileAsPVariant(x86 : Tx86WriteOnlyStream; expr : TByRefParamExpr);
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      procedure DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister); override;
   end;

   Tx86ArrayBase = class (Tx86InterpretedExpr)
      procedure CompileIndexToGPR(indexExpr : TTypedExpr; gpr : TgpRegister; var delta : Integer);
   end;
   Tx86StaticArray = class (Tx86ArrayBase)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      function CompileInteger(expr : TExprBase) : Integer; override;
      procedure DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister); override;
   end;
   Tx86DynamicArrayBase = class (Tx86ArrayBase)
      procedure CompileAsData(expr : TTypedExpr);
   end;
   Tx86DynamicArray = class (Tx86DynamicArrayBase)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      function CompileInteger(expr : TExprBase) : Integer; override;
      function CompileScriptObj(expr : TExprBase) : Integer; override;
   end;
   Tx86DynamicArraySet = class (Tx86DynamicArrayBase)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86AssignConstToFloatVar = class (Tx86InterpretedExpr)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86AssignConstToIntegerVar = class (Tx86InterpretedExpr)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86AssignConstToBoolVar = class (Tx86InterpretedExpr)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86Assign = class (Tx86InterpretedExpr)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86OpAssignFloat = class (TdwsJITter_x86)
      public
         OP : TxmmOp;
         constructor Create(jit : TdwsJITx86; op : TxmmOp);
         procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86BlockExprNoTable = class (TdwsJITter_x86)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86IfThen = class (TdwsJITter_x86)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86IfThenElse = class (TdwsJITter_x86)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86Loop = class (TdwsJITter_x86)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86Repeat = class (Tx86Loop)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86While = class (Tx86Loop)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86ForUpward = class (TdwsJITter_x86)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86Continue = class (TdwsJITter_x86)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86Exit = class (TdwsJITter_x86)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86ExitValue = class (Tx86Exit)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86FloatBinOp = class (TdwsJITter_x86)
      public
         OP : TxmmOp;
         constructor Create(jit : TdwsJITx86; op : TxmmOp);
         function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;
   Tx86SqrFloat = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;
   Tx86AbsFloat = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;
   Tx86NegFloat = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;

   Tx86NegInt = class (TdwsJITter_x86)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;
   Tx86AddInt = class (TdwsJITter_x86)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;
   Tx86SubInt = class (TdwsJITter_x86)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;
   Tx86MultInt = class (TdwsJITter_x86)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;
   Tx86MultIntPow2 = class (TdwsJITter_x86)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;
   Tx86DivInt = class (Tx86InterpretedExpr)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;

   Tx86Shr = class (TdwsJITter_x86)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;
   Tx86Shl = class (TdwsJITter_x86)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;

   Tx86Inc = class (Tx86InterpretedExpr)
      procedure DoCompileStatement(v : TIntVarExpr; i : TTypedExpr);
   end;
   Tx86IncIntVar = class (Tx86Inc)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86IncVarFunc = class (Tx86Inc)
      procedure CompileStatement(expr : TExprBase); override;
   end;
   Tx86DecIntVar = class (TdwsJITter_x86)
      procedure CompileStatement(expr : TExprBase); override;
   end;

   Tx86RelOpInt = class (TdwsJITter_x86)
      public
         FlagsHiPass, FlagsHiFail, FlagsLo : TboolFlags;
         constructor Create(jit : TdwsJITx86; flagsHiPass, flagsHiFail, flagsLo : TboolFlags);
         procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override;
   end;
   Tx86RelIntIsZero = class (TdwsJITter_x86)
      procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override;
   end;
   Tx86RelIntIsNotZero = class (Tx86RelIntIsZero)
      procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override;
   end;

   Tx86RelOpFloat = class (TdwsJITter_x86)
      public
         Flags : TboolFlags;
         constructor Create(jit : TdwsJITx86; flags : TboolFlags);
         procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override;
   end;

   Tx86NotExpr = class (TdwsJITter_x86)
      procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override; final;
   end;
   Tx86BoolOrExpr = class (TdwsJITter_x86)
      procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override;
   end;
   Tx86BoolAndExpr = class (TdwsJITter_x86)
      procedure DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup); override;
   end;

   Tx86ConvFloat = class (TdwsJITter_x86)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;

   Tx86MagicFunc = class (Tx86InterpretedExpr)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;

   Tx86DirectCallFunc = class (Tx86MagicFunc)
      public
         AddrPtr : PPointer;
         constructor Create(jit : TdwsJITx86; addrPtr : PPointer);
         function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;

   Tx86SqrtFunc = class (Tx86MagicFunc)
      function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;

   Tx86MinMaxFloatFunc = class (Tx86MagicFunc)
      public
         OP : TxmmOp;
         constructor Create(jit : TdwsJITx86; op : TxmmOp);
         function DoCompileFloat(expr : TExprBase) : TxmmRegister; override;
   end;

   Tx86RoundFunc = class (Tx86MagicFunc)
      function CompileInteger(expr : TExprBase) : Integer; override;
   end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

var
   vAddrPower : function (const base, exponent: Double) : Double = Math.Power;

// ------------------
// ------------------ TdwsJITx86 ------------------
// ------------------

// Create
//
constructor TdwsJITx86.Create;
begin
   inherited;

   FAllocator:=TdwsJITAllocatorWin.Create;

   FAbsMaskPD:=FAllocator.Allocate(TBytes.Create($FF, $FF, $FF, $FF, $FF, $FF, $FF, $7F,
                                                 $FF, $FF, $FF, $FF, $FF, $FF, $FF, $7F));
   FSignMaskPD:=FAllocator.Allocate(TBytes.Create($00, $00, $00, $00, $00, $00, $00, $80,
                                                  $00, $00, $00, $00, $00, $00, $00, $80));
   FBufferBlock:=FAllocator.Allocate(TBytes.Create($66, $66, $66, $90, $66, $66, $66, $90,
                                                   $66, $66, $66, $90, $66, $66, $66, $90));

   JITTedProgramExprClass:=TProgramExpr86;
   JITTedFloatExprClass:=TFloatExpr86;
   JITTedIntegerExprClass:=TIntegerExpr86;

   RegisterJITter(TConstFloatExpr,              Tx86ConstFloat.Create(Self));
   RegisterJITter(TConstIntExpr,                Tx86ConstInt.Create(Self));

   RegisterJITter(TFloatVarExpr,                Tx86FloatVar.Create(Self));
   RegisterJITter(TIntVarExpr,                  Tx86IntVar.Create(Self));
   RegisterJITter(TObjectVarExpr,               Tx86ObjectVar.Create(Self));
   RegisterJITter(TVarParentExpr,               Tx86InterpretedExpr.Create(Self));

   RegisterJITter(TFieldExpr,                   Tx86InterpretedExpr.Create(Self));
   RegisterJITter(TRecordExpr,                  Tx86InterpretedExpr.Create(Self));
   RegisterJITter(TRecordVarExpr,               Tx86RecordVar.Create(Self));
   RegisterJITter(TFieldExpr,                   Tx86InterpretedExpr.Create(Self));
   RegisterJITter(TFieldVarExpr,                Tx86InterpretedExpr.Create(Self));

   RegisterJITter(TVarParamExpr,                Tx86VarParam.Create(Self));

   RegisterJITter(TStaticArrayExpr,             Tx86StaticArray.Create(Self));
   RegisterJITter(TDynamicArrayExpr,            Tx86DynamicArray.Create(Self));
   RegisterJITter(TDynamicArrayVarExpr,         Tx86DynamicArray.Create(Self));
   RegisterJITter(TDynamicArraySetExpr,         Tx86DynamicArraySet.Create(Self));
   RegisterJITter(TDynamicArraySetVarExpr,      Tx86DynamicArraySet.Create(Self));

   RegisterJITter(TArrayLengthExpr,             Tx86InterpretedExpr.Create(Self));
   RegisterJITter(TArraySetLengthExpr,          Tx86InterpretedExpr.Create(Self));

   RegisterJITter(TBlockExprNoTable,            Tx86BlockExprNoTable.Create(Self));
   RegisterJITter(TBlockExprNoTable2,           Tx86BlockExprNoTable.Create(Self));
   RegisterJITter(TBlockExprNoTable3,           Tx86BlockExprNoTable.Create(Self));
   RegisterJITter(TBlockExprNoTable4,           Tx86BlockExprNoTable.Create(Self));

//   RegisterJITter(TExceptExpr,                  Tx86InterpretedExpr.Create(Self));

   RegisterJITter(TAssignConstToIntegerVarExpr, Tx86AssignConstToIntegerVar.Create(Self));
   RegisterJITter(TAssignConstToFloatVarExpr,   Tx86AssignConstToFloatVar.Create(Self));
   RegisterJITter(TAssignConstToBoolVarExpr,    Tx86AssignConstToBoolVar.Create(Self));
   RegisterJITter(TAssignExpr,                  Tx86Assign.Create(Self));

   RegisterJITter(TPlusAssignFloatExpr,         Tx86OpAssignFloat.Create(Self, xmm_addsd));
   RegisterJITter(TMinusAssignFloatExpr,        Tx86OpAssignFloat.Create(Self, xmm_subsd));
   RegisterJITter(TMultAssignFloatExpr,         Tx86OpAssignFloat.Create(Self, xmm_multsd));
   RegisterJITter(TDivideAssignExpr,            Tx86OpAssignFloat.Create(Self, xmm_divsd));

   RegisterJITter(TMultAssignIntExpr,           Tx86InterpretedExpr.Create(Self));

   RegisterJITter(TIfThenExpr,                  Tx86IfThen.Create(Self));
   RegisterJITter(TIfThenElseExpr,              Tx86IfThenElse.Create(Self));

   RegisterJITter(TLoopExpr,                    Tx86Loop.Create(Self));
   RegisterJITter(TRepeatExpr,                  Tx86Repeat.Create(Self));
   RegisterJITter(TWhileExpr,                   Tx86While.Create(Self));

   RegisterJITter(TForUpwardExpr,               Tx86ForUpward.Create(Self));

   RegisterJITter(TContinueExpr,                Tx86Continue.Create(Self));
   RegisterJITter(TExitExpr,                    Tx86Exit.Create(Self));
   RegisterJITter(TExitValueExpr,               Tx86ExitValue.Create(Self));

   RegisterJITter(TAddFloatExpr,                Tx86FloatBinOp.Create(Self, xmm_addsd));
   RegisterJITter(TSubFloatExpr,                Tx86FloatBinOp.Create(Self, xmm_subsd));
   RegisterJITter(TMultFloatExpr,               Tx86FloatBinOp.Create(Self, xmm_multsd));
   RegisterJITter(TSqrFloatExpr,                Tx86SqrFloat.Create(Self));
   RegisterJITter(TDivideExpr,                  Tx86FloatBinOp.Create(Self, xmm_divsd));
   RegisterJITter(TAbsFloatExpr,                Tx86AbsFloat.Create(Self));
   RegisterJITter(TNegFloatExpr,                Tx86NegFloat.Create(Self));

   RegisterJITter(TNegIntExpr,                  Tx86NegInt.Create(Self));
   RegisterJITter(TAddIntExpr,                  Tx86AddInt.Create(Self));
   RegisterJITter(TSubIntExpr,                  Tx86SubInt.Create(Self));
   RegisterJITter(TMultIntExpr,                 Tx86MultInt.Create(Self));
   RegisterJITter(TDivExpr,                     Tx86DivInt.Create(Self));
   RegisterJITter(TModExpr,                     Tx86InterpretedExpr.Create(Self));
   RegisterJITter(TMultIntPow2Expr,             Tx86MultIntPow2.Create(Self));
   RegisterJITter(TIntAndExpr,                  Tx86InterpretedExpr.Create(Self));

   RegisterJITter(TShrExpr,                     Tx86Shr.Create(Self));
   RegisterJITter(TShlExpr,                     Tx86Shl.Create(Self));

   RegisterJITter(TIncIntVarExpr,               Tx86IncIntVar.Create(Self));
   RegisterJITter(TDecIntVarExpr,               Tx86DecIntVar.Create(Self));

   RegisterJITter(TIncVarFuncExpr,              Tx86IncVarFunc.Create(Self));

   RegisterJITter(TRelEqualIntExpr,             Tx86RelOpInt.Create(Self, flagsNone, flagsNZ, flagsZ));
   RegisterJITter(TRelNotEqualIntExpr,          Tx86RelOpInt.Create(Self, flagsNZ, flagsNone, flagsNZ));
   RegisterJITter(TRelGreaterIntExpr,           Tx86RelOpInt.Create(Self, flagsG, flagsL, flagsG));
   RegisterJITter(TRelGreaterEqualStringExpr,   Tx86RelOpInt.Create(Self, flagsG, flagsL, flagsGE));
   RegisterJITter(TRelLessIntExpr,              Tx86RelOpInt.Create(Self, flagsL, flagsG, flagsL));
   RegisterJITter(TRelLessEqualIntExpr,         Tx86RelOpInt.Create(Self, flagsL, flagsG, flagsLE));

   RegisterJITter(TRelIntIsZeroExpr,            Tx86RelIntIsZero.Create(Self));
   RegisterJITter(TRelIntIsNotZeroExpr,         Tx86RelIntIsNotZero.Create(Self));

   RegisterJITter(TRelEqualFloatExpr,           Tx86RelOpFloat.Create(Self, flagsE));
   RegisterJITter(TRelNotEqualFloatExpr,        Tx86RelOpFloat.Create(Self, flagsNE));
   RegisterJITter(TRelGreaterFloatExpr,         Tx86RelOpFloat.Create(Self, flagsNBE));
   RegisterJITter(TRelGreaterEqualFloatExpr,    Tx86RelOpFloat.Create(Self, flagsNB));
   RegisterJITter(TRelLessFloatExpr,            Tx86RelOpFloat.Create(Self, flagsB));
   RegisterJITter(TRelLessEqualFloatExpr,       Tx86RelOpFloat.Create(Self, flagsBE));

   RegisterJITter(TNotBoolExpr,                 Tx86NotExpr.Create(Self));
   RegisterJITter(TBoolOrExpr,                  Tx86BoolOrExpr.Create(Self));
   RegisterJITter(TBoolAndExpr,                 Tx86BoolAndExpr.Create(Self));

   RegisterJITter(TConvFloatExpr,               Tx86ConvFloat.Create(Self));

   RegisterJITter(TFuncExpr,                    Tx86InterpretedExpr.Create(Self));
   RegisterJITter(TMagicProcedureExpr,          Tx86InterpretedExpr.Create(Self));
   RegisterJITter(TMagicFloatFuncExpr,          Tx86MagicFunc.Create(Self));
   RegisterJITter(TMagicIntFuncExpr,            Tx86MagicFunc.Create(Self));

   RegisterJITter(TSqrtFunc,                    Tx86SqrtFunc.Create(Self));
   RegisterJITter(TMaxFunc,                     Tx86MinMaxFloatFunc.Create(Self, xmm_maxsd));
   RegisterJITter(TMinFunc,                     Tx86MinMaxFloatFunc.Create(Self, xmm_minsd));
   RegisterJITter(TPowerFunc,                   Tx86DirectCallFunc.Create(Self, @@vAddrPower));
   RegisterJITter(TRoundFunc,                   Tx86RoundFunc.Create(Self));
end;

// Destroy
//
destructor TdwsJITx86.Destroy;
begin
   inherited;
   FAllocator.Free;
   FSignMaskPD.Free;
   FAbsMaskPD.Free;
   FBufferBlock.Free;
end;

// CreateOutput
//
function TdwsJITx86.CreateOutput : TWriteOnlyBlockStream;
begin
   x86:=Tx86WriteOnlyStream.Create;
   Result:=x86;
end;

// AllocXMMReg
//
function TdwsJITx86.AllocXMMReg(expr : TExprBase; contains : TObject = nil) : TxmmRegister;
var
   i, avail : TxmmRegister;
begin
   avail:=xmmNone;
   if contains=nil then
      contains:=expr;

   for i:=xmm0 to High(TxmmRegister) do begin
      if FXMMIter=High(TxmmRegister) then
         FXMMIter:=xmm0
      else Inc(FXMMIter);
      if FRegs[FXMMIter].Contains=nil then begin
         FRegs[FXMMIter].Contains:=contains;
         FRegs[FXMMIter].Lock:=1;
         Exit(FXMMIter);
      end else if (avail=xmmNone) and (FRegs[FXMMIter].Lock=0) then
         avail:=FXMMIter;
   end;
   if avail=xmmNone then begin
      OutputFailedOn:=expr;
      Result:=xmm0;
   end else begin
      FRegs[avail].Contains:=contains;
      FRegs[avail].Lock:=1;
      FXMMIter:=avail;
      Result:=avail;
   end;
end;

// ReleaseXMMReg
//
procedure TdwsJITx86.ReleaseXMMReg(reg : TxmmRegister);
begin
   Assert(reg in [xmm0..xmm7]);

   if FRegs[reg].Lock>0 then
      Dec(FRegs[reg].Lock);
end;

// CurrentXMMReg
//
function TdwsJITx86.CurrentXMMReg(contains : TObject) : TxmmRegister;
var
   i : TxmmRegister;
begin
   for i:=xmm0 to High(TxmmRegister) do begin
      if FRegs[i].Contains=contains then begin
         Inc(FRegs[i].Lock);
         Exit(i);
      end;
   end;
   Result:=xmmNone;
end;

// ContainsXMMReg
//
procedure TdwsJITx86.ContainsXMMReg(reg : TxmmRegister; contains : TObject);
var
   i : TxmmRegister;
begin
   for i:=xmm0 to High(FRegs) do begin
      if FRegs[i].Contains=contains then begin
         if i<>reg then begin
            FRegs[i].Contains:=nil;
            FRegs[i].Lock:=0;
         end;
      end;
   end;
   FRegs[reg].Contains:=contains;
end;

// ResetXMMReg
//
procedure TdwsJITx86.ResetXMMReg;
var
   i : TxmmRegister;
begin
   FXMMIter:=High(TxmmRegister);
   for i:=xmm0 to High(FRegs) do begin
      FRegs[i].Contains:=nil;
      FRegs[i].Lock:=0;
   end;
end;

// SaveXMMRegs
//
procedure TdwsJITx86.SaveXMMRegs;
var
   i : TxmmRegister;
   n : Integer;
begin
   Assert(FSavedXMM=[]);

   n:=0;
   for i:=xmm0 to High(FRegs) do begin
      if FRegs[i].Lock>0 then begin
         Include(FSavedXMM, i);
         Inc(n);
      end;
   end;

   if n=0 then Exit;

   FPreamble.NeedTempSpace(n*SizeOf(Double));
   for i:=xmm0 to High(FRegs) do begin
      if i in FSavedXMM then begin
         Dec(n);
         x86._movsd_esp_reg(n*SizeOf(Double), i);
      end;
   end;
end;

// RestoreXMMRegs
//
procedure TdwsJITx86.RestoreXMMRegs;
var
   i : TxmmRegister;
   n : Integer;
begin
   if FSavedXMM=[] then Exit;

   n:=0;
   for i:=High(FRegs) downto xmm0 do begin
      if i in FSavedXMM then begin
         x86._movsd_reg_esp(i, n*SizeOf(Double));
         Inc(n);
      end else FRegs[i].Contains:=nil;
   end;

   FSavedXMM:=[];
end;

// StackAddrOfFloat
//
function TdwsJITx86.StackAddrOfFloat(expr : TTypedExpr) : Integer;
begin
   if (expr.ClassType=TFloatVarExpr) and (CurrentXMMReg(TFloatVarExpr(expr).DataSym)=xmmNone) then
      Result:=TFloatVarExpr(expr).StackAddr
   else Result:=-1;
end;

// CompileFloat
//
function TdwsJITx86.CompileFloat(expr : TTypedExpr) : TxmmRegister;
begin
   Result:=TxmmRegister(inherited CompileFloat(expr));
end;

// CompileAssignFloat
//
procedure TdwsJITx86.CompileAssignFloat(expr : TTypedExpr; source : TxmmRegister);
begin
   inherited CompileAssignFloat(expr, Ord(source));
end;

// CompileBoolean
//
procedure TdwsJITx86.CompileBoolean(expr : TTypedExpr; targetTrue, targetFalse : TFixup);
begin
   inherited CompileBoolean(expr, targetTrue, targetFalse);
end;

// CompiledOutput
//
function TdwsJITx86.CompiledOutput : TdwsJITCodeBlock;
begin
   Fixups.FlushFixups(Output.ToBytes, Output);

   Result:=Allocator.Allocate(Output.ToBytes);
   Result.Steppable:=(jitoDoStep in Options);
end;

// StartJIT
//
procedure TdwsJITx86.StartJIT(expr : TExprBase; exitable : Boolean);
begin
   inherited;
   ResetXMMReg;
   Fixups.ClearFixups;
   FPreamble:=TFixupPreamble.Create;
   Fixups.AddFixup(FPreamble);
   FPostamble:=TFixupPostamble.Create(FPreamble);
   FPostamble.Logic:=Fixups;
end;

// EndJIT
//
procedure TdwsJITx86.EndJIT;
begin
   inherited;
   Fixups.AddFixup(FPostamble);
end;

// EndFloatJIT
//
procedure TdwsJITx86.EndFloatJIT(resultHandle : Integer);
begin
   FPreamble.NeedTempSpace(SizeOf(Double));

   x86._movsd_esp_reg(TxmmRegister(resultHandle));
   x86._fld_esp;

   inherited;
end;

// EndIntegerJIT
//
procedure TdwsJITx86.EndIntegerJIT(resultHandle : Integer);
begin
   inherited;
end;

// _xmm_reg_expr
//
procedure TdwsJITx86._xmm_reg_expr(op : TxmmOp; dest : TxmmRegister; expr : TTypedExpr);
var
   addrRight : Integer;
   regRight : TxmmRegister;
begin
   if expr.ClassType=TConstFloatExpr then begin

      x86._xmm_reg_absmem(OP, dest, @TConstFloatExpr(expr).Value);

   end else begin

      addrRight:=StackAddrOfFloat(expr);
      if addrRight>=0 then begin

         x86._xmm_reg_execmem(OP, dest, addrRight);

      end else begin

         regRight:=CompileFloat(expr);
         x86._xmm_reg_reg(OP, dest, regRight);
         ReleaseXMMReg(regRight);

      end;

   end;
end;

// _comisd_reg_expr
//
procedure TdwsJITx86._comisd_reg_expr(dest : TxmmRegister; expr : TTypedExpr);
var
   addrRight : Integer;
   regRight : TxmmRegister;
begin
   if expr.ClassType=TConstFloatExpr then begin

      x86._comisd_reg_absmem(dest, @TConstFloatExpr(expr).Value);

   end else begin

      addrRight:=StackAddrOfFloat(expr);
      if addrRight>=0 then begin

         x86._comisd_reg_execmem(dest, addrRight);

      end else begin

         regRight:=CompileFloat(expr);
         x86._comisd_reg_reg(dest, regRight);
         ReleaseXMMReg(regRight);

      end;

   end;
end;

// _DoStep
//
var
   cPtr_TdwsExecution_DoStep : Pointer = @TdwsExecution.DoStep;
procedure TdwsJITx86._DoStep(expr : TExprBase);
begin
   if not (jitoDoStep in Options) then Exit;

   FPreamble.PreserveExecInEDI:=True;

   x86._mov_reg_reg(gprEAX, gprEDI);
   x86._mov_reg_dword(gprEDX, DWORD(expr));

   x86._call_absmem(@cPtr_TdwsExecution_DoStep);

   ResetXMMReg;
end;

// _RangeCheck
//
var
   cPtr_TProgramExpr_RaiseUpperExceeded : Pointer = @TProgramExpr.RaiseUpperExceeded;
   cPtr_TProgramExpr_RaiseLowerExceeded : Pointer = @TProgramExpr.RaiseLowerExceeded;
procedure TdwsJITx86._RangeCheck(expr : TExprBase; reg : TgpRegister; delta, miniInclusive, maxiExclusive : Integer);
var
   passed, passedMini : TFixupTarget;
begin
   if not (jitoRangeCheck in Options) then Exit;

   FPreamble.PreserveExecInEDI:=True;

   passed:=Fixups.NewHangingTarget;

   delta:=delta-miniInclusive;
   maxiExclusive:=maxiExclusive-miniInclusive;
   if delta<>0 then
      x86._add_reg_int32(reg, delta);
   x86._cmp_reg_int32(reg, maxiExclusive);

   Fixups.NewJump(flagsB, passed);

   if delta<>0 then
      x86._add_reg_int32(reg, -delta);
   x86._cmp_reg_int32(reg, miniInclusive);

   passedMini:=Fixups.NewHangingTarget;

   Fixups.NewJump(flagsGE, passedMini);

   x86._mov_reg_reg(gprECX, reg);
   x86._mov_reg_reg(gprEDX, gprEDI);
   x86._mov_reg_dword(gprEAX, DWORD(expr));
   x86._call_absmem(@cPtr_TProgramExpr_RaiseLowerExceeded);

   Fixups.AddFixup(passedMini);

   x86._mov_reg_reg(gprECX, reg);
   x86._mov_reg_reg(gprEDX, gprEDI);
   x86._mov_reg_dword(gprEAX, DWORD(expr));
   x86._call_absmem(@cPtr_TProgramExpr_RaiseUpperExceeded);

   Fixups.AddFixup(passed);
end;

// ------------------
// ------------------ TFixupJump ------------------
// ------------------

// Create
//
constructor TFixupJump.Create(flags : TboolFlags);
begin
   inherited Create;
   FFlags:=flags;
end;

// GetSize
//
function TFixupJump.GetSize : Integer;
begin
   if (Next=Target) and (Location=Next.Location) then
      Result:=0
   else if NearJump then
      Result:=2
   else if FFlags=flagsNone then
      Result:=5
   else Result:=6;
end;

// NearJump
//
function TFixupJump.NearJump : Boolean;
begin
   Result:=(Abs(FixedLocation-Target.FixedLocation)<120);
end;

// Write
//
procedure TFixupJump.Write(output : TWriteOnlyBlockStream);
var
   offset : Integer;
begin
   if (Next=Target) and (Location=Next.Location) then
      Exit;

   offset:=Target.FixedLocation-FixedLocation;
   if NearJump then begin

      if FFlags=flagsNone then
         output.WriteByte($EB)
      else output.WriteByte(Ord(FFlags));
      output.WriteByte(offset-2);

   end else begin

      if FFlags=flagsNone then begin
         output.WriteByte($E9);
         output.WriteInt32(offset-5);
      end else begin
         output.WriteByte($0F);
         output.WriteByte(Ord(FFlags)+$10);
         output.WriteInt32(offset-6);
      end;

   end;
end;

// ------------------
// ------------------ TFixupPreamble ------------------
// ------------------

// GetSize
//
function TFixupPreamble.GetSize : Integer;
begin
   Result:=1;
   Inc(Result, 3);
   if AllocatedStackSpace>0 then
      Inc(Result, 3);
   if TempSpaceOnStack+AllocatedStackSpace>0 then begin
      Assert(TempSpaceOnStack<=127);
      Inc(Result, 3);
   end;
   if FPreserveExecInEDI then
      Inc(Result, 3);
end;

// Write
//
procedure TFixupPreamble.Write(output : TWriteOnlyBlockStream);
var
   x86 : Tx86WriteOnlyStream;
begin
   x86:=(output as Tx86WriteOnlyStream);

   x86._push_reg(cExecMemGPR);

   if FPreserveExecInEDI then begin
      x86._push_reg(gprEDI);
      x86._mov_reg_reg(gprEDI, gprEDX);
   end;

   if AllocatedStackSpace>0 then begin
      x86._push_reg(gprEBP);
      x86._mov_reg_reg(gprEBP, gprESP);
   end;

   if TempSpaceOnStack+AllocatedStackSpace>0 then
      x86._sub_reg_int32(gprESP, TempSpaceOnStack+AllocatedStackSpace);

   x86._mov_reg_dword_ptr_reg(cExecMemGPR, gprEDX, cStackMixinBaseDataOffset);
end;

// NeedTempSpace
//
procedure TFixupPreamble.NeedTempSpace(bytes : Integer);
begin
   if bytes>TempSpaceOnStack then
      TempSpaceOnStack:=bytes;
end;

// AllocateStackSpace
//
function TFixupPreamble.AllocateStackSpace(bytes : Integer) : Integer;
begin
   Inc(FAllocatedStackSpace, bytes);
   Result:=-AllocatedStackSpace;
end;

// ------------------
// ------------------ TFixupPostamble ------------------
// ------------------

// Create
//
constructor TFixupPostamble.Create(preamble : TFixupPreamble);
begin
   inherited Create;
   FPreamble:=preamble;
end;

// GetSize
//
function TFixupPostamble.GetSize : Integer;
begin
   Result:=0;
   if FPreamble.AllocatedStackSpace>0 then
      Inc(Result, 1);
   if FPreamble.TempSpaceOnStack+FPreamble.AllocatedStackSpace>0 then begin
      Assert(FPreamble.TempSpaceOnStack+FPreamble.AllocatedStackSpace<=127);
      Inc(Result, 3);
   end;
   if FPreamble.FPreserveExecInEDI then
      Inc(Result, 1);
   Inc(Result, 2);

   Inc(Result, ($10-(FixedLocation and $F)) and $F);
end;

// Write
//
procedure TFixupPostamble.Write(output : TWriteOnlyBlockStream);
var
   x86 : Tx86WriteOnlyStream;
begin
   x86:=(output as Tx86WriteOnlyStream);

   if FPreamble.TempSpaceOnStack+FPreamble.AllocatedStackSpace>0 then
      x86._add_reg_int32(gprESP, FPreamble.TempSpaceOnStack+FPreamble.AllocatedStackSpace);

   if FPreamble.AllocatedStackSpace>0 then
      x86._pop_reg(gprEBP);
   if FPreamble.FPreserveExecInEDI then
      x86._pop_reg(gprEDI);
   x86._pop_reg(cExecMemGPR);
   x86._ret;

   // pad to multiple of 16 for alignment
   x86._nop(($10-(output.Position and $F)) and $F);
end;

// ------------------
// ------------------ Tx86FixupLogicHelper ------------------
// ------------------

// NewJump
//
function Tx86FixupLogicHelper.NewJump(flags : TboolFlags) : TFixupJump;
begin
   Result:=TFixupJump.Create(flags);
   AddFixup(Result);
end;

// NewJump
//
function Tx86FixupLogicHelper.NewJump(flags : TboolFlags; target : TFixup) : TFixupJump;
begin
   if target<>nil then begin
      Result:=NewJump(flags);
      Result.Target:=target;
   end else Result:=nil;
end;

// NewJump
//
function Tx86FixupLogicHelper.NewJump(target : TFixup) : TFixupJump;
begin
   Result:=NewJump(flagsNone, target);
end;

// NewConditionalJumps
//
procedure Tx86FixupLogicHelper.NewConditionalJumps(flagsTrue : TboolFlags; targetTrue, targetFalse : TFixup);
begin
   if (targetTrue<>nil) and (targetTrue.Location<>0) then begin
      NewJump(flagsTrue, targetTrue);
      NewJump(NegateBoolFlags(flagsTrue), targetFalse);
   end else begin
      NewJump(NegateBoolFlags(flagsTrue), targetFalse);
      NewJump(flagsTrue, targetTrue);
   end;
end;

// ------------------
// ------------------ TdwsJITter_x86 ------------------
// ------------------

// Create
//
constructor TdwsJITter_x86.Create(jit : TdwsJITx86);
begin
   inherited Create(jit);
   FJIT:=jit;
   Fx86:=jit.x86;
end;

// CompileFloat
//
function TdwsJITter_x86.CompileFloat(expr : TExprBase) : Integer;
begin
   Result:=Ord(DoCompileFloat(expr));
end;

// DoCompileFloat
//
function TdwsJITter_x86.DoCompileFloat(expr : TExprBase) : TxmmRegister;
begin
   jit.OutputFailedOn:=expr;
   Result:=xmm0;
end;

// CompileAssignFloat
//
procedure TdwsJITter_x86.CompileAssignFloat(expr : TTypedExpr; source : Integer);
begin
   DoCompileAssignFloat(expr, TxmmRegister(source));
end;

// DoCompileAssignFloat
//
procedure TdwsJITter_x86.DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister);
begin
   jit.OutputFailedOn:=expr;
end;

// CompileBoolean
//
procedure TdwsJITter_x86.CompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
begin
   DoCompileBoolean(TBooleanBinOpExpr(expr), targetTrue, targetFalse);
end;

// DoCompileBoolean
//
procedure TdwsJITter_x86.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
begin
   jit.OutputFailedOn:=expr;
end;

// ------------------
// ------------------ TProgramExpr86 ------------------
// ------------------

// EvalNoResult
//
procedure TProgramExpr86.EvalNoResult(exec : TdwsExecution);
asm
   jmp [eax+FCode]
end;

// ------------------
// ------------------ TFloatExpr86 ------------------
// ------------------

// EvalAsFloat
//
function TFloatExpr86.EvalAsFloat(exec : TdwsExecution) : Double;
asm
   jmp [eax+FCode]
end;

// ------------------
// ------------------ TIntegerExpr86 ------------------
// ------------------

// EvalAsInteger
//
function TIntegerExpr86.EvalAsInteger(exec : TdwsExecution) : Int64;
asm
   jmp [eax+FCode]
end;

// ------------------
// ------------------ Tx86AssignConstToFloatVar ------------------
// ------------------

// CompileStatement
//
procedure Tx86AssignConstToFloatVar.CompileStatement(expr : TExprBase);
var
   e : TAssignConstToFloatVarExpr;
   reg : TxmmRegister;
begin
   e:=TAssignConstToFloatVarExpr(expr);

   reg:=jit.AllocXMMReg(expr);

   // check below is necessary as -Nan will be reported equal to zero
   if (e.Right=0) and not IsNaN(e.Right) then
      x86._xorps_reg_reg(reg, reg)
   else x86._movsd_reg_absmem(reg, @e.Right);

   jit.CompileAssignFloat(e.Left, reg);
end;

// ------------------
// ------------------ Tx86AssignConstToIntegerVar ------------------
// ------------------

// CompileStatement
//
procedure Tx86AssignConstToIntegerVar.CompileStatement(expr : TExprBase);
var
   e : TAssignConstToIntegerVarExpr;
   reg : TxmmRegister;
begin
   e:=TAssignConstToIntegerVarExpr(expr);

   if e.Left.ClassType=TIntVarExpr then begin

      reg:=jit.AllocXMMReg(expr);

      if e.Right=0 then
         x86._xorps_reg_reg(reg, reg)
      else x86._movq_reg_absmem(reg, @e.Right);

      x86._movq_execmem_reg(TVarExpr(e.Left).StackAddr, reg);

   end else inherited;
end;

// ------------------
// ------------------ Tx86AssignConstToBoolVar ------------------
// ------------------

// CompileStatement
//
procedure Tx86AssignConstToBoolVar.CompileStatement(expr : TExprBase);
var
   e : TAssignConstToBoolVarExpr;
begin
   e:=TAssignConstToBoolVarExpr(expr);

   if e.Left.ClassType=TBoolVarExpr then begin

      if e.Right then
         x86._mov_reg_dword(gprEAX, 1)
      else x86._xor_reg_reg(gprEAX, gprEAX);
      x86._mov_execmem_reg(TVarExpr(e.Left).StackAddr, 0, gprEAX);

   end else inherited;
end;

// ------------------
// ------------------ Tx86Assign ------------------
// ------------------

// CompileStatement
//
procedure Tx86Assign.CompileStatement(expr : TExprBase);
var
   e : TAssignExpr;
   reg : TxmmRegister;
begin
   e:=TAssignExpr(expr);

   if jit.IsFloat(e.Left) then begin

      reg:=jit.CompileFloat(e.Right);
      jit.CompileAssignFloat(e.Left, reg);

   end else if jit.IsInteger(e.Left) then begin

      jit.CompileInteger(e.Right);
      jit.CompileAssignInteger(e.Left, 0);

   end else inherited;
end;

// ------------------
// ------------------ Tx86OpAssignFloat ------------------
// ------------------

// Create
//
constructor Tx86OpAssignFloat.Create(jit : TdwsJITx86; op : TxmmOp);
begin
   inherited Create(jit);
   Self.OP:=op;
end;

// CompileStatement
//
procedure Tx86OpAssignFloat.CompileStatement(expr : TExprBase);
var
   e : TOpAssignExpr;
   reg, regRight : TxmmRegister;
begin
   e:=TOpAssignExpr(expr);

   regRight:=jit.CompileFloat(e.Right);
   reg:=jit.CompileFloat(e.Left);

   x86._xmm_reg_reg(OP, reg, regRight);

   jit.CompileAssignFloat(e.Left, reg);

   if regRight<>reg then
      jit.ReleaseXMMReg(regRight);
end;

// ------------------
// ------------------ Tx86BlockExprNoTable ------------------
// ------------------

// CompileStatement
//
procedure Tx86BlockExprNoTable.CompileStatement(expr : TExprBase);
var
   i : Integer;
   subExpr : TExprBase;
begin
   for i:=0 to expr.SubExprCount-1 do begin
      if jit.OutputFailedOn<>nil then break;
      subExpr:=expr.SubExpr[i];
      jit._DoStep(subExpr);
      jit.CompileStatement(subExpr);
   end;
end;

// ------------------
// ------------------ Tx86IfThen ------------------
// ------------------

// CompileStatement
//
procedure Tx86IfThen.CompileStatement(expr : TExprBase);
var
   e : TIfThenExpr;
   targetTrue, targetFalse : TFixupTarget;
begin
   e:=TIfThenExpr(expr);

   targetTrue:=jit.Fixups.NewHangingTarget;
   targetFalse:=jit.Fixups.NewHangingTarget;

   jit.CompileBoolean(e.CondExpr, targetTrue, targetFalse);

   jit.Fixups.AddFixup(targetTrue);

   jit.CompileStatement(e.ThenExpr);

   jit.Fixups.AddFixup(targetFalse);

   jit.ResetXMMReg;
end;

// ------------------
// ------------------ Tx86IfThenElse ------------------
// ------------------

// CompileStatement
//
procedure Tx86IfThenElse.CompileStatement(expr : TExprBase);
var
   e : TIfThenElseExpr;
   targetTrue, targetFalse, targetDone : TFixupTarget;
begin
   e:=TIfThenElseExpr(expr);

   targetTrue:=jit.Fixups.NewHangingTarget;
   targetFalse:=jit.Fixups.NewHangingTarget;
   targetDone:=jit.Fixups.NewHangingTarget;

   jit.CompileBoolean(e.CondExpr, targetTrue, targetFalse);

   jit.Fixups.AddFixup(targetTrue);

   jit.CompileStatement(e.ThenExpr);
   jit.Fixups.NewJump(flagsNone, targetDone);

   jit.Fixups.AddFixup(targetFalse);

   jit.CompileStatement(e.ElseExpr);

   jit.Fixups.AddFixup(targetDone);

   jit.ResetXMMReg;
end;

// ------------------
// ------------------ Tx86Loop ------------------
// ------------------

// CompileStatement
//
procedure Tx86Loop.CompileStatement(expr : TExprBase);
var
   e : TLoopExpr;
   targetLoop, targetExit : TFixupTarget;
begin
   e:=TLoopExpr(expr);

   jit.ResetXMMReg;

   targetLoop:=jit.Fixups.NewTarget;
   targetExit:=jit.Fixups.NewHangingTarget;

   jit.EnterLoop(targetLoop, targetExit);

   jit._DoStep(e.LoopExpr);
   jit.CompileStatement(e.LoopExpr);

   jit.Fixups.NewJump(flagsNone, targetLoop);

   jit.Fixups.AddFixup(targetExit);

   jit.LeaveLoop;

   jit.ResetXMMReg;
end;

// ------------------
// ------------------ Tx86Repeat ------------------
// ------------------

// CompileStatement
//
procedure Tx86Repeat.CompileStatement(expr : TExprBase);
var
   e : TLoopExpr;
   targetLoop, targetExit : TFixupTarget;
begin
   e:=TLoopExpr(expr);

   jit.ResetXMMReg;

   targetLoop:=jit.Fixups.NewTarget;
   targetExit:=jit.Fixups.NewHangingTarget;

   jit.EnterLoop(targetLoop, targetExit);

   jit._DoStep(e.LoopExpr);
   jit.CompileStatement(e.LoopExpr);

   jit._DoStep(e.CondExpr);
   jit.CompileBoolean(e.CondExpr, targetExit, targetLoop);

   jit.Fixups.AddFixup(targetExit);

   jit.LeaveLoop;

   jit.ResetXMMReg;
end;

// ------------------
// ------------------ Tx86While ------------------
// ------------------

// CompileStatement
//
procedure Tx86While.CompileStatement(expr : TExprBase);
var
   e : TLoopExpr;
   targetLoop, targetLoopStart, targetExit : TFixupTarget;
begin
   e:=TLoopExpr(expr);

   jit.ResetXMMReg;

   targetLoop:=jit.Fixups.NewTarget;
   targetLoopStart:=jit.Fixups.NewHangingTarget;
   targetExit:=jit.Fixups.NewHangingTarget;

   jit.EnterLoop(targetLoop, targetExit);

   jit._DoStep(e.CondExpr);
   jit.CompileBoolean(e.CondExpr, targetLoopStart, targetExit);

   jit.Fixups.AddFixup(targetLoopStart);

   jit._DoStep(e.LoopExpr);
   jit.CompileStatement(e.LoopExpr);

   jit.Fixups.NewJump(flagsNone, targetLoop);

   jit.Fixups.AddFixup(targetExit);

   jit.LeaveLoop;

   jit.ResetXMMReg;
end;

// ------------------
// ------------------ Tx86ForUpward ------------------
// ------------------

// CompileStatement
//
procedure Tx86ForUpward.CompileStatement(expr : TExprBase);
var
   e : TForUpwardExpr;
   jumpIfHiLower : TFixupJump;
   loopStart : TFixupTarget;
   loopContinue : TFixupTarget;
   loopAfter : TFixupTarget;
   fromValue, toValue : Int64;
   toValueIsConstant : Boolean;
   toValueOffset : Integer;
   is32bit : Boolean;
begin
   e:=TForUpwardExpr(expr);

   jit.ResetXMMReg;

   toValueIsConstant:=(e.ToExpr is TConstIntExpr);
   if toValueIsConstant then
      toValue:=TConstIntExpr(e.ToExpr).Value
   else toValue:=0;

   if e.FromExpr is TConstIntExpr then begin

      fromValue:=TConstIntExpr(e.FromExpr).Value;

      x86._mov_execmem_imm(e.VarExpr.StackAddr, fromValue);

      is32bit:=    (fromValue>=0)
               and toValueIsConstant
               and (Integer(toValue)=toValue)
               and (Integer(fromValue)=fromValue);

   end else begin

      jit.CompileInteger(e.FromExpr);
      x86._mov_execmem_eaxedx(e.VarExpr.StackAddr);

      is32bit:=False;

   end;

   if not toValueIsConstant then begin

      jit.CompileInteger(e.ToExpr);

      toValueOffset:=jit.FPreamble.AllocateStackSpace(SizeOf(Int64));
      x86._mov_qword_ptr_reg_eaxedx(gprEBP, toValueOffset);

   end else toValueOffset:=0;

   loopStart:=jit.Fixups.NewTarget;
   loopContinue:=jit.Fixups.NewHangingTarget;
   loopAfter:=jit.Fixups.NewHangingTarget;

   jit.EnterLoop(loopContinue, loopAfter);

   if is32bit then begin

      x86._cmp_execmem_int32(e.VarExpr.StackAddr, 0, toValue);
      jit.Fixups.NewJump(flagsG, loopAfter);

      jit._DoStep(e.DoExpr);
      jit.CompileStatement(e.DoExpr);

      jit.Fixups.AddFixup(loopContinue);

      x86._add_execmem_int32(e.VarExpr.StackAddr, 0, 1);

      jit.Fixups.NewJump(flagsNone, loopStart);

   end else begin

      if toValueIsConstant then begin

         x86._cmp_execmem_int32(e.VarExpr.StackAddr, 4, toValue shr 32);
         jit.Fixups.NewJump(flagsG, loopAfter);
         jumpIfHiLower:=jit.Fixups.NewJump(flagsB);

         x86._cmp_execmem_int32(e.VarExpr.StackAddr, 0, toValue);
         jit.Fixups.NewJump(flagsG, loopAfter);

      end else begin

         x86._mov_eaxedx_qword_ptr_reg(gprEBP, toValueOffset);

         x86._cmp_execmem_reg(e.VarExpr.StackAddr, 4, gprEDX);
         jit.Fixups.NewJump(flagsG, loopAfter);
         jumpIfHiLower:=jit.Fixups.NewJump(flagsB);

         x86._cmp_execmem_reg(e.VarExpr.StackAddr, 0, gprEAX);
         jit.Fixups.NewJump(flagsG, loopAfter);

      end;

      jumpIfHiLower.NewTarget;

      jit._DoStep(e.DoExpr);
      jit.CompileStatement(e.DoExpr);

      jit.Fixups.AddFixup(loopContinue);

      x86._execmem64_inc(e.VarExpr.StackAddr, 1);

      jit.Fixups.NewJump(flagsNone, loopStart);

   end;

   if JIT.LoopContext.Exited then
      jit.ResetXMMReg;

   jit.LeaveLoop;

   jit.Fixups.AddFixup(loopAfter);
end;

// ------------------
// ------------------ Tx86Continue ------------------
// ------------------

// CompileStatement
//
procedure Tx86Continue.CompileStatement(expr : TExprBase);
begin
   if jit.LoopContext<>nil then
      jit.Fixups.NewJump(flagsNone, jit.LoopContext.TargetContinue)
   else jit.OutputFailedOn:=expr;
end;

// ------------------
// ------------------ Tx86Exit ------------------
// ------------------

// CompileStatement
//
procedure Tx86Exit.CompileStatement(expr : TExprBase);
begin
   if jit.ExitTarget<>nil then
      jit.Fixups.NewJump(flagsNone, jit.ExitTarget)
   else jit.OutputFailedOn:=expr;
end;

// ------------------
// ------------------ Tx86ExitValue ------------------
// ------------------

// CompileStatement
//
procedure Tx86ExitValue.CompileStatement(expr : TExprBase);
begin
   jit.CompileStatement(TExitValueExpr(expr).AssignExpr);

   inherited;
end;

// ------------------
// ------------------ Tx86FloatBinOp ------------------
// ------------------

// Create
//
constructor Tx86FloatBinOp.Create(jit : TdwsJITx86; op : TxmmOp);
begin
   inherited Create(jit);
   Self.OP:=op;
end;

// CompileFloat
//
function Tx86FloatBinOp.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TFloatBinOpExpr;
begin
   e:=TFloatBinOpExpr(expr);

   Result:=jit.CompileFloat(e.Left);

   jit._xmm_reg_expr(OP, Result, e.Right);

   jit.ContainsXMMReg(Result, expr);
end;

// ------------------
// ------------------ Tx86SqrFloat ------------------
// ------------------

// CompileFloat
//
function Tx86SqrFloat.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TSqrFloatExpr;
begin
   e:=TSqrFloatExpr(expr);

   Result:=jit.CompileFloat(e.Expr);

   x86._xmm_reg_reg(xmm_multsd, Result, Result);

   jit.ContainsXMMReg(Result, expr);
end;

// ------------------
// ------------------ Tx86AbsFloat ------------------
// ------------------

// DoCompileFloat
//
function Tx86AbsFloat.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TAbsFloatExpr;
begin
   e:=TAbsFloatExpr(expr);

   Result:=jit.CompileFloat(e.Expr);

   // andpd Result, dqword ptr [AbsMask]
   x86.WriteBytes([$66, $0F, $54, $05+Ord(Result)*8]);
   x86.WritePointer(jit.AbsMaskPD);

   jit.ContainsXMMReg(Result, expr);
end;

// ------------------
// ------------------ Tx86NegFloat ------------------
// ------------------

// DoCompileFloat
//
function Tx86NegFloat.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TNegFloatExpr;
begin
   e:=TNegFloatExpr(expr);

   Result:=jit.CompileFloat(e.Expr);

   // xorpd Result, dqword ptr [SignMask]
   x86.WriteBytes([$66, $0F, $57, $05+Ord(Result)*8]);
   x86.WritePointer(jit.SignMaskPD);

   jit.ContainsXMMReg(Result, expr);
end;

// ------------------
// ------------------ Tx86ConstFloat ------------------
// ------------------

// CompileFloat
//
function Tx86ConstFloat.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TConstFloatExpr;
begin
   e:=TConstFloatExpr(expr);

   Result:=jit.AllocXMMReg(e);

   x86._movsd_reg_absmem(Result, @e.Value);
end;

// ------------------
// ------------------ Tx86ConstInt ------------------
// ------------------

// CompileFloat
//
function Tx86ConstInt.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TConstIntExpr;
begin
   e:=TConstIntExpr(expr);

   if (e.Value>-MaxInt) and (e.Value<MaxInt) then begin

      Result:=jit.AllocXMMReg(e, e);

      x86._xmm_reg_absmem(xmm_cvtsi2sd, Result, @e.Value);

   end else Result:=inherited;
end;

// CompileInteger
//
function Tx86ConstInt.CompileInteger(expr : TExprBase) : Integer;
var
   e : TConstIntExpr;
begin
   e:=TConstIntExpr(expr);

   x86._mov_eaxedx_imm(e.Value);

   Result:=0;
end;

// ------------------
// ------------------ Tx86InterpretedExpr ------------------
// ------------------

// DoCallEval
//
procedure Tx86InterpretedExpr.DoCallEval(expr : TExprBase; vmt : Integer);
begin
   jit.FPreamble.PreserveExecInEDI:=True;

   x86._mov_reg_reg(gprEDX, gprEDI);
   x86._mov_reg_dword(gprEAX, DWORD(expr));
   x86._mov_reg_dword_ptr_reg(gprECX, gprEAX);

   x86._call_reg(gprECX, vmt);

   if jit.FSavedXMM=[] then
      jit.ResetXMMReg;

   jit.QueueGreed(expr);
end;

// CompileStatement
//
procedure Tx86InterpretedExpr.CompileStatement(expr : TExprBase);
begin
   DoCallEval(expr, vmt_TExprBase_EvalNoResult);
end;

// DoCompileFloat
//
function Tx86InterpretedExpr.DoCompileFloat(expr : TExprBase) : TxmmRegister;
begin
   jit.SaveXMMRegs;

   DoCallEval(expr, vmt_TExprBase_EvalAsFloat);

   jit.RestoreXMMRegs;

   jit.FPreamble.NeedTempSpace(SizeOf(Double));
   Result:=jit.AllocXMMReg(expr);
   x86._fstp_esp;
   x86._movsd_reg_esp(Result);

   if expr is TFuncExprBase then
      jit.QueueGreed(expr);
end;

// DoCompileAssignFloat
//
procedure Tx86InterpretedExpr.DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister);
begin
   jit.ReleaseXMMReg(source);
   jit.SaveXMMRegs;

   x86._sub_reg_int32(gprESP, SizeOf(Double));
   x86._movsd_esp_reg(source);

   DoCallEval(expr, vmt_TExprBase_AssignValueAsFloat);

   jit.RestoreXMMRegs;
end;

// CompileInteger
//
function Tx86InterpretedExpr.CompileInteger(expr : TExprBase) : Integer;
begin
   jit.SaveXMMRegs;

   DoCallEval(expr, vmt_TExprBase_EvalAsInteger);

   jit.RestoreXMMRegs;

   jit.QueueGreed(expr);

   Result:=0;
end;

// CompileAssignInteger
//
procedure Tx86InterpretedExpr.CompileAssignInteger(expr : TTypedExpr; source : Integer);
begin
   jit.SaveXMMRegs;

   x86._push_reg(gprEDX);
   x86._push_reg(gprEAX);

   DoCallEval(expr, vmt_TExprBase_AssignValueAsInteger);

   jit.RestoreXMMRegs;
end;

// DoCompileBoolean
//
procedure Tx86InterpretedExpr.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
begin
   jit.SaveXMMRegs;

   DoCallEval(expr, vmt_TExprBase_EvalAsBoolean);

   jit.RestoreXMMRegs;

   x86._test_al_al;
   jit.Fixups.NewConditionalJumps(flagsNZ, targetTrue, targetFalse);

   jit.QueueGreed(expr);
end;

// ------------------
// ------------------ Tx86FloatVar ------------------
// ------------------

// CompileFloat
//
function Tx86FloatVar.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TFloatVarExpr;
begin
   e:=TFloatVarExpr(expr);

   Result:=jit.CurrentXMMReg(e.DataSym);

   if Result=xmmNone then begin

      Result:=jit.AllocXMMReg(e, e.DataSym);
      x86._movsd_reg_execmem(Result, e.StackAddr);

   end;
end;

// DoCompileAssignFloat
//
procedure Tx86FloatVar.DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister);
var
   e : TFloatVarExpr;
begin
   e:=TFloatVarExpr(expr);

   x86._movsd_execmem_reg(e.StackAddr, source);

   jit.ContainsXMMReg(source, e.DataSym);
end;

// ------------------
// ------------------ Tx86IntVar ------------------
// ------------------

// CompileFloat
//
function Tx86IntVar.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TIntVarExpr;
begin
   e:=TIntVarExpr(expr);

   Result:=jit.AllocXMMReg(e);

   jit.FPreamble.NeedTempSpace(SizeOf(Double));

   x86._fild_execmem(e.StackAddr);
   x86._fstp_esp;

   x86._movsd_reg_esp(Result);
end;

// CompileInteger
//
function Tx86IntVar.CompileInteger(expr : TExprBase) : Integer;
var
   e : TIntVarExpr;
begin
   e:=TIntVarExpr(expr);

   x86._mov_eaxedx_execmem(e.StackAddr);

   Result:=0;
end;

// CompileAssignInteger
//
procedure Tx86IntVar.CompileAssignInteger(expr : TTypedExpr; source : Integer);
var
   e : TIntVarExpr;
begin
   e:=TIntVarExpr(expr);

   x86._mov_execmem_eaxedx(e.StackAddr);
end;

// ------------------
// ------------------ Tx86ObjectVar ------------------
// ------------------

// CompileScriptObj
//
function Tx86ObjectVar.CompileScriptObj(expr : TExprBase) : Integer;
begin
   Result:=Ord(gprEAX);
   x86._mov_reg_execmem(gprEAX, TObjectVarExpr(expr).StackAddr);
end;

// ------------------
// ------------------ Tx86RecordVar ------------------
// ------------------

// CompileFloat
//
function Tx86RecordVar.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TRecordVarExpr;
begin
   e:=TRecordVarExpr(expr);

   if jit.IsFloat(e) then begin

      Result:=jit.AllocXMMReg(e);
      x86._movsd_reg_execmem(Result, e.VarPlusMemberOffset);

   end else Result:=inherited;
end;

// DoCompileAssignFloat
//
procedure Tx86RecordVar.DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister);
var
   e : TRecordVarExpr;
begin
   e:=TRecordVarExpr(expr);

   if jit.IsFloat(e) then begin

      x86._movsd_execmem_reg(e.VarPlusMemberOffset, source);
      jit.ReleaseXMMReg(source);

   end else inherited;
end;

// ------------------
// ------------------ Tx86VarParam ------------------
// ------------------

// CompileAsPVariant
//
class procedure Tx86VarParam.CompileAsPVariant(x86 : Tx86WriteOnlyStream; expr : TByRefParamExpr);
begin
   x86._mov_reg_execmem(gprEAX, expr.StackAddr);
   x86._xor_reg_reg(gprEDX, gprEDX);
   x86._mov_reg_dword_ptr_reg(gprECX, gprEAX);
   x86._call_reg(gprECX, vmt_IDataContext_AsPVariant);
end;

// DoCompileFloat
//
function Tx86VarParam.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TVarParamExpr;
begin
   e:=TVarParamExpr(expr);

   CompileAsPVariant(x86, e);

   if jit.IsFloat(e) then begin

      Result:=jit.AllocXMMReg(e, e.DataSym);
      x86._movsd_reg_qword_ptr_reg(Result, gprEAX, cVariant_DataOffset);

   end else Result:=inherited;
end;

// DoCompileAssignFloat
//
procedure Tx86VarParam.DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister);
var
   e : TVarParamExpr;
begin
   e:=TVarParamExpr(expr);

   if jit.IsFloat(e) then begin

      CompileAsPVariant(x86, e);

      x86._movsd_qword_ptr_reg_reg(gprEAX, cVariant_DataOffset, source);

   end else inherited;
end;

// ------------------
// ------------------ Tx86ArrayBase ------------------
// ------------------

// CompileIndexToGPR
//
procedure Tx86ArrayBase.CompileIndexToGPR(indexExpr : TTypedExpr; gpr : TgpRegister; var delta : Integer);
var
   tempPtrOffset : Integer;
   sign : Integer;
begin
   delta:=0;
   if indexExpr.ClassType=TConstIntExpr then begin

      x86._mov_reg_dword(gpr, TConstIntExpr(indexExpr).Value);

   end else if indexExpr.ClassType=TIntVarExpr then begin

      x86._mov_reg_execmem(gpr, TIntVarExpr(indexExpr).StackAddr);

   end else begin

      if indexExpr.ClassType=TAddIntExpr then
         sign:=1
      else if indexExpr.ClassType=TSubIntExpr then
         sign:=-1
      else sign:=0;
      if sign<>0 then begin
         if TIntegerBinOpExpr(indexExpr).Right is TConstIntExpr then begin
            CompileIndexToGPR(TIntegerBinOpExpr(indexExpr).Left, gpr, delta);
            delta:=delta+sign*TConstIntExpr(TIntegerBinOpExpr(indexExpr).Right).Value;
            Exit;
         end else if TIntegerBinOpExpr(indexExpr).Left is TConstIntExpr then begin
            CompileIndexToGPR(TIntegerBinOpExpr(indexExpr).Right, gpr, delta);
            delta:=delta+sign*TConstIntExpr(TIntegerBinOpExpr(indexExpr).Left).Value;
            Exit;
         end;
      end;

      tempPtrOffset:=jit.FPreamble.AllocateStackSpace(SizeOf(Pointer));
      x86._mov_dword_ptr_reg_reg(gprEBP, tempPtrOffset, gprEAX);

      jit.CompileInteger(indexExpr);
      x86._mov_reg_reg(gpr, gprEAX);

      x86._mov_reg_dword_ptr_reg(gprEAX, gprEBP, tempPtrOffset);

   end;
end;

// ------------------
// ------------------ Tx86StaticArray ------------------
// ------------------

// DoCompileFloat
//
function Tx86StaticArray.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TStaticArrayExpr;
   index, delta : Integer;
begin
   e:=TStaticArrayExpr(expr);

   if jit.IsFloat(e) then begin

      if (e.BaseExpr is TByRefParamExpr) and (e.IndexExpr is TConstIntExpr) then begin

         index:=TConstIntExpr(e.IndexExpr).Value-e.LowBound;

         Tx86VarParam.CompileAsPVariant(x86, TByRefParamExpr(e.BaseExpr));
         x86._mov_reg_dword(gprECX, index*SizeOf(Variant));
         Result:=jit.AllocXMMReg(e);
         x86._movsd_reg_qword_ptr_indexed(Result, gprEAX, gprECX, 1, cVariant_DataOffset);

      end else if e.BaseExpr.ClassType=TVarExpr then begin

         if e.IndexExpr is TConstIntExpr then begin

            index:=TConstIntExpr(e.IndexExpr).Value-e.LowBound;

            Result:=jit.AllocXMMReg(e);
            x86._movsd_reg_execmem(Result, TVarExpr(e.BaseExpr).StackAddr+index);

         end else begin

            CompileIndexToGPR(e.IndexExpr, gprECX, delta);
            jit._RangeCheck(e, gprECX, delta, e.LowBound, e.LowBound+e.Count);

            Result:=jit.AllocXMMReg(e);
            x86._shift_reg_imm(gpShl, gprECX, 4);
            x86._movsd_reg_qword_ptr_indexed(Result, cExecMemGPR, gprECX, 1, StackAddrToOffset(TVarExpr(e.BaseExpr).StackAddr));

         end;

      end else Result:=inherited;

   end else Result:=inherited;
end;

// CompileInteger
//
function Tx86StaticArray.CompileInteger(expr : TExprBase) : Integer;
var
   e : TStaticArrayExpr;
   delta : Integer;
begin
   e:=TStaticArrayExpr(expr);

   if (e.BaseExpr is TFieldExpr) then  begin

      jit.CompileScriptObj(TFieldExpr(e.BaseExpr).ObjectExpr);
      // TODO object check
      x86._mov_reg_dword_ptr_reg(gprEAX, gprEAX, vmt_ScriptObjInstance_IScriptObj_To_FData);
      x86._add_reg_int32(gprEAX, TFieldExpr(e.BaseExpr).FieldAddr*SizeOf(Variant));

      CompileIndexToGPR(e.IndexExpr, gprECX, delta);
      jit._RangeCheck(e, gprECX, delta, e.LowBound, e.LowBound+e.Count);

      x86._shift_reg_imm(gpShl, gprECX, 4);

      x86._mov_reg_dword_ptr_indexed(gprEDX, gprEAX, gprECX, 1, cVariant_DataOffset+4);
      x86._mov_reg_dword_ptr_indexed(gprEAX, gprEAX, gprECX, 1, cVariant_DataOffset);

      Result:=0;

   end else Result:=inherited;
end;

// DoCompileAssignFloat
//
procedure Tx86StaticArray.DoCompileAssignFloat(expr : TTypedExpr; source : TxmmRegister);
var
   e : TStaticArrayExpr;
   index : Integer;
begin
   e:=TStaticArrayExpr(expr);

   if jit.IsFloat(e) then begin

      if (e.BaseExpr.ClassType=TVarParamExpr) and (e.IndexExpr is TConstIntExpr) then begin

         index:=TConstIntExpr(e.IndexExpr).Value;

         Tx86VarParam.CompileAsPVariant(x86, TVarParamExpr(e.BaseExpr));
         x86._mov_reg_dword(gprECX, index*SizeOf(Variant));
         x86._movsd_qword_ptr_indexed_reg(gprEAX, gprECX, 1, cVariant_DataOffset, source);

      end else if (e.BaseExpr.ClassType=TVarExpr) and (e.IndexExpr is TConstIntExpr) then begin

         index:=TConstIntExpr(e.IndexExpr).Value;

         x86._movsd_execmem_reg(TVarExpr(e.BaseExpr).StackAddr+index, source);

      end else inherited;

   end else inherited;
end;

// ------------------
// ------------------ Tx86DynamicArrayBase ------------------
// ------------------

// CompileAsData
//
procedure Tx86DynamicArrayBase.CompileAsData(expr : TTypedExpr);
begin
   jit.CompileScriptObj(expr);
   x86._mov_reg_dword_ptr_reg(gprEAX, gprEAX, vmt_ScriptDynamicArray_IScriptObj_To_FData);
end;

// ------------------
// ------------------ Tx86DynamicArray ------------------
// ------------------

// DoCompileFloat
//
function Tx86DynamicArray.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TDynamicArrayExpr;
   delta : Integer;
begin
   e:=TDynamicArrayExpr(expr);

   if jit.IsFloat(e) then begin

      CompileAsData(e.BaseExpr);

      CompileIndexToGPR(e.IndexExpr, gprECX, delta);
      delta:=delta*SizeOf(Variant)+cVariant_DataOffset;

      x86._shift_reg_imm(gpShl, gprECX, 4);
      // TODO : range checking

      Result:=jit.AllocXMMReg(e);
      x86._movsd_reg_qword_ptr_indexed(Result, gprEAX, gprECX, 1, delta);

   end else Result:=inherited;
end;

// CompileInteger
//
function Tx86DynamicArray.CompileInteger(expr : TExprBase) : Integer;
var
   e : TDynamicArrayExpr;
   delta : Integer;
begin
   e:=TDynamicArrayExpr(expr);

   CompileAsData(e.BaseExpr);

   CompileIndexToGPR(e.IndexExpr, gprECX, delta);
   delta:=delta*SizeOf(Variant)+cVariant_DataOffset;

   x86._shift_reg_imm(gpShl, gprECX, 4);
   // TODO : range checking

   x86._mov_reg_dword_ptr_indexed(gprEDX, gprEAX, gprECX, 1, delta+4);
   x86._mov_reg_dword_ptr_indexed(gprEAX, gprEAX, gprECX, 1, delta);

   Result:=0;
end;

// CompileScriptObj
//
function Tx86DynamicArray.CompileScriptObj(expr : TExprBase) : Integer;
var
   e : TDynamicArrayExpr;
   delta : Integer;
begin
   e:=TDynamicArrayExpr(expr);

   CompileAsData(e.BaseExpr);

   CompileIndexToGPR(e.IndexExpr, gprECX, delta);
   delta:=delta*SizeOf(Variant)+cVariant_DataOffset;

   x86._shift_reg_imm(gpShl, gprECX, 4);
   // TODO : range checking

   Result:=Ord(gprEAX);
   x86._mov_reg_dword_ptr_indexed(gprEAX, gprEAX, gprECX, 1, delta);
end;

// ------------------
// ------------------ Tx86DynamicArraySet ------------------
// ------------------

// CompileStatement
//
procedure Tx86DynamicArraySet.CompileStatement(expr : TExprBase);
var
   e : TDynamicArraySetExpr;
   reg : TxmmRegister;
   delta : Integer;
begin
   e:=TDynamicArraySetExpr(expr);

   if jit.IsFloat(e.ArrayExpr.Typ.Typ) then begin

      reg:=jit.CompileFloat(e.ValueExpr);
      CompileAsData(e.ArrayExpr);

      CompileIndexToGPR(e.IndexExpr, gprECX, delta);
      // TODO : range checking

      delta:=delta*SizeOf(Variant)+cVariant_DataOffset;

      x86._shift_reg_imm(gpShl, gprECX, 4);

      x86._movsd_qword_ptr_indexed_reg(gprEAX, gprECX, 1, delta, reg);

   end else inherited;
end;

// ------------------
// ------------------ Tx86NegInt ------------------
// ------------------

// CompileInteger
//
function Tx86NegInt.CompileInteger(expr : TExprBase) : Integer;
begin
   Result:=jit.CompileInteger(TNegIntExpr(expr).Expr);

   x86._neg_reg(gprEDX);
   x86._neg_reg(gprEAX);
   x86._sbb_reg_int32(gprEDX, 0);
end;

// ------------------
// ------------------ Tx86AddInt ------------------
// ------------------

// CompileInteger
//
function Tx86AddInt.CompileInteger(expr : TExprBase) : Integer;
var
   e : TAddIntExpr;
   addr : Integer;
begin
   e:=TAddIntExpr(expr);

   Result:=jit.CompileInteger(e.Left);

   if e.Right is TConstIntExpr then begin

      x86._add_eaxedx_imm(TConstIntExpr(e.Right).Value);

   end else if e.Right.ClassType=TIntVarExpr then begin

      x86._add_eaxedx_execmem(TIntVarExpr(e.Right).StackAddr);

   end else begin

      addr:=jit.FPreamble.AllocateStackSpace(SizeOf(Int64));

      x86._mov_qword_ptr_reg_eaxedx(gprEBP, addr);

      jit.CompileInteger(e.Right);

      x86._add_reg_dword_ptr_reg(gprEAX, gprEBP, addr);
      x86._adc_reg_dword_ptr_reg(gprEDX, gprEBP, addr+4);

   end;
end;

// ------------------
// ------------------ Tx86SubInt ------------------
// ------------------

// CompileInteger
//
function Tx86SubInt.CompileInteger(expr : TExprBase) : Integer;
var
   e : TSubIntExpr;
   addr : Integer;
begin
   e:=TSubIntExpr(expr);

   if e.Right is TConstIntExpr then begin

      Result:=jit.CompileInteger(e.Left);
      x86._sub_eaxedx_imm(TConstIntExpr(e.Right).Value);

   end else if e.Right.ClassType=TIntVarExpr then begin

      Result:=jit.CompileInteger(e.Left);
      x86._sub_eaxedx_execmem(TIntVarExpr(e.Right).StackAddr);

   end else begin

      Result:=jit.CompileInteger(e.Right);
      addr:=jit.FPreamble.AllocateStackSpace(SizeOf(Int64));

      x86._mov_qword_ptr_reg_eaxedx(gprEBP, addr);

      jit.CompileInteger(e.Left);

      x86._sub_reg_dword_ptr_reg(gprEAX, gprEBP, addr);
      x86._sbb_reg_dword_ptr_reg(gprEDX, gprEBP, addr+4);

   end;
end;

// ------------------
// ------------------ Tx86MultInt ------------------
// ------------------

// CompileInteger
//
function Tx86MultInt.CompileInteger(expr : TExprBase) : Integer;

   procedure CompileOperand(expr : TTypedExpr; var reg : TgpRegister; var addr : Integer);
   begin
      if expr is TIntVarExpr then begin
         reg:=cExecMemGPR;
         addr:=StackAddrToOffset(TIntVarExpr(expr).StackAddr);
      end else begin
         reg:=gprEBP;
         addr:=jit.FPreamble.AllocateStackSpace(SizeOf(Int64));
         jit.CompileInteger(expr);
         x86._mov_qword_ptr_reg_eaxedx(reg, addr);
      end;
   end;

var
   e : TMultIntExpr;
   twomuls, done : TFixupTarget;
   leftReg, rightReg : TgpRegister;
   leftAddr, rightAddr : Integer;
begin
   e:=TMultIntExpr(expr);

   CompileOperand(e.Left, leftReg, leftAddr);
   CompileOperand(e.Right, rightReg, rightAddr);

   // Based on reference code from AMD Athlon Optimization guide

   twomuls:=jit.Fixups.NewHangingTarget;
   done:=jit.Fixups.NewHangingTarget;

   x86._mov_reg_dword_ptr_reg(gprEDX, leftReg, leftAddr+4);    // left_hi
   x86._mov_reg_dword_ptr_reg(gprECX, rightReg, rightAddr+4);  // right_hi
   x86._op_reg_reg(gpOp_or, gprEDX, gprECX);                   // one operand >= 2^32?
   x86._mov_reg_dword_ptr_reg(gprEDX, rightReg, rightAddr);    // right_lo
   x86._mov_reg_dword_ptr_reg(gprEAX, leftReg, leftAddr);      // left_lo

   jit.Fixups.NewJump(flagsNZ, twomuls);                       // yes, need two multiplies

   x86._mul_reg(gprEDX);                                       // left_lo * right_lo
   jit.Fixups.NewJump(flagsNone, done);

   jit.Fixups.AddFixup(twomuls);

   x86._imul_reg_dword_ptr_reg(gprEDX, leftReg, leftAddr+4);   // p3_lo = left_hi*right_lo
   x86._imul_reg_reg(gprECX, gprEAX);                          // p2_lo = right_hi*left_lo
   x86._add_reg_reg(gprECX, gprEDX);                           // p2_lo + p3_lo
   x86._mul_dword_ptr_reg(rightReg, rightAddr);                // p1 = left_lo*right_lo
   x86._add_reg_reg(gprEDX, gprECX);                           // p1+p2lo+p3_lo

   jit.Fixups.AddFixup(done);

   Result:=0;
end;

// ------------------
// ------------------ Tx86MultIntPow2 ------------------
// ------------------

// CompileInteger
//
function Tx86MultIntPow2.CompileInteger(expr : TExprBase) : Integer;
var
   e : TMultIntPow2Expr;
begin
   e:=TMultIntPow2Expr(expr);

   Result:=jit.CompileInteger(e.Expr);
   x86._shl_eaxedx_imm(e.Shift+1);
end;

// ------------------
// ------------------ Tx86DivInt ------------------
// ------------------

// CompileInteger
//
function Tx86DivInt.CompileInteger(expr : TExprBase) : Integer;

   procedure DivideByPowerOfTwo(p : Integer);
   begin
      x86._mov_reg_reg(gprECX, gprEDX);
      x86._shift_reg_imm(gpShr, gprECX, 32-p);
      x86._add_reg_reg(gprEAX, gprECX);
      x86._adc_reg_int32(gprEDX, 0);
      x86._sar_eaxedx_imm(p);
   end;

var
   e : TDivExpr;
   d : Int64;
   i : Integer;
begin
   e:=TDivExpr(expr);

   if e.Right is TConstIntExpr then begin

      d:=TConstIntExpr(e.Right).Value;
      if d=1 then begin
         Result:=jit.CompileInteger(e.Left);
         Exit;
      end;

      if d>0 then begin
         // is it a power of two?
         i:=WhichPowerOfTwo(d);
         if (i>0) and (i<=31) then begin
            Result:=jit.CompileInteger(e.Left);
            DivideByPowerOfTwo(i);
            Exit;
         end;
      end;

   end;
   Result:=inherited;
end;

// ------------------
// ------------------ Tx86Shr ------------------
// ------------------

// CompileInteger
//
function Tx86Shr.CompileInteger(expr : TExprBase) : Integer;
var
   e : TShrExpr;
begin
   e:=TShrExpr(expr);

   if e.Right is TConstIntExpr then begin

      Result:=jit.CompileInteger(e.Left);

      x86._shr_eaxedx_imm(TConstIntExpr(e.Right).Value);

   end else Result:=inherited;
end;

// ------------------
// ------------------ Tx86Shl ------------------
// ------------------

// CompileInteger
//
function Tx86Shl.CompileInteger(expr : TExprBase) : Integer;
var
   e : TShlExpr;
   addr : Integer;
   below32, done : TFixupTarget;
begin
   e:=TShlExpr(expr);

   Result:=jit.CompileInteger(e.Left);

   if e.Right is TConstIntExpr then begin

      x86._shl_eaxedx_imm(TConstIntExpr(e.Right).Value);

   end else begin

      if e.Right is TIntVarExpr then begin

         x86._mov_reg_execmem(gprECX, TIntVarExpr(e.Right).StackAddr);

      end else begin

         addr:=jit.FPreamble.AllocateStackSpace(SizeOf(Int64));

         x86._mov_qword_ptr_reg_eaxedx(gprEBP, addr);

         jit.CompileInteger(e.Right);
         x86._mov_reg_reg(gprECX, gprEAX);

         x86._mov_eaxedx_qword_ptr_reg(gprEBP, addr);

      end;

      x86._op_reg_int32(gpOp_and, gprECX, 63);

      below32:=jit.Fixups.NewHangingTarget;
      done:=jit.Fixups.NewHangingTarget;

      x86._cmp_reg_int32(gprECX, 32);
      jit.Fixups.NewJump(flagsB, below32);

      x86._mov_reg_reg(gprEDX, gprEAX);
      x86._mov_reg_dword(gprEAX, 0);
      x86._shift_reg_cl(gpShl, gprEDX);

      jit.Fixups.NewJump(done);
      jit.Fixups.AddFixup(below32);

      x86._shl_eaxedx_cl;

      jit.Fixups.AddFixup(done);
   end;
end;

// ------------------
// ------------------ Tx86Inc ------------------
// ------------------

// DoCompileStatement
//
procedure Tx86Inc.DoCompileStatement(v : TIntVarExpr; i : TTypedExpr);
begin
   if i is TConstIntExpr then begin

      x86._execmem64_inc(v.StackAddr, TConstIntExpr(i).Value);

   end else begin

      jit.CompileInteger(i);

      x86._add_execmem_reg(v.StackAddr, 0, gprEAX);
      x86._adc_execmem_reg(v.StackAddr, 4, gprEDX);

   end;
end;

// ------------------
// ------------------ Tx86IncIntVar ------------------
// ------------------

// CompileStatement
//
procedure Tx86IncIntVar.CompileStatement(expr : TExprBase);
var
   e : TIncIntVarExpr;
begin
   e:=TIncIntVarExpr(expr);
   DoCompileStatement(e.Left as TIntVarExpr, e.Right);;
end;

// ------------------
// ------------------ Tx86IncVarFunc ------------------
// ------------------

// CompileStatement
//
procedure Tx86IncVarFunc.CompileStatement(expr : TExprBase);
var
   e : TIncVarFuncExpr;
begin
   e:=TIncVarFuncExpr(expr);

   if e.Args[0] is TIntVarExpr then
      DoCompileStatement(TIntVarExpr(e.Args[0]), e.Args[1] as TTypedExpr)
   else inherited;
end;

// ------------------
// ------------------ Tx86DecIntVar ------------------
// ------------------

// CompileStatement
//
procedure Tx86DecIntVar.CompileStatement(expr : TExprBase);
var
   e : TDecIntVarExpr;
   left : TVarExpr;
begin
   e:=TDecIntVarExpr(expr);
   left:=e.Left as TVarExpr;

   if e.Right is TConstIntExpr then begin

      x86._execmem64_dec((e.Left as TVarExpr).StackAddr, TConstIntExpr(e.Right).Value);

   end else begin

      jit.CompileInteger(e.Right);

      x86._sub_execmem_reg(left.StackAddr, 0, gprEAX);
      x86._sbb_execmem_reg(left.StackAddr, 4, gprEDX);

   end;
end;

// ------------------
// ------------------ Tx86RelOpInt ------------------
// ------------------

// Create
//
constructor Tx86RelOpInt.Create(jit : TdwsJITx86; flagsHiPass, flagsHiFail, flagsLo : TboolFlags);
begin
   inherited Create(jit);
   Self.FlagsHiPass:=flagsHiPass;
   Self.FlagsHiFail:=flagsHiFail;
   Self.FlagsLo:=flagsLo;
end;

// DoCompileBoolean
//
procedure Tx86RelOpInt.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
var
   e : TIntegerRelOpExpr;
   addr : Integer;
begin
   e:=TIntegerRelOpExpr(expr);

   if e.Right is TConstIntExpr then begin

      if e.Left is TIntVarExpr then begin

         addr:=TIntVarExpr(e.Left).StackAddr;

         x86._cmp_execmem_int32(addr, 4, TConstIntExpr(e.Right).Value shr 32);
         if FlagsHiPass<>flagsNone then
            jit.Fixups.NewJump(FlagsHiPass, targetTrue);
         if FlagsHiFail<>flagsNone then
            jit.Fixups.NewJump(FlagsHiFail, targetFalse);
         x86._cmp_execmem_int32(addr, 0, TConstIntExpr(e.Right).Value);
         jit.Fixups.NewConditionalJumps(FlagsLo, targetTrue, targetFalse);

      end else begin

         jit.CompileInteger(e.Left);

         x86._cmp_reg_int32(gprEDX, TConstIntExpr(e.Right).Value shr 32);
         if FlagsHiPass<>flagsNone then
            jit.Fixups.NewJump(FlagsHiPass, targetTrue);
         if FlagsHiFail<>flagsNone then
            jit.Fixups.NewJump(FlagsHiFail, targetFalse);
         x86._cmp_reg_int32(gprEAX, TConstIntExpr(e.Right).Value);
         jit.Fixups.NewConditionalJumps(FlagsLo, targetTrue, targetFalse);

      end;

   end else if e.Right is TIntVarExpr then begin

      jit.CompileInteger(e.Left);

      addr:=TIntVarExpr(e.Right).StackAddr;

      x86._cmp_reg_execmem(gprEDX, addr, 4);
      if FlagsHiPass<>flagsNone then
         jit.Fixups.NewJump(FlagsHiPass, targetTrue);
      if FlagsHiFail<>flagsNone then
         jit.Fixups.NewJump(FlagsHiFail, targetFalse);
      x86._cmp_reg_execmem(gprEAX, addr, 0);
      jit.Fixups.NewConditionalJumps(FlagsLo, targetTrue, targetFalse);

   end else begin

      jit.CompileInteger(e.Right);

      addr:=jit.FPreamble.AllocateStackSpace(SizeOf(Int64));

      x86._mov_qword_ptr_reg_eaxedx(gprEBP, addr);

      jit.CompileInteger(e.Left);

      x86._cmp_reg_dword_ptr_reg(gprEDX, gprEBP, addr+4);
      if FlagsHiPass<>flagsNone then
         jit.Fixups.NewJump(FlagsHiPass, targetTrue);
      if FlagsHiFail<>flagsNone then
         jit.Fixups.NewJump(FlagsHiFail, targetFalse);
      x86._cmp_reg_dword_ptr_reg(gprEAX, gprEBP, addr);
      jit.Fixups.NewConditionalJumps(FlagsLo, targetTrue, targetFalse);

   end;
end;

// ------------------
// ------------------ Tx86RelIntIsZero ------------------
// ------------------

// DoCompileBoolean
//
procedure Tx86RelIntIsZero.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
var
   e : TUnaryOpBoolExpr;
   addr : Integer;
begin
   e:=TUnaryOpBoolExpr(expr);

   if e.Expr is TIntVarExpr then begin

      addr:=TIntVarExpr(e.Expr).StackAddr;

      x86._cmp_execmem_int32(addr, 0, 0);
      jit.Fixups.NewJump(flagsNZ, targetFalse);
      x86._cmp_execmem_int32(addr, 4, 0);
      jit.Fixups.NewConditionalJumps(flagsZ, targetTrue, targetFalse);

   end else begin

      jit.CompileInteger(e.Expr);

      x86._cmp_reg_int32(gprEAX, 0);
      jit.Fixups.NewJump(flagsNZ, targetFalse);
      x86._cmp_reg_int32(gprEDX, 0);
      jit.Fixups.NewConditionalJumps(flagsZ, targetTrue, targetFalse);

   end;
end;

// ------------------
// ------------------ Tx86RelIntIsNotZero ------------------
// ------------------

// DoCompileBoolean
//
procedure Tx86RelIntIsNotZero.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
begin
   inherited DoCompileBoolean(expr, targetFalse, targetTrue);
end;

// ------------------
// ------------------ Tx86RelOpFloat ------------------
// ------------------

// Create
//
constructor Tx86RelOpFloat.Create(jit : TdwsJITx86; flags : TboolFlags);
begin
   inherited Create(jit);
   Self.Flags:=flags;
end;

// DoCompileBoolean
//
procedure Tx86RelOpFloat.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
var
   e : TRelGreaterFloatExpr;
   regLeft : TxmmRegister;
begin
   e:=TRelGreaterFloatExpr(expr);

   regLeft:=jit.CompileFloat(e.Left);

   jit._comisd_reg_expr(regLeft, e.Right);

   jit.Fixups.NewConditionalJumps(Flags, targetTrue, targetFalse);
end;

// ------------------
// ------------------ Tx86NotExpr ------------------
// ------------------

// DoCompileBoolean
//
procedure Tx86NotExpr.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
var
   e : TNotBoolExpr;
begin
   e:=TNotBoolExpr(expr);

   jit.CompileBoolean(e.Expr, targetFalse, targetTrue);
end;

// ------------------
// ------------------ Tx86BoolOrExpr ------------------
// ------------------

// DoCompileBoolean
//
procedure Tx86BoolOrExpr.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
var
   e : TBooleanBinOpExpr;
   targetFirstFalse : TFixupTarget;
begin
   e:=TBooleanBinOpExpr(expr);

   targetFirstFalse:=jit.Fixups.NewHangingTarget;
   jit.CompileBoolean(e.Left, targetTrue, targetFirstFalse);
   jit.Fixups.AddFixup(targetFirstFalse);
   jit.CompileBoolean(e.Right, targetTrue, targetFalse);
end;

// ------------------
// ------------------ Tx86BoolAndExpr ------------------
// ------------------

// JumpSafeCompile
//
procedure Tx86BoolAndExpr.DoCompileBoolean(expr : TExprBase; targetTrue, targetFalse : TFixup);
var
   e : TBooleanBinOpExpr;
   targetFirstTrue : TFixupTarget;
begin
   e:=TBooleanBinOpExpr(expr);

   targetFirstTrue:=jit.Fixups.NewHangingTarget;
   jit.CompileBoolean(e.Left, targetFirstTrue, targetFalse);
   jit.Fixups.AddFixup(targetFirstTrue);
   jit.CompileBoolean(e.Right, targetTrue, targetFalse);
end;

// ------------------
// ------------------ Tx86ConvFloat ------------------
// ------------------

// DoCompileFloat
//
function Tx86ConvFloat.DoCompileFloat(expr : TExprBase) : TxmmRegister;
begin
   jit.CompileInteger(TConvFloatExpr(expr).Expr);

   jit.FPreamble.NeedTempSpace(SizeOf(Double));

   x86._mov_dword_ptr_reg_reg(gprESP, 0, gprEAX);
   x86._mov_dword_ptr_reg_reg(gprESP, 4, gprEDX);
   x86._fild_esp;
   x86._fstp_esp;
   Result:=jit.AllocXMMReg(expr);
   x86._movsd_reg_esp(Result);
end;

// ------------------
// ------------------ Tx86MagicFunc ------------------
// ------------------

// DoCompileFloat
//
function Tx86MagicFunc.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   jitter : TdwsJITter_x86;
   e : TMagicFloatFuncExpr;
begin
   e:=(expr as TMagicFloatFuncExpr);

   jitter:=TdwsJITter_x86(jit.FindJITter(TMagicFuncSymbol(e.FuncSym).InternalFunction.ClassType));
   if jitter<>nil then

      Result:=jitter.DoCompileFloat(expr)

   else Result:=inherited;
end;

// CompileInteger
//
function Tx86MagicFunc.CompileInteger(expr : TExprBase) : Integer;
var
   jitter : TdwsJITter_x86;
   e : TMagicIntFuncExpr;
begin
   e:=(expr as TMagicIntFuncExpr);

   jitter:=TdwsJITter_x86(jit.FindJITter(TMagicFuncSymbol(e.FuncSym).InternalFunction.ClassType));
   if jitter<>nil then

      Result:=jitter.CompileInteger(expr)

   else Result:=inherited;
end;

// ------------------
// ------------------ Tx86DirectCallFunc ------------------
// ------------------

// Create
//
constructor Tx86DirectCallFunc.Create(jit : TdwsJITx86; addrPtr : PPointer);
begin
   inherited Create(jit);
   Self.AddrPtr:=addrPtr;
end;

// DoCompileFloat
//
function Tx86DirectCallFunc.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   i, stackOffset : Integer;
   e : TMagicFuncExpr;
   f : TFuncSymbol;
   p : TParamSymbol;
   paramReg : array of TxmmRegister;
   paramOffset : array of Integer;
begin
   e:=TMagicFuncExpr(expr);
   f:=e.FuncSym;

   SetLength(paramReg, f.Params.Count);
   SetLength(paramOffset, f.Params.Count);

   stackOffset:=0;
   for i:=0 to f.Params.Count-1 do begin
      p:=f.Params[i];
      if jit.IsFloat(p.Typ) then begin

         paramReg[i]:=jit.CompileFloat(e.Args[i] as TTypedExpr);
         Inc(stackOffset, SizeOf(Double));
         paramOffset[i]:=stackOffset;

      end else Exit(inherited);
   end;

   x86._sub_reg_int32(gprESP, stackOffset);

   for i:=0 to High(paramReg) do begin
      if paramReg[i]<>xmmNone then
         x86._movsd_esp_reg(stackOffset-paramOffset[i], paramReg[i]);
   end;

   jit.ResetXMMReg;

   x86._call_absmem(addrPtr);

   if jit.IsFloat(f.Typ) then begin

      jit.FPreamble.NeedTempSpace(SizeOf(Double));
      x86._fstp_esp;
      Result:=jit.AllocXMMReg(expr);
      x86._movsd_reg_esp(Result);

   end else Exit(inherited);
end;

// ------------------
// ------------------ Tx86SqrtFunc ------------------
// ------------------

// DoCompileFloat
//
function Tx86SqrtFunc.DoCompileFloat(expr : TExprBase) : TxmmRegister;
begin
   Result:=jit.AllocXMMReg(expr);

   jit._xmm_reg_expr(xmm_sqrtsd, Result, TMagicFuncExpr(expr).Args[0] as TTypedExpr);
end;

// ------------------
// ------------------ Tx86MinMaxFloatFunc ------------------
// ------------------

// Create
//
constructor Tx86MinMaxFloatFunc.Create(jit : TdwsJITx86; op : TxmmOp);
begin
   inherited Create(jit);
   Self.OP:=op;
end;

// DoCompileFloat
//
function Tx86MinMaxFloatFunc.DoCompileFloat(expr : TExprBase) : TxmmRegister;
var
   e : TMagicFuncExpr;
begin
   e:=TMagicFuncExpr(expr);

   Result:=jit.CompileFloat(e.Args[0] as TTypedExpr);

   jit._xmm_reg_expr(OP, Result, e.Args[1] as TTypedExpr);

   jit.ContainsXMMReg(Result, expr);
end;

// ------------------
// ------------------ Tx86RoundFunc ------------------
// ------------------

// CompileInteger
//
function Tx86RoundFunc.CompileInteger(expr : TExprBase) : Integer;
var
   reg : TxmmRegister;
begin
   reg:=jit.CompileFloat(TMagicFuncExpr(expr).Args[0] as TTypedExpr);

   jit.FPreamble.NeedTempSpace(SizeOf(Double));

   x86._movsd_esp_reg(reg);

   jit.ReleaseXMMReg(reg);

   x86._fld_esp;
   x86._fistp_esp;

   x86._mov_eaxedx_qword_ptr_reg(gprESP, 0);

   Result:=0;
end;

end.
