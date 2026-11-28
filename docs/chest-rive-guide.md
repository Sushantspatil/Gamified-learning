# Making the chest openings in Rive (beginner guide)

This guide makes one smooth opening animation per chest (Golden, Cyber, Galaxy)
in the Rive editor, with no coding. The app is already set up: when a file is
in `assets/chests/rive/`, that chest plays it; a chest without a file keeps
today's picture animation.

> **Already made with the Rive CLI:** `design/rive/{golden,cyber,galaxy}` hold
> finished scenes for all three chests. `design/rive/README.md` shows how to
> build the `.riv` files from them. This guide is only needed to redo them by
> hand in the editor. Note the artboard sizes differ: Golden 756 × 738,
> Cyber 774 × 774, Galaxy 747 × 783 (each chest's picture size).

Rive changes its editor often. If a button below looks different, the official
docs have the current screens: https://rive.app/docs

## What you need

- A free account at https://rive.app (works in the browser; there is also a
  desktop app).
- **Cost:** on the Free plan, exported files play a short **Rive splash
  screen**. For the real app, export from the paid **Cadet** plan (about
  $17 per month; one month is enough to export all three chests).
- About 1–2 hours for the first chest, less for the next two.

## The rules the app needs (do not change these)

| What | Must be |
|---|---|
| File names | `golden.riv`, `cyber.riv`, `galaxy.riv` |
| Artboard | One artboard, 756 × 738 (the size of the chest pictures) |
| Length | About **2.3 seconds**, ending on the **open** chest (the reward appears at 2.6 s) |
| Start | The opening plays as soon as the file starts (State Machine: Entry → Open) |
| Background | Transparent (no background rectangle) |

## Step 1: get the pictures

Each chest has four pictures in the app, all 756 × 738 with a transparent
background:

```
assets/chests/golden/3.0x/closed.png    the closed chest
assets/chests/golden/3.0x/opening.png   lid glowing, about to open
assets/chests/golden/3.0x/burst.png     lid flying up, light bursting out
assets/chests/golden/3.0x/opened.png    open chest, glowing inside
```

(Same names under `cyber/3.0x/` and `galaxy/3.0x/`.)

These four are separate drawings, so the lid does not exactly match between
them. The plan below hides the changes inside motion and flashes of light, which
looks smooth. For a truly hinged lid that swings open, see "Better art" at the
end.

## Step 2: set up the file

1. Sign in at rive.app and create a **New File**.
2. Select the artboard and set its size to **756 × 738**. Remove its fill
   (background colour) so it is transparent.
3. Rename the artboard `Chest`.
4. Import the four pictures: drag the four PNG files into the editor, or open
   the **Assets** panel, click **+**, then **Upload**.
5. Drag each picture onto the artboard and set every one to position **X 0,
   Y 0** with size **756 × 738**, so they sit exactly on top of each other.
6. In the layer list, put them in this order from bottom to top: `closed`,
   `opening`, `burst`, `opened`.
7. Select all four and **group** them (Ctrl+G). Name the group `chest`. You
   will move and squash this group.
8. Set the origin (pivot) of the `chest` group to the **bottom centre** of the
   chest, so it squashes and bounces from the floor.

Stay in **Design Mode** while setting up (toggle with the **Mode Toggle** in the
toolbar, or press **Tab**).

## Step 3: add simple light effects (Design Mode)

**Only `flash` is needed.** The app already draws its own glow, rays and
particles behind the Rive chest (the same ones as the picture animation),
timed to the opening. So in Rive, make `flash` and skip `glow`, `rays` and
`sparkles` (and their rows in the Step 4 table). Add them only if you want
extra light on top of the app's.

Draw these with Rive's shape tools, behind and in front of the chest:

- `glow`: a large soft circle behind the chest, warm colour (gold for Golden,
  cyan for Cyber, purple for Galaxy), with a blur or radial gradient fill.
  Opacity 0.
- `flash`: a white circle in front of everything, a bit larger than the chest.
  Opacity 0.
- `rays`: 6–8 long thin triangles pointing outward from the chest's top, as one
  group behind the chest. Opacity 0, scale 0.5.
- `sparkles`: 5–6 small four-pointed stars around the chest. Opacity 0.

## Step 4: animate (Animate Mode)

1. Switch to **Animate Mode** (Tab).
2. Click **+** next to the timeline tabs and choose **Timeline**. Name it
   `Open`.
3. Click the time display at the top of the timeline. Set **Duration** to
   **2.3 s** (2 seconds 18 frames at 60 fps).
4. Set the end behaviour button to **One-Shot** (not Loop).
5. Set keys at the times below. To key a value: move the playhead to the time,
   then change the value (or click the key diamond next to it).
6. Select all keys and set **Cubic** easing (press **F8**). Use **Cubic Value**
   (**F9**) for the bounce keys marked "overshoot", so they spring past and
   settle.

| Time | What to key | Feel |
|---|---|---|
| 0.00 | `closed` opacity 100%, others 0%. `chest` scale 100%, rotation 0. | still |
| 0.00–0.60 | `chest` rotation −4° → +4° → −3° → +3° → 0 (every 0.12 s). `glow` opacity 0 → 40%. | nervous rattle |
| 0.60 | `chest` scale X 106% / Y 92%. | squash down |
| 0.75 | `chest` scale X 96% / Y 108%, Y position −20. `opening` opacity 0 → 100% (between 0.62 and 0.70). | jumps up (overshoot) |
| 0.90 | `chest` scale 100%, Y 0. `flash` opacity 0 → 70%. | lands, light leaks |
| 0.98 | `burst` opacity 100% (from 0 at 0.94); `opening` and `closed` to 0 at 1.00. `flash` 70% → 0 by 1.20. | hidden behind the flash |
| 0.98–1.40 | `rays` opacity 0 → 100%, scale 50% → 110%, rotation 0 → 15°. `glow` 40% → 90%. `sparkles` pop in one by one (opacity 0 → 100%, scale 0 → 100%). | burst of light |
| 1.40 | `chest` scale 108% (overshoot), then 100% at 1.60. | punch |
| 1.50 | `opened` opacity 0 → 100% by 1.62; `burst` to 0 at 1.64. A small `flash` (0 → 40% → 0) between 1.48 and 1.70. | settles open |
| 1.60–2.30 | `rays` slowly rotate to 30° and fade to 40%. `sparkles` drift up 20 px and fade to 0. `glow` gently to 70%. | calm glow |
| 2.30 | End: `opened` 100%, everything else calm. | rest |

Tips:
- Never show two chest pictures both at 50%: switch them quickly (within
  0.06 s) while a flash or a jump covers the change.
- Play it with the space bar and adjust until it feels good. Smaller rattle,
  bigger burst usually looks best.

## Step 5: make it play by itself (State Machine)

1. Still in Animate Mode, open the default **State Machine** (create one with
   **+** next to the timeline tabs → **State Machine** if there is none).
2. Drag the `Open` timeline into the state machine graph.
3. Connect **Entry** → `Open`. That is all: the opening plays once when the app
   starts the file, and stays on its last frame.
4. Press play on the state machine to check it.

(Optional, for later: the app also sends a trigger named `open` and a number
`progress` from 0 to 100. A file can use them, but it does not have to.)

## Step 6: export and add to the app

1. Click **Publish** on the right of the toolbar and choose **To .riv** (or the
   main menu → **Export** → **For Runtime**), then **Export your Rive file**.
2. Rename the downloaded file to `golden.riv`.
3. Put it in the project at `assets/chests/rive/golden.riv` (or send it to the
   developer).
4. Rebuild the app. Open a Golden chest: it now plays the Rive animation.

Repeat steps 2–6 for `cyber` and `galaxy`. Tip: duplicate the Golden file in
Rive, then swap the four pictures (Assets panel → replace) and change the glow
colour, so all the timing is reused.

## Better art: a lid that really swings open

For a real hinged lid, the chest must be drawn as separate parts that fit
together, from the same angle:

1. `body`: the box without its lid, with a glowing **inside** visible.
2. `lid`: the lid alone (closed shape), drawn so it can rotate on its back
   hinge.
3. `lid_inside`: the underside of the lid, seen when it is open.
4. `lock`: the padlock alone.
5. Optional `treasure`: coins or gems peeking out of the box.

Ask a designer for these (the four existing pictures show the style), or ask an
AI image tool for each part separately "in the exact style of this chest, same
angle, transparent background". In Rive, the lid is then rotated on its hinge
(about 0° → −110°) between 0.9 s and 1.4 s, with the same light effects as
above.
