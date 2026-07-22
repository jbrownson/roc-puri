#define _POSIX_C_SOURCE 200112L

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

extern int32_t roc_main(void);

int main(void) {
    int32_t result = roc_main();
    printf("result=%d\n", result);
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
