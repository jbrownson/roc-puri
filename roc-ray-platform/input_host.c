#include <math.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

// RocRay's host calls WindowShouldClose before Roc receives each frame, and
// Raylib uses Escape as its default exit key. Puri handles Escape as ordinary
// keyboard input, so opt out after RocRay has initialized the window.
extern void SetExitKey(int key);
extern const char *GetClipboardText(void);
extern void SetClipboardText(const char *text);
extern void *roc_alloc(size_t size, size_t alignment);
extern void roc_dealloc(void *ptr, size_t alignment);

typedef struct {
    uint8_t *bytes;
    size_t capacity_or_alloc_ptr;
    size_t length;
} RocStr;

static int roc_str_is_small(RocStr str) {
    return (intptr_t)str.length < 0;
}

static size_t roc_str_len(const RocStr *str) {
    if (roc_str_is_small(*str)) {
        return ((const uint8_t *)str)[sizeof(RocStr) - 1u] ^ 0x80u;
    }
    return str->length;
}

static const uint8_t *roc_str_bytes(const RocStr *str) {
    return roc_str_is_small(*str) ? (const uint8_t *)str : str->bytes;
}

static uint8_t *roc_str_allocation_ptr(RocStr str) {
    if (roc_str_is_small(str)) return NULL;
    if ((str.capacity_or_alloc_ptr & 1u) != 0) {
        return (uint8_t *)(str.capacity_or_alloc_ptr & ~(uintptr_t)1u);
    }
    return str.bytes;
}

static void roc_str_decref(RocStr str) {
    uint8_t *alloc_ptr = roc_str_allocation_ptr(str);
    if (alloc_ptr == NULL) return;
    intptr_t *refcount = (intptr_t *)(alloc_ptr - sizeof(intptr_t));
    if (*refcount == 0) return;
    *refcount -= 1;
    if (*refcount == 0) {
        roc_dealloc(alloc_ptr - sizeof(size_t), _Alignof(size_t));
    }
}

static RocStr roc_str_from_bytes(const uint8_t *bytes, size_t length) {
    RocStr result = {0};
    if (length < sizeof(RocStr)) {
        memcpy(&result, bytes, length);
        ((uint8_t *)&result)[sizeof(RocStr) - 1u] = (uint8_t)length | 0x80u;
        return result;
    }

    const size_t total = sizeof(size_t) + length;
    uint8_t *base = roc_alloc(total, _Alignof(size_t));
    if (base == NULL) {
        ((uint8_t *)&result)[sizeof(RocStr) - 1u] = 0x80u;
        return result;
    }
    uint8_t *data = base + sizeof(size_t);
    ((intptr_t *)data)[-1] = 1;
    memcpy(data, bytes, length);
    result.bytes = data;
    result.capacity_or_alloc_ptr = length << 1;
    result.length = length;
    return result;
}

void roc_host_disable_escape_exit(void) {
    SetExitKey(0); // KEY_NULL
}

RocStr roc_clipboard_get_text(void) {
    const char *text = GetClipboardText();
    if (text == NULL) text = "";
    return roc_str_from_bytes((const uint8_t *)text, strlen(text));
}

void roc_clipboard_set_text(RocStr text) {
    const size_t length = roc_str_len(&text);
    char *terminated = malloc(length + 1u);
    if (terminated != NULL) {
        memcpy(terminated, roc_str_bytes(&text), length);
        terminated[length] = '\0';
        SetClipboardText(terminated);
        free(terminated);
    }
    roc_str_decref(text);
}

uint8_t roc_mouse_click_count(uint64_t timestamp_nanos, float x, float y) {
    static uint64_t last_timestamp = 0;
    static float last_x = 0;
    static float last_y = 0;
    static uint8_t count = 0;
    const uint64_t interval = 500000000u;
    const float slop = 4.0f;
    const int continues = last_timestamp != 0
        && timestamp_nanos >= last_timestamp
        && timestamp_nanos - last_timestamp <= interval
        && fabsf(x - last_x) <= slop
        && fabsf(y - last_y) <= slop;

    count = continues ? (count < 3 ? count + 1 : 3) : 1;
    last_timestamp = timestamp_nanos;
    last_x = x;
    last_y = y;
    return count;
}
