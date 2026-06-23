/* libXfixes-stub.c - Minimal libXfixes stub for Android WebRTC compatibility
 *
 * Minecraft 26.2+ P2P uses WebRTC data-channel only.
 * The libwebrtc-native library has DT_NEEDED: libXfixes.so.3 from the
 * X11 extension module, but data-channel doesn't use X11.
 *
 * This stub provides no-op implementations of libXfixes symbols
 * to satisfy the linker at dlopen time.
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libXfixes.so.3 \
 *     -o libXfixes.so.3 libXfixes-stub.c
 */

/* ============================================================================
 * libXfixes.so.3 - X Fixes extension
 * ============================================================================ */

/* Query extension */
int XFixesQueryExtension(void *display, int *event_base, int *error_base) {
    return 0; /* False - extension not available */
}

int XFixesQueryVersion(void *display, int *major_version, int *minor_version) {
    return 0; /* False */
}

/* Cursor region operations */
void XFixesSetCursorName(void *display, unsigned long cursor, const char *name) {}

const char* XFixesGetCursorName(void *display, unsigned long cursor) {
    return (const char*)0;
}

void XFixesChangeCursor(void *display, unsigned long source, unsigned long destination) {}

void XFixesChangeCursorByName(void *display, unsigned long source, const char *name) {}

/* Cursor image */
unsigned long XFixesGetCursorImage(void *display) {
    return 0;
}

/* Cursor notification */
void XFixesSelectCursorInput(void *display, unsigned long window, unsigned long event_mask) {}

/* Region operations */
unsigned long XFixesCreateRegion(void *display, void *rectangles, int nrectangles) {
    return 0;
}

void XFixesCreateRegionFromBitmap(void *display, unsigned long bitmap) {}

void XFixesCreateRegionFromWindow(void *display, unsigned long window, int kind) {}

void XFixesCreateRegionFromGC(void *display, void *gc) {}

void XFixesCreateRegionFromPicture(void *display, void *picture) {}

void XFixesDestroyRegion(void *display, unsigned long region) {}

void XFixesSetRegion(void *display, unsigned long region, void *rectangles, int nrectangles) {}

void XFixesCopyRegion(void *display, unsigned long source, unsigned long destination) {}

void XFixesUnionRegion(void *display, unsigned long source1, unsigned long source2, unsigned long destination) {}

void XFixesIntersectRegion(void *display, unsigned long source1, unsigned long source2, unsigned long destination) {}

void XFixesSubtractRegion(void *display, unsigned long source1, unsigned long source2, unsigned long destination) {}

void XFixesInvertRegion(void *display, unsigned long source, void *bounds, unsigned long destination) {}

void XFixesTranslateRegion(void *display, unsigned long region, int dx, int dy) {}

void XFixesRegionExtents(void *display, unsigned long source, unsigned long destination) {}

/* Region picture operations */
void XFixesSetPictureClipRegion(void *display, void *picture, int clip_x_origin, int clip_y_origin, unsigned long region) {}

void XFixesSetWindowShapeRegion(void *display, unsigned long window, int shape_kind, int x, int y, unsigned long region) {}

void XFixesSetGCClipRegion(void *display, void *gc, int clip_x_origin, int clip_y_origin, unsigned long region) {}

/* Selection notification */
void XFixesSelectSelectionInput(void *display, unsigned long window, void *selection, unsigned long event_mask) {}

/* Visibility notification */
void XFixesSelectInput(void *display, unsigned long window, unsigned long event_mask) {}
