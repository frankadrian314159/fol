#include <stdlib.h>
#include <string.h>

typedef struct {
    const char* type_name;
    int size;
} DispatchResult;

// Dispatch functions (simple handlers)
DispatchResult process_int(long x) {
    DispatchResult r;
    r.type_name = "int";
    r.size = (int)(x & 0xFF);
    return r;
}

DispatchResult process_string(const char* s) {
    DispatchResult r;
    r.type_name = "string";
    r.size = (int)strlen(s);
    return r;
}

DispatchResult process_list(int* arr, int len) {
    DispatchResult r;
    r.type_name = "list";
    r.size = len;
    return r;
}

DispatchResult process_other() {
    DispatchResult r;
    r.type_name = "other";
    r.size = 0;
    return r;
}

// Main uncached dispatch - Python calls this
// Python passes type ID and data
DispatchResult dispatch_uncached(int type_id, long int_val, const char* str_val, int* arr, int arr_len) {
    switch (type_id) {
        case 0: return process_int(int_val);
        case 1: return process_string(str_val != NULL ? str_val : "");
        case 2: return process_list(arr, arr_len);
        default: return process_other();
    }
}

// No cached version in C - caching happens in Python
