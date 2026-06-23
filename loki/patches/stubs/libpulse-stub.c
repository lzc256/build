/* libpulse-stub.c - Minimal PulseAudio stub for Android WebRTC compatibility
 *
 * Minecraft 26.2+ P2P uses WebRTC data-channel only (no audio).
 * The libwebrtc-native library has DT_NEEDED: libpulse.so.0 from the
 * audio device module, but data-channel doesn't use audio.
 *
 * This stub provides no-op implementations of PulseAudio symbols
 * to satisfy the linker at dlopen time.
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libpulse.so.0 \
 *     -o libpulse.so.0 libpulse-stub.c
 */

#include <stddef.h>

/* ============================================================================
 * libpulse-simple.so - Simple synchronous API
 * ============================================================================ */

void* pa_simple_new(
    const char *server,
    const char *name,
    int dir,
    const char *dev,
    const char *stream_name,
    const void *ss,
    const void *map,
    const void *attr,
    int *error
) {
    return (void*)0;
}

void pa_simple_free(void *s) {}

int pa_simple_write(void *s, const void *data, size_t nbytes, int *error) {
    return 0;
}

int pa_simple_read(void *s, void *data, size_t nbytes, int *error) {
    return -1;
}

int pa_simple_drain(void *s, int *error) {
    return 0;
}

int pa_simple_flush(void *s, int *error) {
    return 0;
}

double pa_simple_get_latency(void *s, int *error) {
    return 0.0;
}

/* ============================================================================
 * libpulse.so - Asynchronous context API
 * ============================================================================ */

void* pa_context_new(void *mainloop, const char *name) {
    return (void*)0;
}

int pa_context_connect(
    void *c,
    const char *server,
    int flags,
    const void *api
) {
    return -1;
}

void pa_context_disconnect(void *c) {}

void pa_context_unref(void *c) {}

void pa_context_set_state_callback(void *c, void *cb, void *userdata) {}

int pa_context_get_state(void *c) {
    return 0; /* PA_CONTEXT_UNCONNECTED */
}

void pa_context_subscribe(void *c, int mask, void *cb, void *userdata) {}

void pa_context_set_subscribe_callback(void *c, void *cb, void *userdata) {}

void pa_context_get_server_info(void *c, void *cb, void *userdata) {}

int pa_context_set_default_sink(void *c, const char *name, void *cb, void *userdata) {
    return -1;
}

int pa_context_set_default_source(void *c, const char *name, void *cb, void *userdata) {
    return -1;
}

/* ============================================================================
 * libpulse.so - Asynchronous stream API
 * ============================================================================ */

void* pa_stream_new(void *c, const char *name, const void *ss, const void *map) {
    return (void*)0;
}

int pa_stream_connect_playback(
    void *s,
    const char *dev,
    const void *attr,
    int flags,
    const void *volume,
    const void *sync_stream
) {
    return -1;
}

int pa_stream_connect_record(
    void *s,
    const char *dev,
    const void *attr,
    int flags
) {
    return -1;
}

void pa_stream_disconnect(void *s) {}

void pa_stream_unref(void *s) {}

void pa_stream_set_state_callback(void *s, void *cb, void *userdata) {}

void pa_stream_set_write_callback(void *s, void *cb, void *userdata) {}

void pa_stream_set_read_callback(void *s, void *cb, void *userdata) {}

int pa_stream_write(
    void *s,
    const void *data,
    size_t nbytes,
    void *free_cb,
    long offset,
    int seek
) {
    return -1;
}

void* pa_stream_read(void *s, size_t *nbytes) {
    return (void*)0;
}

int pa_stream_cork(void *s, int b, void *cb, void *userdata) {
    return -1;
}

int pa_stream_flush(void *s, void *cb, void *userdata) {
    return -1;
}

double pa_stream_get_latency(void *s, void *usec, int *negative) {
    return 0.0;
}

int pa_stream_get_state(void *s) {
    return 0; /* PA_STREAM_UNCONNECTED */
}

void* pa_stream_get_sample_spec(void *s) {
    return (void*)0;
}

void* pa_stream_get_channel_map(void *s) {
    return (void*)0;
}

void* pa_stream_get_buffer_attr(void *s) {
    return (void*)0;
}

int pa_stream_is_suspended(void *s) {
    return 1;
}

int pa_stream_begin_write(void *s, void **data, size_t *nbytes) {
    return -1;
}

/* ============================================================================
 * libpulse.so - Asynchronous operation API
 * ============================================================================ */

void pa_operation_unref(void *o) {}

int pa_operation_get_state(void *o) {
    return 0; /* PA_OPERATION_DONE */
}

void pa_operation_cancel(void *o) {}

/* ============================================================================
 * libpulse.so - Threaded mainloop API
 * ============================================================================ */

void* pa_threaded_mainloop_new(void) {
    return (void*)0;
}

void pa_threaded_mainloop_free(void *m) {}

void pa_threaded_mainloop_lock(void *m) {}

void pa_threaded_mainloop_unlock(void *m) {}

void pa_threaded_mainloop_wait(void *m) {}

void pa_threaded_mainloop_signal(void *m, int wait_for_accept) {}

int pa_threaded_mainloop_start(void *m) {
    return -1;
}

void pa_threaded_mainloop_stop(void *m) {}

void* pa_threaded_mainloop_get_api(void *m) {
    return (void*)0;
}

/* ============================================================================
 * libpulse.so - Sample and channel utilities
 * ============================================================================ */

void pa_sample_spec_init(void *ss) {}

void pa_channel_map_init(void *map) {}

void* pa_channel_map_init_auto(void *map, unsigned channels, int def) {
    return (void*)0;
}

/* ============================================================================
 * libpulse.so - Miscellaneous
 * ============================================================================ */

const char* pa_strerror(int error) {
    return "stub";
}

void* pa_proplist_new(void) {
    return (void*)0;
}

void pa_proplist_free(void *p) {}

int pa_proplist_sets(void *p, const char *key, const char *value) {
    return -1;
}

int pa_utf8_valid(const char *str) {
    return 0;
}

/* ============================================================================
 * libpulse-common.so - Memory allocation
 * ============================================================================ */

void* pa_xmalloc(size_t size) {
    return (void*)0;
}

void pa_xfree(void *p) {}

void* pa_xrealloc(void *p, size_t size) {
    return (void*)0;
}

void* pa_xnew0(size_t n, size_t k) {
    return (void*)0;
}

void* pa_xnew(size_t n, size_t k) {
    return (void*)0;
}
