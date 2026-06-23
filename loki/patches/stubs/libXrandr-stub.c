/* libXrandr-stub.c - Minimal libXrandr stub for Android WebRTC compatibility
 *
 * X RandR (Resize and Rotate) extension stub.
 * libwebrtc-native has DT_NEEDED: libXrandr.so.2.
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libXrandr.so.2 \
 *     -o libXrandr.so.2 libXrandr-stub.c
 */

/* XRandR version */
int XRRQueryVersion(void *display, int *major_version, int *minor_version) {
    if (major_version) *major_version = 1;
    if (minor_version) *minor_version = 5;
    return 1; /* True */
}

/* XRandR screen configuration */
void* XRRGetScreenInfo(void *display, unsigned long root) {
    return (void*)0;
}

void XRRFreeScreenInfo(void *screen_info) {}

/* XRandR screen size */
int XRRConfigCurrentConfiguration(void *screen_info, void *rotation) {
    return 0;
}

int XRRConfigCurrentRate(void *screen_info) {
    return 0;
}

/* XRandR screen sizes */
void* XRRSizes(void *screen_info, int *nsizes) {
    if (nsizes) *nsizes = 0;
    return (void*)0;
}

void* XRRRates(void *screen_info, int size_index, int *nrates) {
    if (nrates) *nrates = 0;
    return (void*)0;
}

/* XRandR change configuration */
int XRRSetScreenConfig(void *display, void *screen_info, unsigned long root,
                       int size_index, void *rotation, unsigned long timestamp) {
    return 0; /* False */
}

int XRRSetScreenConfigAndRate(void *display, void *screen_info, unsigned long root,
                               int size_index, void *rotation, short rate, unsigned long timestamp) {
    return 0; /* False */
}

/* XRandR screen current info */
void* XRRGetScreenCurrentInfo(void *display, unsigned long root) {
    return (void*)0;
}

/* XRandR output info */
void* XRRGetOutputInfo(void *display, void *resources, unsigned long output) {
    return (void*)0;
}

void XRRFreeOutputInfo(void *output_info) {}

/* XRandR crtc info */
void* XRRGetCrtcInfo(void *display, void *resources, unsigned long crtc) {
    return (void*)0;
}

void XRRFreeCrtcInfo(void *crtc_info) {}

/* XRandR screen resources */
void* XRRGetScreenResources(void *display, unsigned long window) {
    return (void*)0;
}

void* XRRGetScreenResourcesCurrent(void *display, unsigned long window) {
    return (void*)0;
}

void XRRFreeScreenResources(void *resources) {}

/* XRandR output and crtc */
unsigned long XRRGetOutputPrimary(void *display, unsigned long window) {
    return 0;
}

void XRRSetOutputPrimary(void *display, unsigned long window, unsigned long output) {}

int XRRSetCrtcConfig(void *display, void *resources, unsigned long crtc,
                     unsigned long timestamp, unsigned long config_timestamp,
                     int x, int y, unsigned long mode, void *rotation,
                     unsigned long *outputs, int noutputs) {
    return 0; /* False */
}

/* XRandR mode info */
void* XRRGetModeInfo(void *display, void *resources, unsigned long mode) {
    return (void*)0;
}

void XRRFreeModeInfo(void *mode_info) {}

/* XRandR property */
void* XRRQueryOutputProperty(void *display, unsigned long output, void *atom) {
    return (void*)0;
}

void XRRConfigureOutputProperty(void *display, unsigned long output, void *atom,
                                 int pending, int range, int num_values, long *values) {}

int XRRChangeOutputProperty(void *display, unsigned long output, void *atom,
                            void *type, int format, int mode,
                            const unsigned char *data, int nelements) {
    return 0;
}

int XRRGetOutputProperty(void *display, unsigned long output, void *atom,
                         long offset, long length, int delete, int pending,
                         void *req_type, void *actual_type, int *actual_format,
                         unsigned long *nitems, unsigned long *bytes_after,
                         unsigned char **prop) {
    return 1; /* BadValue */
}

void XRRDeleteOutputProperty(void *display, unsigned long output, void *atom) {}

/* XRandR provider */
void* XRRGetProviderInfo(void *display, void *resources, unsigned long provider) {
    return (void*)0;
}

void XRRFreeProviderInfo(void *provider_info) {}

unsigned long XRRGetProviderPrimary(void *display, unsigned long window) {
    return 0;
}

void XRRSetProviderPrimary(void *display, unsigned long window, unsigned long provider) {}

int XRRSetProviderOutputSource(void *display, unsigned long provider, unsigned long source_provider) {
    return 0;
}

int XRRSetProviderOffloadSink(void *display, unsigned long provider, unsigned long sink_provider) {
    return 0;
}