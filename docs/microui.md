# microui

Immediate-mode UI library. Every frame you describe what the UI looks like; microui
tracks state internally and generates draw commands for the `ui` package to render.

## Frame structure

```odin
mu_ctx := ui.ctx_ptr()
ui.begin_frame()          // must come first

// ... build UI here ...

// inside sg.begin_pass / sg.end_pass:
ui.render()               // must come last
```

---

## Windows

A window is the top-level container. All widgets must live inside one.

```odin
if mu.begin_window(mu_ctx, "Title", {x, y, w, h}) {
    // widgets go here
    mu.end_window(mu_ctx)
}
```

`begin_window` returns `false` if the window is closed or off-screen, so the
`if` naturally skips the body. Always pair `begin_window` with `end_window`.

### Window options

Pass a bit set as the last argument:

```odin
mu.begin_window(mu_ctx, "Title", {10, 10, 200, 300}, {.NO_RESIZE, .NO_CLOSE})
```

| Option | Effect |
|---|---|
| `.NO_RESIZE` | Disables the resize handle |
| `.NO_CLOSE` | Hides the close button |
| `.NO_TITLE` | Hides the title bar entirely |
| `.NO_SCROLL` | Disables scrolling |
| `.AUTO_SIZE` | Window resizes to fit its content |

---

## Layout

Before placing widgets you must declare the row layout. A row is a horizontal
slice of the window divided into columns.

```odin
mu.layout_row(mu_ctx, widths, height)
```

- **`widths`** — a slice of column widths in pixels. `-1` means "fill remaining width".
- **`height`** — row height in pixels. `0` uses the default (one line of text).

`layout_row` applies only to the **next row** of widgets. When all columns in
that row are filled, you need to call `layout_row` again.

```odin
// One full-width column
mu.layout_row(mu_ctx, {-1}, 0)
mu.label(mu_ctx, "Hello")        // occupies the whole row

// Two columns: fixed label + stretchy value
mu.layout_row(mu_ctx, {80, -1}, 0)
mu.label(mu_ctx, "Speed")
mu.slider(mu_ctx, &speed, 0, 100)

// Three equal-ish columns
mu.layout_row(mu_ctx, {60, 60, -1}, 0)
mu.button(mu_ctx, "A")
mu.button(mu_ctx, "B")
mu.button(mu_ctx, "C")
```

---

## Widgets

All widgets return a `Result_Set` (a bit set of `.ACTIVE`, `.SUBMIT`, `.CHANGE`).

### Label

Displays static text. No return value worth checking.

```odin
mu.label(mu_ctx, "some text")
```

For dynamic text, format into a local buffer first:

```odin
buf: [64]u8
mu.label(mu_ctx, fmt.bprintf(buf[:], "entities: %d", count))
```

### Button

Returns `.SUBMIT` when clicked.

```odin
if .SUBMIT in mu.button(mu_ctx, "Reset") {
    reset()
}
```

### Checkbox

Toggles a `bool`. Returns `.CHANGE` when toggled.

```odin
if .CHANGE in mu.checkbox(mu_ctx, "Visible", &entity.visible) {
    // reacted to toggle
}
```

### Slider

Drags a `f32` value between `low` and `high`. Returns `.CHANGE` while dragging.

```odin
mu.slider(mu_ctx, &speed, 0.0, 100.0)

// Custom step and format string
mu.slider(mu_ctx, &angle, 0.0, 360.0, 1.0, "%.0f deg")
```

### Text input

Edits a byte buffer in place. Returns `.CHANGE` on edit, `.SUBMIT` on Enter.

```odin
name_buf: [64]u8
name_len: int

if .SUBMIT in mu.textbox(mu_ctx, name_buf[:], &name_len) {
    submit(string(name_buf[:name_len]))
}
```

---

## Panels

A panel is a scrollable sub-container inside a window, with no title bar.
Useful for lists or sections that might overflow.

```odin
mu.begin_panel(mu_ctx, "entities")
for &e in entities {
    mu.layout_row(mu_ctx, {-1}, 0)
    mu.label(mu_ctx, e.name)
}
mu.end_panel(mu_ctx)
```

---

## Tree nodes

Collapsible sections. Returns `.ACTIVE` when expanded.

```odin
if .ACTIVE in mu.begin_treenode(mu_ctx, "Transform") {
    mu.layout_row(mu_ctx, {40, -1}, 0)
    mu.label(mu_ctx, "pos")
    // ... widgets ...
    mu.end_treenode(mu_ctx)
}
```

---

## Typical debug panel pattern

```odin
build_debug_ui :: proc() {
    mu_ctx := ui.ctx_ptr()

    if mu.begin_window(mu_ctx, "Debug", {10, 10, 220, 400}, {.NO_CLOSE}) {

        // Stats row
        mu.layout_row(mu_ctx, {-1}, 0)
        buf: [64]u8
        mu.label(mu_ctx, fmt.bprintf(buf[:], "dt: %.2f ms", g.dt * 1000))

        // Per-entity section
        if .ACTIVE in mu.begin_treenode(mu_ctx, "Entities") {
            for &e in g.entities {
                if e.kind == .nil { continue }
                mu.layout_row(mu_ctx, {-1}, 0)
                mu.label(mu_ctx, fmt.bprintf(buf[:], "[%d] %v", e.handle.id, e.kind))
            }
            mu.end_treenode(mu_ctx)
        }

        mu.end_window(mu_ctx)
    }
}
```
