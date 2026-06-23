/* libudev-stub.c - Minimal libudev stub for Android WebRTC compatibility
 *
 * Minecraft 26.2+ P2P uses WebRTC data-channel only.
 * The libwebrtc-native library has DT_NEEDED: libudev.so.1 from the
 * video/device monitoring module, but data-channel doesn't use udev.
 *
 * This stub provides no-op implementations of libudev symbols
 * to satisfy the linker at dlopen time.
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libudev.so.1 \
 *     -o libudev.so.1 libudev-stub.c
 */

/* ============================================================================
 * libudev.so.1 - Device enumeration and monitoring
 * ============================================================================ */

void* udev_new(void) {
    return (void*)0;
}

void udev_unref(void *udev) {}

void* udev_ref(void *udev) {
    return (void*)0;
}

void* udev_enumerate_new(void *udev) {
    return (void*)0;
}

void udev_enumerate_unref(void *enumerate) {}

int udev_enumerate_add_match_subsystem(void *enumerate, const char *subsystem) {
    return -1;
}

int udev_enumerate_add_match_property(void *enumerate, const char *property, const char *value) {
    return -1;
}

int udev_enumerate_scan_devices(void *enumerate) {
    return -1;
}

void* udev_enumerate_get_list_entry(void *enumerate) {
    return (void*)0;
}

void* udev_list_entry_get_next(void *list_entry) {
    return (void*)0;
}

const char* udev_list_entry_get_name(void *list_entry) {
    return (const char*)0;
}

void* udev_device_new_from_syspath(void *udev, const char *syspath) {
    return (void*)0;
}

void udev_device_unref(void *device) {}

void* udev_device_ref(void *device) {
    return (void*)0;
}

const char* udev_device_get_devnode(void *device) {
    return (const char*)0;
}

const char* udev_device_get_subsystem(void *device) {
    return (const char*)0;
}

const char* udev_device_get_devtype(void *device) {
    return (const char*)0;
}

void* udev_device_get_parent(void *device) {
    return (void*)0;
}

void* udev_device_get_parent_with_subsystem_devtype(void *device, const char *subsystem, const char *devtype) {
    return (void*)0;
}

const char* udev_device_get_property_value(void *device, const char *key) {
    return (const char*)0;
}

const char* udev_device_get_sysattr_value(void *device, const char *sysattr) {
    return (const char*)0;
}

const char* udev_device_get_syspath(void *device) {
    return (const char*)0;
}

const char* udev_device_get_action(void *device) {
    return (const char*)0;
}

void* udev_monitor_new_from_netlink(void *udev, const char *name) {
    return (void*)0;
}

void udev_monitor_unref(void *monitor) {}

int udev_monitor_filter_add_match_subsystem_devtype(void *monitor, const char *subsystem, const char *devtype) {
    return -1;
}

int udev_monitor_enable_receiving(void *monitor) {
    return -1;
}

int udev_monitor_get_fd(void *monitor) {
    return -1;
}

void* udev_monitor_receive_device(void *monitor) {
    return (void*)0;
}

int udev_enumerate_add_match_sysname(void *enumerate, const char *sysname) {
    return -1;
}

int udev_enumerate_add_match_tag(void *enumerate, const char *tag) {
    return -1;
}

const char* udev_device_get_driver(void *device) {
    return (const char*)0;
}

long udev_device_get_seqnum(void *device) {
    return 0;
}

long long udev_device_get_usec_since_initialized(void *device) {
    return 0;
}

void* udev_device_get_devnum(void *device) {
    return (void*)0;
}

const char* udev_device_get_sysname(void *device) {
    return (const char*)0;
}

const char* udev_device_get_sysnum(void *device) {
    return (const char*)0;
}
