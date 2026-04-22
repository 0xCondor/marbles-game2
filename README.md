# Marbles Game

3D physics marble race game, designed for online casino integration (crypto-first). First-to-finish wins the pot.

See [PLAN.md](PLAN.md) for the full development plan, [PROGRESS.md](PROGRESS.md) for what's done. Current status: **M4 done** — round state machine with `WAITING → BUY_IN → RACING → SETTLE` loop, mock buy-ins, payout calculator, per-round audit trail. Next up: M5 Web client + WebSocket streaming.

## Quick preview (no Godot needed)

Open **[demo.html](demo.html)** in any browser — standalone Three.js + Cannon-es preview of the marble race with leader camera, finish banner, and race results. Not the production build, just a concept demo.

## Repo layout

```
marbles-game/
├── PLAN.md           # Development plan (scope, architecture, milestones)
├── demo.html         # Browser preview (Three.js, no install needed)
├── game/             # Godot 4 project (both sim and client targets)
├── server/           # Backend glue (not started)
├── ops/              # Dockerfiles, CI (not started)
└── docs/             # Design docs
    ├── fairness.md       # Provably-fair commit/reveal protocol
    └── tick-schema.md    # Replay wire format
```

## Dev setup

### Godot

- **Version:** 4.6.2-stable (latest as of 2026-04). Jolt is the default 3D physics backend from 4.4+.
- **Install path on this machine:** `C:\Users\sergi\Godot\Godot_v4.6.2-stable_win64.exe`
- If reinstalling, grab the win64 zip from <https://godotengine.org/download/> or the GitHub releases page. No Hub, no account required.

### Opening the project

```bash
# Launch editor on the project
"C:\Users\sergi\Godot\Godot_v4.6.2-stable_win64.exe" --editor --path "game"
```

Or just open Godot → Import → point at [game/project.godot](game/project.godot).

### Running the current prototype

Four end-to-end scenes, all runnable headlessly:

| Scene | What it does |
|---|---|
| `res://round_main.tscn` | **Round loop** — continuous `WAITING → BUY_IN → RACING → SETTLE` cycle with mock buy-ins, payout calculator, per-round commit/reveal and replay archive |
| `res://main.tscn` | Single race: generate `server_seed`, publish hash, run seeded race with leader camera, write replay, print full race results, reveal seed |
| `res://playback_main.tscn` | Load latest replay, render visual-only marbles with real colors driven by interpolated tick frames |
| `res://verify_main.tscn` | Headless verifier: re-derive spawn slots from the revealed seed and confirm they match the recording |

In the editor: press **F5** and pick the scene. Headless:

```bash
"C:\Users\sergi\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path game --quit-after 3000             # record
"C:\Users\sergi\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path game res://playback_main.tscn      # play back latest
"C:\Users\sergi\Godot\Godot_v4.6.2-stable_win64.exe" --headless --path game res://verify_main.tscn        # verify latest
```

### Headless smoke-test

Useful to catch script errors without opening the editor:

```bash
"C:\Users\sergi\Godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path game --import
```

## Project settings locked in

- Physics tick rate: **60 Hz**, also the wire tick rate for v2 replays (revisit when bandwidth becomes a concern in M5 — see [PLAN.md open questions](PLAN.md#L161)).
- Physics engine: **JoltPhysics3D** (set explicitly in [game/project.godot](game/project.godot)).
- Renderer: **Forward+** (may switch to Mobile or Compatibility for Web export in M5 if bundle size blows up).
