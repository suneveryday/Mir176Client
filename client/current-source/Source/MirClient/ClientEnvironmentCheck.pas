unit ClientEnvironmentCheck;

interface

uses Windows;

type
  TClientDebuggerState = (cdsUnavailable, cdsClear, cdsAttached);
  TClientDebuggerQuery = function(Process: THandle;
    var DebuggerPresent: BOOL): BOOL; stdcall;

function EvaluateClientDebuggerCheck(Query: TClientDebuggerQuery;
  Process: THandle): TClientDebuggerState;
function QueryClientDebuggerState: TClientDebuggerState;

implementation

function EvaluateClientDebuggerCheck(Query: TClientDebuggerQuery;
  Process: THandle): TClientDebuggerState;
var
  DebuggerPresent: BOOL;
begin
  Result := cdsUnavailable;
  if not Assigned(Query) then Exit;
  DebuggerPresent := False;
  // The output is meaningful only when the documented API succeeds.
  if not Query(Process, DebuggerPresent) then Exit;
  if DebuggerPresent then Result := cdsAttached
  else Result := cdsClear;
end;

function QueryClientDebuggerState: TClientDebuggerState;
var
  Module: HMODULE;
  Query: TClientDebuggerQuery;
begin
  Result := cdsUnavailable;
  Module := GetModuleHandle('kernel32.dll');
  if Module = 0 then Exit;
  Query := TClientDebuggerQuery(GetProcAddress(Module, 'CheckRemoteDebuggerPresent'));
  Result := EvaluateClientDebuggerCheck(Query, GetCurrentProcess);
end;

end.
