#include <stdint.h>

extern int32_t roc_main(void);

__attribute__((export_name("wasm_main"), used, visibility("default")))
int32_t wasm_main(void) {
    return roc_main();
}
