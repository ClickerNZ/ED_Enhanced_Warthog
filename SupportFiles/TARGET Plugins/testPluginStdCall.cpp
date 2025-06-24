// testPluginStdCall.cpp
// ---------------------
// A “stdcall”‐based smoke‐test for TARGET. Exports exactly “targetPluginMap” (no decoration).
// When TARGET invokes targetPluginMap, it will emit an OutputDebugStringA, so you can
// verify in DebugView if the function ever ran. No additional .lib is needed (kernel32 is
// linked by default).

#include <windows.h>

// We force __stdcall here because some TARGET versions expect a stdcall Map.
// Regardless, the /EXPORT:targetPluginMap will ensure the export name is exactly “targetPluginMap”.

// The following Map does nothing except send a debug string. If you never see this debug string,
// then TARGET is not finding/calling your Map at all (export/signature issue).
extern "C" __declspec(dllexport)
void __stdcall targetPluginMap(void* /*tableAddress*/)
{
    OutputDebugStringA(">>> targetPluginMap() was called <<<\n");
}
