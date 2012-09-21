unit UdwsUtilsTests;

interface

uses Classes, SysUtils, dwsXPlatformTests, dwsUtils, dwsJSON;

type

   TdwsUtilsTests = class (TTestCase)
      private
         FTightList : TTightList;

      protected
         procedure TightListOutOfBoundsDelete;
         procedure TightListOutOfBoundsInsert;
         procedure TightListOutOfBoundsMove;

         procedure JSONExtraComma;

      published

         procedure StackIntegerTest;
         procedure WriteOnlyBlockStreamTest;
         procedure WOBSBigFirstTest;
         procedure TightListTest;
         procedure LookupTest;
         procedure SortedListExtract;

         procedure JSONTest;
         procedure ParseJSON;
         procedure AccessJSON;
         procedure JSONUnicodeLiteral;
         procedure JSONCRLF;
         procedure JSONQuote;
         procedure UndefinedJSON;
         procedure JSONEmptyObject;

         procedure UnicodeCompareTextTest;

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

// StackIntegerTest
//
procedure TdwsUtilsTests.StackIntegerTest;
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

// JSONTest
//
procedure TdwsUtilsTests.JSONTest;
var
   json : TdwsJSONObject;
begin
   json:=TdwsJSONObject.Create;

   CheckEquals('{}', json.ToString);
   CheckEquals('{ }', json.ToBeautifiedString(0, 3));

   json.AddValue('hello').AsString:='world';

   CheckEquals('{"hello":"world"}', json.ToString);
   CheckEquals('{'#13#10#9'"hello" : "world"'#13#10'}', json.ToBeautifiedString(0, 1));

   with json.AddArray('items') do begin
      AddValue;
      AddValue.AsNumber:=12.3;
      AddValue.AsBoolean:=True;
      AddValue.AsBoolean:=False;
      AddValue.IsNull:=True;
   end;

   CheckEquals('{"hello":"world","items":[null,12.3,true,false,null]}', json.ToString);
   CheckEquals( '{'#13#10
                  +#9'"hello" : "world",'#13#10
                  +#9'"items" : ['#13#10
                     +#9#9'null,'#13#10
                     +#9#9'12.3,'#13#10
                     +#9#9'true,'#13#10
                     +#9#9'false,'#13#10
                     +#9#9'null'#13#10
                  +#9']'#13#10
               +'}', json.ToBeautifiedString(0, 1));

   json.Free;
end;

// ParseJSON
//
procedure TdwsUtilsTests.ParseJSON;
var
   json : TdwsJSONValue;
   sl : TStringList;
begin
   json:=TdwsJSONValue.ParseString('"hello"');
   CheckEquals(TdwsJSONImmediate.ClassName, json.ClassName, '"hello"');
   CheckEquals('"hello"', json.ToString, '"hello"');
   json.Free;

   json:=TdwsJSONValue.ParseString('{"hello":"world","abc":123}');
   CheckEquals(TdwsJSONObject.ClassName, json.ClassName, '"hello"');
   CheckEquals('{"hello":"world","abc":123}', json.ToString, '"hello"');
   json.Free;

   sl:=TStringList.Create;
   try
      sl.LoadFromFile(ExtractFilePath(ParamStr(0))+'\Data\json.txt');
      json:=TdwsJSONValue.ParseString(sl.Text);
      CheckEquals(TdwsJSONObject.ClassName, json.ClassName, 'json.txt');
      CheckEquals(1, json.ElementCount, 'json.txt');
      CheckEquals(3, json.Elements[0].ElementCount, 'json.txt');
      CheckEquals('"templates"', json[0]['servlet'][0]['init-param']['templatePath'].ToString, 'json.txt');
      CheckEquals('', json['doh'][5]['bug'].ToString, 'json.txt');
      json.Free;
   finally
      sl.Free;
   end;
end;

// AccessJSON
//
procedure TdwsUtilsTests.AccessJSON;
const
   jsonData = '{"Result":[{"Links":[{"UrlTo":"http://atomos.com/ninja/","Anchor":"Manufacturer info",'
             +'"Type":"Text","Flag":[]}],"Index":1,"Rating":2.035556,"Visited":1330236394,"UrlFrom":'
             +'"http://anthonywrites.posterous.com/","IpFrom":"184.106.20.99","Title":"Anthony Agius - Home"},'
             +'{"Links":[{"UrlTo":"http://atomos.com/samurai/","Type":"Redirect","HttpCode":302,"Flag":[]}],'
             +'"Index":2,"Rating":0.941064,"Visited":1329500858,"UrlFrom":"http://theeditman.com/blogg/ct.ashx'
             +'?id=13592790-3605-42fd-9308-73c79199d1eb&url=http%3A%2F%2Fatomos.com%2Fsamurai%2F","IpFrom":'
             +'"64.202.163.118","Title":""},{"Links":[{"UrlTo":"http://atomos.com/ninja/","Anchor":"","Type":'
             +'"Text","Flag":["img"],"Alt":""}],"Index":3,"Rating":0.925152,"Visited":1329902294,"UrlFrom":'
             +'"http://www.lafcpug.org/events/supermeet_sf_2012.html","IpFrom":"64.93.81.159","Title":'
             +'"The Eleventh Annual San Francisco SuperMeet"},{"Links":[{"UrlTo":"http://atomos.com/",'
             +'"Type":"Redirect","HttpCode":302,"Flag":[]}],"Index":4,"Rating":0.915592,"Visited":1330795307,'
             +'"UrlFrom":"http://tienda.vantec.es/redirect.php?action=manufacturer&manufacturers_id=39",'
             +'"IpFrom":"194.79.85.30","Title":""}]}';
var
   json : TdwsJSONValue;
   result : TdwsJSONValue;
begin
   json:=TdwsJSONValue.ParseString(jsonData);
   try
      result:=json.Items['Result'];
      Check(result<>nil, 'Result is present');
      CheckEquals(4, result.ElementCount, '4 Entries');
      CheckEquals('http://theeditman.com/blogg/ct.ashx?id=13592790-3605-42fd-9308-73c79199d1eb&url=http%3A%2F%2Fatomos.com%2Fsamurai%2F',
                  result[1]['UrlFrom'].Value.AsString, 'long url');
   finally
      json.Free;
   end;
end;

// JSONUnicodeLiteral
//
procedure TdwsUtilsTests.JSONUnicodeLiteral;
var
   json : TdwsJSONValue;
begin
   json:=TdwsJSONValue.ParseString('"\u044F\u00aA"');
   CheckEquals(TdwsJSONImmediate.ClassName, json.ClassName, 'TdwsJSONImmediate');
   {$ifdef FPC}
   CheckEquals(UTF8Encode(WideChar($44f)+WideChar($aa)), TdwsJSONImmediate(json).AsString, 'unicode');
   {$else}
   CheckEquals(WideChar($44f)+WideChar($aa), TdwsJSONImmediate(json).AsString, 'unicode');
   {$endif}
   json.Free;

   json:=TdwsJSONObject.Create;
   TdwsJSONObject(json).AddValue('test', #$1234#$ABCD);
   CheckEquals('{"test":"\u1234\uABCD"}', json.ToString, 'encode');
   json.Free;
end;

// JSONCRLF
//
procedure TdwsUtilsTests.JSONCRLF;
var
   json1, json2 : TdwsJSONValue;
begin
   json1:=TdwsJSONValue.ParseString('{"Value": []}');
   json2:=TdwsJSONValue.ParseString( '{'#13#10
                                    +#9'"Value": ['#13#10
                                    +#9']'#13#10
                                    +'}');
   CheckEquals('{"Value":[]}', json1.ToString, 'Roundtrip');
   CheckEquals(json1.ToString, json2.ToString, 'Json1 vs Json2');

   json1.Free;
   json2.Free;
end;

// JSONQuote
//
procedure TdwsUtilsTests.JSONQuote;
var
   json : TdwsJSONValue;
begin
   json:=TdwsJSONValue.ParseString('{"Value":"\""}');
   CheckEquals('"', json['Value'].Value.AsString, 'parse');
   CheckEquals('{"Value":"\""}', json.ToString, 'roundtrip');
   json.Free;
end;

// UndefinedJSON
//
procedure TdwsUtilsTests.UndefinedJSON;
var
   json : TdwsJSONValue;
begin
   json:=TdwsJSONValue.ParseString('{"hello":123}');

   Check(json['hello'].ValueType=jvtNumber, 'check hello value type');
   Check(json['missing'].ValueType=jvtUndefined, 'check missing value type');
   Check(json['missing'][2].ValueType=jvtUndefined, 'check missing[2] value type');

   json.Free;
end;

// JSONExtraComma
//
procedure TdwsUtilsTests.JSONExtraComma;
var
   json : TdwsJSONValue;
begin
   json:=TdwsJSONValue.ParseString('{"a":1,}');
   json.Free;
end;

// JSONEmptyObject
//
procedure TdwsUtilsTests.JSONEmptyObject;
var
   json : TdwsJSONValue;
begin
   json:=TdwsJSONValue.ParseString('{"empty":{}}');

   Check(json['empty'].ValueType=jvtObject, 'check empty value type');
   CheckEquals(0, json['empty'].ElementCount, 'check empty element count');

   json.Free;

   CheckException(JSONExtraComma, EdwsJSONParseError, 'extra comma');
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

   RegisterTest('dwsUtilsTests', TdwsUtilsTests);

end.
