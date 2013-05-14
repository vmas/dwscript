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
unit dwsTimeFunctions;

{$I dws.inc}

interface

uses
   Classes, SysUtils,
   dwsUtils, dwsStrings, dwsXPlatform,
   dwsFunctions, dwsExprs, dwsSymbols, dwsExprList, dwsMagicExprs;

type

  TNowFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TDateFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TTimeFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TUTCDateTimeFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TDateTimeToStrFunc = class(TInternalMagicStringFunction)
    procedure DoEvalAsString(args : TExprBaseList; var Result : UnicodeString); override;
  end;

  TStrToDateTimeFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TStrToDateTimeDefFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TDateToStrFunc = class(TInternalMagicStringFunction)
    procedure DoEvalAsString(args : TExprBaseList; var Result : UnicodeString); override;
  end;

  TStrToDateFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TStrToDateDefFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TTimeToStrFunc = class(TInternalMagicStringFunction)
    procedure DoEvalAsString(args : TExprBaseList; var Result : UnicodeString); override;
  end;

  TStrToTimeFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TStrToTimeDefFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TDateToISO8601Func = class(TInternalMagicStringFunction)
    procedure DoEvalAsString(args : TExprBaseList; var Result : UnicodeString); override;
  end;

  TDateTimeToISO8601Func = class(TInternalMagicStringFunction)
    procedure DoEvalAsString(args : TExprBaseList; var Result : UnicodeString); override;
  end;

  TDayOfWeekFunc = class(TInternalMagicIntFunction)
    function DoEvalAsInteger(args : TExprBaseList) : Int64; override;
  end;

  TDayOfTheWeekFunc = class(TInternalMagicIntFunction)
    function DoEvalAsInteger(args : TExprBaseList) : Int64; override;
  end;

  TFormatDateTimeFunc = class(TInternalMagicStringFunction)
    procedure DoEvalAsString(args : TExprBaseList; var Result : UnicodeString); override;
  end;

  TIsLeapYearFunc = class(TInternalMagicBoolFunction)
    function DoEvalAsBoolean(args : TExprBaseList) : Boolean; override;
  end;

  TIncMonthFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TDecodeDateFunc = class(TInternalMagicProcedure)
    procedure DoEvalProc(args : TExprBaseList); override;
  end;

  TEncodeDateFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TDecodeTimeFunc = class(TInternalMagicProcedure)
    procedure DoEvalProc(args : TExprBaseList); override;
  end;

  TEncodeTimeFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TFirstDayOfYearFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TFirstDayOfNextYearFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TFirstDayOfMonthFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TFirstDayOfNextMonthFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TFirstDayOfWeekFunc = class(TInternalMagicFloatFunction)
    procedure DoEvalAsFloat(args : TExprBaseList; var Result : Double); override;
  end;

  TDayOfYearFunc = class(TInternalMagicIntFunction)
    function DoEvalAsInteger(args : TExprBaseList) : Int64; override;
  end;

  TMonthOfYearFunc = class(TInternalMagicIntFunction)
    function DoEvalAsInteger(args : TExprBaseList) : Int64; override;
  end;

  TDayOfMonthFunc = class(TInternalMagicIntFunction)
    function DoEvalAsInteger(args : TExprBaseList) : Int64; override;
  end;

  TWeekNumberFunc = class(TInternalMagicIntFunction)
    function DoEvalAsInteger(args : TExprBaseList) : Int64; override;
  end;

  TYearOfWeekFunc = class(TInternalMagicIntFunction)
    function DoEvalAsInteger(args : TExprBaseList) : Int64; override;
  end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

const
  cDateTime = SYS_FLOAT;

{ TNowFunc }

procedure TNowFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=Now;
end;

{ TDateFunc }

procedure TDateFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=Date;
end;

{ TTimeFunc }

procedure TTimeFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=Time;
end;

{ TUTCDateTimeFunc }

procedure TUTCDateTimeFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=UTCDateTime;
end;

{ TDateTimeToStrFunc }

// DoEvalAsString
//
procedure TDateTimeToStrFunc.DoEvalAsString(args : TExprBaseList; var Result : UnicodeString);
begin
   Result:=DateTimeToStr(args.AsFloat[0]);
end;

{ TStrToDateTimeFunc }

procedure TStrToDateTimeFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=StrToDateTime(args.AsString[0]);
end;

{ TStrToDateTimeDefFunc }

procedure TStrToDateTimeDefFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=StrToDateTimeDef(args.AsString[0], args.AsFloat[1]);
end;

{ TDateToStrFunc }

// DoEvalAsString
//
procedure TDateToStrFunc.DoEvalAsString(args : TExprBaseList; var Result : UnicodeString);
begin
   Result:=DateToStr(args.AsFloat[0]);
end;

{ TStrToDateFunc }

procedure TStrToDateFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=StrToDate(args.AsString[0]);
end;

{ TStrToDateDefFunc }

procedure TStrToDateDefFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=StrToDateDef(args.AsString[0], args.AsFloat[1]);
end;

{ TTimeToStrFunc }

// DoEvalAsString
//
procedure TTimeToStrFunc.DoEvalAsString(args : TExprBaseList; var Result : UnicodeString);
begin
   Result:=TimeToStr(args.AsFloat[0]);
end;

{ TStrToTimeFunc }

procedure TStrToTimeFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=StrToTime(args.AsString[0]);
end;

{ TStrToTimeDefFunc }

procedure TStrToTimeDefFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=StrToTimeDef(args.AsString[0], args.AsFloat[1]);
end;

{ TDateToISO8601Func }

procedure TDateToISO8601Func.DoEvalAsString(args : TExprBaseList; var Result : UnicodeString);
begin
   Result:=FormatDateTime('yyyy-mm-dd', args.AsFloat[0]);
end;

{ TDateTimeToISO8601Func }

procedure TDateTimeToISO8601Func.DoEvalAsString(args : TExprBaseList; var Result : UnicodeString);
var
   dt : TDateTime;
begin
   dt:=args.AsFloat[0];
   Result:=FormatDateTime('yyyy-mm-dd', dt)+'T'+FormatDateTime('hh:nn', dt)+'Z';
end;

{ TDayOfWeekFunc }

function TDayOfWeekFunc.DoEvalAsInteger(args : TExprBaseList) : Int64;
begin
   Result:=DayOfWeek(args.AsFloat[0]);
end;

{ TDayOfTheWeekFunc }

function TDayOfTheWeekFunc.DoEvalAsInteger(args : TExprBaseList) : Int64;
begin
   Result:=(DayOfWeek(args.AsFloat[0])+5) mod 7 +1;
end;

{ TFormatDateTimeFunc }

// DoEvalAsString
//
procedure TFormatDateTimeFunc.DoEvalAsString(args : TExprBaseList; var Result : UnicodeString);
begin
   Result:=FormatDateTime(args.AsString[0], args.AsFloat[1]);
end;

{ TIsLeapYearFunc }

function TIsLeapYearFunc.DoEvalAsBoolean(args : TExprBaseList) : Boolean;
begin
   Result:=IsLeapYear(args.AsInteger[0]);
end;

{ TIncMonthFunc }

procedure TIncMonthFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=IncMonth(args.AsFloat[0], args.AsInteger[1]);
end;

{ TDecodeDateFunc }

// DoEvalProc
//
procedure TDecodeDateFunc.DoEvalProc(args : TExprBaseList);
var
  y, m, d: word;
begin
  DecodeDate(args.AsFloat[0], y, m, d);
  args.AsInteger[1] := y;
  args.AsInteger[2] := m;
  args.AsInteger[3] := d;
end;

{ TEncodeDateFunc }

procedure TEncodeDateFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=EncodeDate(args.AsInteger[0], args.AsInteger[1], args.AsInteger[2]);
end;

{ TDecodeTimeFunc }

// DoEvalProc
//
procedure TDecodeTimeFunc.DoEvalProc(args : TExprBaseList);
var
   h, m, s, ms: word;
begin
   DecodeTime(args.AsFloat[0], h, m, s, ms);
   args.AsInteger[1]:=h;
   args.AsInteger[2]:=m;;
   args.AsInteger[3]:=s;
   args.AsInteger[4]:=ms;
end;

{ TEncodeTimeFunc }

procedure TEncodeTimeFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
begin
   Result:=EncodeTime(args.AsInteger[0], args.AsInteger[1], args.AsInteger[2], args.AsInteger[3]);
end;

{ TFirstDayOfYearFunc }

procedure TFirstDayOfYearFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
var
   dt : TDateTime;
   y, m, d : Word;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   DecodeDate(dt, y, m, d);
   Result:=EncodeDate(y, 1, 1);
end;

{ TFirstDayOfNextYearFunc }

procedure TFirstDayOfNextYearFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
var
   dt : TDateTime;
   y, m, d : Word;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   DecodeDate(dt, y, m, d);
   Result:=EncodeDate(y+1, 1, 1);
end;

{ TFirstDayOfMonthFunc }

procedure TFirstDayOfMonthFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
var
   dt : TDateTime;
   y, m, d : Word;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   DecodeDate(dt, y, m, d);
   Result:=EncodeDate(y, m, 1);
end;

{ TFirstDayOfNextMonthFunc }

procedure TFirstDayOfNextMonthFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
var
   dt : TDateTime;
   y, m, d : Word;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   DecodeDate(dt, y, m, d);
   if m=12 then begin
      Inc(y);
      m:=1;
   end else Inc(m);
   Result:=EncodeDate(y, m, 1);
end;

{ TFirstDayOfWeekFunc }

procedure TFirstDayOfWeekFunc.DoEvalAsFloat(args : TExprBaseList; var Result : Double);
const
   cDayOfWeekConverter : array [1..7] of Byte = (6, 0, 1, 2, 3, 4, 5);
var
   dt : TDateTime;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   Result:=Trunc(dt)-cDayOfWeekConverter[DayOfWeek(dt)];
end;

{ TDayOfYearFunc }

function TDayOfYearFunc.DoEvalAsInteger(args : TExprBaseList) : Int64;
var
   dt : TDateTime;
   y, m, d : Word;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   DecodeDate(dt, y, m, d);
   Result:=Trunc(dt-EncodeDate(y, 1, 1))+1;
end;

{ TMonthOfYearFunc }

function TMonthOfYearFunc.DoEvalAsInteger(args : TExprBaseList) : Int64;
var
   dt : TDateTime;
   y, m, d : Word;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   DecodeDate(dt, y, m, d);
   Result:=m;
end;

{ TDayOfMonthFunc }

function TDayOfMonthFunc.DoEvalAsInteger(args : TExprBaseList) : Int64;
var
   dt : TDateTime;
   y, m, d : Word;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   DecodeDate(dt, y, m, d);
   Result:=d;
end;

{ TWeekNumberFunc }

// DateToWeekNumber
//
function DateToWeekNumber(aDate : TDateTime) : Integer;
var
   weekDay : Integer;
   month, day : Word;
   yearOfWeek : Word;
const
   // Weekday to start the week
   //   1 : Sunday
   //   2 : Monday (according to ISO 8601)
   cISOFirstWeekDay = 2;

   // minmimum number of days of the year in the first week of the year week
   //   1 : week one starts at 1/1
   //   4 : first week has at least four days (according to ISO 8601)
   //   7 : first full week
   cISOFirstWeekMinDays=4;
begin
   weekDay:=((DayOfWeek(aDate)-cISOFirstWeekDay+7) mod 7)+1;
   aDate:=aDate-weekDay+8-cISOFirstWeekMinDays;
   DecodeDate(aDate, YearOfWeek, month, day);
   Result:=(Trunc(aDate-EncodeDate(yearOfWeek, 1, 1)) div 7)+1;
end;

function TWeekNumberFunc.DoEvalAsInteger(args : TExprBaseList) : Int64;
var
   dt : TDateTime;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   Result:=DateToWeekNumber(dt);
end;

{ TYearOfWeekFunc }

function TYearOfWeekFunc.DoEvalAsInteger(args : TExprBaseList) : Int64;
var
   dt : TDateTime;
   y, m, d : Word;
begin
   dt:=args.AsFloat[0];
   if dt=0 then
      dt:=Now;
   DecodeDate(dt, y, m, d);
   if ((m=1) and (d<4)) then begin
      // days whose week can be on previous year
      if (DateToWeekNumber(dt)=1) then begin
         // first week of the same year as the day
         Result:=y;
      end else begin
         // week 52 or 53 of previous year
         Result:=y-1;
      end;
   end else if ((m=12) and (d>=29)) then begin
      // days whose week can be on the next year
      if (DateToWeekNumber(dt)=1) then begin
         // week one of next year
         Result:=y+1;
      end else begin
         // week 52 or 53 of current year
         Result:=y;
      end;
   end else begin
      // middle of the year, nothing to compute
      Result:=y;
   end;
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

   RegisterInternalFloatFunction(TNowFunc, 'Now', []);
   RegisterInternalFloatFunction(TDateFunc, 'Date', []);
   RegisterInternalFloatFunction(TTimeFunc, 'Time', []);

   RegisterInternalFloatFunction(TUTCDateTimeFunc, 'UTCDateTime', []);

   RegisterInternalStringFunction(TDateTimeToStrFunc, 'DateTimeToStr', ['dt', cDateTime]);
   RegisterInternalFloatFunction(TStrToDateTimeFunc, 'StrToDateTime', ['str', SYS_STRING]);
   RegisterInternalFloatFunction(TStrToDateTimeDefFunc, 'StrToDateTimeDef', ['str', SYS_STRING, 'def', cDateTime]);

   RegisterInternalStringFunction(TDateToStrFunc, 'DateToStr', ['dt', cDateTime]);
   RegisterInternalFloatFunction(TStrToDateFunc, 'StrToDate', ['str', SYS_STRING]);
   RegisterInternalFloatFunction(TStrToDateDefFunc, 'StrToDateDef', ['str', SYS_STRING, 'def', cDateTime]);

   RegisterInternalStringFunction(TDateToISO8601Func, 'DateToISO8601', ['dt', cDateTime]);
   RegisterInternalStringFunction(TDateTimeToISO8601Func, 'DateTimeToISO8601', ['dt', cDateTime]);

   RegisterInternalStringFunction(TTimeToStrFunc, 'TimeToStr', ['dt', cDateTime]);
   RegisterInternalFloatFunction(TStrToTimeFunc, 'StrToTime', ['str', SYS_STRING]);
   RegisterInternalFloatFunction(TStrToTimeDefFunc, 'StrToTimeDef', ['str', SYS_STRING, 'def', cDateTime]);

   RegisterInternalIntFunction(TDayOfWeekFunc, 'DayOfWeek', ['dt', cDateTime]);
   RegisterInternalIntFunction(TDayOfTheWeekFunc, 'DayOfTheWeek', ['dt', cDateTime]);
   RegisterInternalStringFunction(TFormatDateTimeFunc, 'FormatDateTime', ['frm', SYS_STRING, 'dt', cDateTime]);
   RegisterInternalBoolFunction(TIsLeapYearFunc, 'IsLeapYear', ['year', SYS_INTEGER]);
   RegisterInternalFloatFunction(TIncMonthFunc, 'IncMonth', ['dt', cDateTime, 'nb', SYS_INTEGER]);
   RegisterInternalProcedure(TDecodeDateFunc, 'DecodeDate', ['dt', cDateTime, '@y', SYS_INTEGER, '@m', SYS_INTEGER, '@d', SYS_INTEGER]);
   RegisterInternalFloatFunction(TEncodeDateFunc, 'EncodeDate', ['y', SYS_INTEGER, 'm', SYS_INTEGER, 'd', SYS_INTEGER]);
   RegisterInternalProcedure(TDecodeTimeFunc, 'DecodeTime', ['dt', cDateTime, '@h', SYS_INTEGER, '@m', SYS_INTEGER, '@s', SYS_INTEGER, '@ms', SYS_INTEGER]);
   RegisterInternalFloatFunction(TEncodeTimeFunc, 'EncodeTime', ['h', SYS_INTEGER, 'm', SYS_INTEGER, 's', SYS_INTEGER, 'ms', SYS_INTEGER]);

   RegisterInternalFloatFunction(TFirstDayOfYearFunc, 'FirstDayOfYear', ['dt', cDateTime]);
   RegisterInternalFloatFunction(TFirstDayOfNextYearFunc, 'FirstDayOfNextYear', ['dt', cDateTime]);
   RegisterInternalFloatFunction(TFirstDayOfMonthFunc, 'FirstDayOfMonth', ['dt', cDateTime]);
   RegisterInternalFloatFunction(TFirstDayOfNextMonthFunc, 'FirstDayOfNextMonth', ['dt', cDateTime]);
   RegisterInternalFloatFunction(TFirstDayOfWeekFunc, 'FirstDayOfWeek', ['dt', cDateTime]);
   RegisterInternalIntFunction(TDayOfYearFunc, 'DayOfYear', ['dt', cDateTime]);
   RegisterInternalIntFunction(TMonthOfYearFunc, 'MonthOfYear', ['dt', cDateTime]);
   RegisterInternalIntFunction(TDayOfMonthFunc, 'DayOfMonth', ['dt', cDateTime]);

   RegisterInternalIntFunction(TWeekNumberFunc, 'DateToWeekNumber', ['dt', cDateTime]);
   RegisterInternalIntFunction(TWeekNumberFunc, 'WeekNumber', ['dt', cDateTime]);
   RegisterInternalIntFunction(TYearOfWeekFunc, 'DateToYearOfWeek', ['dt', cDateTime]);
   RegisterInternalIntFunction(TYearOfWeekFunc, 'YearOfWeek', ['dt', cDateTime]);

end.
