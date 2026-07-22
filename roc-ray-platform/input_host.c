// RocRay's host calls WindowShouldClose before Roc receives each frame, and
// Raylib uses Escape as its default exit key. Puri handles Escape as ordinary
// keyboard input, so opt out after RocRay has initialized the window.
extern void SetExitKey(int key);

void roc_host_disable_escape_exit(void) {
    SetExitKey(0); // KEY_NULL
}
