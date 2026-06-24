/* libstdc++-stub.c - Minimal libstdc++ stub for Android WebRTC compatibility
 *
 * libwebrtc-native has DT_NEEDED: libstdc++.so.6.
 * Android uses libc++ instead. This stub satisfies the linker.
 *
 * IMPORTANT: This must be compiled with -nostdlib to avoid glibc dependency.
 * Android uses Bionic (libc.so), not glibc (libc.so.6).
 *
 * Build:
 *   aarch64-linux-gnu-g++ -shared -fPIC -nostdlib -Wl,-soname,libstdc++.so.6 \
 *     -o libstdc++.so.6 libstdc++-stub.c
 */

#include <stdint.h>

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

void* __cxa_allocate_exception(unsigned long size) {
    /* Simple bump allocator using stack - good enough for stub */
    static char buf[4096];
    static unsigned long offset = 0;
    if (offset + size < sizeof(buf)) {
        void* p = buf + offset;
        offset += (size + 15) & ~15;  /* align to 16 */
        return p;
    }
    return (void*)0;
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
int __cxa_guard_acquire(unsigned long long* guard) {
    return 1;
}

void __cxa_guard_release(unsigned long long* guard) {}

void __cxa_guard_abort(unsigned long long* guard) {}

/* Atexit */
int atexit(void (*func)(void)) {
    return 0;
}

int __cxa_atexit(void (*func)(void*), void* arg, void* dso) {
    return 0;
}

/* operator new/delete - simple bump allocator */
static char _new_buf[65536];
static unsigned long _new_offset = 0;

void* _Znwm(unsigned long size) {  /* operator new(unsigned long) */
    if (_new_offset + size < sizeof(_new_buf)) {
        void* p = _new_buf + _new_offset;
        _new_offset += (size + 15) & ~15;  /* align to 16 */
        return p;
    }
    return (void*)0;
}

void* _Znam(unsigned long size) {  /* operator new[](unsigned long) */
    return _Znwm(size);
}

void _ZdlPv(void* ptr) {}  /* operator delete(void*) - no-op for bump allocator */
void _ZdaPv(void* ptr) {}  /* operator delete[](void*) */

void* _ZnwmRKSt9nothrow_t(unsigned long size, void* nothrow) {
    return _Znwm(size);
}

void* _ZnamRKSt9nothrow_t(unsigned long size, void* nothrow) {
    return _Znam(size);
}

void _ZdlPvRKSt9nothrow_t(void* ptr, void* nothrow) {}
void _ZdaPvRKSt9nothrow_t(void* ptr, void* nothrow) {}

/* Aligned allocation variants (C++17) */
void* _ZnwmSt11align_val_t(unsigned long size, unsigned long align) {
    return _Znwm(size);
}

void* _ZnamSt11align_val_t(unsigned long size, unsigned long align) {
    return _Znam(size);
}

void _ZdlPvSt11align_val_t(void* ptr, unsigned long align) {}
void _ZdaPvSt11align_val_t(void* ptr, unsigned long align) {}

/* Sized delete (C++14) */
void _ZdlPvm(void* ptr, unsigned long size) {}
void _ZdaPvm(void* ptr, unsigned long size) {}

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

/* Additional C++ ABI symbols that may be needed */
void* __gxx_personality_v0 = 0;

/* More typeinfo for common types */
void* _ZTIPi = 0;   /* typeinfo for int* */
void* _ZTIPd = 0;   /* typeinfo for double* */
void* _ZTIPKv = 0;  /* typeinfo for void const* */

/* Exception typeinfo */
void* _ZTVN10__cxxabiv117__class_type_infoE = 0;
void* _ZTVN10__cxxabiv120__si_class_type_infoE = 0;
void* _ZTVN10__cxxabiv121__vmi_class_type_infoE = 0;
