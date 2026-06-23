/* libXcursor-stub.c - Minimal libXcursor stub for Android WebRTC compatibility
 *
 * X Cursor extension stub for cursor theme handling.
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libXcursor.so.1 \
 *     -o libXcursor.so.1 libXcursor-stub.c
 */

void* XcursorLibraryLoadImage(const char *file, const char *theme, int size) {
    return (void*)0;
}

void* XcursorLibraryLoadImages(const char *file, const char *theme, int size) {
    return (void*)0;
}

void XcursorImagesDestroy(void *images) {}

void* XcursorImageCreate(int width, int height) {
    return (void*)0;
}

void XcursorImageDestroy(void *image) {}

unsigned long XcursorImageLoadCursor(void *display, void *image) {
    return 0;
}

unsigned long XcursorImagesLoadCursor(void *display, void *images) {
    return 0;
}

void* XcursorGetTheme(void *display) {
    return (void*)0;
}

int XcursorGetDefaultSize(void *display) {
    return 0;
}

int XcursorGetThemeCore(void *display) {
    return 0;
}

void XcursorSetThemeCore(void *display, int core) {}

void* XcursorGetThemeData(void *display) {
    return (void*)0;
}

void XcursorSetThemeData(void *display, void *data) {}