/* libstdc++-stub.c - Comprehensive libstdc++.so.6 stub for Android WebRTC compatibility
 *
 * libwebrtc-native has DT_NEEDED: libstdc++.so.6.
 * Android uses libc++ instead. This stub satisfies the linker.
 *
 * This stub provides ALL common C++ ABI symbols that libstdc++.so.6 exports,
 * including exception handling, RTTI, typeinfo for all standard types,
 * std::string, std::exception, iostream stubs, etc.
 *
 * IMPORTANT: This must be compiled with -nostdlib to avoid glibc dependency.
 * Android uses Bionic (libc.so), not glibc (libc.so.6).
 *
 * Build:
 *   aarch64-linux-gnu-g++ -shared -fPIC -nostdlib -Wl,-soname,libstdc++.so.6 \
 *     -o libstdc++.so.6 libstdc++-stub.c
 */

#include <stdint.h>
#include <stddef.h>

/* ============================================================================
 * MEMORY ALLOCATION - Simple bump allocators
 * ============================================================================ */

static char _alloc_buf[1048576];  /* 1MB allocation pool */
static size_t _alloc_offset = 0;

static void* _bump_alloc(size_t size) {
    size = (size + 15) & ~15;  /* align to 16 bytes */
    if (_alloc_offset + size <= sizeof(_alloc_buf)) {
        void* p = _alloc_buf + _alloc_offset;
        _alloc_offset += size;
        return p;
    }
    return NULL;
}

/* operator new */
void* _Znwm(unsigned long size) { return _bump_alloc(size); }
void* _Znam(unsigned long size) { return _bump_alloc(size); }
void* _ZnwmRKSt9nothrow_t(unsigned long size, void* nt) { return _bump_alloc(size); }
void* _ZnamRKSt9nothrow_t(unsigned long size, void* nt) { return _bump_alloc(size); }
void* _ZnwmSt11align_val_t(unsigned long size, unsigned long align) { return _bump_alloc(size); }
void* _ZnamSt11align_val_t(unsigned long size, unsigned long align) { return _bump_alloc(size); }
void* _ZnwmSt11align_val_tRKSt9nothrow_t(unsigned long size, unsigned long align, void* nt) { return _bump_alloc(size); }
void* _ZnamSt11align_val_tRKSt9nothrow_t(unsigned long size, unsigned long align, void* nt) { return _bump_alloc(size); }

/* operator delete - no-op for bump allocator */
void _ZdlPv(void* ptr) {}
void _ZdaPv(void* ptr) {}
void _ZdlPvRKSt9nothrow_t(void* ptr, void* nt) {}
void _ZdaPvRKSt9nothrow_t(void* ptr, void* nt) {}
void _ZdlPvm(void* ptr, unsigned long size) {}
void _ZdaPvm(void* ptr, unsigned long size) {}
void _ZdlPvSt11align_val_t(void* ptr, unsigned long align) {}
void _ZdaPvSt11align_val_t(void* ptr, unsigned long align) {}
void _ZdlPvmSt11align_val_t(void* ptr, unsigned long size, unsigned long align) {}
void _ZdaPvmSt11align_val_t(void* ptr, unsigned long size, unsigned long align) {}
void _ZdlPvSt11align_val_tRKSt9nothrow_t(void* ptr, unsigned long align, void* nt) {}
void _ZdaPvSt11align_val_tRKSt9nothrow_t(void* ptr, unsigned long align, void* nt) {}

/* ============================================================================
 * EXCEPTION HANDLING - C++ ABI
 * ============================================================================ */

static char _exception_buf[65536];
static size_t _exception_offset = 0;

void* __cxa_allocate_exception(unsigned long size) {
    size = (size + 15) & ~15;
    if (_exception_offset + size <= sizeof(_exception_buf)) {
        void* p = _exception_buf + _exception_offset;
        _exception_offset += size;
        return p;
    }
    return _bump_alloc(size);
}

void __cxa_free_exception(void* ptr) {}

void __cxa_throw(void* exc, void* type, void (*dtor)(void*)) {
    /* In real implementation, unwinds stack. We just abort. */
    for (;;) {}
}

void* __cxa_begin_catch(void* exc) { return exc; }
void __cxa_end_catch(void) {}
void __cxa_rethrow(void) { for (;;) {} }
void* __cxa_get_exception_ptr(void* exc) { return exc; }
void* __cxa_current_primary_exception(void) { return NULL; }
void __cxa_decrement_exception_refcount(void* exc) {}
void __cxa_increment_exception_refcount(void* exc) {}
void* __cxa_allocate_dependent_exception(void) { return _bump_alloc(64); }
void __cxa_free_dependent_exception(void* exc) {}
void __cxa_throw_bad_array_new_length(void) { for (;;) {} }
void __cxa_throw_bad_array_length(void) { for (;;) {} }

/* Personality function */
void* __gxx_personality_v0 = NULL;
void* __gxx_personality_seh0 = NULL;
void* __gxx_personality_sj0 = NULL;

/* Exception type info */
void* __cxa_current_exception_type(void) { return NULL; }

/* Unwind helpers */
void _Unwind_Resume(void* exc) { for (;;) {} }
void* _Unwind_GetIP(void* ctx) { return NULL; }
void _Unwind_SetIP(void* ctx, void* ip) {}
void* _Unwind_GetLanguageSpecificData(void* ctx) { return NULL; }
unsigned long _Unwind_GetRegionStart(void* ctx) { return 0; }
unsigned long _Unwind_GetIPInfo(void* ctx, int* ip_before_insn) { *ip_before_insn = 0; return 0; }

/* ============================================================================
 * PURE VIRTUAL / DELETED VIRTUAL
 * ============================================================================ */

void __cxa_pure_virtual(void) {}
void __cxa_deleted_virtual(void) {}

/* ============================================================================
 * GUARD VARIABLES - Static initialization
 * ============================================================================ */

int __cxa_guard_acquire(unsigned long long* guard) {
    if (*((unsigned char*)guard) == 0) {
        *((unsigned char*)guard) = 1;
        return 1;
    }
    return 0;
}

void __cxa_guard_release(unsigned long long* guard) {
    *((unsigned char*)guard) = 2;
}

void __cxa_guard_abort(unsigned long long* guard) {
    *((unsigned char*)guard) = 0;
}

/* ============================================================================
 * ATEXIT
 * ============================================================================ */

int atexit(void (*func)(void)) { return 0; }
int __cxa_atexit(void (*func)(void*), void* arg, void* dso) { return 0; }
int __cxa_thread_atexit(void (*func)(void*), void* arg, void* dso) { return 0; }
int __aeabi_atexit(void* arg, void (*func)(void*), void* dso) { return 0; }

/* ============================================================================
 * DYNAMIC CAST
 * ============================================================================ */

void* __dynamic_cast(void* ptr, void* from, void* to, int offset) {
    return NULL;
}

/* ============================================================================
 * TLS (Thread Local Storage)
 * ============================================================================ */

void* __tls_get_addr(void* arg) { return NULL; }

/* ============================================================================
 * TYPEINFO - std::type_info and all fundamental types
 * ============================================================================ */

/* std::type_info vtable and class */
struct type_info {
    void** vtable;
    const char* name;
};

/* Vtables for type_info hierarchy - must point to our type_info vtable */
static void* _type_info_vtable[8] = {0};

/* Virtual table pointers for all type_info subclasses */
static void* _class_type_info_vtable[8] = {0};
static void* _si_class_type_info_vtable[8] = {0};
static void* _vmi_class_type_info_vtable[8] = {0};
static void* _fundamental_type_info_vtable[8] = {0};
static void* _array_type_info_vtable[8] = {0};
static void* _function_type_info_vtable[8] = {0};
static void* _enum_type_info_vtable[8] = {0};
static void* _pointer_type_info_vtable[8] = {0};
static void* _pointer_to_member_type_info_vtable[8] = {0};
static void* _pbase_type_info_vtable[8] = {0};

/* typeinfo objects for fundamental types */
struct type_info _ZTIi = { _type_info_vtable, "i" };           /* int */
struct type_info _ZTIj = { _type_info_vtable, "j" };           /* unsigned int */
struct type_info _ZTIl = { _type_info_vtable, "l" };           /* long */
struct type_info _ZTIm = { _type_info_vtable, "m" };           /* unsigned long */
struct type_info _ZTIx = { _type_info_vtable, "x" };           /* long long */
struct type_info _ZTIy = { _type_info_vtable, "y" };           /* unsigned long long */
struct type_info _ZTIf = { _type_info_vtable, "f" };           /* float */
struct type_info _ZTId = { _type_info_vtable, "d" };           /* double */
struct type_info _ZTIe = { _type_info_vtable, "e" };           /* long double */
struct type_info _ZTIa = { _type_info_vtable, "a" };           /* signed char */
struct type_info _ZTIh = { _type_info_vtable, "h" };           /* unsigned char */
struct type_info _ZTIc = { _type_info_vtable, "c" };           /* char */
struct type_info _ZTIs = { _type_info_vtable, "s" };           /* short */
struct type_info _ZTIt = { _type_info_vtable, "t" };           /* unsigned short */
struct type_info _ZTIb = { _type_info_vtable, "b" };           /* bool */
struct type_info _ZTIw = { _type_info_vtable, "w" };           /* wchar_t */
struct type_info _ZTIDi = { _type_info_vtable, "Di" };         /* char32_t */
struct type_info _ZTIDs = { _type_info_vtable, "Ds" };         /* char16_t */
struct type_info _ZTIDn = { _type_info_vtable, "Dn" };         /* decltype(nullptr) */
struct type_info _ZTIv = { _type_info_vtable, "v" };           /* void */

/* typeinfo for pointers */
struct type_info _ZTIPi = { _pointer_type_info_vtable, "Pi" };    /* int* */
struct type_info _ZTIPj = { _pointer_type_info_vtable, "Pj" };    /* unsigned int* */
struct type_info _ZTIPf = { _pointer_type_info_vtable, "Pf" };    /* float* */
struct type_info _ZTIPd = { _pointer_type_info_vtable, "Pd" };    /* double* */
struct type_info _ZTIPKc = { _pointer_type_info_vtable, "PKc" };  /* const char* */
struct type_info _ZTIPv = { _pointer_type_info_vtable, "Pv" };    /* void* */
struct type_info _ZTIPKv = { _pointer_type_info_vtable, "PKv" };  /* const void* */

/* Vtables exported by mangled names */
void** _ZTVN10__cxxabiv117__class_type_infoE = _class_type_info_vtable;
void** _ZTVN10__cxxabiv120__si_class_type_infoE = _si_class_type_info_vtable;
void** _ZTVN10__cxxabiv121__vmi_class_type_infoE = _vmi_class_type_info_vtable;
void** _ZTVN10__cxxabiv123__fundamental_type_infoE = _fundamental_type_info_vtable;
void** _ZTVN10__cxxabiv117__array_type_infoE = _array_type_info_vtable;
void** _ZTVN10__cxxabiv119__function_type_infoE = _function_type_info_vtable;
void** _ZTVN10__cxxabiv116__enum_type_infoE = _enum_type_info_vtable;
void** _ZTVN10__cxxabiv119__pointer_type_infoE = _pointer_type_info_vtable;
void** _ZTVN10__cxxabiv129__pointer_to_member_type_infoE = _pointer_to_member_type_info_vtable;
void** _ZTVN10__cxxabiv117__pbase_type_infoE = _pbase_type_info_vtable;
void** _ZTVSt9type_info = _type_info_vtable;

/* ============================================================================
 * std::exception AND DERIVED CLASSES
 * ============================================================================ */

/* std::exception class structure */
struct std_exception {
    void** vtable;
};

/* Virtual tables for exception hierarchy */
static void* _exception_vtable[8] = {0};
static void* _bad_alloc_vtable[8] = {0};
static void* _bad_array_new_length_vtable[8] = {0};
static void* _bad_cast_vtable[8] = {0};
static void* _bad_typeid_vtable[8] = {0};
static void* _logic_error_vtable[8] = {0};
static void* _runtime_error_vtable[8] = {0};
static void* _out_of_range_vtable[8] = {0};
static void* _length_error_vtable[8] = {0};
static void* _invalid_argument_vtable[8] = {0};
static void* _domain_error_vtable[8] = {0};
static void* _range_error_vtable[8] = {0};
static void* _overflow_error_vtable[8] = {0};
static void* _underflow_error_vtable[8] = {0};
static void* _ios_failure_vtable[8] = {0};
static void* _system_error_vtable[8] = {0};
static void* _future_error_vtable[8] = {0};
static void* _bad_optional_access_vtable[8] = {0};
static void* _bad_variant_access_vtable[8] = {0};
static void* _bad_any_cast_vtable[8] = {0};
static void* _bad_weak_ptr_vtable[8] = {0};
static void* _bad_function_call_vtable[8] = {0};

/* std::exception typeinfo */
struct type_info _ZTISt9exception = { _exception_vtable, "St9exception" };
struct type_info _ZTISt9bad_alloc = { _bad_alloc_vtable, "St9bad_alloc" };
struct type_info _ZTISt20bad_array_new_length = { _bad_array_new_length_vtable, "St20bad_array_new_length" };
struct type_info _ZTISt8bad_cast = { _bad_cast_vtable, "St8bad_cast" };
struct type_info _ZTISt10bad_typeid = { _bad_typeid_vtable, "St10bad_typeid" };
struct type_info _ZTISt11logic_error = { _logic_error_vtable, "St11logic_error" };
struct type_info _ZTISt12runtime_error = { _runtime_error_vtable, "St12runtime_error" };
struct type_info _ZTISt12out_of_range = { _out_of_range_vtable, "St12out_of_range" };
struct type_info _ZTISt12length_error = { _length_error_vtable, "St12length_error" };
struct type_info _ZTISt16invalid_argument = { _invalid_argument_vtable, "St16invalid_argument" };
struct type_info _ZTISt11domain_error = { _domain_error_vtable, "St11domain_error" };
struct type_info _ZTISt11range_error = { _range_error_vtable, "St11range_error" };
struct type_info _ZTISt14overflow_error = { _overflow_error_vtable, "St14overflow_error" };
struct type_info _ZTISt15underflow_error = { _underflow_error_vtable, "St15underflow_error" };
struct type_info _ZTISt13ios_base7failure = { _ios_failure_vtable, "St13ios_base7failure" };
struct type_info _ZTISt12system_error = { _system_error_vtable, "St12system_error" };
struct type_info _ZTISt12future_error = { _future_error_vtable, "St12future_error" };
struct type_info _ZTISt19bad_optional_access = { _bad_optional_access_vtable, "St19bad_optional_access" };
struct type_info _ZTISt18bad_variant_access = { _bad_variant_access_vtable, "St18bad_variant_access" };
struct type_info _ZTISt11bad_any_cast = { _bad_any_cast_vtable, "St11bad_any_cast" };
struct type_info _ZTISt12bad_weak_ptr = { _bad_weak_ptr_vtable, "St12bad_weak_ptr" };
struct type_info _ZTISt17bad_function_call = { _bad_function_call_vtable, "St17bad_function_call" };

/* std::exception vtable exported */
void** _ZTVSt9exception = _exception_vtable;
void** _ZTVSt9bad_alloc = _bad_alloc_vtable;
void** _ZTVSt20bad_array_new_length = _bad_array_new_length_vtable;
void** _ZTVSt8bad_cast = _bad_cast_vtable;
void** _ZTVSt10bad_typeid = _bad_typeid_vtable;
void** _ZTVSt11logic_error = _logic_error_vtable;
void** _ZTVSt12runtime_error = _runtime_error_vtable;
void** _ZTVSt12out_of_range = _out_of_range_vtable;
void** _ZTVSt12length_error = _length_error_vtable;
void** _ZTVSt16invalid_argument = _invalid_argument_vtable;
void** _ZTVSt11domain_error = _domain_error_vtable;
void** _ZTVSt11range_error = _range_error_vtable;
void** _ZTVSt14overflow_error = _overflow_error_vtable;
void** _ZTVSt15underflow_error = _underflow_error_vtable;
void** _ZTVSt13ios_base7failure = _ios_failure_vtable;
void** _ZTVSt12system_error = _system_error_vtable;
void** _ZTVSt12future_error = _future_error_vtable;
void** _ZTVSt19bad_optional_access = _bad_optional_access_vtable;
void** _ZTVSt18bad_variant_access = _bad_variant_access_vtable;
void** _ZTVSt11bad_any_cast = _bad_any_cast_vtable;
void** _ZTVSt12bad_weak_ptr = _bad_weak_ptr_vtable;
void** _ZTVSt17bad_function_call = _bad_function_call_vtable;

/* std::exception methods (D0, D1, D2 = deleting, complete, base destructors) */
void _ZNSt9exceptionD0Ev(void* this) {}
void _ZNSt9exceptionD1Ev(void* this) {}
void _ZNSt9exceptionD2Ev(void* this) {}
void _ZNSt9exceptionC1Ev(void* this) {}
void _ZNSt9exceptionC2Ev(void* this) {}
const char* _ZNKSt9exception4whatEv(void* this) { return "std::exception"; }

/* std::bad_alloc methods */
void _ZNSt9bad_allocD0Ev(void* this) {}
void _ZNSt9bad_allocD1Ev(void* this) {}
void _ZNSt9bad_allocD2Ev(void* this) {}
void _ZNSt9bad_allocC1Ev(void* this) {}
void _ZNSt9bad_allocC2Ev(void* this) {}
const char* _ZNKSt9bad_alloc4whatEv(void* this) { return "std::bad_alloc"; }

/* std::bad_array_new_length methods */
void _ZNSt20bad_array_new_lengthD0Ev(void* this) {}
void _ZNSt20bad_array_new_lengthD1Ev(void* this) {}
void _ZNSt20bad_array_new_lengthD2Ev(void* this) {}
void _ZNSt20bad_array_new_lengthC1Ev(void* this) {}
void _ZNSt20bad_array_new_lengthC2Ev(void* this) {}
const char* _ZNKSt20bad_array_new_length4whatEv(void* this) { return "std::bad_array_new_length"; }

/* std::bad_cast methods */
void _ZNSt8bad_castD0Ev(void* this) {}
void _ZNSt8bad_castD1Ev(void* this) {}
void _ZNSt8bad_castD2Ev(void* this) {}
void _ZNSt8bad_castC1Ev(void* this) {}
void _ZNSt8bad_castC2Ev(void* this) {}
const char* _ZNKSt8bad_cast4whatEv(void* this) { return "std::bad_cast"; }

/* std::bad_typeid methods */
void _ZNSt10bad_typeidD0Ev(void* this) {}
void _ZNSt10bad_typeidD1Ev(void* this) {}
void _ZNSt10bad_typeidD2Ev(void* this) {}
void _ZNSt10bad_typeidC1Ev(void* this) {}
void _ZNSt10bad_typeidC2Ev(void* this) {}
const char* _ZNKSt10bad_typeid4whatEv(void* this) { return "std::bad_typeid"; }

/* std::logic_error methods */
void _ZNSt11logic_errorD0Ev(void* this) {}
void _ZNSt11logic_errorD1Ev(void* this) {}
void _ZNSt11logic_errorD2Ev(void* this) {}
void _ZNSt11logic_errorC1EPKc(void* this, const char* s) {}
void _ZNSt11logic_errorC2EPKc(void* this, const char* s) {}
void _ZNSt11logic_errorC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
void _ZNSt11logic_errorC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
const char* _ZNKSt11logic_error4whatEv(void* this) { return "std::logic_error"; }

/* std::runtime_error methods */
void _ZNSt12runtime_errorD0Ev(void* this) {}
void _ZNSt12runtime_errorD1Ev(void* this) {}
void _ZNSt12runtime_errorD2Ev(void* this) {}
void _ZNSt12runtime_errorC1EPKc(void* this, const char* s) {}
void _ZNSt12runtime_errorC2EPKc(void* this, const char* s) {}
void _ZNSt12runtime_errorC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
void _ZNSt12runtime_errorC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
const char* _ZNKSt12runtime_error4whatEv(void* this) { return "std::runtime_error"; }

/* std::out_of_range methods */
void _ZNSt12out_of_rangeD0Ev(void* this) {}
void _ZNSt12out_of_rangeD1Ev(void* this) {}
void _ZNSt12out_of_rangeD2Ev(void* this) {}
void _ZNSt12out_of_rangeC1EPKc(void* this, const char* s) {}
void _ZNSt12out_of_rangeC2EPKc(void* this, const char* s) {}
void _ZNSt12out_of_rangeC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
void _ZNSt12out_of_rangeC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
const char* _ZNKSt12out_of_range4whatEv(void* this) { return "std::out_of_range"; }

/* std::length_error methods */
void _ZNSt12length_errorD0Ev(void* this) {}
void _ZNSt12length_errorD1Ev(void* this) {}
void _ZNSt12length_errorD2Ev(void* this) {}
void _ZNSt12length_errorC1EPKc(void* this, const char* s) {}
void _ZNSt12length_errorC2EPKc(void* this, const char* s) {}
void _ZNSt12length_errorC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
void _ZNSt12length_errorC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
const char* _ZNKSt12length_error4whatEv(void* this) { return "std::length_error"; }

/* std::invalid_argument methods */
void _ZNSt16invalid_argumentD0Ev(void* this) {}
void _ZNSt16invalid_argumentD1Ev(void* this) {}
void _ZNSt16invalid_argumentD2Ev(void* this) {}
void _ZNSt16invalid_argumentC1EPKc(void* this, const char* s) {}
void _ZNSt16invalid_argumentC2EPKc(void* this, const char* s) {}
void _ZNSt16invalid_argumentC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
void _ZNSt16invalid_argumentC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
const char* _ZNKSt16invalid_argument4whatEv(void* this) { return "std::invalid_argument"; }

/* std::domain_error methods */
void _ZNSt11domain_errorD0Ev(void* this) {}
void _ZNSt11domain_errorD1Ev(void* this) {}
void _ZNSt11domain_errorD2Ev(void* this) {}
void _ZNSt11domain_errorC1EPKc(void* this, const char* s) {}
void _ZNSt11domain_errorC2EPKc(void* this, const char* s) {}
const char* _ZNKSt11domain_error4whatEv(void* this) { return "std::domain_error"; }

/* std::range_error methods */
void _ZNSt11range_errorD0Ev(void* this) {}
void _ZNSt11range_errorD1Ev(void* this) {}
void _ZNSt11range_errorD2Ev(void* this) {}
void _ZNSt11range_errorC1EPKc(void* this, const char* s) {}
void _ZNSt11range_errorC2EPKc(void* this, const char* s) {}
const char* _ZNKSt11range_error4whatEv(void* this) { return "std::range_error"; }

/* std::overflow_error methods */
void _ZNSt14overflow_errorD0Ev(void* this) {}
void _ZNSt14overflow_errorD1Ev(void* this) {}
void _ZNSt14overflow_errorD2Ev(void* this) {}
void _ZNSt14overflow_errorC1EPKc(void* this, const char* s) {}
void _ZNSt14overflow_errorC2EPKc(void* this, const char* s) {}
const char* _ZNKSt14overflow_error4whatEv(void* this) { return "std::overflow_error"; }

/* std::underflow_error methods */
void _ZNSt15underflow_errorD0Ev(void* this) {}
void _ZNSt15underflow_errorD1Ev(void* this) {}
void _ZNSt15underflow_errorD2Ev(void* this) {}
void _ZNSt15underflow_errorC1EPKc(void* this, const char* s) {}
void _ZNSt15underflow_errorC2EPKc(void* this, const char* s) {}
const char* _ZNKSt15underflow_error4whatEv(void* this) { return "std::underflow_error"; }

/* std::bad_function_call methods */
void _ZNSt17bad_function_callD0Ev(void* this) {}
void _ZNSt17bad_function_callD1Ev(void* this) {}
void _ZNSt17bad_function_callD2Ev(void* this) {}
const char* _ZNKSt17bad_function_call4whatEv(void* this) { return "std::bad_function_call"; }

/* std::bad_optional_access methods */
void _ZNSt19bad_optional_accessD0Ev(void* this) {}
void _ZNSt19bad_optional_accessD1Ev(void* this) {}
void _ZNSt19bad_optional_accessD2Ev(void* this) {}
const char* _ZNKSt19bad_optional_access4whatEv(void* this) { return "std::bad_optional_access"; }

/* std::bad_variant_access methods */
void _ZNSt18bad_variant_accessD0Ev(void* this) {}
void _ZNSt18bad_variant_accessD1Ev(void* this) {}
void _ZNSt18bad_variant_accessD2Ev(void* this) {}
const char* _ZNKSt18bad_variant_access4whatEv(void* this) { return "std::bad_variant_access"; }

/* std::bad_any_cast methods */
void _ZNSt11bad_any_castD0Ev(void* this) {}
void _ZNSt11bad_any_castD1Ev(void* this) {}
void _ZNSt11bad_any_castD2Ev(void* this) {}
const char* _ZNKSt11bad_any_cast4whatEv(void* this) { return "std::bad_any_cast"; }

/* std::bad_weak_ptr methods */
void _ZNSt12bad_weak_ptrD0Ev(void* this) {}
void _ZNSt12bad_weak_ptrD1Ev(void* this) {}
void _ZNSt12bad_weak_ptrD2Ev(void* this) {}
void _ZNSt12bad_weak_ptrC1Ev(void* this) {}
void _ZNSt12bad_weak_ptrC2Ev(void* this) {}
const char* _ZNKSt12bad_weak_ptr4whatEv(void* this) { return "std::bad_weak_ptr"; }

/* ============================================================================
 * std::string (basic_string<char>)
 * ============================================================================ */

/* std::string is typically std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char>> */
/* Ss = std::string (pre-C++11) */
/* NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE = C++11 std::string */

/* typeinfo for std::string */
struct type_info _ZTISs = { _type_info_vtable, "Ss" };
struct type_info _ZTINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE = { _type_info_vtable, "NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE" };

/* std::string methods - just provide signatures, no-op implementations */
/* Many of these are template instantiations - we provide the most common ones */

/* std::string constructors */
void _ZNSsC1Ev(void* this) {}
void _ZNSsC1EPKc(void* this, const char* s) {}
void _ZNSsC1ERKSs(void* this, void* other) {}
void _ZNSsC1EPKcm(void* this, const char* s, unsigned long n) {}
void _ZNSsC1Emc(void* this, unsigned long n, char c) {}
void _ZNSsD1Ev(void* this) {}
void _ZNSsC2Ev(void* this) {}
void _ZNSsC2EPKc(void* this, const char* s) {}
void _ZNSsC2ERKSs(void* this, void* other) {}
void _ZNSsD2Ev(void* this) {}

/* C++11 std::string */
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1Ev(void* this) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1EPKc(void* this, const char* s) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* other) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1Emc(void* this, unsigned long n, char c) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED1Ev(void* this) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2Ev(void* this) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EPKc(void* this, const char* s) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* other) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED2Ev(void* this) {}

/* std::string assignment */
void* _ZNSsaSEPKc(void* this, const char* s) { return this; }
void* _ZNSsaSERKSs(void* this, void* other) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEaSEPKc(void* this, const char* s) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEaSERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* other) { return this; }

/* std::string c_str() and data() */
const char* _ZNSs5c_strEv(void* this) { return ""; }
const char* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5c_strEv(void* this) { return ""; }
const char* _ZNSs4dataEv(void* this) { return ""; }
const char* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4dataEv(void* this) { return ""; }

/* std::string size() and length() */
unsigned long _ZNSs4sizeEv(void* this) { return 0; }
unsigned long _ZNSs6lengthEv(void* this) { return 0; }
unsigned long _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4sizeEv(void* this) { return 0; }
unsigned long _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6lengthEv(void* this) { return 0; }

/* std::string empty() */
unsigned char _ZNSs5emptyEv(void* this) { return 1; }
unsigned char _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5emptyEv(void* this) { return 1; }

/* std::string clear() */
void _ZNSs5clearEv(void* this) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5clearEv(void* this) {}

/* std::string append */
void* _ZNSs6appendEPKc(void* this, const char* s) { return this; }
void* _ZNSs6appendERKSs(void* this, void* other) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6appendEPKc(void* this, const char* s) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6appendERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* other) { return this; }

/* std::string operator+ */
void* _ZNSs4appendEc(void* this, char c) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6appendEmc(void* this, unsigned long n, char c) { return this; }

/* std::string resize */
void _ZNSs6resizEm(void* this, unsigned long n) {}
void _ZNSs6resizEmc(void* this, unsigned long n, char c) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6resizEm(void* this, unsigned long n) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6resizEmc(void* this, unsigned long n, char c) {}

/* std::string reserve */
void _ZNSs7reserveEm(void* this, unsigned long n) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7reserveEm(void* this, unsigned long n) {}

/* std::string capacity */
unsigned long _ZNSs8capacityEv(void* this) { return 0; }
unsigned long _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE8capacityEv(void* this) { return 0; }

/* std::string at and operator[] */
char _ZNSs2atEm(void* this, unsigned long n) { return '\0'; }
char _ZNSsixEm(void* this, unsigned long n) { return '\0'; }
char _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE2atEm(void* this, unsigned long n) { return '\0'; }
char _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEixEm(void* this, unsigned long n) { return '\0'; }

/* std::string compare */
int _ZNSs7compareEPKc(void* this, const char* s) { return 0; }
int _ZNSs7compareERKSs(void* this, void* other) { return 0; }
int _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7compareEPKc(void* this, const char* s) { return 0; }
int _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7compareERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* other) { return 0; }

/* std::string find */
unsigned long _ZNSs4findEPKcm(void* this, const char* s, unsigned long pos) { return (unsigned long)-1; }
unsigned long _ZNSs4findEcm(void* this, char c, unsigned long pos) { return (unsigned long)-1; }
unsigned long _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4findEPKcm(void* this, const char* s, unsigned long pos) { return (unsigned long)-1; }
unsigned long _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4findEcm(void* this, char c, unsigned long pos) { return (unsigned long)-1; }

/* std::string rfind */
unsigned long _ZNSs5rfindEPKcm(void* this, const char* s, unsigned long pos) { return (unsigned long)-1; }
unsigned long _ZNSs5rfindEcm(void* this, char c, unsigned long pos) { return (unsigned long)-1; }
unsigned long _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5rfindEPKcm(void* this, const char* s, unsigned long pos) { return (unsigned long)-1; }
unsigned long _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5rfindEcm(void* this, char c, unsigned long pos) { return (unsigned long)-1; }

/* std::string substr */
void* _ZNSs6substrEmm(void* this, unsigned long pos, unsigned long n) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6substrEmm(void* this, unsigned long pos, unsigned long n) { return this; }

/* std::string erase */
void* _ZNSs5eraseEmm(void* this, unsigned long pos, unsigned long n) { return this; }
void* _ZNSs5eraseEm(void* this, unsigned long pos) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5eraseEmm(void* this, unsigned long pos, unsigned long n) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5eraseEm(void* this, unsigned long pos) { return this; }

/* std::string insert */
void* _ZNSs6insertEmPKc(void* this, unsigned long pos, const char* s) { return this; }
void* _ZNSs6insertEmmc(void* this, unsigned long pos, unsigned long n, char c) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6insertEmPKc(void* this, unsigned long pos, const char* s) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6insertEmmc(void* this, unsigned long pos, unsigned long n, char c) { return this; }

/* std::string replace */
void* _ZNSs7replaceEmmPKc(void* this, unsigned long pos, unsigned long n, const char* s) { return this; }
void* _ZNSs7replaceEmmRKSs(void* this, unsigned long pos, unsigned long n, void* other) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7replaceEmmPKc(void* this, unsigned long pos, unsigned long n, const char* s) { return this; }
void* _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7replaceEmmRKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, unsigned long pos, unsigned long n, void* other) { return this; }

/* std::string copy */
unsigned long _ZNSs4copyEPcmm(void* this, char* dest, unsigned long n, unsigned long pos) { return 0; }
unsigned long _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4copyEPcmm(void* this, char* dest, unsigned long n, unsigned long pos) { return 0; }

/* std::string swap */
void _ZNSs4swapERSs(void* this, void* other) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4swapERS1_(void* this, void* other) {}

/* ============================================================================
 * std::allocator<char>
 * ============================================================================ */

void* _ZNSaIcEC1Ev(void* this) { return this; }
void* _ZNSaIcEC2Ev(void* this) { return this; }
void* _ZNSaIcEC1ERKS_(void* this, void* other) { return this; }
void* _ZNSaIcEC2ERKS_(void* this, void* other) { return this; }
void _ZNSaIcED1Ev(void* this) {}
void _ZNSaIcED2Ev(void* this) {}
void* _ZNSaIcE8allocateEm(void* this, unsigned long n) { return _bump_alloc(n); }
void _ZNSaIcE10deallocateEPcm(void* this, void* p, unsigned long n) {}

/* ============================================================================
 * std::char_traits<char>
 * ============================================================================ */

unsigned long _ZNSt11char_traitsIcE4findEPKcmS2_(const char* s, unsigned long n, const char* c) { return (unsigned long)-1; }
unsigned long _ZNSt11char_traitsIcE6assignEPcmc(char* s, unsigned long n, char c) { return n; }
unsigned long _ZNSt11char_traitsIcE4copyEPcPKcm(char* dest, const char* src, unsigned long n) { return n; }
unsigned long _ZNSt11char_traitsIcE6lengthEPKc(const char* s) { return 0; }
int _ZNSt11char_traitsIcE7compareEPKcS2_m(const char* s1, const char* s2, unsigned long n) { return 0; }
char _ZNSt11char_traitsIcE2eqERKcS2_(const char* a, const char* b) { return *a == *b; }

/* ============================================================================
 * std::cout, std::cerr, std::cin STUBS
 * ============================================================================ */

/* These are complex objects - just provide dummy symbols */
static char _cout_buf[256];
static char _cerr_buf[256];
static char _cin_buf[256];

void* _ZSt4cout = _cout_buf;
void* _ZSt4cerr = _cerr_buf;
void* _ZSt3cin = _cin_buf;

/* std::ostream::operator<< stubs */
void* _ZNSolsEi(void* this, int val) { return this; }
void* _ZNSolsEl(void* this, long val) { return this; }
void* _ZNSolsEm(void* this, unsigned long val) { return this; }
void* _ZNSolsEd(void* this, double val) { return this; }
void* _ZNSolsEf(void* this, float val) { return this; }
void* _ZNSolsEPKc(void* this, const char* val) { return this; }
void* _ZNSolsEc(void* this, char val) { return this; }
void* _ZNSolsEb(void* this, unsigned char val) { return this; }
void* _ZNSolsEPFRSoS_E(void* this, void* (*f)(void*)) { return this; }

/* std::ostream::put, write, flush */
void* _ZNSo3putEc(void* this, char c) { return this; }
void* _ZNSo5writeEPKcl(void* this, const char* s, long n) { return this; }
void* _ZNSo5flushEv(void* this) { return this; }

/* std::ostream width, fill, precision */
unsigned long _ZNSo5widthEv(void* this) { return 0; }
unsigned long _ZNSo5widthEm(void* this, unsigned long w) { return 0; }
char _ZNSo4fillEv(void* this) { return ' '; }
char _ZNSo4fillEc(void* this, char c) { return ' '; }
unsigned long _ZNSo9precisionEv(void* this) { return 6; }
unsigned long _ZNSo9precisionEm(void* this, unsigned long p) { return 6; }

/* std::ostream flags, setf, unsetf */
unsigned long _ZNSo5flagsEv(void* this) { return 0; }
unsigned long _ZNSo5flagsEm(void* this, unsigned long f) { return 0; }
unsigned long _ZNSo4setfEm(void* this, unsigned long f) { return 0; }
unsigned long _ZNSo4setfEmm(void* this, unsigned long f, unsigned long mask) { return 0; }
void _ZNSo5unsetfEm(void* this, unsigned long f) {}

/* std::istream stubs */
void* _ZNSirsEPFRSiS_E(void* this, void* (*f)(void*)) { return this; }
void* _ZNSirsERi(void* this, int* val) { *val = 0; return this; }
void* _ZNSirsERl(void* this, long* val) { *val = 0; return this; }
void* _ZNSirsERd(void* this, double* val) { *val = 0; return this; }
void* _ZNSirsERf(void* this, float* val) { *val = 0; return this; }

/* std::istream get, getline */
int _ZNSi3getEv(void* this) { return -1; }
void* _ZNSi7getlineEPcic(void* this, char* buf, int n, char delim) { *buf = '\0'; return this; }
void* _ZNSi4readEPcl(void* this, char* buf, long n) { return this; }

/* std::endl, std::flush, std::hex, std::dec, std::oct */
void* _ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_(void* os) { return os; }
void* _ZSt5flushIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_(void* os) { return os; }
void* _ZSt3hex(void* ios) { return ios; }
void* _ZSt3dec(void* ios) { return ios; }
void* _ZSt3oct(void* ios) { return ios; }

/* ============================================================================
 * std::ios_base
 * ============================================================================ */

void _ZNSt8ios_base4InitC1Ev(void* this) {}
void _ZNSt8ios_base4InitD1Ev(void* this) {}
void _ZNSt8ios_base4InitC2Ev(void* this) {}
void _ZNSt8ios_base4InitD2Ev(void* this) {}

/* ============================================================================
 * std::stringstream
 * ============================================================================ */

void _ZNSt18stringstreamC1Ev(void* this) {}
void _ZNSt18stringstreamC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
void _ZNSt18stringstreamD1Ev(void* this) {}
void _ZNSt18stringstreamC2Ev(void* this) {}
void _ZNSt18stringstreamC2ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}
void _ZNSt18stringstreamD2Ev(void* this) {}
void* _ZNSt18stringstream3strEv(void* this) { return NULL; }
void _ZNSt18stringstream5strERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* s) {}

/* ============================================================================
 * std::mutex and threading primitives
 * ============================================================================ */

void _ZNSt5mutex4lockEv(void* this) {}
void _ZNSt5mutex6unlockEv(void* this) {}
void _ZNSt5mutex8try_lockEv(void* this) { return; }
void _ZNSt5mutexC1Ev(void* this) {}
void _ZNSt5mutexC2Ev(void* this) {}
void _ZNSt5mutexD1Ev(void* this) {}
void _ZNSt5mutexD2Ev(void* this) {}

/* std::recursive_mutex */
void _ZNSt16recursive_mutex4lockEv(void* this) {}
void _ZNSt16recursive_mutex6unlockEv(void* this) {}
void _ZNSt16recursive_mutex8try_lockEv(void* this) {}
void _ZNSt16recursive_mutexC1Ev(void* this) {}
void _ZNSt16recursive_mutexD1Ev(void* this) {}

/* std::condition_variable */
void _ZNSt18condition_variable10notify_oneEv(void* this) {}
void _ZNSt18condition_variable10notify_allEv(void* this) {}
void _ZNSt18condition_variable4waitERSt11unique_lockISt5mutexE(void* this, void* lock) {}
void _ZNSt18condition_variableC1Ev(void* this) {}
void _ZNSt18condition_variableD1Ev(void* this) {}

/* std::thread */
void* _ZNSt6thread20hardware_concurrencyEv(void) { return (void*)4; }
void _ZNSt6thread4joinEv(void* this) {}
void _ZNSt6thread9joinableEv(void* this) { return 0; }
void _ZNSt6thread6detachEv(void* this) {}

/* std::this_thread::sleep_for, sleep_until, yield */
void _ZNSt11this_thread9sleep_forERKNSt6chrono8durationIlSt5ratioILl1ELl0EEEE(void* dur) {}
void _ZNSt11this_thread11sleep_untilERKNSt6chrono10time_pointINS0_3_V212steady_clockENS0_8durationIlSt5ratioILl1ELl0EEEEEE(void* tp) {}
void _ZNSt11this_thread5yieldEv(void) {}

/* std::call_once */
void _ZSt9call_onceIRMSt9once_flagRFvvEJEvEET0_T1_DpOT2_(void* flag, void (*func)(void)) {}

/* ============================================================================
 * std::shared_ptr and std::weak_ptr
 * ============================================================================ */

/* These are template classes - just provide some key symbols */

/* ============================================================================
 * std::function
 * ============================================================================ */

/* Template class - key symbols provided via bad_function_call above */

/* ============================================================================
 * std::vector (minimal)
 * ============================================================================ */

/* Template instantiations - most common ones */
void* _ZNSt6vectorISsSaISsEEC1Ev(void* this) { return this; }
void _ZNSt6vectorISsSaISsEED1Ev(void* this) {}
void _ZNSt6vectorISsSaISsEE9push_backERKSs(void* this, void* val) {}
void* _ZNSt6vectorISsSaISsEE4backEv(void* this) { return NULL; }
void* _ZNSt6vectorISsSaISsEE5beginEv(void* this) { return NULL; }
void* _ZNSt6vectorISsSaISsEE3endEv(void* this) { return NULL; }
unsigned long _ZNSt6vectorISsSaISsEE4sizeEv(void* this) { return 0; }
unsigned long _ZNSt6vectorISsSaISsEE8capacityEv(void* this) { return 0; }
void _ZNSt6vectorISsSaISsEE5clearEv(void* this) {}
void _ZNSt6vectorISsSaISsEE9pop_backEv(void* this) {}

/* ============================================================================
 * std::map (minimal)
 * ============================================================================ */

void* _ZNSt3mapISsSsSt4lessISsESaISt4pairIKSsSsEEEC1Ev(void* this) { return this; }
void _ZNSt3mapISsSsSt4lessISsESaISt4pairIKSsSsEEED1Ev(void* this) {}

/* ============================================================================
 * std::set (minimal)
 * ============================================================================ */

void* _ZNSt3setISsSt4lessISsESaISsEEC1Ev(void* this) { return this; }
void _ZNSt3setISsSt4lessISsESaISsEEED1Ev(void* this) {}

/* ============================================================================
 * std::list (minimal)
 * ============================================================================ */

void* _ZNSt4listISsSaISsEEC1Ev(void* this) { return this; }
void _ZNSt4listISsSaISsEED1Ev(void* this) {}

/* ============================================================================
 * std::queue (minimal)
 * ============================================================================ */

void* _ZNSt5queueISsSt5dequeISsSaISsEEEC1Ev(void* this) { return this; }
void _ZNSt5queueISsSt5dequeISsSaISsEED1Ev(void* this) {}

/* ============================================================================
 * std::deque (minimal)
 * ============================================================================ */

void* _ZNSt5dequeISsSaISsEEC1Ev(void* this) { return this; }
void _ZNSt5dequeISsSaISsEED1Ev(void* this) {}

/* ============================================================================
 * UTILITY FUNCTIONS
 * ============================================================================ */

/* std::terminate */
void _ZSt9terminatev(void) { for (;;) {} }

/* std::unexpected */
void _ZSt10unexpectedv(void) {}

/* std::set_terminate */
void* _ZSt13set_terminatePFvvE(void (*f)(void)) { return NULL; }

/* std::set_unexpected */
void* _ZSt14set_unexpectedPFvvE(void (*f)(void)) { return NULL; }

/* std::current_exception */
void* _ZSt17current_exceptionv(void) { return NULL; }

/* std::rethrow_exception */
void _ZSt17rethrow_exceptionNSt15__exception_ptr13exception_ptrE(void* p) { for (;;) {} }

/* std::make_exception_ptr */
void* _ZSt17make_exception_ptrINSt15__exception_ptr13exception_ptrEEaS1_RKT_(void* p) { return p; }

/* std::move, std::forward */
void* _ZSt4moveIRiEONSt16remove_referenceIT_E4typeEOS2_(void* t) { return t; }
void* _ZSt4moveIRlEONSt16remove_referenceIT_E4typeEOS2_(void* t) { return t; }
void* _ZSt4moveIRdEONSt16remove_referenceIT_E4typeEOS2_(void* t) { return t; }
void* _ZSt4moveIRfEONSt16remove_referenceIT_E4typeEOS2_(void* t) { return t; }
void* _ZSt4moveIRcEONSt16remove_referenceIT_E4typeEOS2_(void* t) { return t; }

/* std::swap */
void _ZSt4swapIiENSt9enable_ifIXsrSt6__and_IJSt21is_move_constructibleIT_ESt18is_move_assignableIS2_EEE5valueEvE4typeERS2_S5_(int* a, int* b) {}
void _ZSt4swapIlENSt9enable_ifIXsrSt6__and_IJSt21is_move_constructibleIT_ESt18is_move_assignableIS2_EEE5valueEvE4typeERS2_S5_(long* a, long* b) {}
void _ZSt4swapIdENSt9enable_ifIXsrSt6__and_IJSt21is_move_constructibleIT_ESt18is_move_assignableIS2_EEE5valueEvE4typeERS2_S5_(double* a, double* b) {}
void _ZSt4swapIfENSt9enable_ifIXsrSt6__and_IJSt21is_move_constructibleIT_ESt18is_move_assignableIS2_EEE5valueEvE4typeERS2_S5_(float* a, float* b) {}

/* std::addressof */
void* _ZSt7addressofIiEPT_RS0_(int* r) { return r; }
void* _ZSt7addressofIlEPT_RS0_(long* r) { return r; }
void* _ZSt7addressofIdEPT_RS0_(double* r) { return r; }
void* _ZSt7addressofIfEPT_RS0_(float* r) { return r; }
void* _ZSt7addressofIcEPT_RS0_(char* r) { return r; }
void* _ZSt7addressofIvEPT_RS0_(void* r) { return r; }

/* std::pair */
void* _ZNSt4pairIKSsSsEC1Ev(void* this) { return this; }
void* _ZNSt4pairIKSsSsEC1ERKSsS2_(void* this, void* k, void* v) { return this; }

/* std::less */
unsigned char _ZNKSt4lessIiEclERKiS2_(int* a, int* b) { return *a < *b; }
unsigned char _ZNKSt4lessIlEclERKlS2_(long* a, long* b) { return *a < *b; }

/* std::equal_to */
unsigned char _ZNKSt8equal_toIiEclERKiS2_(int* a, int* b) { return *a == *b; }

/* std::hash */
unsigned long _ZNSt4hashIiEclEi(int v) { return (unsigned long)v; }
unsigned long _ZNSt4hashIlEclEl(long v) { return (unsigned long)v; }
unsigned long _ZNSt4hashIvEclEPv(void* v) { return (unsigned long)v; }

/* ============================================================================
 * CHRONO
 * ============================================================================ */

/* std::chrono::system_clock::now() */
void* _ZNSt6chrono12system_clock3nowEv(void) { return NULL; }

/* std::chrono::steady_clock::now() */
void* _ZNSt6chrono12steady_clock3nowEv(void) { return NULL; }

/* std::chrono::high_resolution_clock::now() */
void* _ZNSt6chrono20high_resolution_clock3nowEv(void) { return NULL; }

/* ============================================================================
 * ATOMIC
 * ============================================================================ */

/* std::atomic_flag */
unsigned char _ZNSt12atomic_flag5clearESt12memory_order(void* this, int order) { return 0; }
unsigned char _ZNSt12atomic_flag12test_and_setESt12memory_order(void* this, int order) { return 0; }

/* ============================================================================
 * GLIBCXX VERSION SYMBOLS
 * These are version tags that libstdc++.so.6 exports
 * ============================================================================ */

/* Version symbols - we just provide dummy definitions */
void* _ZNSt7num_getIcSt19istreambuf_iteratorIcSt11char_traitsIcEEEC2Ej = NULL;
void* _ZNSt7num_putIcSt19ostreambuf_iteratorIcSt11char_traitsIcEEEC2Ej = NULL;

/* More common symbols that may be referenced */
void _ZNSt9basic_iosIcSt11char_traitsIcEE8setstateESt12_Ios_Iostate(void* this, int state) {}
void _ZNSt9basic_iosIcSt11char_traitsIcEE4initEPSt15basic_streambufIcS1_E(void* this, void* buf) {}
void* _ZNSt9basic_iosIcSt11char_traitsIcEE5rdbufEv(void* this) { return NULL; }
void _ZNSt9basic_iosIcSt11char_traitsIcEE5clearESt12_Ios_Iostate(void* this, int state) {}
unsigned char _ZNKSt9basic_iosIcSt11char_traitsIcEE4goodEv(void* this) { return 1; }
unsigned char _ZNKSt9basic_iosIcSt11char_traitsIcEE4failEv(void* this) { return 0; }
unsigned char _ZNKSt9basic_iosIcSt11char_traitsIcEE4eofEv(void* this) { return 0; }
unsigned char _ZNKSt9basic_iosIcSt11char_traitsIcEE4badEv(void* this) { return 0; }
int _ZNKSt9basic_iosIcSt11char_traitsIcEE6rdstateEv(void* this) { return 0; }

/* basic_streambuf stubs */
void _ZNSt15basic_streambufIcSt11char_traitsIcEEC2Ev(void* this) {}
void _ZNSt15basic_streambufIcSt11char_traitsIcEED2Ev(void* this) {}
void _ZNSt15basic_streambufIcSt11char_traitsIcEE4syncEv(void* this) {}

/* basic_istream */
void _ZNSt14basic_istreamIcSt11char_traitsIcEED1Ev(void* this) {}
void _ZNSt14basic_istreamIcSt11char_traitsIcEED2Ev(void* this) {}

/* basic_ostream */
void _ZNSt13basic_ostreamIcSt11char_traitsIcEED1Ev(void* this) {}
void _ZNSt13basic_ostreamIcSt11char_traitsIcEED2Ev(void* this) {}

/* ============================================================================
 * MORE TYPEINFO FOR STD TYPES
 * ============================================================================ */

struct type_info _ZTISt11logic_error = { _logic_error_vtable, "St11logic_error" };
struct type_info _ZTISt12runtime_error = { _runtime_error_vtable, "St12runtime_error" };
struct type_info _ZTISt12out_of_range = { _out_of_range_vtable, "St12out_of_range" };
struct type_info _ZTISt12length_error = { _length_error_vtable, "St12length_error" };
struct type_info _ZTISt16invalid_argument = { _invalid_argument_vtable, "St16invalid_argument" };

/* ============================================================================
 * MORE STRING METHODS (C++11 ABI)
 * ============================================================================ */

/* Additional string constructor variants */
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1EPKcmRKSaIcE(void* this, const char* s, unsigned long n, void* a) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EPKcmRKSaIcE(void* this, const char* s, unsigned long n, void* a) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1EmcRKSaIcE(void* this, unsigned long n, char c, void* a) {}
void _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC2EmcRKSaIcE(void* this, unsigned long n, char c, void* a) {}

/* String comparison operators */
unsigned char _ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EEPKS5_(void* lhs, const char* rhs) { return 0; }
unsigned char _ZSteqIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EES9_(void* lhs, void* rhs) { return 0; }
unsigned char _ZStneIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EEPKS5_(void* lhs, const char* rhs) { return 1; }
unsigned char _ZStneIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EES9_(void* lhs, void* rhs) { return 1; }
unsigned char _ZStltIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EES9_(void* lhs, void* rhs) { return 0; }
unsigned char _ZStgtIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EES9_(void* lhs, void* rhs) { return 0; }
unsigned char _ZStleIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EES9_(void* lhs, void* rhs) { return 1; }
unsigned char _ZStgeIcSt11char_traitsIcESaIcEEbRKNSt7__cxx1112basic_stringIT_T0_T1_EES9_(void* lhs, void* rhs) { return 1; }

/* String concatenation operators */
void* _ZStplIcSt11char_traitsIcESaIcEENSt7__cxx1112basic_stringIT_T0_T1_EERKS9_PKS6_(void* lhs, const char* rhs) { return lhs; }
void* _ZStplIcSt11char_traitsIcESaIcEENSt7__cxx1112basic_stringIT_T0_T1_EEPKS6_RKS9_(const char* lhs, void* rhs) { return rhs; }
void* _ZStplIcSt11char_traitsIcESaIcEENSt7__cxx1112basic_stringIT_T0_T1_EERKS9_SA_(void* lhs, void* rhs) { return lhs; }

/* ============================================================================
 * FUTURE / PROMISE
 * ============================================================================ */

void _ZNSt12future_errorC1ESt13future_err_code(void* this, int code) {}
void _ZNSt12future_errorD1Ev(void* this) {}
const char* _ZNKSt12future_error4whatEv(void* this) { return "std::future_error"; }

/* ============================================================================
 * REGEX
 * ============================================================================ */

void* _ZNSt11regex_errorC1ESt15regex_constants10error_type(void* this, int code) { return this; }
void _ZNSt11regex_errorD1Ev(void* this) {}

/* ============================================================================
 * SYSTEM ERROR
 * ============================================================================ */

void _ZNSt12system_errorC1ESt10error_codeRKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* code, void* msg) {}
void _ZNSt12system_errorC1EiRKSt13error_categoryRKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, int ev, void* cat, void* msg) {}
void _ZNSt12system_errorD1Ev(void* this) {}
const char* _ZNKSt12system_error4whatEv(void* this) { return "std::system_error"; }

/* error_code */
void _ZNSt10error_codeC1Ev(void* this) {}
void _ZNSt10error_codeC1EiRKSt13error_category(void* this, int ev, void* cat) {}
int _ZNKSt10error_code8categoryEv(void* this) { return 0; }
int _ZNKSt10error_code7messageEv(void* this) { return 0; }

/* error_category */
void* _ZNSt13error_categoryC2Ev(void* this) { return this; }
void _ZNSt13error_categoryD2Ev(void* this) {}

/* ============================================================================
 * TYPE_TRAITS
 * ============================================================================ */

/* These are compile-time, but some runtime helpers may be referenced */

/* ============================================================================
 * MEMORY
 * ============================================================================ */

/* std::unique_ptr */
void* _ZNSt10unique_ptrIiSt14default_deleteIiEEC1EPi(void* this, int* p) { return this; }
void _ZNSt10unique_ptrIiSt14default_deleteIiEED1Ev(void* this) {}
void* _ZNSt10unique_ptrIiSt14default_deleteIiEE3getEv(void* this) { return NULL; }
void _ZNSt10unique_ptrIiSt14default_deleteIiEE5resetEPi(void* this, int* p) {}
void* _ZNSt10unique_ptrIiSt14default_deleteIiEE7releaseEv(void* this) { return NULL; }

/* std::shared_ptr */
void* _ZNSt10shared_ptrIiEC1Ev(void* this) { return this; }
void* _ZNSt10shared_ptrIiEC1EPi(void* this, int* p) { return this; }
void _ZNSt10shared_ptrIiED1Ev(void* this) {}
void* _ZNSt10shared_ptrIiEE3getEv(void* this) { return NULL; }
long _ZNKSt10shared_ptrIiE3useEv(void* this) { return 1; }

/* std::weak_ptr */
void* _ZNSt8weak_ptrIiEC1Ev(void* this) { return this; }
void* _ZNSt8weak_ptrIiEC1ERKSt10shared_ptrIiE(void* this, void* sp) { return this; }
void _ZNSt8weak_ptrIiED1Ev(void* this) {}
void* _ZNSt8weak_ptrIiE4lockEv(void* this) { return NULL; }

/* std::enable_shared_from_this */
void _ZNSt20enable_shared_from_thisIiEC2Ev(void* this) {}

/* std::default_delete */
void _ZNSt14default_deleteIiEclEPi(void* this, int* p) {}

/* std::make_shared */
void* _ZSt15make_sharedIiENSt9enable_ifIXsrSt6__and_IJSt21is_move_constructibleIT_ESt18is_move_assignableIS2_EEE5valueEvE4typeEiERKi(int* args) { return NULL; }

/* std::make_unique */
void* _ZSt12make_uniqueIiENSt9enable_ifIXsrSt6__and_IJSt21is_move_constructibleIT_ESt18is_move_assignableIS2_EEE5valueEvE4typeERKi(int* args) { return NULL; }

/* ============================================================================
 * TUPLE
 * ============================================================================ */

void* _ZNSt5tupleIJiEEC1Ev(void* this) { return this; }
void* _ZNSt5tupleIJiEEC1IiEERKT_(void* this, int* v) { return this; }

/* ============================================================================
 * OPTIONAL
 * ============================================================================ */

void* _ZNSt8optionalIiEC1Ev(void* this) { return this; }
void* _ZNSt8optionalIiEC1IiEERKT_(void* this, int* v) { return this; }
void _ZNSt8optionalIiED1Ev(void* this) {}
void* _ZNSt8optionalIiE5valueEv(void* this) { return NULL; }
unsigned char _ZNKSt8optionalIiE8has_valueEv(void* this) { return 0; }

/* ============================================================================
 * VARIANT
 * ============================================================================ */

void* _ZNSt7variantIJiEEC1Ev(void* this) { return this; }
void _ZNSt7variantIJiEED1Ev(void* this) {}
void* _ZNSt7variantIJiEE5indexEv(void* this) { return 0; }

/* ============================================================================
 * ANY
 * ============================================================================ */

void* _ZNSt3anyC1Ev(void* this) { return this; }
void _ZNSt3anyD1Ev(void* this) {}

/* ============================================================================
 * FUNCTIONAL
 * ============================================================================ */

/* std::placeholders */
void* _ZSt9addressofISt10shared_ptrIiEEPT_RS2_(void* r) { return r; }

/* ============================================================================
 * ALGORITHM (runtime parts)
 * ============================================================================ */

/* Most algorithms are header-only, but some may have explicit instantiations */

/* ============================================================================
 * LOCALE
 * ============================================================================ */

void* _ZNSt6localeC1Ev(void* this) { return this; }
void _ZNSt6localeD1Ev(void* this) {}
void* _ZNSt6locale5facetC2Em(void* this, unsigned long refs) { return this; }
void _ZNSt6locale5facetD2Ev(void* this) {}

/* std::numpunct */
void* _ZNSt8numpunctIcEC2Em(void* this, unsigned long refs) { return this; }

/* ============================================================================
 * CODECVT
 * ============================================================================ */

void* _ZNSt7codecvtIcc11__mb_state_tEC2Em(void* this, unsigned long refs) { return this; }

/* ============================================================================
 * RANDOM
 * ============================================================================ */

void* _ZNSt13random_deviceC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE(void* this, void* token) { return this; }
void _ZNSt13random_deviceD1Ev(void* this) {}
unsigned int _ZNSt13random_deviceclEv(void* this) { return 0; }

/* ============================================================================
 * COMPLEX
 * ============================================================================ */

void* _ZNSt7complexIdEC1Edd(void* this, double re, double im) { return this; }
void* _ZNSt7complexIfEC1Eff(void* this, float re, float im) { return this; }

/* ============================================================================
 * VALARRAY
 * ============================================================================ */

void* _ZNSt8valarrayIdEC1Em(void* this, unsigned long n) { return this; }
void _ZNSt8valarrayIdED1Ev(void* this) {}

/* ============================================================================
 * BITSET
 * ============================================================================ */

void* _ZNSt6bitsetILm32EEC1Ev(void* this) { return this; }
void _ZNSt6bitsetILm32EEC2Ev(void* this) {}

/* ============================================================================
 * STACK
 * ============================================================================ */

void* _ZNSt5stackISt5dequeISsSaISsEEEC1Ev(void* this) { return this; }
void _ZNSt5stackISt5dequeISsSaISsEEED1Ev(void* this) {}

/* ============================================================================
 * PRIORITY_QUEUE
 * ============================================================================ */

void* _ZNSt14priority_queueISsSt6vectorISsSaISsEESt4lessISsEEC1Ev(void* this) { return this; }
void _ZNSt14priority_queueISsSt6vectorISsSaISsEESt4lessISsEED1Ev(void* this) {}

/* ============================================================================
 * UNORDERED_MAP/SET
 * ============================================================================ */

void* _ZNSt13unordered_mapISsSsSt4hashISsESt8equal_toISsESaISt4pairIKSsSsEEEC1Ev(void* this) { return this; }
void _ZNSt13unordered_mapISsSsSt4hashISsESt8equal_toISsESaISt4pairIKSsSsEEED1Ev(void* this) {}

void* _ZNSt13unordered_setISsSt4hashISsESt8equal_toISsESaISsEEC1Ev(void* this) { return this; }
void _ZNSt13unordered_setISsSt4hashISsESt8equal_toISsESaISsEEED1Ev(void* this) {}

/* ============================================================================
 * FORWARD_LIST
 * ============================================================================ */

void* _ZNSt10forward_listISsSaISsEEC1Ev(void* this) { return this; }
void _ZNSt10forward_listISsSaISsEED1Ev(void* this) {}

/* ============================================================================
 * ARRAY
 * ============================================================================ */

/* Template - no runtime symbols needed typically */

/* ============================================================================
 * RATIO
 * ============================================================================ */

/* Compile-time only */

/* ============================================================================
 * TYPEINDEX
 * ============================================================================ */

void* _ZNSt8type_indexC1ERKSt9type_info(void* this, void* ti) { return this; }
void _ZNSt8type_indexD1Ev(void* this) {}

/* ============================================================================
 * SCOPED_ALLOCATOR
 * ============================================================================ */

void* _ZNSt15scoped_allocatorISaIiEEC1Ev(void* this) { return this; }

/* ============================================================================
 * INITIALIZER_LIST
 * ============================================================================ */

/* Compiler built-in */

/* ============================================================================
 * EXCEPTION_PTR
 * ============================================================================ */

void* _ZNSt15__exception_ptr13exception_ptrC1Ev(void* this) { return this; }
void _ZNSt15__exception_ptr13exception_ptrD1Ev(void* this) {}
void* _ZNSt15__exception_ptr13exception_ptr10_M_releaseEv(void* this) { return NULL; }

/* ============================================================================
 * NESTED_EXCEPTION
 * ============================================================================ */

void _ZNSt16nested_exceptionC2Ev(void* this) {}
void _ZNSt16nested_exceptionD2Ev(void* this) {}

/* ============================================================================
 * END
 * ============================================================================ */
