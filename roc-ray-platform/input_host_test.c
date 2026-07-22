#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *mock_clipboard = "";
static char written_clipboard[256];
static int exit_key = -1;

void SetExitKey(int key) {
    exit_key = key;
}

const char *GetClipboardText(void) {
    return mock_clipboard;
}

void SetClipboardText(const char *text) {
    snprintf(written_clipboard, sizeof(written_clipboard), "%s", text);
}

void *roc_alloc(size_t size, size_t alignment) {
    (void)alignment;
    return malloc(size);
}

void roc_dealloc(void *ptr, size_t alignment) {
    (void)alignment;
    free(ptr);
}

#include "input_host.c"

static int failures = 0;

static void check(int condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "input_host_test: %s\n", message);
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

    check_clipboard_read("small");
    check_clipboard_read("this clipboard string exceeds the inline RocStr capacity");

    const char *written = "clipboard write also exceeds the inline RocStr capacity";
    RocStr write_value = roc_str_from_bytes((const uint8_t *)written, strlen(written));
	roc_clipboard_set_text(write_value);
    check(strcmp(written_clipboard, written) == 0, "clipboard write bytes differ");

	check(roc_mouse_click_count(1000000000u, 10.0f, 10.0f) == 1, "first click was not single");
	check(roc_mouse_click_count(1200000000u, 11.0f, 9.0f) == 2, "second nearby click was not double");
	check(roc_mouse_click_count(1300000000u, 10.0f, 10.0f) == 3, "third nearby click was not triple");
	check(roc_mouse_click_count(1400000000u, 20.0f, 10.0f) == 1, "distant click did not reset count");
	check(roc_mouse_click_count(2000000001u, 20.0f, 10.0f) == 1, "late click did not reset count");

    return failures == 0 ? 0 : 1;
}
