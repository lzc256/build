/* libdbus-1-stub.c - Minimal D-Bus stub for Android WebRTC compatibility
 *
 * libwebrtc-native has DT_NEEDED: libdbus-1.so.3 for system integration.
 * Android doesn't have D-Bus. This stub satisfies the linker.
 *
 * Build:
 *   aarch64-linux-gnu-gcc -shared -fPIC -Wl,-soname,libdbus-1.so.3 \
 *     -o libdbus-1.so.3 libdbus-1-stub.c
 */

#include <stddef.h>

/* D-Bus types */
typedef struct DBusConnection DBusConnection;
typedef struct DBusMessage DBusMessage;
typedef struct DBusError {
    char *name;
    char *message;
    unsigned int dummy1;
    int dummy2;
    int dummy3;
    int dummy4;
    int dummy5;
    void *padding1;
} DBusError;

typedef struct DBusMessageIter {
    void *dummy1;
    void *dummy2;
    unsigned int dummy3;
    int dummy4;
    int dummy5;
    int dummy6;
    int dummy7;
    int dummy8;
    int dummy9;
    int dummy10;
    int dummy11;
    int pad1;
    int pad2;
    void *pad3;
} DBusMessageIter;

/* Connection management */
DBusConnection* dbus_bus_get(unsigned int type, DBusError *error) {
    return (DBusConnection*)0;
}

DBusConnection* dbus_bus_get_private(unsigned int type, DBusError *error) {
    return (DBusConnection*)0;
}

void dbus_connection_close(DBusConnection *connection) {}

void dbus_connection_unref(DBusConnection *connection) {}

void dbus_connection_ref(DBusConnection *connection) {}

int dbus_connection_get_is_connected(DBusConnection *connection) {
    return 0;
}

int dbus_connection_get_is_authenticated(DBusConnection *connection) {
    return 0;
}

/* Message handling */
DBusMessage* dbus_message_new_method_call(
    const char *destination,
    const char *path,
    const char *interface,
    const char *method
) {
    return (DBusMessage*)0;
}

DBusMessage* dbus_message_new_signal(
    const char *path,
    const char *interface,
    const char *name
) {
    return (DBusMessage*)0;
}

DBusMessage* dbus_message_new_error(
    DBusMessage *reply_to,
    const char *error_name,
    const char *error_message
) {
    return (DBusMessage*)0;
}

void dbus_message_unref(DBusMessage *message) {}

DBusMessage* dbus_message_ref(DBusMessage *message) {
    return message;
}

int dbus_message_get_type(DBusMessage *message) {
    return 0;
}

const char* dbus_message_get_path(DBusMessage *message) {
    return NULL;
}

const char* dbus_message_get_interface(DBusMessage *message) {
    return NULL;
}

const char* dbus_message_get_member(DBusMessage *message) {
    return NULL;
}

const char* dbus_message_get_destination(DBusMessage *message) {
    return NULL;
}

const char* dbus_message_get_sender(DBusMessage *message) {
    return NULL;
}

/* Message iteration */
void dbus_message_iter_init(DBusMessage *message, DBusMessageIter *iter) {}

int dbus_message_iter_get_arg_type(DBusMessageIter *iter) {
    return 0; /* DBUS_TYPE_INVALID */
}

void dbus_message_iter_recurse(DBusMessageIter *iter, DBusMessageIter *sub) {}

int dbus_message_iter_next(DBusMessageIter *iter) {
    return 0;
}

void dbus_message_iter_get_basic(DBusMessageIter *iter, void *value) {}

int dbus_message_iter_append_basic(DBusMessageIter *iter, int type, const void *value) {
    return 0;
}

int dbus_message_iter_init_append(DBusMessage *message, DBusMessageIter *iter) {
    return 0;
}

int dbus_message_iter_open_container(
    DBusMessageIter *iter,
    int type,
    const char *contained_signature,
    DBusMessageIter *sub
) {
    return 0;
}

int dbus_message_iter_close_container(DBusMessageIter *iter, DBusMessageIter *sub) {
    return 0;
}

/* Sending messages */
int dbus_connection_send(DBusConnection *connection, DBusMessage *message, unsigned int *serial) {
    return 0;
}

int dbus_connection_send_with_reply(
    DBusConnection *connection,
    DBusMessage *message,
    void **pending_return,
    int timeout_milliseconds
) {
    return 0;
}

DBusMessage* dbus_connection_send_with_reply_and_block(
    DBusConnection *connection,
    DBusMessage *message,
    int timeout_milliseconds,
    DBusError *error
) {
    return (DBusMessage*)0;
}

void dbus_connection_flush(DBusConnection *connection) {}

/* Connection setup */
int dbus_connection_read_write(DBusConnection *connection, int timeout_milliseconds) {
    return 0;
}

DBusMessage* dbus_connection_borrow_message(DBusConnection *connection) {
    return (DBusMessage*)0;
}

void dbus_connection_return_message(DBusConnection *connection, DBusMessage *message) {}

DBusMessage* dbus_connection_pop_message(DBusConnection *connection) {
    return (DBusMessage*)0;
}

int dbus_connection_dispatch(DBusConnection *connection) {
    return 0; /* DBUS_DISPATCH_COMPLETE */
}

/* Pending calls */
void dbus_pending_call_unref(void *pending) {}

void* dbus_pending_call_steal_reply(void *pending) {
    return NULL;
}

int dbus_pending_call_get_completed(void *pending) {
    return 0;
}

void dbus_pending_call_block(void *pending) {}

/* Error handling */
void dbus_error_init(DBusError *error) {
    if (error) {
        error->name = NULL;
        error->message = NULL;
    }
}

void dbus_error_free(DBusError *error) {
    if (error) {
        error->name = NULL;
        error->message = NULL;
    }
}

int dbus_error_is_set(const DBusError *error) {
    return 0;
}

int dbus_error_has_name(const DBusError *error, const char *name) {
    return 0;
}

/* Bus operations */
unsigned int dbus_bus_request_name(
    DBusConnection *connection,
    const char *name,
    unsigned int flags,
    DBusError *error
) {
    return 0;
}

int dbus_bus_release_name(
    DBusConnection *connection,
    const char *name,
    DBusError *error
) {
    return 0;
}

int dbus_bus_name_has_owner(
    DBusConnection *connection,
    const char *name,
    DBusError *error
) {
    return 0;
}

void dbus_bus_add_match(DBusConnection *connection, const char *rule, DBusError *error) {}

void dbus_bus_remove_match(DBusConnection *connection, const char *rule, DBusError *error) {}

/* Signal handling */
void dbus_connection_add_filter(
    DBusConnection *connection,
    void *function,
    void *user_data,
    void *free_data_function
) {}

void dbus_connection_remove_filter(
    DBusConnection *connection,
    void *function,
    void *user_data
) {}

int dbus_connection_add_match(
    DBusConnection *connection,
    const char *rule,
    DBusError *error
) {
    return 0;
}

void dbus_connection_remove_match(
    DBusConnection *connection,
    const char *rule,
    DBusError *error
) {}

/* Message appending */
DBusMessage* dbus_message_new(int type) {
    return (DBusMessage*)0;
}

int dbus_message_set_destination(DBusMessage *message, const char *destination) {
    return 0;
}

int dbus_message_set_path(DBusMessage *message, const char *object_path) {
    return 0;
}

int dbus_message_set_interface(DBusMessage *message, const char *interface) {
    return 0;
}

int dbus_message_set_member(DBusMessage *message, const char *member) {
    return 0;
}

/* Signature validation */
int dbus_signature_validate(const char *signature, DBusError *error) {
    return 1;
}

int dbus_signature_validate_single(const char *signature, DBusError *error) {
    return 1;
}

/* Other */
void* dbus_malloc(size_t bytes) {
    return NULL;
}

void* dbus_malloc0(size_t bytes) {
    return NULL;
}

void* dbus_realloc(void *memory, size_t bytes) {
    return NULL;
}

void dbus_free(void *memory) {}

char* dbus_strdup(const char *str) {
    return NULL;
}

unsigned int dbus_message_get_serial(DBusMessage *message) {
    return 0;
}
