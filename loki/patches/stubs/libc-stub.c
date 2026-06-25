/* libc-stub.c - Minimal libc.so.6 stub for Android WebRTC compatibility
 *
 * libwebrtc-java-linux-aarch64.so has DT_NEEDED: libc.so.6 (glibc SONAME).
 * Android uses Bionic with SONAME libc.so.
 *
 * This stub only sets SONAME to libc.so.6 to satisfy DT_NEEDED.
 * All symbols (malloc, pthread_*, etc.) are resolved from Bionic's libc.so
 * in the global group (loaded by main executable).
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -nostdlib \
 *     -Wl,-soname,libc.so.6 -o libc.so.6 libc-stub.c
 */

/* Empty - no symbols exported. All resolved from global group (Bionic libc.so) */