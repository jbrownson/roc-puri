// Minimal diagnostic for mouse edges lost below Roc/Puri.
//
// This intentionally compares Raylib's public per-frame snapshot with the raw
// GLFW callback that feeds it. It uses only the small part of each API needed
// here so the repro can link against RocRay's existing Raylib archive without
// vendoring headers.

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Color {
    unsigned char r;
    unsigned char g;
    unsigned char b;
    unsigned char a;
} Color;

typedef struct GLFWwindow GLFWwindow;
typedef void (*GLFWmousebuttonfun)(GLFWwindow *, int, int, int);

extern void InitWindow(int width, int height, const char *title);
extern void CloseWindow(void);
extern bool WindowShouldClose(void);
extern void SetTargetFPS(int fps);
extern bool IsMouseButtonPressed(int button);
extern bool IsMouseButtonDown(int button);
extern bool IsMouseButtonReleased(int button);
extern void BeginDrawing(void);
extern void ClearBackground(Color color);
extern void DrawText(const char *text, int x, int y, int font_size, Color color);
extern void EndDrawing(void);

extern GLFWwindow *glfwGetCurrentContext(void);
extern GLFWmousebuttonfun glfwSetMouseButtonCallback(GLFWwindow *window, GLFWmousebuttonfun callback);

enum {
    GLFW_RELEASE = 0,
    GLFW_PRESS = 1,
    MOUSE_BUTTON_LEFT = 0,
};

static GLFWmousebuttonfun raylib_mouse_callback = NULL;
static unsigned long raw_pressed = 0;
static unsigned long raw_released = 0;

static void compare_mouse_callback(GLFWwindow *window, int button, int action, int modifiers) {
    // Preserve Raylib's normal input processing before observing the event.
    if (raylib_mouse_callback != NULL) raylib_mouse_callback(window, button, action, modifiers);

    if (button != MOUSE_BUTTON_LEFT) return;
    if (action == GLFW_PRESS) {
        raw_pressed++;
        printf("RAW      press   #%lu\n", raw_pressed);
    } else if (action == GLFW_RELEASE) {
        raw_released++;
        printf("RAW      release #%lu\n", raw_released);
    }
    fflush(stdout);
}

int main(int argc, char **argv) {
    const bool slow = argc > 1 && strcmp(argv[1], "--slow") == 0;
    const int fps = slow ? 2 : 60;
    const Color background = { 244, 241, 234, 255 };
    const Color ink = { 39, 37, 34, 255 };
    char status[256];
    unsigned long frame = 0;
    unsigned long raylib_pressed = 0;
    unsigned long raylib_released = 0;
    bool previous_down = false;

    InitWindow(760, 320, "Raylib mouse-edge comparison");
    SetTargetFPS(fps);

    GLFWwindow *window = glfwGetCurrentContext();
    if (window == NULL) {
        fprintf(stderr, "GLFW has no current window\n");
        CloseWindow();
        return EXIT_FAILURE;
    }
    raylib_mouse_callback = glfwSetMouseButtonCallback(window, compare_mouse_callback);

    printf("Comparing raw GLFW edges with Raylib snapshots at %d FPS.\n", fps);
    printf("A RAW pair without a RAYLIB line means Raylib collapsed the click.\n");
    fflush(stdout);

    while (!WindowShouldClose()) {
        const bool pressed = IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
        const bool down = IsMouseButtonDown(MOUSE_BUTTON_LEFT);
        const bool released = IsMouseButtonReleased(MOUSE_BUTTON_LEFT);

        if (pressed) raylib_pressed++;
        if (released) raylib_released++;
        if (pressed || released || down != previous_down) {
            printf(
                "RAYLIB   frame=%lu pressed=%d down=%d released=%d totals=%lu/%lu\n",
                frame,
                pressed,
                down,
                released,
                raylib_pressed,
                raylib_released
            );
            fflush(stdout);
        }
        previous_down = down;

        BeginDrawing();
        ClearBackground(background);
        DrawText(slow ? "2 FPS stress mode" : "60 FPS: reproduce the original click", 24, 24, 24, ink);
        DrawText("Click normally and quickly; close the window when done.", 24, 68, 20, ink);
        snprintf(
            status,
            sizeof(status),
            "raw press/release: %lu/%lu    Raylib: %lu/%lu",
            raw_pressed,
            raw_released,
            raylib_pressed,
            raylib_released
        );
        DrawText(status, 24, 116, 20, ink);
        DrawText("A mismatch isolates the loss to Raylib's snapshot.", 24, 164, 20, ink);
        EndDrawing();

        frame++;
    }

    (void)glfwSetMouseButtonCallback(window, raylib_mouse_callback);
    CloseWindow();
    return EXIT_SUCCESS;
}
