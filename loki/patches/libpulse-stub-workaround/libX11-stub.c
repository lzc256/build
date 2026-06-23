/* libX11-stub.c - Minimal libX11 stub for Android WebRTC compatibility
 *
 * Minecraft 26.2+ P2P uses WebRTC data-channel only.
 * The libwebrtc-native library has DT_NEEDED: libX11.so.6 from the
 * X11 display module, but data-channel doesn't use X11.
 *
 * This stub provides no-op implementations of libX11 symbols
 * to satisfy the linker at dlopen time.
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libX11.so.6 \
 *     -o libX11.so.6 libX11-stub.c
 */

/* ============================================================================
 * libX11.so.6 - X11 core display and window functions
 * ============================================================================ */

void* XOpenDisplay(const char *name) {
    return (void*)0;
}

void XCloseDisplay(void *display) {}

void* XDefaultScreenOfDisplay(void *display) {
    return (void*)0;
}

int XDefaultScreen(void *display) {
    return 0;
}

unsigned long XDefaultRootWindow(void *display) {
    return 0;
}

void* XDefaultVisualOfScreen(void *screen) {
    return (void*)0;
}

unsigned long XDefaultDepthOfScreen(void *screen) {
    return 0;
}

void* XDefaultGC(void *display, int screen) {
    return (void*)0;
}

unsigned long XWhitePixel(void *display, int screen) {
    return 0;
}

unsigned long XBlackPixel(void *display, int screen) {
    return 0;
}

int XDisplayWidth(void *display, int screen) {
    return 0;
}

int XDisplayHeight(void *display, int screen) {
    return 0;
}

int XDisplayWidthMM(void *display, int screen) {
    return 0;
}

int XDisplayHeightMM(void *display, int screen) {
    return 0;
}

void* XRootWindow(void *display, int screen) {
    return (void*)0;
}

int XFlush(void *display) {
    return 0;
}

int XSync(void *display, int discard) {
    return 0;
}

/* X11 window operations */
unsigned long XCreateWindow(
    void *display, unsigned long parent,
    int x, int y, unsigned int width, unsigned int height,
    unsigned int border_width, int depth, unsigned int class,
    void *visual, unsigned long valuemask, void *attributes
) {
    return 0;
}

unsigned long XCreateSimpleWindow(
    void *display, unsigned long parent,
    int x, int y, unsigned int width, unsigned int height,
    unsigned int border_width, unsigned long border,
    unsigned long background
) {
    return 0;
}

void XDestroyWindow(void *display, unsigned long window) {}

void XMapWindow(void *display, unsigned long window) {}

void XUnmapWindow(void *display, unsigned long window) {}

void XMoveWindow(void *display, unsigned long window, int x, int y) {}

void XResizeWindow(void *display, unsigned long window, unsigned int width, unsigned int height) {}

void XMoveResizeWindow(void *display, unsigned long window, int x, int y, unsigned int width, unsigned int height) {}

/* X11 GC (Graphics Context) */
void* XCreateGC(void *display, unsigned long drawable, unsigned long valuemask, void *values) {
    return (void*)0;
}

void XFreeGC(void *display, void *gc) {}

int XChangeGC(void *display, void *gc, unsigned long valuemask, void *values) {
    return 0;
}

/* X11 drawing */
int XDrawLine(void *display, unsigned long drawable, void *gc, int x1, int y1, int x2, int y2) {
    return 0;
}

int XDrawRectangle(void *display, unsigned long drawable, void *gc, int x, int y, unsigned int width, unsigned int height) {
    return 0;
}

int XFillRectangle(void *display, unsigned long drawable, void *gc, int x, int y, unsigned int width, unsigned int height) {
    return 0;
}

int XDrawPoint(void *display, unsigned long drawable, void *gc, int x, int y) {
    return 0;
}

/* X11 pixmap */
unsigned long XCreatePixmap(void *display, unsigned long drawable, unsigned int width, unsigned int height, unsigned int depth) {
    return 0;
}

void XFreePixmap(void *display, unsigned long pixmap) {}

/* X11 events */
int XNextEvent(void *display, void *event) {
    return 0;
}

int XPeekEvent(void *display, void *event) {
    return 0;
}

int XEventsQueued(void *display, int mode) {
    return 0;
}

int XPending(void *display) {
    return 0;
}

int XSendEvent(void *display, unsigned long w, int propagate, long event_mask, void *event) {
    return 0;
}

void XSelectInput(void *display, unsigned long window, long event_mask) {}

/* X11 property */
int XGetWindowProperty(
    void *display, unsigned long window, void *atom,
    long offset, long length, int delete, void *req_type,
    void *actual_type, int *actual_format, unsigned long *nitems,
    unsigned long *bytes_after, unsigned char **prop
) {
    return 1; /* BadValue */
}

int XChangeProperty(void *display, unsigned long window, void *atom, void *type, int format, int mode, const unsigned char *data, int nelements) {
    return 0;
}

void XDeleteProperty(void *display, unsigned long window, void *atom) {}

/* X11 atom */
void* XInternAtom(void *display, const char *atom_name, int only_if_exists) {
    return (void*)0;
}

const char* XGetAtomName(void *display, void *atom) {
    return (const char*)0;
}

/* X11 window attributes */
int XGetWindowAttributes(void *display, unsigned long window, void *attributes) {
    return 0; /* False */
}

int XChangeWindowAttributes(void *display, unsigned long window, unsigned long valuemask, void *attributes) {
    return 0;
}

/* X11 selection and clipboard */
unsigned long XGetSelectionOwner(void *display, void *atom) {
    return 0;
}

void XSetSelectionOwner(void *display, void *atom, unsigned long owner, unsigned long time) {}

/* X11 grab */
int XGrabPointer(void *display, unsigned long grab_window, int owner_events, unsigned int event_mask, int pointer_mode, int keyboard_mode, unsigned long confine_to, unsigned long cursor, unsigned long time) {
    return 1; /* AlreadyGrabbed */
}

void XUngrabPointer(void *display, unsigned long time) {}

int XGrabKeyboard(void *display, unsigned long grab_window, int owner_events, int pointer_mode, int keyboard_mode, unsigned long time) {
    return 1; /* AlreadyGrabbed */
}

void XUngrabKeyboard(void *display, unsigned long time) {}

/* X11 keyboard */
int XLookupString(void *event, char *buffer, int nbytes, void *keysym, void *status) {
    return 0;
}

void* XKeysymToKeycode(void *display, unsigned long keysym) {
    return (void*)0;
}

unsigned long XKeycodeToKeysym(void *display, unsigned int keycode, int index) {
    return 0;
}

/* X11 cursor */
unsigned long XCreateFontCursor(void *display, unsigned int shape) {
    return 0;
}

void XFreeCursor(void *display, unsigned long cursor) {}

/* X11 free */
int XFree(void *data) {
    return 0;
}

/* X11 error handling */
typedef void (*XErrorHandler)(void *, void *);
XErrorHandler XSetErrorHandler(XErrorHandler handler) {
    return (XErrorHandler)0;
}

typedef int (*XIOErrorHandler)(void *);
XIOErrorHandler XSetIOErrorHandler(XIOErrorHandler handler) {
    return (XIOErrorHandler)0;
}

/* X11 connection */
int XConnectionNumber(void *display) {
    return -1;
}

void* XDisplayName(const char *string) {
    return (void*)0;
}

int XScreenCount(void *display) {
    return 0;
}
