/* libXcomposite-stub.c - Minimal libXcomposite stub for Android WebRTC compatibility
 *
 * X Composite extension stub.
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libXcomposite.so.1 \
 *     -o libXcomposite.so.1 libXcomposite-stub.c
 */

int XCompositeQueryExtension(void *display, int *event_base, int *error_base) {
    return 0; /* False */
}

int XCompositeQueryVersion(void *display, int *major_versionp, int *minor_versionp) {
    if (major_versionp) *major_versionp = 0;
    if (minor_versionp) *minor_versionp = 4;
    return 0;
}

int XCompositeVersion(void) {
    0; /* 0.4 */
}

unsigned long XCompositeRedirectWindow(void *display, unsigned long window, int update) {
    return 0;
}

unsigned long XCompositeRedirectSubwindows(void *display, unsigned long window, int update) {
    return 0;
}

void XCompositeUnredirectWindow(void *display, unsigned long window, int update) {}

void XCompositeUnredirectSubwindows(void *display, unsigned long window, int update) {}

unsigned long XCompositeCreateRegionFromBorderClip(void *display, unsigned long window) {
    return 0;
}

void* XCompositeGetNameWindowPixmap(void *display, unsigned long window) {
    return (void*)0;
}

void XCompositeReleaseNameWindowPixmap(void *display, unsigned long pixmap) {}

void* XCompositeGetOverlayWindow(void *display, unsigned long window) {
    return (void*)0;
}

void XCompositeReleaseOverlayWindow(void *display, unsigned long overlay) {}
