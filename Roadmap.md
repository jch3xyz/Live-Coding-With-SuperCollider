# Roadmap — Live Coding System Build Pipeline

Handoff document. Self-contained enough to start a build session from, with design
rationale living in its two companion docs:

- **"Design Notes.md"** — the core quark: language thesis, registers, vocabulary
  buckets, auto-GUI/Board, visuals painting-protocol design.
- **"Companion Quarks.md"** — perception quarks (MediaPipe, emotion, pose, etc.).
- **"Vocabulary Sketch.scd"** — what using the language should look like (design
  fiction; Phase 1–2 make it real).

Owner: John (john@newmedianashville.com). Repo: Live-Coding-With-SuperCollider.
Current state: co34pt-style ProxySpace setup (Setup/Setup.scd, 18 SynthDefs, sample
dict `d`, ddwSnippets, StageLimiter, timestamped recording). Design phase complete;
nothing below is built yet.

## Non-negotiable design rules (apply to every phase)

1. **Terseness as sugar, not a wall**: every terse form evaluates to a plain SC
   object (Pattern / Function / NodeProxy); raw SC composes anywhere.
2. **Named controls are the universal substrate**: quark verbs lift literals into
   named controls with registered Specs. GUI, trackpad, CV, presets, and patterns are
   all clients of the same interface.
3. **Nothing auxiliary gets performance commands**: visuals, GUI, and camera all
   materialize from the sound code / Setup, never from typed commands mid-set.
4. **Laptop-first**: trackpad, keyboard, webcam, screen. No external hardware assumed.
5. **Process isolation**: helpers (CV, visuals) are separate processes speaking OSC;
   a crash anywhere else never stops sound.
6. **Frequency is the pitch currency**: degrees, note names, chord symbols
   (ChordSymbol2) are notations that resolve to freqs.

## Phase ordering rationale

Audio first (Phases 0–2) because the instrument must be playable before it is
visible; visuals (Phase 4) consume the language, so the language must exist; advanced
interactivity (Phase 5) consumes both. Phase 3 (Board/gesture) sits between because
its named-controls audit is a prerequisite for clean preset-morphing (used by color
mixing) and for everything CV eventually drives.

---

## Phase 0 — Foundations (≈ a day) → the substrate

Goal: a real quark skeleton and a hardened Setup, with zero behavior change to the
existing workflow.

- [x] Create the personal quark: **Synesthesia**, its own repo at
      `~/Tools/Synesthesia` (git-initialized, first commit made);
      registered via sclang_conf.yaml includePaths (same mechanism Quarks uses).
- [x] Pin dependencies in the quark file: Bjorklund, BatLib, ddwSnippets,
      JITLibExtensions (cloned into downloaded-quarks + include path added).
      BenoitLib documented as manual dep in README. ChordSymbol2 was ALREADY
      installed as a quark (downloaded-quarks/ChordSymbol2, identical to the Help/
      reference copy) — no action needed.
- [x] Setup.scd hardening: `History.start`; `p.quant = 4`; standing FX returns
      `~verbIn/~verb` (GVerb) and `~delayIn/~delay` (tempo-synced CombC), silent
      until fed via `.add`, created after `s.freeAll` so they survive setup.
      (Dropped `~master` — StageLimiter already covers the master chain.)
- [x] Merge `Snippets copy.scd` into active Snippets.scd — co34pt's full library +
      John's three presets appended last (they win collisions: kick, snare, ring1).
      Fixed for this sample set: piano→Piano, stabs→stab, breaks→breaks175,
      rhodes→Piano, cym→oh; fixed co34pt bugs (loop's unescaped \amp, HPF snippet
      wired to ~lpfSend).
- **Done when**: one evaluation boots to playable; everything that worked before
  still works; `History` is logging.

## Phase 1 — MVP audio language (≈ 1–2 weeks of sessions) → THE MINIMUM VIABLE SYSTEM

Goal: the engineering-register instrument. The set opening in "Vocabulary Sketch.scd"
(minus colors) runs verbatim. This phase alone is a complete, gig-able system.

Build order (each step independently playable):

- [x] 1a. Bare control words: `bpm(n)`, `grid(n)`, `hush(t)`, `rec(beats)`, `pad(\x)`.
      (Implementation note: sclang's `foo(x)` dispatches to the first argument, so
      these live on SimpleNumber/Symbol, not Interpreter — call syntax unchanged.)
- [x] 1b. **hits-string parser** + `\k.hits("x.Xx")` / euclid `\k.hits(3,8)` →
      real Pbinds on d + bplay; accents, digit variants, rests via Rest();
      `"x.x.".steps` / `.stepAmps` for any \dur socket. Unit-tested.
- [x] 1c. **deg-string parser** + `\sinfb.deg("0 3 5 [0 2 4]", 0.5, oct:3)`
      (bracket chords, rests, negatives) and `\sinfb.chord("Cm7_3 Fm9")` via
      ChordSymbol2 stream embedding. Unit-tested.
- [x] 1d. Graph words: `\dfm/.tone/.saw .drone(root, mult, wob)` + `.stack(root,
      mults)` recipes; `.fx(\name, val)`/`.unfx` on proxy slots 10+ (recipe
      registry: lpf/hpf/verb/delay/dist/crush/wide/dc; ProxyChain wants to own the
      proxy, so slots+registry instead); `.feeds(proxy, amt)`, **`.route`**(\return,
      amt) (renamed — NodeProxy:send exists), `.fade(t)`, `.wide(w)`, `.dc`.
- [x] 1e. Bridges: `.follow`, `.duck(proxy, amt)`, `.pat` (Pkr); `pad(\x)/pad(\y)`
      with **`.mapExp/.mapLin`** (renamed — .exp/.lin are math operators).
- [x] 1f. Transform verbs: `.fast/.slow/.sometimes(p, f, beats)/.jux(f)`
      (sometimes = per-window coin-flip via Pn+Plazy+Pfindur).
- [x] 1g. Numeric params lift to NamedControls + Spec registry in Synesthesia
      *initClass — GUI/presets/MIDI-learn substrate in place from day one.

- **Done when**: the words compile, the parsers pass their unit tests, and the
  Vocabulary Sketch set-opening evaluates without errors. (Playing it — and the
  History-log Zipf pass — happens whenever John plays; it feeds design, not the gate.)
- **DONE July 2026** — verified headless: clean class-library compile; 27 assertions
  (all parser unit-test cases + construction smoke of the sketch opening, incl. fx/
  duck/feeds/route/follow/pad graph building) pass. Tests also runnable in the IDE:
  `TestSynesthesiaParsers.run`. Synesthesia repo commit 42314e1.
- After: mine History for frequency → promote/rename/kill words (Zipf pass #1).

## Phase 1.5 — SynthDef & sample library audit (decided July 2026)

The co34pt-inherited SynthDefs and samples are scaffolding, not the destination —
**scrap and rebuild as John's own library.** Phase 2 colors must be recipes over the
NEW instruments, so this precedes it.

- [x] Audit of all 18 legacy defs done (July 2026, 3-agent workflow): 5 buffer
      players collapse to a rebuilt one-or-two; keeps-as-concepts: bpfsaw, sinfb,
      warp1, henon, ring1, bpfbuf, lplay, wtabl, hats + stock rebuilds of the dead
      AnalogKick/AnalogSnare; kills: dfm1 (buggy+dep), duplicates. Systemic legacy
      bugs catalogued (44100 hardcodes, vplay 4-bus Pan2, lplay baked tempo,
      henonc never frees). Corrections: Henon*/SinOscFB/Warp1 are STOCK.
- [x] House SynthDef style defined: **Setup/SynthDefs/CONVENTIONS.md** — one def
      per file (folder auto-loaded), shared macro axes `bright/grit/morph`
      normalized 0..1 (the color contract; MI-architecture validated), freq for
      pitched, every-synth-can-die, no env capture/44100, channel correctness,
      Specs travel with defs, plugin tiers (Tier 0 stock; Tier 1 whitelist incl.
      mi-UGens minus MiRipples [missing binary], DEINDUGens, DFM1, Bhob/MCLD/
      Distortion/Membrane/SLU/Mda picks; PortedPlugins banned).
- [x] Restructure: SynthDefs/ folder (seeds: bplay, bplaym), Snippets.scd blank
      (kept loadable), samples/ empty with global folder-per-key loader (no more
      "sets"), Setup.scd rewritten (setupDir var, folder loaders, count posts);
      legacy preserved under Setup/legacy/. Headless-verified (PHASE15-CHECK OK).
- [x] Palette v1 BUILT & VERIFIED (July 2026), all stock, per the tool-voice
      designs: \mark (2-op PM), \brush (VarSaw→sync→MoogFF), \spray (GrainFM),
      \sprayb (GrainBuf — MONO buffers only; rec() captures work directly),
      \wash (noise→comb→modal), drums \kick \snare \hat \tom \metal; plus
      Setup/GamutTour.scd (q[\tour]/q[\tourGated] matrix walks). Verification:
      headless load gate + 11-agent adversarial review (UGen signatures checked
      against class sources, NRT peak measurements) + 3-agent fix re-verification
      incl. re-rendered peaks. Notable fixes: metal Klank amps/ringtimes slot
      swap (+6.4dBFS→−8.1dBFS), log-symmetric grain jitter (sprays no longer
      transpose with grit), wash LeakDC (Crackle DC), tom bright moved to band
      center, grain overlap gain compensation, players' rel→hold rename,
      family-wide LinSelectX drive stages. John: play GamutTour, rename
      voices/axes, report dead zones.
- [ ] Sample library: deferred by design (synthesized drums; future spoken-word/
      Alan Watts material for looping/granulation).
- [ ] Retune Synesthesia drone recipes / defaults once the palette lands.
- **Done when**: Setup boots the new library with no missing-UGen exceptions and
  Synesthesia words target it end-to-end (compile + boot-log gate).

## Phase 2 — Painting register (≈ 1 week + a calibration week)

Goal: the perceptual layer over Phase 1. Timbre/texture words become colors and tools;
pitch/time stay music-language.

- [ ] Color type: HSV coordinate → synthesis recipe *region* (hue = spectral family,
      value = register, saturation = purity↔roughness); sampled-with-variation on
      each use. Start with ~6 colors over existing SynthDefs.
- [ ] Tools = applicators mapped to spawner families: `brush` (drone), `spray`
      (granular), `mark` (pattern), `wash` (bed), `dab` (hit), `drip` (Dust-driven).
      `tool(color, ...)` returns the same plain objects as Phase 1 words.
- [ ] Perceptual sculpt verbs: `.darker/.paler/.warmer/.saturate(x)` as moves on
      named controls.
- [ ] `mix(colorA, colorB, x)` = parameter interpolation (foundation for Phase 3
      preset morphing); canvas ops: `thin`, `glaze`, `bleed`, `scrape`.
- [ ] **Calibration** (John's, on his own schedule): play; rename by ear; kill words
      that die; harden survivors. The lexicon is discovered, not specified.
- **Done when**: colors/tools/mix compile and evaluate correctly (build gate);
  calibration then refines the lexicon whenever John plays.

## Phase 3 — The Board + laptop gesture (≈ 1–2 weeks)

Goal: controls materialize with the signals; hands get continuous surfaces.

- [ ] Named-controls audit: every Phase 1–2 verb passes rule #2; Spec registry
      complete.
- [ ] **The Board**: persistent dock window from Setup — row per active proxy (name,
      vol, meter, auto-sliders from named controls), rebuilding on spawn/rebind,
      two-way sync. Study NdefGui/NdefMixer internals first; steal, don't rebuild.
- [ ] MultiTouchPad quark evaluation on current macOS (private API risk — timebox
      it); if dead, `pad(\x/\y)` + Board sliders suffice.
- [ ] Optional: KeyState gate words on reserved keys; NdefPreset scene save/morph
      words (this is where `mix()` infrastructure pays off twice).
- **Done when**: the Board builds rows for live proxies with two-way-synced sliders,
  and `pad()` words compile and map correctly.

## Phase 4 — Visuals: painting protocol + Processing renderer (≈ 1–2 weeks)

Goal: visuals that generate themselves; one utterance, two renderers.

- [ ] 4a. SC side: painting words emit semantic OSC as they execute
      (`/paint/spray [id, hsv, params]`, plus lifecycle: `/paint/scrape`, `/paint/hush`);
      master-bus analysis tap + per-proxy taps auto-registered on `.play`
      (`/tap/<proxy> [amp, centroid, onset...]` at ~30 Hz).
- [ ] 4b. Processing sketch v1: renderer for the gesture protocol — one visual
      implementation per painting word, HSV shared with sound; each visual object
      subscribes to its proxy's tap (structure from events, life from signal).
- [ ] 4c. Performance plumbing: fullscreen on second display/projector; Syphon out
      (for Resolume/MadMapper later); scope X/Y mode kept as an alternative look for
      drone material.
- **Done when**: painting words emit their OSC, the sketch renders each gesture type,
  and analysis taps animate them — verified by evaluating test gestures.

## Phase 5 — Advanced interactivity: companion quarks (incremental, each ≈ weekend–week)

Goal: perception as control surface. Order chosen so each step reuses the last.

- [ ] 5a. **MediaPipe quark v1 (hands)**: Python helper (venv/uv bootstrap; camera +
      hands → OSC at 30fps, **broadcast to SC and Processing**); SC class launches/
      supervises (`.unixCmd`, auto-reconnect), derived features (pinch, openness,
      x/y/z, velocity) → control buses + Specs; `hand(\right, \pinch)` words; camera
      starts in Setup. Latency budget honest: continuous control only, no triggers.
- [ ] 5b. Face: blendshapes → `face(\mouthOpen)` etc.; valence/arousal emotion axes
      (continuous, not labels); Processing composites landmarks; Syphon frames from
      helper if camera image wanted in visuals.
- [ ] 5c. Mapping by demonstration: FluCoMa MLPRegressor (in-SC; preferred) or
      Wekinator (faster experiment) — record gesture↔sound-state pairs, train,
      bind to named controls.
- [ ] 5d. Backlog (pull when a collaboration/concept demands): pose/dance (model
      swap or LivePose; EyesWeb expressive features as the design guide), voice
      tone (openSMILE valence/arousal), rPPG heart rate (closed biofeedback loop),
      gaze zones (Board row selection), optical-flow motion energy, keystroke
      dynamics.
- **Done when (5a–5c)**: the helper streams landmarks to both subscribers, `hand()`
  words read as signals, and a demonstrated mapping trains and binds — each verified
  with the camera live at the desk.

---

## Risks / open questions

- **Quark name** — undecided; blocks Phase 0 class files. Low effort, do first.
- **MultiTouchPad** uses a private macOS API — may be dead on current OS; timebox the
  evaluation (Phase 3), fallback is fine.
- **MediaPipe Python packaging** — wheel availability on new macOS/Python versions;
  bootstrap script must pin versions (Phase 5a).
- **SC IDE limits** — no inline widgets (Board is a window, not in-code sliders);
  KeyState words conflict with typing (reserved keys only).
- **ProxyChain vs custom .fx** — decide by studying ProxyChain first (Phase 1d);
  wrapping beats reinventing unless it fights the vocabulary.
- **Scope creep** — Phases 2–5 are each optional layers on a playable Phase 1.
  If momentum stalls, ship Phase 1 and play it.

## Working practice (any build session, human or Claude)

1. Read "Design Notes.md" (+ "Companion Quarks.md" for Phase 5) before coding.
2. Keep the non-negotiable rules; when a task fights a rule, the rule wins — or the
   design docs get updated *first*, deliberately.
3. **The acceptance test for a build session is verification appropriate to the
   phase — if the code compiles and its checks pass, move on.** Play-testing is
   John's, done when he chooses; it informs design (renames, kills, calibration)
   but is not a gate on build progress.
4. Parsers and pure functions get unit tests.
5. **Help docs ship with code, every phase.** Comprehensive SCDoc (.schelp) written
   for a reader with zero project context: a complete novice must be able to learn
   the system from the help browser alone. Every word documented on its home class
   (via .ext.schelp), every page with runnable examples — including a minimal
   self-contained environment (SC's bundled sounds) so examples never require
   John's Setup repo. The Guides/Synesthesia page is the entry point; new words
   are not done until documented. **The central page,
   Reference/Synesthesia-Reference, documents the entire vocabulary in one
   document and is REWRITTEN HOLISTICALLY each phase — new words integrate into
   their families and earlier entries are revised with the new context, never
   merely appended (append-only reference pages rot: early sections end up
   describing an obsolete system).** If the reference disagrees with the code,
   the reference is a bug.
6. Update this file's checkboxes and the design docs as decisions land; History logs
   and Past Sets feed the Zipf passes.
