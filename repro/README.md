# Raylib mouse-edge comparison

`raylib_mouse_edges.c` compares the raw GLFW mouse callback with Raylib's
public `IsMouseButtonPressed`, `IsMouseButtonDown`, and
`IsMouseButtonReleased` frame snapshot. It contains no Roc or Puri code and
links the unmodified Raylib 6.0 archive downloaded with RocRay 0.8.0.

Run it at the same 60 FPS as the Puri demo:

```sh
make mouse-edge-repro
```

Run the deterministic stress case at 2 FPS:

```sh
make mouse-edge-repro-slow
```

Each physical edge prints a `RAW` line from GLFW. A corresponding `RAYLIB`
line appears only when Raylib preserves that edge in its next public input
snapshot. A `RAW press`/`RAW release` pair with no `RAYLIB` line therefore
isolates the loss to Raylib, below RocRay, Roc, and Puri.

On macOS with Raylib 6.0, the 60 FPS case produced ten complete raw
press/release pairs with no Raylib edge. Two longer clicks then crossed polling
boundaries and appeared in both streams. At 2 FPS, twelve raw press/release
pairs were similarly lost before a longer thirteenth click appeared in both
streams. The Puri demo itself also logged approximately 17 ms frames, so the
slow case is only an amplifier for the mechanism: low application frame rate is
not required to reproduce it.

This is the same behavior reported in
[raylib issue #4749](https://github.com/raysan5/raylib/issues/4749). Its later
discussion notes that macOS window-management utilities such as Magnet can
delay button events and deliver both edges together. That makes the limitation
easy to trigger, but the raw comparison shows why only Raylib consumers lose
the click: GLFW still delivers both ordered callback events while Raylib keeps
only the final per-frame button state.
