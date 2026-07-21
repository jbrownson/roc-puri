#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

extern int32_t roc_main(void);

void hosted_test_case(int32_t case_number) {
    fprintf(stderr, "Roclay generated case %d failed\n", case_number);
}

void hosted_expected_rect(float x, float y, float width, float height) {
    fprintf(stderr, "  expected %9.4f %9.4f %9.4f %9.4f\n", x, y, width, height);
}

void hosted_actual_rect(float x, float y, float width, float height) {
    fprintf(stderr, "  actual   %9.4f %9.4f %9.4f %9.4f\n", x, y, width, height);
}

int main(void) {
    int32_t result = roc_main();
    if (result == 0) {
        puts("Roc test platform: passed");
    } else {
        fprintf(stderr, "Roclay conformance case %d failed\n", result);
    }
    return result;
}

void *roc_alloc(size_t size, size_t alignment) {
    if (alignment <= _Alignof(max_align_t)) {
        return malloc(size);
    }

    void *pointer = NULL;
    if (posix_memalign(&pointer, alignment, size) != 0) {
        return NULL;
    }
    return pointer;
}

void roc_dealloc(void *pointer, size_t alignment) {
    (void)alignment;
    free(pointer);
}

void *roc_realloc(void *pointer, size_t new_size, size_t alignment) {
    (void)alignment;
    return realloc(pointer, new_size);
}

static void print_roc_message(const char *kind, const char *bytes, size_t length) {
    fprintf(stderr, "%s: ", kind);
    fwrite(bytes, 1, length, stderr);
    fputc('\n', stderr);
}

void roc_dbg(const char *bytes, size_t length) {
    print_roc_message("roc dbg", bytes, length);
}

void roc_expect_failed(const char *bytes, size_t length) {
    print_roc_message("roc expect failed", bytes, length);
}

void roc_crashed(const char *bytes, size_t length) {
    print_roc_message("roc crashed", bytes, length);
    exit(1);
}
