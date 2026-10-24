# Windows client environment regression

Open `EnvironmentRegression.dpr` with the licensed Delphi Win32 IDE, build it, then run the resulting console executable **without a debugger**. It uses the production `ClientEnvironmentCheck` unit. No resources, account, game server or gameplay are needed.

Alternatively run `run-windows.ps1 -Ide <licensed-IDE> -OutputDirectory <fresh-output-directory>` from the signed-in Windows session. It uses documented IDE AutoBuild, requires a newly produced executable, then launches it directly. Compiler output stays in that local output directory.

The cases cover a missing API, initialized output, a successful clear result, a successful attached result, a failed call that writes an attached result, a failed call that leaves output untouched, the forwarded process handle and the actual Windows API without a debugger. A failed or unavailable query must remain distinct from a confirmed attachment.

The game timer only stops on `cdsAttached`, disables itself before displaying a specific debugger message, and does not infer cheating from Explorer window controls or DLL entry bytes. Packet, timing and server validation remain separate. Full game acceptance is still pending.
