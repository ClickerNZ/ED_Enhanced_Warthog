// Build with exactly:
/*
    cl /nologo /W3 /EHsc /MD /LD targetPlugin.cpp /link /EXPORT:targetPluginMap /OUT:targetPlugin.dll
*/

#include <windows.h>

extern "C" __declspec(dllexport) 
int __stdcall fndstr(const char* string, const char* substring)
{
    if (!string || !substring) return -1;
    const char* p = string;
    while (*p) {
        const char* q = p, *r = substring;
        while (*r && *q == *r) { ++q; ++r; }
        if (!*r) return int(p - string);
        ++p;
    }
    return -1;
}
