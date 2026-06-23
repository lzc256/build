/* libstdc++-stub.c - Minimal libstdc++ stub for Android WebRTC compatibility
 *
 * libwebrtc-native has DT_NEEDED: libstdc++.so.6.
 * Android uses libc++ instead. This stub satisfies the linker.
 *
 * Build:
 *   aarch64-linux-gnu-g++ -shared -fPIC -Wl,-soname,libstdc++.so.6 \
 *     -o libstdc++.so.6 libstdc++-stub.c
 */

#include <stddef.h>
#include <stdint.h>

/* Basic type definitions */
typedef struct __va_list_tag { char x[32]; } va_list;

/* Exception handling - minimal stubs */
void __cxa_throw(void* thrown_exception, void* type_info, void (*dest)(void*)) {
    /* Never returns in real implementation */
    for (;;) {}
}

void* __cxa_begin_catch(void* exc_obj) {
    return exc_obj;
}

void __cxa_end_catch(void) {}

void __cxa_rethrow(void) {
    for (;;) {}
}

void* __cxa_allocate_exception(size_t size) {
    return 0;
}

void __cxa_free_exception(void* ptr) {}

void* __cxa_get_exception_ptr(void* exc_obj) {
    return exc_obj;
}

/* Typeinfo stubs */
void* _ZTIi = 0;  /* typeinfo for int */
void* _ZTId = 0;  /* typeinfo for double */
void* _ZTIPKc = 0; /* typeinfo for char const* */
void* _ZTIv = 0;  /* typeinfo for void */
void* _ZTIPv = 0; /* typeinfo for void* */

/* Pure virtual function handler */
void __cxa_pure_virtual(void) {}

/* Deleted virtual function handler */
void __cxa_deleted_virtual(void) {}

/* Guard variables for static initialization */
int __cxa_guard_acquire(uint64_t* guard) {
    return 1;
}

void __cxa_guard_release(uint64_t* guard) {}

void __cxa_guard_abort(uint64_t* guard) {}

/* Atexit */
int atexit(void (*func)(void)) {
    return 0;
}

int __cxa_atexit(void (*func)(void*), void* arg, void* dso) {
    return 0;
}

/* String functions - basic stubs */
void* _Znwm(size_t size) {
    return 0;  /* operator new(unsigned long) */
}

void* _Znam(size_t size) {
    return 0;  /* operator new[](unsigned long) */
}

void _ZdlPv(void* ptr) {}  /* operator delete(void*) */
void _ZdaPv(void* ptr) {}  /* operator delete[](void*) */

void* _ZnwmRKSt9nothrow_t(size_t size, void* nothrow) {
    return 0;
}

void* _ZnamRKSt9nothrow_t(size_t size, void* nothrow) {
    return 0;
}

void _ZdlPvRKSt9nothrow_t(void* ptr, void* nothrow) {}
void _ZdaPvRKSt9nothrow_t(void* ptr, void* nothrow) {}

/* Aligned allocation variants (C++17) */
void* _ZnwmSt11align_val_t(size_t size, size_t align) {
    return 0;
}

void* _ZnamSt11align_val_t(size_t size, size_t align) {
    return 0;
}

void _ZdlPvSt11align_val_t(void* ptr, size_t align) {}
void _ZdaPvSt11align_val_t(void* ptr, size_t align) {}

/* Sized delete (C++14) */
void _ZdlPvm(void* ptr, size_t size) {}
void _ZdaPvm(void* ptr, size_t size) {}

/* RTTI stubs */
void* __dynamic_cast(void* ptr, void* from_type, void* to_type, int offset) {
    return 0;
}

/* Thread local storage - stubs */
void* __tls_get_addr(void* arg) {
    return 0;
}

/* Mutex stubs */
void _ZSt15__once_callable(void) {}
void _ZSt14__once_call(void) {}

/* Atomic operations - basic stubs */
void __atomic_thread_fence(int order) {}
void __atomic_signal_fence(int order) {}

/* ABI namespace functions */
void _ZNSt9exceptionD1Ev(void* this) {}
void _ZNSt9exceptionD2Ev(void* this) {}

/* Basic_ios destructor */
void _ZNSt8ios_baseD1Ev(void* this) {}
void _ZNSt8ios_baseD2Ev(void* this) {}

/* Locale stubs */
void* _ZNSt6localeC1Ev(void* this) { return this; }
void* _ZNSt6localeC2Ev(void* this) { return this; }
void _ZNSt6localeD1Ev(void* this) {}
void _ZNSt6localeD2Ev(void* this) {}

/* Codecvt stubs */
void _ZNSt7codecvtIcc11__mbstate_tED1Ev(void* this) {}
void _ZNSt7codecvtIcc11__mbstate_tED2Ev(void* this) {}

/* Basic string stubs */
void* _ZNSsC1EPKc(void* this, const char* s) { return this; }
void* _ZNSsC2EPKc(void* this, const char* s) { return this; }
void _ZNSsD1Ev(void* this) {}
void _ZNSsD2Ev(void* this) {}

/* iostream stubs - minimal */
void _ZSt4cout = 0;
void _ZSt4cerr = 0;
void _ZSt4clog = 0;
void _ZSt3cin = 0;

/* Stream operators - stubs */
void* _ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc(void* out, const char* s) {
    return out;
}

/* Ostream */
void* _ZNSolsEPFRSoS_E(void* this, void* func) { return this; }
void* _ZNSolsEi(void* this, int val) { return this; }
void* _ZNSolsEd(void* this, double val) { return this; }
void* _ZNSolsEm(void* this, uint64_t val) { return this; }

/* Manipulators */
void* _ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_(void* out) { return out; }
void* _ZSt5flushIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_(void* out) { return out; }

/* Numeric limits - stubs */
void _ZNSt11char_traitsIcE6assignERcc(void* r, char c) {}

/* Utility functions */
void* _ZSt9terminatev(void) {
    for (;;) {}
}

void* _ZSt9type_infoC1EPKcPKSt9type_info(void* this, const char* name, void* base) {
    return this;
}

/* Unexpected handler */
void _ZSt10unexpectedv(void) {}

/* Current exception */
void* __cxa_current_exception_type(void) {
    return 0;
}

/* Bad_alloc stub */
void _ZNSt9bad_allocD1Ev(void* this) {}
void _ZNSt9bad_allocD2Ev(void* this) {}

/* Bad_cast stub */
void _ZNSt8bad_castD1Ev(void* this) {}
void _ZNSt8bad_castD2Ev(void* this) {}

/* Bad_typeid stub */
void _ZNSt10bad_typeidD1Ev(void* this) {}
void _ZNSt10bad_typeidD2Ev(void* this) {}

/* Logic_error family */
void _ZNSt11logic_errorD1Ev(void* this) {}
void _ZNSt11logic_errorD2Ev(void* this) {}
void _ZNSt12length_errorD1Ev(void* this) {}
void _ZNSt12out_of_rangeD1Ev(void* this) {}

/* Runtime_error family */
void _ZNSt13runtime_errorD1Ev(void* this) {}
void _ZNSt13runtime_errorD2Ev(void* this) {}

/* Function objects */
void* _ZNKSt8functionIFvvEEclEv(void* this) { return 0; }

/* Move semantics */
void* _ZSt4moveIRiEONSt16remove_referenceIT_E4typeEOS2_(int* x) { return x; }
void* _ZSt4moveIRdEONSt16remove_referenceIT_E4typeEOS2_(double* x) { return x; }

/* Allocator traits */
void* _ZNSt15allocator_traitsISaIiEE10deallocateERS0_Pim(void* alloc, int* p, uint64_t n) {
    return 0;
}
