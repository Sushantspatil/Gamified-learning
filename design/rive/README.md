# Chest opening animations (Rive source)

The source for `assets/chests/rive/{golden,cyber,galaxy}.riv`, written as Rive
CLI projects (`scene.rml` markup plus the chest pictures). This folder is not
bundled into the app; only the built `.riv` files are.

Each scene: one artboard the size of that chest's pictures, transparent, which
plays once on load (Entry -> `Open`, 2.4 s) and holds on the open chest. The
picture changes are timed to `lib/features/chests/presentation/chest_timeline.dart`
(lock 0.52 s, burst 0.83 s, open 1.14 s), and the app draws its own glow,
rays and particles behind it (`ChestRiveFrame`).

## Tools

Rive CLI: `irm https://releases.rive.app/cli/install.ps1 | iex` (Windows) or
`curl -fsSL https://releases.rive.app/cli/install.sh | sh`. Docs: `rive docs`.

## Check and preview (no sign-in needed)

```bash
rive design/rive/golden --verify                       # compile, exit 1 on errors
rive design/rive/golden                                # live preview window
rive design/rive/golden --screenshot=f51.png --advance=51   # one frame as a png
```

## Build the .riv files (needs `rive login` once)

```bash
rive design/rive/golden --publish --output-dir=../../../assets/chests/rive
rive design/rive/cyber  --publish --output-dir=../../../assets/chests/rive
rive design/rive/galaxy --publish --output-dir=../../../assets/chests/rive
```

`--output-dir` is relative to the project folder. The Rive account's plan
decides whether the file carries the Rive splash (watermark): publish from a
paid plan for release builds.

To change the timing, edit the keyframes in `scene.rml` (frames at 60 fps) in
all three projects; they differ only in size, pivot, flash colour and pictures.
