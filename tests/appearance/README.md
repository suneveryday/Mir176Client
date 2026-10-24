# Client appearance regression

`build-regression.py --out <build-directory>/appearance.pas` extracts the current production weapon and clothing routing methods into a Pascal harness. Compile it in Delphi-compatible mode and run it. Texture-recording doubles exercise the actual method bodies without a graphics device, client login or player changes.

The checks cover male/female library boundaries, ordinary standing/walking/running/attack/casting/death frame offsets, extended shapes, combination-action libraries, external-library caching and absent optional libraries. Enabling automatic pickup filtering must leave every appearance route unchanged. An old-source negative control must fail.

Resource acceptance is separate: verify matching WZL/WZX pairs against their original archive CRC and SHA256, decode the required nonempty action frames and test the resulting client on Windows. Routing tests do not prove that a missing library has been installed or that Windows gameplay has passed.
