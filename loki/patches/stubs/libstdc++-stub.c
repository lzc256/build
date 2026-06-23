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
#include <stdlib.h>

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
    return malloc(size);
}

void __cxa_free_exception(void* ptr) {
    free(ptr);
}

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
    return malloc(size);  /* operator new(unsigned long) */
}

void* _Znam(size_t size) {
    return malloc(size);  /* operator new[](unsigned long) */
}

void _ZdlPv(void* ptr) { free(ptr); }  /* operator delete(void*) */
void _ZdaPv(void* ptr) { free(ptr); }  /* operator delete[](void*) */

void* _ZnwmRKSt9nothrow_t(size_t size, void* nothrow) {
    return malloc(size);
}

void* _ZnamRKSt9nothrow_t(size_t size, void* nothrow) {
    return malloc(size);
}

void _ZdlPvRKSt9nothrow_t(void* ptr, void* nothrow) { free(ptr); }
void _ZdaPvRKSt9nothrow_t(void* ptr, void* nothrow) { free(ptr); }

/* Aligned allocation variants (C++17) */
void* _ZnwmSt11align_val_t(size_t size, size_t align) {
    return malloc(size);
}

void* _ZnamSt11align_val_t(size_t size, size_t align) {
    return malloc(size);
}

void _ZdlPvSt11align_val_t(void* ptr, size_t align) { free(ptr); }
void _ZdaPvSt11align_val_t(void* ptr, size_t align) { free(ptr); }

/* Sized delete (C++14) */
void _ZdlPvm(void* ptr, size_t size) { free(ptr); }
void _ZdaPvm(void* ptr, size_t size) { free(ptr); }

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

/* Utility functions */
void* _ZSt9terminatev(void) {
    for (;;) {}
}

void _ZSt10unexpectedv(void) {}

/* Current exception */
void* __cxa_current_exception_type(void) {
    return 0;
}
