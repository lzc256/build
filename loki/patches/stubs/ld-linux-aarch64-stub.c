/* ld-linux-aarch64.so.1 - Minimal glibc dynamic linker stub for Android WebRTC compatibility
 *
 * libwebrtc-java-linux-aarch64.so may have DT_NEEDED: ld-linux-aarch64.so.1 (glibc ld.so).
 * Android uses its own linker at /system/bin/linker64 (SONAME: linker).
 *
 * This stub only sets SONAME to ld-linux-aarch64.so.1 to satisfy DT_NEEDED.
 * No actual dynamic linking services are provided - all symbols resolved from
 * the global group (Android's linker and Bionic libc.so).
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -nostdlib \
 *     -Wl,-soname,ld-linux-aarch64.so.1 -o ld-linux-aarch64.so.1 ld-linux-aarch64-stub.c
 */

/* Empty - no symbols exported. All resolved from global group (Android linker) */
