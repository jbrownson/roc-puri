#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *mock_clipboard = "";
static char written_clipboard[256];
static int exit_key = -1;
static bool window_ready = true;
static int window_min_width = 0;
static int window_min_height = 0;

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

    window_ready = false;
    roc_host_set_window_min_size(100, 100);
    check(window_min_width == 520 && window_min_height == 360, "headless minimum window size touched Raylib");

    return failures == 0 ? 0 : 1;
}
