#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *mock_clipboard = "";
static char written_clipboard[256];
static int exit_key = -1;
static int scissor_begin_count = 0;
static int scissor_end_count = 0;
static int scissor_x = 0;
static int scissor_y = 0;
static int scissor_width = 0;
static int scissor_height = 0;
static bool window_ready = true;
static int window_min_width = 0;
static int window_min_height = 0;
static float wheel_x = 0.0f;
static float wheel_y = 0.0f;

void SetExitKey(int key) {
    exit_key = key;
}

void SetWindowMinSize(int width, int height) {
    window_min_width = width;
    window_min_height = height;
}

const char *GetClipboardText(void) {
    return mock_clipboard;
}

void SetClipboardText(const char *text) {
    snprintf(written_clipboard, sizeof(written_clipboard), "%s", text);
}

void BeginScissorMode(int x, int y, int width, int height) {
    scissor_begin_count += 1;
    scissor_x = x;
    scissor_y = y;
    scissor_width = width;
    scissor_height = height;
}

void EndScissorMode(void) {
    scissor_end_count += 1;
}

bool IsWindowReady(void) {
    return window_ready;
}

void *roc_alloc(size_t size, size_t alignment) {
    (void)alignment;
    return malloc(size);
}

void roc_dealloc(void *ptr, size_t alignment) {
    (void)alignment;
    free(ptr);
}

#include "../roc_ray_adapter.c"

RaylibVector2 GetMouseWheelMoveV(void) {
    return (RaylibVector2){ .x = wheel_x, .y = wheel_y };
}

static int failures = 0;

static void check(int condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "roc_ray_adapter_test: %s\n", message);
        failures += 1;
    }
}

static void check_clipboard_read(const char *expected) {
    mock_clipboard = expected;
    RocStr result = roc_clipboard_get_text();
    const size_t expected_length = strlen(expected);
    check(roc_str_len(&result) == expected_length, "clipboard read length differs");
    check(memcmp(roc_str_bytes(&result), expected, expected_length) == 0, "clipboard read bytes differ");
    roc_str_decref(result);
}

int main(void) {
    roc_host_disable_escape_exit();
    check(exit_key == 0, "Escape exit was not disabled");
    roc_host_set_window_min_size(520, 360);
    check(window_min_width == 520 && window_min_height == 360, "minimum window size was not forwarded");

    check_clipboard_read("small");
    check_clipboard_read("this clipboard string exceeds the inline RocStr capacity");

    const char *written = "clipboard write also exceeds the inline RocStr capacity";
    RocStr write_value = roc_str_from_bytes((const uint8_t *)written, strlen(written));
    roc_clipboard_set_text(write_value);
    check(strcmp(written_clipboard, written) == 0, "clipboard write bytes differ");

    check(roc_mouse_click_count(1000000000u, 10.0f, 10.0f) == 1, "first click was not single");
    check(roc_mouse_click_count(1200000000u, 11.0f, 9.0f) == 2, "second nearby click was not double");
    check(roc_mouse_click_count(1300000000u, 10.0f, 10.0f) == 3, "third nearby click was not triple");
    check(roc_mouse_click_count(1400000000u, 10.0f, 10.0f) == 4, "fourth nearby click was not preserved");
    check(roc_mouse_click_count(1500000000u, 20.0f, 10.0f) == 1, "distant click did not reset count");
    check(roc_mouse_click_count(2000000001u, 20.0f, 10.0f) == 1, "late click did not reset count");

    wheel_x = 0.125f;
    wheel_y = -0.375f;
    RaylibVector2 wheel = roc_mouse_scroll_delta();
    check(wheel.x == wheel_x && wheel.y == wheel_y, "fractional two-axis scroll delta was not preserved");

    roc_draw_begin_scissor_raw(1.2f, 2.2f, 10.1f, 10.1f);
    check(scissor_x == 1 && scissor_y == 2 && scissor_width == 11 && scissor_height == 11, "outer scissor rounding differs");
    roc_draw_begin_scissor_raw(5.0f, 0.0f, 10.0f, 10.0f);
    check(scissor_x == 5 && scissor_y == 2 && scissor_width == 7 && scissor_height == 8, "nested scissor did not intersect");
    roc_draw_end_scissor();
    check(scissor_begin_count == 3 && scissor_end_count == 1 && scissor_x == 1 && scissor_y == 2 && scissor_width == 11 && scissor_height == 11, "ending nested scissor did not restore outer scissor");
    roc_draw_end_scissor();
    check(scissor_end_count == 2, "ending outer scissor did not disable it");

    window_ready = false;
    wheel = roc_mouse_scroll_delta();
    check(wheel.x == 0.0f && wheel.y == 0.0f, "headless scroll touched Raylib");
    roc_host_set_window_min_size(100, 100);
    check(window_min_width == 520 && window_min_height == 360, "headless minimum window size touched Raylib");
    roc_draw_begin_scissor_raw(0.0f, 0.0f, 10.0f, 10.0f);
    roc_draw_end_scissor();
    check(scissor_begin_count == 3 && scissor_end_count == 2, "headless scissor touched Raylib");

    return failures == 0 ? 0 : 1;
}
