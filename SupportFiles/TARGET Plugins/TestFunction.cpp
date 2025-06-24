// TestFunction.cpp

extern "C" __declspec(dllexport)
int TestFunction(int dummy = 0)

{
    return 42 * dummy;
}

