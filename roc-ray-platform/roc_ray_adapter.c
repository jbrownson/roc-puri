// Small hosted-ABI additions used by Puri's RocRay interpreter.
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

// RocRay's host calls WindowShouldClose before Roc receives each frame, and
// Raylib uses Escape as its default exit key. Puri handles Escape as ordinary
// keyboard input, so opt out after RocRay has initialized the window.
extern void SetExitKey(int key);
extern void SetWindowMinSize(int width, int height);
extern const char *GetClipboardText(void);
extern void SetClipboardText(const char *text);
extern void BeginScissorMode(int x, int y, int width, int height);
extern void EndScissorMode(void);
extern bool IsWindowReady(void);
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

void roc_host_set_window_min_size(int32_t width, int32_t height) {
    if (IsWindowReady()) SetWindowMinSize(width, height);
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

typedef struct {
    int x;
    int y;
    int width;
    int height;
} ScissorRect;

static ScissorRect scissor_stack[64];
static size_t scissor_depth = 0;
static size_t scissor_overflow = 0;

static int max_int(int left, int right) {
    return left > right ? left : right;
}

static int min_int(int left, int right) {
    return left < right ? left : right;
}

static ScissorRect intersect_scissors(ScissorRect left, ScissorRect right) {
    const int x = max_int(left.x, right.x);
    const int y = max_int(left.y, right.y);
    const int right_edge = min_int(left.x + left.width, right.x + right.width);
    const int bottom_edge = min_int(left.y + left.height, right.y + right.height);
    return (ScissorRect){
        .x = x,
        .y = y,
        .width = max_int(0, right_edge - x),
        .height = max_int(0, bottom_edge - y),
    };
}

static void apply_scissor(ScissorRect rect) {
    BeginScissorMode(rect.x, rect.y, rect.width, rect.height);
}

void roc_draw_begin_scissor_raw(float x, float y, float width, float height) {
    // RocRay still runs the Roc renderer for headless frames, but Raylib has no
    // graphics context in that mode. Scissoring is meaningful only when a
    // window exists, and calling BeginScissorMode without one crashes Raylib.
    if (!IsWindowReady()) return;

    if (scissor_overflow > 0) {
        scissor_overflow += 1;
        return;
    }
    if (scissor_depth == sizeof(scissor_stack) / sizeof(scissor_stack[0])) {
        scissor_overflow = 1;
        return;
    }

    const int left = (int)floorf(x);
    const int top = (int)floorf(y);
    const int right = (int)ceilf(x + fmaxf(0.0f, width));
    const int bottom = (int)ceilf(y + fmaxf(0.0f, height));
    ScissorRect rect = {
        .x = left,
        .y = top,
        .width = max_int(0, right - left),
        .height = max_int(0, bottom - top),
    };
    if (scissor_depth > 0) {
        rect = intersect_scissors(scissor_stack[scissor_depth - 1], rect);
    }
    scissor_stack[scissor_depth] = rect;
    scissor_depth += 1;
    apply_scissor(rect);
}

void roc_draw_end_scissor(void) {
    if (!IsWindowReady()) {
        scissor_depth = 0;
        scissor_overflow = 0;
        return;
    }

    if (scissor_overflow > 0) {
        scissor_overflow -= 1;
        return;
    }
    if (scissor_depth == 0) return;

    scissor_depth -= 1;
    EndScissorMode();
    if (scissor_depth > 0) {
        apply_scissor(scissor_stack[scissor_depth - 1]);
    }
}
