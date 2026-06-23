/* libXdamage-stub.c - Minimal libXdamage stub for Android WebRTC compatibility
 *
 * X Damage extension stub for tracking damaged regions.
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libXdamage.so.1 \
 *     -o libXdamage.so.1 libXdamage-stub.c
 */

int XDamageQueryExtension(void *display, int *event_base, int *error_base) {
    return 0; /* False */
}

int XDamageQueryVersion(void *display, int *major_version, int *minor_version) {
    if (major_version) *major_version = 1;
    if (minor_version) *minor_version = 1;
    return 0;
}

unsigned long XDamageCreate(void *display, unsigned long drawable, int level) {
    return 0;
}

void XDamageDestroy(void *display, unsigned long damage) {}

void XDamageSubtract(void *display, unsigned long damage, void *repair, void *parts) {}

void* XDamageAdd(void *display, unsigned long drawable, void *region) {
    return (void*)0;
}
