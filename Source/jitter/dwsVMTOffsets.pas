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
unit dwsVMTOffsets;

interface

uses
   dwsExprs, dwsDataContext, dwsSymbols;

var
   vmt_Prepared : Boolean;

   vmt_IDataContext_GetSelf : Integer;
   vmt_IDataContext_AsPVariant : Integer;
   vmt_IDataContext_AsPData : Integer;
   vmt_IDataContext_FData : Integer;
   vmt_IScriptObj_ExternalObject : Integer;
   vmt_TExprBase_EvalNoResult : Integer;
   vmt_TExprBase_EvalAsInteger : Integer;
   vmt_TExprBase_EvalAsFloat : Integer;
   vmt_TExprBase_EvalAsBoolean : Integer;
   vmt_TExprBase_EvalAsString: Integer;
   vmt_TExprBase_EvalAsScriptObj: Integer;
   vmt_TExprBase_EvalAsVariant: Integer;
   vmt_TExprBase_EvalAsDataContext: Integer;
   vmt_TExprBase_AssignValueAsFloat : Integer;
   vmt_TExprBase_AssignValueAsInteger : Integer;

   vmt_ScriptDynamicArray_IScriptObj_To_FData : Integer;
   vmt_ScriptObjInstance_IScriptObj_To_FData : Integer;

   func_ustr_clear: pointer;
   func_handle_finally: pointer;
   func_intf_clear: pointer;
   func_var_clr: pointer;
   func_dyn_array_clear: pointer;
   func_var_from_int: pointer;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

uses Variants;

// PrepareVMTOffsets
//
procedure PrepareVMTOffsets;
asm
   mov vmt_Prepared, True
   mov vmt_IDataContext_GetSelf, VMTOFFSET IDataContext.GetSelf
   mov vmt_IDataContext_AsPData, VMTOFFSET IDataContext.AsPData
   mov vmt_IDataContext_AsPVariant, VMTOFFSET IDataContext.AsPVariant
   mov vmt_IScriptObj_ExternalObject, VMTOFFSET IScriptObj.GetExternalObject
   mov vmt_TExprBase_EvalNoResult, VMTOFFSET TExprBase.EvalNoResult
   mov vmt_TExprBase_EvalAsInteger, VMTOFFSET TExprBase.EvalAsInteger
   mov vmt_TExprBase_EvalAsFloat, VMTOFFSET TExprBase.EvalAsFloat
   mov vmt_TExprBase_EvalAsBoolean, VMTOFFSET TExprBase.EvalAsBoolean
   mov vmt_TExprBase_EvalAsString, VMTOFFSET TExprBase.EvalAsString
   mov vmt_TExprBase_EvalAsScriptObj, VMTOFFSET TExprBase.EvalAsScriptObj
   mov vmt_TExprBase_EvalAsVariant, VMTOFFSET TExprBase.EvalAsVariant
   mov vmt_TExprBase_EvalAsDataContext,  VMTOFFSET TExprBase.EvalAsDataContext
   mov vmt_TExprBase_AssignValueAsFloat, VMTOFFSET TExprBase.AssignValueAsFloat
   mov vmt_TExprBase_AssignValueAsInteger, VMTOFFSET TExprBase.AssignValueAsInteger
   mov func_ustr_clear, offset System.@UStrClr
   mov func_intf_clear, offset System.@IntfClear
   mov func_var_clr, offset variants.@VarClr
   mov func_dyn_array_clear, offset system.@DynArrayClear
   mov func_handle_finally, offset System.@HandleFinally
   mov func_var_from_int, offset Variants.@VarFromInt
end;

procedure PrepareDynArrayIDataContextToFDataOffset;
var
   sda : TScriptDynamicArray;
   soi : TScriptObjInstance;
   i : IScriptObj;
begin
   sda:=TScriptDynamicArray.CreateNew(nil);
   i:=IScriptObj(sda);

   vmt_ScriptDynamicArray_IScriptObj_To_FData:=NativeInt(i.AsPData)-NativeInt(i);

   soi:=TScriptObjInstance.Create(nil);
   i:=IScriptObj(soi);

   vmt_ScriptObjInstance_IScriptObj_To_FData:=NativeInt(i.AsPData)-NativeInt(i);
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   PrepareVMTOffsets;
   PrepareDynArrayIDataContextToFDataOffset;

end.
