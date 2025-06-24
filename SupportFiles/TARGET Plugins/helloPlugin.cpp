// helloPlugin.cpp
// ----------------
// A minimal “Hello, TARGET” plugin. Exports one function, add(a, b) → int,
// and registers it in targetPluginMap. If TARGET can’t map this, then
// no user DLLs will ever work in your install.

// 1) Pull in Win32 basics:
#include <windows.h>

// 2) The same VAR_/MAP_ codes from sys.tmh:
#define VAR_INT    5     // “int”
#define VAR_ALIAS  6     // “alias” (pointer to char)
#define MAP_NORMAL 1     // cdecl mapping

// 3) A simple function for TARGET scripts to call:
//    int add(alias a, alias b) { return atoi(a) + atoi(b); }
//    We convert the two `alias` (char*) arguments to integers and return their sum.
extern "C" __declspec(dllexport)
int add(const char* a, const char* b)
{
    if (!a || !b) return 0;
    return atoi(a) + atoi(b);
}

// 4) Typedef for TARGET’s registration pointer (cdecl):
typedef void (__cdecl* PF_REGISTER)(
    void*        tableAddress,  // the void* that TARGET passes in
    const char*  funcName,      // script–side name
    int          returnType,    // VAR_INT, VAR_ALIAS, etc.
    int          paramCount,    // number of arguments
    const int*   paramTypes,    // array of VAR_ codes (or nullptr if zero)
    int          mapType,       // MAP_NORMAL (==1) for cdecl
    void*        funcPtr        // pointer to the C/C++ function
);

// 5) The exported Map function. Must be “helloPluginMap” if the DLL is named helloPlugin.dll.
//    We mark this __cdecl because most TARGET installs expect cdecl for “Map”.
//    Inside, we register one function: “add(alias, alias) → int”.
extern "C" __declspec(dllexport)
void __cdecl helloPluginMap(void* tableAddress)
{
    PF_REGISTER RegisterFunction = reinterpret_cast<PF_REGISTER>(tableAddress);
    if (!RegisterFunction) {
        return;  // Shouldn’t happen, but just in case
    }

    // Register “add(alias a, alias b) → int”
    {
        const int params[2] = { VAR_ALIAS, VAR_ALIAS };
        RegisterFunction(
            tableAddress,
            "add",          // the name scripts will use (match in .tmh)
            VAR_INT,        // return type = int
            2,              // two parameters
            params,         // both VAR_ALIAS
            MAP_NORMAL,     // cdecl calling convention
            reinterpret_cast<void*>(add)
        );
    }
}
