// testPlugin.cpp
// ---------------
// A “smoke‐test” TARGET plugin that exports exactly one function—
//   void targetPluginMap(void* tableAddress)
// and does nothing else. This will tell us if TARGET can call your Map at all.

#include <windows.h>

// Force the export of exactly “targetPluginMap” (no decoration):
extern "C" __declspec(dllexport)
void targetPluginMap(void* /*tableAddress*/)
{
    // Intentionally empty—just here to test that TARGET can find & call this.
}
