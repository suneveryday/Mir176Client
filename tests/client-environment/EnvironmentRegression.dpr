program EnvironmentRegression;

{$APPTYPE CONSOLE}

uses
  Windows, SysUtils,
  ClientEnvironmentCheck in '../../client/current-source/Source/MirClient/ClientEnvironmentCheck.pas';

var
  Checks, Calls: Integer;
  ExpectedProcess: THandle;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
  Inc(Checks);
end;

function ClearQuery(Process: THandle; var Present: BOOL): BOOL; stdcall;
begin
  Inc(Calls);
  Check(Process = ExpectedProcess, 'current process handle forwarded');
  Check(not Present, 'output initialized before API call');
  Present := False;
  Result := True;
end;

function AttachedQuery(Process: THandle; var Present: BOOL): BOOL; stdcall;
begin
  Inc(Calls);
  Present := True;
  Result := True;
end;

function FailedQuery(Process: THandle; var Present: BOOL): BOOL; stdcall;
begin
  Inc(Calls);
  // Even an output indicating attachment cannot be trusted after failure.
  Present := True;
  Result := False;
end;

function FailedUntouchedQuery(Process: THandle; var Present: BOOL): BOOL; stdcall;
begin
  Inc(Calls);
  Check(not Present, 'failed query starts with an initialized output');
  Result := False;
end;

begin
  ExpectedProcess := GetCurrentProcess;
  Check(EvaluateClientDebuggerCheck(nil, ExpectedProcess) = cdsUnavailable,
    'missing API is unavailable');
  Check(Calls = 0, 'missing API is never called');
  Check(EvaluateClientDebuggerCheck(ClearQuery, ExpectedProcess) = cdsClear,
    'successful clear query');
  Check(EvaluateClientDebuggerCheck(AttachedQuery, ExpectedProcess) = cdsAttached,
    'successful attached query still detected');
  Check(EvaluateClientDebuggerCheck(FailedQuery, ExpectedProcess) = cdsUnavailable,
    'API failure cannot report attachment');
  Check(EvaluateClientDebuggerCheck(FailedUntouchedQuery, ExpectedProcess) = cdsUnavailable,
    'API failure with untouched output');
  Check(Calls = 4, 'exactly one call per available query');
  // This offline test is launched directly, with no debugger or game connection.
  Check(QueryClientDebuggerState = cdsClear, 'real Windows API without a debugger');
  Writeln('PASS ', Checks, ' client environment checks; no game connection');
end.
