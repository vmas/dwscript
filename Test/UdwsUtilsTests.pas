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
unit UdwsUtilsTests;

interface

uses Classes, SysUtils, Math, dwsXPlatformTests, dwsUtils;

type

   TdwsUtilsTests = class (TTestCase)
      private
         FTightList : TTightList;

      protected
         procedure TightListOutOfBoundsDelete;
         procedure TightListOutOfBoundsInsert;
         procedure TightListOutOfBoundsMove;

      published

         procedure StackIntegerGenericTest;
         procedure StackLotsOfIntegerGenericTest;
         procedure StackIntegerTest;
         procedure StackLotsOfIntegerTest;
         procedure WriteOnlyBlockStreamTest;
         procedure WOBSBigFirstTest;
         procedure TightListTest;
         procedure LookupTest;
         procedure SortedListExtract;
         procedure SimpleListOfInterfaces;

         procedure UnicodeCompareTextTest;
         procedure FastCompareTextSortedValues;

         procedure FastIntToStrTest;

         procedure VarRecArrayTest;
   end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

// ------------------
// ------------------ TdwsUtilsTests ------------------
// ------------------

// StackIntegerGenericTest
//
procedure TdwsUtilsTests.StackIntegerGenericTest;
var
   stack : TSimpleStack<Integer>;
begin
   stack:=TSimpleStack<Integer>.Create;

   CheckEquals(0, stack.Count);

   stack.Push(123);

   CheckEquals(1, stack.Count);
   CheckEquals(123, stack.Peek);

   stack.Push(456);

   CheckEquals(2, stack.Count);
   CheckEquals(456, stack.Peek);

   CheckEquals(456, stack.Peek);
   stack.Pop;

   CheckEquals(1, stack.Count);

   CheckEquals(123, stack.Peek);
   stack.Pop;

   CheckEquals(0, stack.Count);

   stack.Free;
end;

// StackLotsOfIntegerGenericTest
//
procedure TdwsUtilsTests.StackLotsOfIntegerGenericTest;
var
   i, j : Integer;
   stack : TSimpleStack<Integer>;
begin
   stack:=TSimpleStack<Integer>.Create;
   try
      for i:=1 to 1000 do
         stack.Push(i);

      CheckEquals(1000, stack.Count, 'nb');

      for i:=9 downto 0 do begin
         for j:=100 downto 1 do begin
            CheckEquals(i*100+j, stack.Peek, 'pop');
            stack.Pop;
         end;
         for j:=1 to 100 do
            stack.Push(j);
         for j:=100 downto 1 do begin
            CheckEquals(j, stack.Peek, 'pop bis');
            stack.Pop;
         end;
      end;

      CheckEquals(0, stack.Count, 'final nb');
   finally
      stack.Free;
   end;
end;

// StackIntegerTest
//
procedure TdwsUtilsTests.StackIntegerTest;
var
   stack : TSimpleIntegerStack;
begin
   stack:=TSimpleIntegerStack.Allocate;

   CheckEquals(0, stack.Count);

   stack.Push(123);

   CheckEquals(1, stack.Count);
   CheckEquals(123, stack.Peek);

   stack.Push(456);

   CheckEquals(2, stack.Count);
   CheckEquals(456, stack.Peek);

   CheckEquals(456, stack.Peek);
   stack.Pop;

   CheckEquals(1, stack.Count);

   CheckEquals(123, stack.Peek);
   stack.Pop;

   CheckEquals(0, stack.Count);

   stack.Free;
end;

// StackLotsOfIntegerTest
//
procedure TdwsUtilsTests.StackLotsOfIntegerTest;
var
   i, j : Integer;
   stack : TSimpleIntegerStack;
begin
   stack:=TSimpleIntegerStack.Allocate;
   try
      for i:=1 to 1000 do
         stack.Push(i);

      CheckEquals(1000, stack.Count, 'nb');

      for i:=9 downto 0 do begin
         for j:=100 downto 1 do begin
            CheckEquals(i*100+j, stack.Peek, 'pop');
            stack.Pop;
         end;
         for j:=1 to 100 do
            stack.Push(j);
         for j:=100 downto 1 do begin
            CheckEquals(j, stack.Peek, 'pop bis');
            stack.Pop;
         end;
      end;

      CheckEquals(0, stack.Count, 'final nb');
   finally
      stack.Free;
   end;
end;

// WriteOnlyBufferBlockTest
//
procedure TdwsUtilsTests.WriteOnlyBlockStreamTest;
var
   buffer : TWriteOnlyBlockStream;
   b : Integer;
   bs : AnsiString;
begin
   buffer:=TWriteOnlyBlockStream.Create;

   CheckEquals(0, buffer.Position);

   b:=Ord('1');
   buffer.Write(b, 1);
   CheckEquals(1, buffer.Position);

   bs:='23';
   buffer.Write(bs[1], 2);
   CheckEquals(3, buffer.Position);

   for b:=Ord('4') to Ord('9') do
      buffer.Write(b, 1);
   CheckEquals(9, buffer.Position);

   SetLength(bs, buffer.Size);
   buffer.StoreData(bs[1]);

   buffer.Free;

   CheckEquals(AnsiString('123456789'), bs);
end;

// WOBSBigFirstTest
//
procedure TdwsUtilsTests.WOBSBigFirstTest;
var
   buffer : TWriteOnlyBlockStream;
   i : Integer;
   bw, br : TBytes;
begin
   buffer:=TWriteOnlyBlockStream.Create;

   SetLength(bw, cWriteOnlyBlockStreamBlockSize*2);
   for i:=0 to High(bw) do
      bw[i]:=Byte(i and 255);

   buffer.Write(bw[0], Length(bw));

   CheckEquals(Length(bw), buffer.Size, 'size');

   SetLength(br, buffer.Size);
   buffer.StoreData(br[0]);

   for i:=0 to High(br) do
      if br[i]<>bw[i] then
         CheckEquals(bw[i], br[i], IntToStr(i));

   buffer.Free;
end;

// TightListOutOfBoundsDelete
//
procedure TdwsUtilsTests.TightListOutOfBoundsDelete;
begin
   FTightList.Delete(-1);
end;

// TightListOutOfBoundsInsert
//
procedure TdwsUtilsTests.TightListOutOfBoundsInsert;
begin
   FTightList.Insert(999, nil);
end;

// TightListOutOfBoundsMove
//
procedure TdwsUtilsTests.TightListOutOfBoundsMove;
begin
   FTightList.Insert(1, nil);
end;

// TightListTest
//
procedure TdwsUtilsTests.TightListTest;
var
   s : TRefCountedObject;
begin
   s:=TRefCountedObject.Create;

   CheckEquals(-1, FTightList.IndexOf(nil), 'empty search');

   CheckException(TightListOutOfBoundsDelete, ETightListOutOfBound, 'OutOfBounds Delete');
   CheckException(TightListOutOfBoundsInsert, ETightListOutOfBound, 'OutOfBounds Insert');
   CheckException(TightListOutOfBoundsMove, ETightListOutOfBound, 'OutOfBounds Move');

   FTightList.Add(s);
   CheckEquals(-1, FTightList.IndexOf(nil), 'single search nil');
   CheckEquals(0, FTightList.IndexOf(s), 'single search Self');

   FTightList.Move(0, 0);

   CheckEquals(0, FTightList.IndexOf(s), 'single search Self 2');

   FTightList.Add(nil);
   CheckEquals(1, FTightList.IndexOf(nil), 'two search nil');
   CheckEquals(0, FTightList.IndexOf(s), 'two search Self');
   CheckEquals(-1, FTightList.IndexOf(Pointer(-1)), 'two search -1');

   FTightList.Move(0, 1);

   CheckEquals(0, FTightList.IndexOf(nil), 'two search nil 2');
   CheckEquals(1, FTightList.IndexOf(s), 'two search Self 2');

   FTightList.Move(1, 0);

   CheckEquals(1, FTightList.IndexOf(nil), 'two search nil 3');
   CheckEquals(0, FTightList.IndexOf(s), 'two search Self 3');

   FTightList.Add(nil);
   FTightList.Move(2, 0);

   CheckEquals(0, FTightList.IndexOf(nil), 'three search nil');
   CheckEquals(1, FTightList.IndexOf(s), 'three search Self');

   FTightList.Clear;

   s.Free;
end;

// LookupTest
//
procedure TdwsUtilsTests.LookupTest;
var
   lookup : TObjectsLookup;
   obj : TRefCountedObject;
begin
   lookup:=TObjectsLookup.Create;
   try
      CheckFalse(lookup.IndexOf(nil)>=0, 'empty');
      lookup.Add(nil);
      CheckTrue(lookup.IndexOf(nil)>=0, 'nil');
      obj:=TRefCountedObject.Create;
      CheckFalse(lookup.IndexOf(obj)>=0, 'obj');
      lookup.Add(obj);
      CheckTrue(lookup.IndexOf(nil)>=0, 'nil bis');
      CheckTrue(lookup.IndexOf(obj)>=0, 'obj bis');
      lookup.Clean;
   finally
      lookup.Free;
   end;
end;

// SortedListExtract
//
type
   TTestSortedList = class (TSortedList<TRefCountedObject>)
      function Compare(const item1, item2 : TRefCountedObject) : Integer; override;
   end;
function TTestSortedList.Compare(const item1, item2 : TRefCountedObject) : Integer;
begin
   Result:=NativeInt(item1)-NativeInt(item2);
end;
procedure TdwsUtilsTests.SortedListExtract;
var
   list : TSortedList<TRefCountedObject>;
begin
   list:=TTestSortedList.Create;
   list.Add(nil);
   list.Add(nil);
   CheckEquals(2, list.Count);
   list.ExtractAt(0);
   CheckEquals(1, list.Count);
   list.ExtractAt(0);
   CheckEquals(0, list.Count);
   list.Free;
end;

// SimpleListOfInterfaces
//
procedure TdwsUtilsTests.SimpleListOfInterfaces;
var
   list : TSimpleList<IGetSelf>;
   obj1 : IGetSelf;
begin
   obj1:=TInterfacedSelfObject.Create;

   list:=TSimpleList<IGetSelf>.Create;
   try
      list.Add(nil);
      list.Add(obj1);

      CheckEquals(2, list.Count, 'count');
      CheckEquals(2, (obj1.GetSelf as TRefCountedObject).RefCount, 'ref 1');

      list.Extract(0);
      list.Add(obj1);

      CheckEquals(3, (obj1.GetSelf as TRefCountedObject).RefCount, 'ref 2');

      list.Extract(1);

      CheckEquals(2, (obj1.GetSelf as TRefCountedObject).RefCount, 'ref 3');

      list.Extract(0);

      CheckEquals(1, (obj1.GetSelf as TRefCountedObject).RefCount, 'ref 4');
   finally
      list.Free;
   end;
end;

// UnicodeCompareTextTest
//
procedure TdwsUtilsTests.UnicodeCompareTextTest;
begin
   CheckTrue(UnicodeCompareText('', '')=0, 'both empty');

   CheckTrue(UnicodeCompareText('a', '')>0, 'a, empty');
   CheckTrue(UnicodeCompareText('', 'a')<0, 'empty, a');
   CheckTrue(UnicodeCompareText('�', '')>0, '�, empty');
   CheckTrue(UnicodeCompareText('', '�')<0, 'empty, �');

   CheckTrue(UnicodeCompareText('abc', 'abc')=0, 'abc, abc');
   CheckTrue(UnicodeCompareText('abcd', 'abc')>0, 'abcd, abc');
   CheckTrue(UnicodeCompareText('abc', 'abcd')<0, 'abc, abcd');
   CheckTrue(UnicodeCompareText('abc', 'abd')<0, 'abc, abd');
   CheckTrue(UnicodeCompareText('abd', 'abc')>0, 'abc, abd');

   CheckTrue(UnicodeCompareText('abe', 'ab�')<0, 'abe, ab�');
   CheckTrue(UnicodeCompareText('ab�', 'abe')>0, 'ab�, abe');
   CheckTrue(UnicodeCompareText('ab�a', 'ab�z')<0, 'ab�a, ab�z');
   CheckTrue(UnicodeCompareText('ab�z', 'ab�a')>0, 'ab�z, ab�a');

   CheckTrue(UnicodeCompareText('ab�', 'ab�')=0, 'ab�, ab�');
   CheckTrue(UnicodeCompareText('ab�aa', 'ab�z')<0, 'ab�aa, ab�z');
   CheckTrue(UnicodeCompareText('ab�z', 'ab�aa')>0, 'ab�z, ab�aa');

   CheckTrue(UnicodeCompareText('se', 's�')<0, 'se, s�');
   CheckTrue(UnicodeCompareText('s�', 's�')=0, 's�, s�');
   CheckTrue(UnicodeCompareText('se', 'se')=0, 'se, se');
   CheckTrue(UnicodeCompareText('s�', 'se')>0, 's�, se');

   CheckTrue(UnicodeCompareText('su', 's�')>0, 'su, s�');
   CheckTrue(UnicodeCompareText('su', 'se')>0, 'su, se');
   CheckTrue(UnicodeCompareText('s�', 'su')<0, 's�, su');
   CheckTrue(UnicodeCompareText('se', 'su')<0, 'se, su');
   CheckTrue(UnicodeCompareText('su', 'se')>0, 'su, se');
   CheckTrue(UnicodeCompareText('se', 'su')<0, 'se, su');

   CheckTrue(UnicodeCompareText('sup', 's�')>0, 'su, s�');
   CheckTrue(UnicodeCompareText('sup', 'se')>0, 'su, se');
   CheckTrue(UnicodeCompareText('s�', 'sup')<0, 's�, su');
   CheckTrue(UnicodeCompareText('se', 'sup')<0, 'se, su');
   CheckTrue(UnicodeCompareText('sup', 'se')>0, 'su, se');
   CheckTrue(UnicodeCompareText('se', 'sup')<0, 'se, su');
end;

// FastCompareTextSortedValues
//
procedure TdwsUtilsTests.FastCompareTextSortedValues;
var
   i, k : Integer;
   sl : TStringList;
   fsl : TFastCompareTextList;
begin
   RandSeed:=0;
   sl:=TStringList.Create;
   fsl:=TFastCompareTextList.Create;
   try
      for i:=1 to 50 do begin
         k:=Round(IntPower(10, 3+Random(8)));
         sl.Values[IntToStr(Random(k))]:=IntToStr(Random(10000));
      end;
      fsl.Assign(sl);

      // check unsorted
      for i:=0 to sl.Count-1 do
         CheckEquals(sl.ValueFromIndex[i], fsl.Values[sl.Names[i]], IntToStr(i));
      CheckEquals('', fsl.Values['none'], 'none');

      // check sorted
      fsl.Sorted:=True;
      for i:=0 to sl.Count-1 do
         CheckEquals(sl.ValueFromIndex[i], fsl.Values[sl.Names[i]], IntToStr(i));
      CheckEquals('', fsl.Values['none'], 'none');
   finally
      sl.Free;
      fsl.Free;
   end;
end;

// FastIntToStrTest
//
procedure TdwsUtilsTests.FastIntToStrTest;
var
   i : Integer;
   n : Int64;
   s : String;
begin
   FastInt64ToStr(0, s);
   CheckEquals('0', s);
   FastInt64ToStr(123, s);
   CheckEquals('123', s);
   FastInt64ToStr(123456, s);
   CheckEquals('123456', s);
   FastInt64ToStr(1234567, s);
   CheckEquals('1234567', s);
   FastInt64ToStr(12345678, s);
   CheckEquals('12345678', s);
   FastInt64ToStr(123456789, s);
   CheckEquals('123456789', s);
   FastInt64ToStr(123456789123456789, s);
   CheckEquals('123456789123456789', s);

   n:=1;
   for i:=1 to 20 do begin
      FastInt64ToStr(n, s);
      CheckEquals(IntToStr(n), s);
      n:=n*10;
   end;
   n:=-1;
   for i:=1 to 20 do begin
      FastInt64ToStr(n, s);
      CheckEquals(IntToStr(n), s);
      n:=n*10;
   end;

   FastInt64ToStr(High(Int64), s);
   CheckEquals(IntToStr(High(Int64)), s);
   FastInt64ToStr(Low(Int64), s);
   CheckEquals(IntToStr(Low(Int64)), s);
end;

// VarRecArrayTest
//
procedure TdwsUtilsTests.VarRecArrayTest;
var
   v : TVarRecArrayContainer;
begin
   v:=TVarRecArrayContainer.Create;
   try
      v.Add(True);
      v.Add(False);

      CheckEquals(2, Length(v.VarRecArray));

      CheckEquals(vtBoolean, v.VarRecArray[0].VType, 'type 0');
      CheckEquals(True, v.VarRecArray[0].VBoolean, 'value 0');

      CheckEquals(vtBoolean, v.VarRecArray[1].VType, 'type 1');
      CheckEquals(False, v.VarRecArray[1].VBoolean, 'value 1');
   finally
      v.Free;
   end;
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   RegisterTest('UtilsTests', TdwsUtilsTests);

end.
