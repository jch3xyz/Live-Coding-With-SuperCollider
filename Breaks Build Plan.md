# Breaks — Build Plan (breakbeat machine)

Status: **BUILT August 2026.** Designed and implemented in one session; verified
headless (70 language-side assertions + a 13-render NRT battery). Not yet played —
John has no break library loaded yet, so calibration by ear is outstanding.
Owner: John. Companion docs: "Design Notes.md" (language thesis), "Roadmap.md"
(build pipeline), Setup/SynthDefs/CONVENTIONS.md (def contract).

Documentation shipped with the code: **Guides/Breaks** (tutorial, runnable with
SuperCollider's own bundled sound so it needs no library), **Classes/Break**
(registry API), break words added to Classes/NodeProxy and Classes/Symbol, and
Reference/Synesthesia-Reference rewritten to integrate the family.

**As-built deviations from this plan are recorded at the bottom** — several are
consequences of measurement, and the reasons matter more than the plan did.

## What it is

Breakbeat loops as first-class performable material: any break locks to the session
tempo the moment it enters; one macro (`grind`) moves the material continuously from
intact loop → beat/16th chops → granular dust; slice order is sequenced, reversed, or
stochastic on a fader; the source recording swaps mid-flight in one token with no gap
and no re-declaration. Target surface:

```supercollider
~d.brk(\amen); ~d.play;      // enters bar-aligned, tempo-locked
~d.grind(0.45);              // clean 16th chops
~d.seq("0.325476");          // resequence, "." = rest
~d.scr(0.5);                 // half stochastic
~d.brk(\think);              // swap source, gapless, controls persist
~d.grind(0.95); ~d.jit(0.6); // dissolve to dust
~d.ord; ~d.grind(0.3);       // reassemble
```

## Architecture decisions (settled at design time)

1. **Not a new quark, not a lone SynthDef.** One new SynthDef family member
   (`\break`, canvas voice) + one one-shot def (`\brk1`, pattern brush) in
   Setup/SynthDefs/, plus a `Break` registry class and vocabulary words inside the
   existing Synesthesia quark. Rationale: CONVENTIONS rule 5 (no environment capture
   in defs) makes it impossible for a def to know sample tempos, index `d`, or hold a
   rewritable sequence — that intelligence is language-side by the system's own law.
   The quark is the designated home for all vocabulary (Design Notes, non-negotiable
   rule 1).
2. **Grain engine, single voice, server-side triggering.** The beats→grains
   continuum is one mechanism: a tempo-locked GrainBuf whose pointer tracks musical
   time through the loop at session tempo. Slicing IS big grains quantized to the
   grid — that is why the gesture can be continuous. Server-side triggers because the
   dust end needs 100–200 trig/s, past the language scheduler's comfort (~50 ev/s).
3. **Sequencing lives in the signal graph** ("patterns inside the signal graph",
   Design Notes): slice order in a small control buffer read per-trigger
   (Stepper + Index), rewritten live with `setn` — resequencing without rebuild.
   Stepper over Dbufrd deliberately: Stepper's max is a signal, so variable-length
   sequences wrap correctly and `\resync.tr` realigns for free.
4. **Gapless swap is free**: GrainBuf latches its buffer number per grain, so
   `.set(\buf, ...)` is click-free (in-flight grains finish on the old break). The
   `brk` word bundles `buf/beats/steps` bar-quantized on `p.clock`.
5. **Mono core** (GrainBuf requires mono; spatial rule 6b wants mono anyway). The
   registry loads its own mono reads (`Buffer.readChannel(..., channels: [0])`);
   the existing stereo `d` loader is untouched. Duplicate memory is trivial
   (breaks are seconds long).
6. **Tempo knowledge is load-time metadata**, inference chain: filename regex →
   folder-name regex → duration heuristic → persistent manual override. The engine
   only ever consumes `beats` (loop length in beats) + the live tempo bus.
7. **Prior art rejected**: SuperDirt (installed; has slice/splice/loopAtBpm but
   brings Tidal's event/signal wall and orbit topology — the exact paradigm Design
   Notes inverts); BBCut2 (canonical SC breakcutter; unmaintained, own clock,
   fights JITLib quant); pattern-only slicing (dies at the dust end; survives as
   the `\amen.chop` brush layer).

## Components

| File | What |
|---|---|
| `Synesthesia/classes/Break.sc` | registry: scan/load/infer/override/persist; tempo bus; per-proxy seq-buffer bookkeeping |
| `Synesthesia/classes/extSymbolBreaks.sc` | `\amen.buf`, `.bpm_`, `.beats_`, `\amen.chop(...)` brush |
| `Synesthesia/classes/extNodeProxy.sc` (extend) | `brk, grind, seq, ord, rev, scr, jit, over, vari, roll, resync, next` |
| `Setup/SynthDefs/break.scd` | the engine (canvas voice) |
| `Setup/SynthDefs/brk1.scd` | one-shot slice player (brush voice) |
| `Setup/Setup.scd` (one hook) | `Break.scan(setupDir +/+ "samples")` after the `d` loader |
| `Setup/samples/breaks/…` | the material (repopulate; Dirt-Samples has stopgap break folders) |
| `Setup/BreakTour.scd` | GamutTour-style matrix walk for calibration by ear |
| `Synesthesia/HelpSource/…` | Classes/Break.schelp + holistic Reference rewrite |

## Engine spec — `\break`

Family: grain voice (gated). Tier 0 (stock). Mono core, `Pan2` at output, gated
`Env.asr` with `doneAction: 2` (proxy owns the gate).

Controls (all NamedControls; Specs registered — shared names already in 00_specs.scd,
break-unique ones added there in this build):

| control | spec | meaning |
|---|---|---|
| `buf` | — | current break (set by `brk`, latched per grain) |
| `tempo` | — | **mapped** to `Break.tempoBus` (beats/sec), never set per-voice |
| `beats` | [1, 64, lin] | loop length in beats (per-source metadata, set on swap) |
| `steps` | [1, 64, lin] | slice grid per loop (default `beats * 4` = 16ths) |
| `grind` | [0, 1] lagged | THE macro: grains/beat = `0.25 * (256 ** grind)` (0.25 → 64, exp) |
| `over` | [0.25, 4, exp] | grain overlap; grain dur = `over / trigRate`. <1 = MPC-gap feel, >1 = smear |
| `scram` | [0, 1] | per-trigger probability of random slice substitution (ordered↔stochastic fader) |
| `jit` | [0, 1] | grain position scatter (squared scaling; the dust ingredient) |
| `vari` | [0, 1] | pitch behavior: 0 = pitch-preserved stretch, 1 = full varispeed repitch |
| `rate` | [0.25, 4, exp] | musical transpose on top of `vari` |
| `sbuf`, `slen` | — | slice-sequence control buffer + active length (registry-managed) |
| `resync` | trigger | realign step counter + pointer to the bar |
| `pos` | [0, 1] | static pointer offset into the loop |
| `atk`, `rel`, `amp`, `pan`, `out` | shared | per conventions |

Load-bearing math (the whole engine in eight lines):

```supercollider
var loopNorm  = tempo / beats;                        // normalized loop units per second
var sliceTrig = Impulse.ar(steps / beats * tempo);    // the musical slice grid
var stepIdx   = Stepper.ar(sliceTrig, \resync.tr(0), 0, slen - 1, 1);
var seqVal    = Index.ar(sbuf, stepIdx);              // -1 encodes a rest
var useRnd    = TRand.ar(0, 1, sliceTrig) < scram;
var idx       = Select.ar(useRnd, [seqVal.max(0), TIRand.ar(0, steps - 1, sliceTrig)]);
var slicePtr  = (idx / steps) + Sweep.ar(sliceTrig, loopNorm);   // stretched pointer
var trigRate  = 0.25 * (256 ** grind) * tempo;
var trig      = Impulse.ar(trigRate);
var strch     = BufDur.kr(buf) * tempo / beats;       // source↔session speed ratio
var sig       = GrainBuf.ar(1, trig, over / trigRate, buf, rate * (strch ** vari),
                    (slicePtr + (TRand.ar(-1, 1, trig) * jit * jit * 0.1)).wrap(0, 1))
                * Latch.ar(Select.ar(useRnd, [seqVal >= 0, DC.ar(1)]), trig);
```

Named regions of the control space (document these in help; they are the presets):

- `grind ≈ 0, vari 1` — classic looper: exact fit, jungle repitch.
- `grind ≈ 0, vari 0` — bar-grain stretch: original pitch, resyncs each grain
  (audibly "chop-fit" when tempos differ; this is a sound, not a bug — see Risks).
- `grind 0.4–0.55, over ≈ 1.1` — clean chops on the grid, original pitch.
- `grind 0.4–0.55, over < 0.8` — gated MPC chop (gaps as groove).
- `grind > 0.85 + jit` — dust; `over > 2` besides — wash territory (feed `~verbIn`).

## Registry spec — `Break`

- `Break.scan(path)` at boot: walks `samples/breaks*` folders (configurable list).
  Per file → entry `Break.all[\key] = (buf:, bpm:, beats:, path:)`; key = sanitized
  filename Symbol, deduped.
- **Inference chain** (pure function, unit-tested): filename `(\d{2,3})\s*bpm` →
  folder-name same regex → duration heuristic: for bars in [0.5, 1, 2, 4, 8],
  candidate bpm = `bars * 4 * 60 / dur`; prefer the candidate in 130–180 (break
  window), else nearest 60–200. `beats = round(dur * bpm / 60)`.
- **Override + persistence**: `\amen.bpm_(172)` / `\amen.beats_(8)` update the entry
  AND write `_breaks.scd` sidecar (Dictionary literal) in the folder; sidecar merges
  over inference at every boot. Odd meters need no special case — `beats_` is the
  escape hatch.
- **Tempo bus**: `Break.tempoBus` (control Bus, beats/sec). The existing `bpm()` word
  gains one line to set it; a lightweight watcher (SkipJack) mirrors direct
  `p.clock.tempo` changes. Engine voices `map` — never `set` — `\tempo`.
- **Seq buffers**: `Break.seqBufFor(proxy)` allocates a 64-frame control Buffer per
  proxy (identity ramp default), caches, frees on `Break.clear`.
- **Live capture**: `Break.capture(\name, buf, beats)` — `rec()` captures carry
  perfect metadata (recorded at session tempo, no inference). Chop your own playing.

## Vocabulary (every word returns a plain SC object; rule 1)

| word | effect |
|---|---|
| `~d.brk(\amen)` | first call: `source_(\break)`, map tempo bus, alloc seq buffer, set buf/beats/steps. Later: bar-quantized gapless swap. Returns proxy. |
| `~d.brk` | no arg: cycle to the next break in registry order |
| `~d.grind(x)` / `.scr(x)` / `.jit(x)` / `.over(x)` / `.vari(x)` | one fader each (lagged sets) |
| `~d.seq("04.2 6a.b")` | hex digit = slice index, `.` = rest, space ignored; also accepts Array. `setn` scheduled on next bar. Sequences shorter/longer than `steps` wrap at `slen` → free polymeter |
| `~d.ord` / `~d.rev` | identity / reversed slice order, `scram = 0` |
| `~d.roll(n)` | freeze step counter, multiply slice trig ×2^n (stutter); `~d.roll(0)` releases |
| `~d.resync` | realign counter + pointer to the bar |
| `\amen.buf` / `.bpm_` / `.beats_` | raw Buffer access; persistent metadata override |
| `\amen.chop("0325", step: 0.25)` | **brush**: Pbind on `\brk1` — per-event work (per-hit rate/pan/amp, PbindFx, euclid masks via Bjorklund). Reuses hits-string conventions |

Collision rule: before landing any word, check `Object.findRespondingMethodFor` /
existing class methods (`rev`, `seq`, `roll` are the likely suspects) and rename on
collision — same practice as Phase 1d's `send → route` rename. `Break` as a class
name: verify `\Break.asClass.isNil` at build start.

---

## Build phases

Each step independently playable; verification appropriate to the phase is the gate
(working practice #3 — play-testing informs calibration, never blocks build).

### B0 — Prerequisites (blocking, ~minutes)

- [ ] **sclang_conf include path fixed** (separate task already running: repoint
      `~/Documents/GitHub/Synesthesia` → `~/Tools/Synesthesia`). Gate: headless
      sclang compile posts `Synesthesia.version`. Nothing else starts until this
      passes — the quark is currently not loading at all.
- [ ] Repopulate `Setup/samples/breaks/` — minimum 3 loops at ≥2 different source
      tempos (stopgap: copy from Dirt-Samples' break folders; long-term: rebuild
      John's own collection).
- [ ] Name-collision sweep for `Break` and the planned words; record renames here.

### B1 — Registry (language-side only, ~half session)

- [ ] `Break.sc`: scan/load (mono reads), inference chain, sidecar merge,
      override setters, `tempoBus` + `bpm()` hook + clock watcher, seq-buffer
      bookkeeping, `capture`.
- [ ] Setup.scd hook (one line, after the `d` loader block).
- [ ] Unit tests (SynesthesiaTests): inference regexes, duration heuristic across
      the bar table, beats rounding, sidecar merge precedence, seq-string parser
      (hex digits, rests, whitespace).
- **Done when**: tests pass headless; boot posts `Breaks: N loops (M inferred, K tagged)`.

### B2 — The brush: `\brk1` + `\amen.chop` (~half session; first playable milestone)

- [ ] `brk1.scd`: one-shot windowed slice player per conventions (buf/rate/pos/amp/
      pan/out, `Env.linen` with click-proof edges, doneAction 2, hold failsafe).
- [ ] `extSymbolBreaks.sc`: `.chop` word — parses slice string, builds Pbind
      (\pos from slice index, \dur from step, \rate default = strch via Pfunc
      reading clock tempo so it tracks live bpm changes).
- [ ] Unit tests for the chop-string parse; construction smoke test of the Pbind.
- **Done when**: with samples loaded, `\amen.chop("0123").play` chops any break to
      the session grid, verified by NRT onset render (see Verification).

### B3 — The engine: `\break` (~1 session)

- [ ] `break.scd` per the spec above; Specs for grind/scram/vari/over/jit/steps
      added to 00_specs.scd (shared-name registry).
- [ ] NRT verification battery (house practice, as used for palette v1):
      - slice onsets land on the session grid ±5 ms at two session tempos
        (fixture: synthesized click loop at a known source tempo);
      - tempo-lock: same fixture, `tempoBus` changed mid-render, grid follows;
      - rest slices render silent; scram=1 renders nonsilent with slice-count
        onsets;
      - buf swap mid-render: no discontinuity above normal grain-boundary level
        (peak-window comparison);
      - grind sweep 0→1 render: no clipping, no NaN, node dies on gate release;
      - grain budget: max concurrent grains at grind=1/over=4 well under
        GrainBuf's default 512.
- **Done when**: battery passes headless; def loads at boot with no exceptions.

### B4 — Canvas words + plumbing (~1 session)

- [ ] `extNodeProxy.sc` additions: brk (source/map/alloc/swap logic, bar-quantized
      bundles on `p.clock`), grind/scr/jit/over/vari/rate (lagged sets), seq/ord/rev
      (setn scheduled on bar), roll, resync, next.
- [ ] Construction smoke tests (pattern of Phase 1's word tests): each word returns
      the proxy / a plain object; swap preserves control state; seq of wrong length
      wraps.
- [ ] `BreakTour.scd`: q[\breakTour] — scripted walk of the named regions
      (looper → chops → gated chop → dust → wash) across two breaks and a
      mid-tour bpm change.
- **Done when**: smoke tests pass; the set fragment at the top of this doc
      evaluates end-to-end headless (construction + a short real-time render).

### B5 — Extras (pull individually, each ≤ half session; none blocks B6)

- [ ] `flip(p)` — probability a grain plays reversed (negative rate, pos offset by
      grain length).
- [ ] Euclid rest-masks: `~d.mask(3, 8)` writes rests into the seq buffer via
      Bjorklund (dep already pinned).
- [ ] Swing: off-beat trigger phase offset (`swing` control, dual-Impulse or phase
      trick — timebox; drop to brush-layer-only if the server plumbing fights).
- [ ] `rec()` → `Break.capture` wiring: one word from live playing to choppable break.
- [ ] Per-slice sends: route grain output share to `~verbIn`/`~delayIn` keyed off
      slice index (evaluate; may be Phase-2 fx territory).

### B6 — Docs + calibration handoff (~half session)

- [ ] `Classes/Break.schelp` + word docs on their home classes; runnable examples
      use SC's bundled mono sounds (a11wlk01) so examples never require this repo.
- [ ] **Holistic rewrite** of Reference/Synesthesia-Reference (working practice #5:
      integrate into families — breaks join the spawner + canvas word families —
      never append).
- [ ] Roadmap.md: fold this plan in as a phase, check off, note renames.
- [ ] Calibration (John, by ear, no deadline): play BreakTour; rename words that
      don't sit right; report dead zones in the grind continuum; decide whether
      this becomes a painting-register applicator (`chop` as a tool?) and what, if
      anything, hue should mean. HSV mapping sketch when ready: val = spectral
      tilt, sat = trigger regularity/scatter (sprayb precedent), hue = TBD.

## Risks / open questions

- **"Automatically" is only as good as the cuts.** Duration inference presumes
  whole-bar loops. Ragged cuts → wrong beats → wrong grid. Mitigation: sidecar
  tagging is one-time per file; boot post names which loops were inferred vs
  tagged so surprises are visible.
- **The grind mid-zone** (slice→grain transition) is mathematically continuous but
  its musicality is unproven — NRT proves math, ears prove instruments. Fallback
  (no vocabulary change): two engines crossfaded behind the same macro.
- **Impulse vs TempoClock phase** after mid-set tempo changes: frequency updates
  instantly but phase error accrues at the change moment. `resync` word + auto
  resync inside `bpm()` on the next bar. Accepted as performance-grade, not
  sample-accurate.
- **Word collisions** (`rev`, `seq`, `roll`) — resolved at B0 sweep, renames
  recorded here.
- **grind=0 + vari=0 drift-within-grain** when tempos differ widely (bar-long
  grains resync only at boundaries). Documented as a named region rather than
  engineered away; if it grates, cap the low end of grain duration.

## Deferred by design

- HSV contract for `\break` (post-calibration; conventions allow omitting axes).
- Painting-register naming (tool vs time-word) — John's call during calibration.
- Spatial: engine is mono-core already; placement arrives with the spatial phase.
- Onset-based tempo detection: not worth it while the heuristic + sidecar covers
  the library; revisit only if a large untagged ragged collection shows up.
- Swing (a trigger phase offset on odd slices) — dropped from v1 to keep the
  phase derivation single-sourced; reachable later as a slice-grid offset.
- Per-slice fx sends: Phase-2 fx territory, not the engine's job.

---

# As built — where the implementation diverged, and why

Every item here came from measurement or from a collision check, not from taste.

1. **Step counter: `Phasor` + `PulseCount` + wrap detection, not `Stepper`.**
   The plan used `Stepper` with a modulatable `max`. Instead everything derives from
   ONE `Phasor` that runs a cycle per loop, with slice and grain grids read off it.
   Consequences: no drift possible between grids (they share a phase), the whole
   thing is resettable to the bar (`resync`), the sequence index is
   `((loops * steps) + slice).mod(slen)` which can never leave the buffer or get
   stuck when the sequence length changes, and the pointer becomes a pure function
   of phase — `(slice + fractionThroughSlice) / steps` — so no `Sweep` is needed at
   all. Verified: exactly 16 single-sample triggers for 16 slices.

2. **A dedicated phasor for the grain grid** rather than `loopPhase * grainsPerLoop`.
   Scaling an advancing phase by a moving factor makes the phase itself jump, which
   fired spurious grains while `grind` was being swept — measured as a peak of 2.16
   during a sweep, down to 1.30 after the fix. Both phasors start together at reset,
   so the exact coincidence at `grind` 0.5 (grain grid == slice grid) survives.

3. **`grind` is piecewise exponential with three exact stations**, not one curve.
   `0` = 1 grain per loop, `0.5` = exactly `steps` grains per loop (one per slice —
   clean chops), `1` = 64 grains per beat. A single exponential put the
   musically-important chop station at an arbitrary value that also moved with
   `beats`. Now `0.5` is exact for any loop length.

4. **Overlap compensation is `1/over`, not `1/sqrt(over)`.** Measured: RMS rose
   +6 dB from `over` 1 to 4 under the sqrt law. The reason is specific to this
   design — the pointer advances at exactly the rate the grid does, so two
   overlapping grains play the *same* source audio in phase and sum coherently
   rather than incoherently. With the linear law, measured RMS is flat to 0.0 dB
   across `over` = [0.5, 1, 2, 4].

5. **Selectable grain windows, defaulting to `\punch`** — not in the plan at all.
   `GrainBuf`'s built-in window is a Hann curve, which fades in the front of every
   grain, i.e. exactly where a snare transient lives. Chops through it are mush.
   `Break.windows` holds `\punch` (fast attack, short tail), `\gate`, `\hann` and
   `\swell`; the engine polls its envelope buffer per grain, so `~d.win(...)`
   switches live. This is probably the single biggest audible-quality decision in
   the build.

6. **No tempo bus.** The plan mapped a control `Bus` into every voice. Instead the
   registry keeps the set of live break voices and pushes tempo to them
   (`bpm()` calls it for immediacy, a `SkipJack` catches changes made any other
   way). Fewer moving parts, no server-state lifecycle to rebuild after a reboot,
   and nothing extra appears in the ProxyMixer or gets caught by `hush`.

7. **`Break.trig` sets a trigger control and then unsets it.** `NodeProxy:set`
   stores values in the proxy's nodeMap, which is replayed on every rebuild — so a
   `\resync` left set to 1 would fire a phantom realign on every re-evaluation.

8. **Two renames forced by collision checks** (run before writing the words, in the
   spirit of Phase 1d's `send → route`): `rate` → **`speed`** on NodeProxy, because
   `BusPlug:rate` exists and reports audio-vs-control; `beats_` → **`len_`** on
   Symbol, because `Object:beats_` is a real (empty) method "for PauseStream" and
   Symbols do flow through stream machinery in this system via ChordSymbol2 — a
   scheduler could otherwise have silently rewritten a break's metadata and its
   sidecar file.

9. **`flip` and `mask` shipped in v1** rather than waiting for B5 — both were a
   couple of lines once the phase machinery existed. `flip` offsets a reversed
   grain by its own source length so it covers the same audio as the forward one.

10. **`chop` throws on a missing buffer.** `Pbind` terminates the moment any key
    stream yields nil, so a break with no buffer would have produced a pattern that
    silently played nothing.

11. **Sidecar gained a `key:` field**, which renames a break. This is what makes a
    60-character freesound filename usable mid-set, and it solves the "auto keys are
    ugly" problem without any name-shortening heuristic.

12. **Verification artifacts are permanent**: `Setup/BreakCheck.scd` (NRT battery,
    builds its own fixtures, re-runnable after any engine edit) and
    `TestBreak.run` (language-side, instant).

## Verified, and not

**Measured true:** slice onsets land on the session grid to the sample (5512.5
samples for a sixteenth at 120 bpm, min 5512 / max 5514); a 90 bpm source and a
175 bpm source both lock to the same 120 bpm grid; the grid follows a tempo change;
rests silence their slices; a buffer swap has no gap; `vari 0` holds the loop period
to exactly 88200 samples; peak is −3.8 dBFS at default amp on worst-case
full-scale-impulse material; the node frees itself on gate release; 70 language-side
assertions pass, including that the inference ignores freesound id numbers and reads
`breaks175` folder names.

**Not verified, by nature:** whether the middle of the `grind` range is *musically*
useful rather than merely continuous, and whether the word names survive contact
with playing. Both are John's calibration pass, and both are cheap to change — a
curve and a set of method names, no architecture.
