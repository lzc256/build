/* libpthread-stub.c - Minimal libpthread.so.0 stub for Android WebRTC compatibility
 *
 * libwebrtc-native has DT_NEEDED: libpthread.so.0 (glibc's pthread library).
 * Android uses Bionic, which has pthread functions in libc.so directly.
 *
 * This stub provides the SONAME and exports pthread symbols that will be
 * resolved from Android's libc.so (global group).
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -nostdlib -Wl,-soname,libpthread.so.0 \
 *     -o libpthread.so.0 libpthread-stub.c
 */

#include <stdint.h>
#include <stddef.h>

/* pthread_t is typically unsigned long on aarch64 */
typedef unsigned long pthread_t;
typedef unsigned long pthread_attr_t;
typedef unsigned long pthread_mutex_t;
typedef unsigned long pthread_cond_t;
typedef unsigned long pthread_rwlock_t;
typedef unsigned long pthread_key_t;
typedef unsigned long pthread_once_t;
typedef unsigned long sem_t;

/* Thread functions - will resolve from Android's libc.so */
int pthread_create(pthread_t* thread, const void* attr, void* (*start_routine)(void*), void* arg) {
    /* Stub - real implementation in Android libc.so */
    return -1;
}

int pthread_join(pthread_t thread, void** retval) { return 0; }
int pthread_detach(pthread_t thread) { return 0; }
int pthread_exit(void* retval) { for(;;) {} }
pthread_t pthread_self(void) { return 0; }
int pthread_equal(pthread_t t1, pthread_t t2) { return t1 == t2; }

/* Thread attributes */
int pthread_attr_init(pthread_attr_t* attr) { return 0; }
int pthread_attr_destroy(pthread_attr_t* attr) { return 0; }
int pthread_attr_setstacksize(pthread_attr_t* attr, size_t stacksize) { return 0; }
int pthread_attr_getstacksize(const pthread_attr_t* attr, size_t* stacksize) { *stacksize = 0; return 0; }
int pthread_attr_setstack(pthread_attr_t* attr, void* stackaddr, size_t stacksize) { return 0; }
int pthread_attr_getstack(const pthread_attr_t* attr, void** stackaddr, size_t* stacksize) { return 0; }
int pthread_attr_setdetachstate(pthread_attr_t* attr, int detachstate) { return 0; }
int pthread_attr_getdetachstate(const pthread_attr_t* attr, int* detachstate) { *detachstate = 0; return 0; }
int pthread_attr_setscope(pthread_attr_t* attr, int scope) { return 0; }
int pthread_attr_getscope(const pthread_attr_t* attr, int* scope) { *scope = 0; return 0; }
int pthread_attr_setinheritsched(pthread_attr_t* attr, int inheritsched) { return 0; }
int pthread_attr_getinheritsched(const pthread_attr_t* attr, int* inheritsched) { *inheritsched = 0; return 0; }
int pthread_attr_setschedpolicy(pthread_attr_t* attr, int policy) { return 0; }
int pthread_attr_getschedpolicy(const pthread_attr_t* attr, int* policy) { *policy = 0; return 0; }
int pthread_attr_setschedparam(pthread_attr_t* attr, const void* param) { return 0; }
int pthread_attr_getschedparam(const pthread_attr_t* attr, void* param) { return 0; }
int pthread_attr_setguardsize(pthread_attr_t* attr, size_t guardsize) { return 0; }
int pthread_attr_getguardsize(const pthread_attr_t* attr, size_t* guardsize) { *guardsize = 0; return 0; }

/* Mutex functions */
int pthread_mutex_init(pthread_mutex_t* mutex, const void* attr) { return 0; }
int pthread_mutex_destroy(pthread_mutex_t* mutex) { return 0; }
int pthread_mutex_lock(pthread_mutex_t* mutex) { return 0; }
int pthread_mutex_trylock(pthread_mutex_t* mutex) { return 0; }
int pthread_mutex_unlock(pthread_mutex_t* mutex) { return 0; }
int pthread_mutex_timedlock(pthread_mutex_t* mutex, const void* abstime) { return 0; }

/* Mutex attributes */
int pthread_mutexattr_init(void* attr) { return 0; }
int pthread_mutexattr_destroy(void* attr) { return 0; }
int pthread_mutexattr_settype(void* attr, int type) { return 0; }
int pthread_mutexattr_gettype(const void* attr, int* type) { *type = 0; return 0; }
int pthread_mutexattr_setpshared(void* attr, int pshared) { return 0; }
int pthread_mutexattr_getpshared(const void* attr, int* pshared) { *pshared = 0; return 0; }
int pthread_mutexattr_setprotocol(void* attr, int protocol) { return 0; }
int pthread_mutexattr_getprotocol(const void* attr, int* protocol) { *protocol = 0; return 0; }
int pthread_mutexattr_setrobust(void* attr, int robustness) { return 0; }
int pthread_mutexattr_getrobust(const void* attr, int* robustness) { *robustness = 0; return 0; }

/* Condition variable functions */
int pthread_cond_init(pthread_cond_t* cond, const void* attr) { return 0; }
int pthread_cond_destroy(pthread_cond_t* cond) { return 0; }
int pthread_cond_wait(pthread_cond_t* cond, pthread_mutex_t* mutex) { return 0; }
int pthread_cond_timedwait(pthread_cond_t* cond, pthread_mutex_t* mutex, const void* abstime) { return 0; }
int pthread_cond_signal(pthread_cond_t* cond) { return 0; }
int pthread_cond_broadcast(pthread_cond_t* cond) { return 0; }

/* Condition variable attributes */
int pthread_condattr_init(void* attr) { return 0; }
int pthread_condattr_destroy(void* attr) { return 0; }
int pthread_condattr_setpshared(void* attr, int pshared) { return 0; }
int pthread_condattr_getpshared(const void* attr, int* pshared) { *pshared = 0; return 0; }
int pthread_condattr_setclock(void* attr, int clock_id) { return 0; }
int pthread_condattr_getclock(const void* attr, int* clock_id) { *clock_id = 0; return 0; }

/* Read-write lock functions */
int pthread_rwlock_init(pthread_rwlock_t* rwlock, const void* attr) { return 0; }
int pthread_rwlock_destroy(pthread_rwlock_t* rwlock) { return 0; }
int pthread_rwlock_rdlock(pthread_rwlock_t* rwlock) { return 0; }
int pthread_rwlock_tryrdlock(pthread_rwlock_t* rwlock) { return 0; }
int pthread_rwlock_timedrdlock(pthread_rwlock_t* rwlock, const void* abstime) { return 0; }
int pthread_rwlock_wrlock(pthread_rwlock_t* rwlock) { return 0; }
int pthread_rwlock_trywrlock(pthread_rwlock_t* rwlock) { return 0; }
int pthread_rwlock_timedwrlock(pthread_rwlock_t* rwlock, const void* abstime) { return 0; }
int pthread_rwlock_unlock(pthread_rwlock_t* rwlock) { return 0; }

/* Read-write lock attributes */
int pthread_rwlockattr_init(void* attr) { return 0; }
int pthread_rwlockattr_destroy(void* attr) { return 0; }
int pthread_rwlockattr_setpshared(void* attr, int pshared) { return 0; }
int pthread_rwlockattr_getpshared(const void* attr, int* pshared) { *pshared = 0; return 0; }

/* Thread-specific data */
int pthread_key_create(pthread_key_t* key, void (*destructor)(void*)) { *key = 0; return 0; }
int pthread_key_delete(pthread_key_t key) { return 0; }
void* pthread_getspecific(pthread_key_t key) { return NULL; }
int pthread_setspecific(pthread_key_t key, const void* value) { return 0; }

/* One-time initialization */
int pthread_once(pthread_once_t* once_control, void (*init_routine)(void)) { return 0; }

/* Spin lock */
int pthread_spin_init(void* lock, int pshared) { return 0; }
int pthread_spin_destroy(void* lock) { return 0; }
int pthread_spin_lock(void* lock) { return 0; }
int pthread_spin_trylock(void* lock) { return 0; }
int pthread_spin_unlock(void* lock) { return 0; }

/* Barrier */
int pthread_barrier_init(void* barrier, const void* attr, unsigned count) { return 0; }
int pthread_barrier_destroy(void* barrier) { return 0; }
int pthread_barrier_wait(void* barrier) { return 0; }

/* Cancellation */
int pthread_cancel(pthread_t thread) { return 0; }
int pthread_setcancelstate(int state, int* oldstate) { *oldstate = 0; return 0; }
int pthread_setcanceltype(int type, int* oldtype) { *oldtype = 0; return 0; }
void pthread_testcancel(void) {}

/* Scheduling */
int pthread_setschedparam(pthread_t thread, int policy, const void* param) { return 0; }
int pthread_getschedparam(pthread_t thread, int* policy, void* param) { *policy = 0; return 0; }
int pthread_setschedprio(pthread_t thread, int prio) { return 0; }

/* CPU affinity */
int pthread_setaffinity_np(pthread_t thread, size_t cpusetsize, const void* cpuset) { return 0; }
int pthread_getaffinity_np(pthread_t thread, size_t cpusetsize, void* cpuset) { return 0; }

/* Thread name */
int pthread_setname_np(pthread_t thread, const char* name) { return 0; }
int pthread_getname_np(pthread_t thread, char* name, size_t len) { *name = '\0'; return 0; }

/* Signal handling */
int pthread_sigmask(int how, const void* set, void* oldset) { return 0; }
int pthread_kill(pthread_t thread, int sig) { return 0; }

/* Atfork */
int pthread_atfork(void (*prepare)(void), void (*parent)(void), void (*child)(void)) { return 0; }

/* Semaphore functions (librt on glibc, but often referenced with pthread) */
int sem_init(sem_t* sem, int pshared, unsigned int value) { return 0; }
int sem_destroy(sem_t* sem) { return 0; }
int sem_wait(sem_t* sem) { return 0; }
int sem_trywait(sem_t* sem) { return 0; }
int sem_timedwait(sem_t* sem, const void* abstime) { return 0; }
int sem_post(sem_t* sem) { return 0; }
int sem_getvalue(sem_t* sem, int* sval) { *sval = 0; return 0; }
sem_t* sem_open(const char* name, int oflag, ...) { return NULL; }
int sem_close(sem_t* sem) { return 0; }
int sem_unlink(const char* name) { return 0; }

/* POSIX thread-local storage (__thread keyword support) */
void* __tls_get_addr(void* arg) { return NULL; }
