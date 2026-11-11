# Roadmap — Live Coding System Build Pipeline

Handoff document. Self-contained enough to start a build session from, with design
rationale living in its two companion docs:

- **"Design Notes.md"** — the core quark: language thesis, registers, vocabulary
  buckets, auto-GUI/Board, visuals painting-protocol design (the painting parts are
  now history — see Phase 2).
- **"Companion Quarks.md"** — perception quarks (MediaPipe, emotion, pose, etc.).
- **"Vocabulary Sketch.scd"** — what using the language should look like (design
  fiction; Phase 1 made the engineering register real).
- **"Breaks Build Plan.md"** — the breakbeat machine (Phase 1.6), design and as-built.
- **`~/Tools/Synesthesia/Broadcast Manifest.md`** — success parameters for Broadcast,
  which now stands where Phase 4 did.

Owner: John (john@newmedianashville.com). Repo: Live-Coding-With-SuperCollider.

**Current state (2026-11-10):** Phases 0, 1, 1.5, 1.6, 2 and 4 are built and
verified — the audio language, John's own SynthDef palette, the breakbeat machine,
the painting register (colours and tools over the audio words, as the `Paint` class
in the quark), and Broadcast (events, control values and per-proxy stems to a VJ's
machine), all loaded or started by `Setup/Setup.scd`. The sample library is
connected (Phase 1.6): ~1,250 drum loops indexed for the breaks machine, and
kick/snare/clap/percussion one-shots in `d`. The system has still not been played
in earnest; calibration by ear is John's open work, and for Phase 2 it is the
whole point: the palette's names and the tools' feel are a first set. Phase 2 was
dropped on 2026-08-19 and revived by John on 2026-11-10; the canvas ops it listed
(thin, glaze, bleed, scrape) are not built. Broadcast is merged to main in both
repos (2026-11-09) and confirmed reaching TouchDesigner on this Mac; its OSC names
stay open until the collaborator's answers and John's naming pass (Phase 4,
"Requested"); painted strokes go out under `/syn/paint/<tool>/` with their colour.
On 2026-11-11, after John's first looks at the wire in TouchDesigner, the whole event
namespace became one value per address with a `trig` pulse per event, and `/syn/beat`
became the `/syn/bar` phase with half/quarter/eighth/sixteenth pulses beside it.
`Tutorial.scd` at the repo root is the current hands-on walkthrough of everything
built, and `Tutorial-Paint.scd` beside it walks the painting register alone, every
way to use it. Phase 3 and 5 are unstarted. Downstream: Music-Robot
(`~/Studio/Sketches/Claude Code/Music-Robot`) plays this system; its DECISIONS.md
D8 was the ruling that dropped Phase 2 and is superseded by the revival — the
robot may now paint as well as play the open language.

Gates, as of 2026-11-11: `TestSynesthesiaParsers.run` + `TestPaint.run` +
`TestSynesthesiaGuard.run` + `TestBreak.run` + `TestBroadcast.run` (language, 352
assertions), `check-help.scd` in the quark (every help file parses and renders),
`Setup/SetupCheck.scd` (boots
Setup for real, 22 checks incl. the library), `Setup/TutorialCheck.scd` (plays
`Tutorial.scd` top to bottom on a private server, and `Tutorial-Paint.scd` with
`SYN_TUTORIAL=Tutorial-Paint.scd`: every statement must run, every voice must
sound and none may clip or lose its start to the JITLib fault below),
`Setup/BreakIntegration.scd` (live server, 34), `Setup/BreakCheck.scd` (NRT audio),
`Setup/BroadcastCheck.scd` (live server plus a receiver stub in a second sclang:
the manifest's acceptance walkthrough, the event timing measurement and the
negative test; two measurement flakes in the check itself were repaired on
2026-11-09: the chord-as-one-instant test now allows 2 ms, since the stub rounds
arrival times to 0.1 ms, and the three-state house-level comparison now follows a
warm-up pass, since a freshly created voice measures a quarter low on its first bar
under any Broadcast state). Every gate above was rerun on 2026-11-11 after the wire
was reshaped (and on 2026-11-10 after the painting register, 2026-11-09 after the
two fixes below), each live check on a private server so an open IDE session is
never touched: all green.

Two faults found by the tutorial check on 2026-11-09, both fixed in the quark:
(1) `.chord` fed chord names to `\note` as Symbols, where SuperCollider reads
`\G7` note-first (G, octave 7, about 100 kHz) and silently mangles unknown names
such as `Abmaj7`; `Synesthesia.parseChords` now resolves names chord-first through
ChordSymbol2, with chart spellings (`m7`, `maj7`, `m7b5`, `sus4`, `C/E`, `_4` for
an octave) and a clear error for names it cannot read. (2) SuperCollider 3.13.0's
`NodeProxy.put` never marks a proxy loaded, so a proxy that is read by another
proxy and then reassigned inside one bar loses its start ("duplicate node ID",
reader silent); `Synesthesia.guard(p)` in Setup installs a ProxySpace dispatch
hook that settles each proxy on assignment. Still present in upstream `develop`;
not yet reported upstream.

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
its named-controls audit is a prerequisite for clean preset-morphing and for
everything CV eventually drives.

Revised 2026-11-09: Phase 2 is dropped, so the audio language is complete at
Phase 1 + 1.6. Phase 4 is now Broadcast, which needs only what Phase 1 already
provides (Pbind events, named controls, one bus per proxy) — so it no longer waits
on Phase 3, and is the next build.

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
- [x] Sample library: the *breakbeat* half is now built — see Phase 1.6. Still
      deferred: spoken-word / Alan Watts material for looping and granulation.
- [ ] Retune Synesthesia drone recipes / defaults once the palette lands.
- **Done when**: Setup boots the new library with no missing-UGen exceptions and
  Synesthesia words target it end-to-end (compile + boot-log gate).

## Phase 1.6 — Breakbeat machine (BUILT August 2026)

Goal: a whole drum-loop recording as one sculptable voice — locked to the session
tempo whatever tempo it was recorded at, dissolvable continuously from intact loop
to granular dust, reorderable live, swappable with no gap. Full design rationale and
as-built deviations: **"Breaks Build Plan.md"**.

Independent of Phase 2 — it neither blocks nor is blocked by colors.

- [x] `\break` engine + `\brk1` chop player (Setup/SynthDefs/, Tier 0 stock). One
      Phasor per loop is the single source of phase, so no grid can drift and
      `resync` realigns everything to the bar. `grind` has exact stations at 0
      (intact) / 0.5 (clean chops) / 1 (dust).
- [x] `Break` registry + vocabulary in the Synesthesia quark: tempo inference
      (filename tag → folder tag → duration heuristic) with a persistent,
      hand-editable `_breaks.scd` sidecar that can also rename a break; canvas words
      on NodeProxy, `chop` brush on Symbol. 43 new unit tests (`TestBreak.run`).
- [x] Verification: `Setup/BreakCheck.scd` — NRT battery, builds its own fixtures,
      15/15 passing. Proves sample-accurate grid lock from two different source
      tempos, gapless swap, silent rests, no clipping, self-freeing node.
- [x] Docs: `Guides/Breaks` tutorial (runs on SC's bundled sound, so it needs no
      library), `Classes/Break`, words on their home classes, and a holistic rewrite
      of `Reference/Synesthesia-Reference`.
- [x] **Break library connected** (2026-11-09) — John's collection at
      `~/Studio/Assets/Audio Samples/Breaks` (7 packs, ~2.7 h of audio). Too big to
      load at boot, so `Break.addLibrary` (new in the quark) *indexes* it — 1,253
      loops, header reads only, ~0.4 s — and each loop loads the first time it plays
      (~50 ms, hidden behind the bar-quantised swap; `Break.preload` for set
      openers). Folders of one-shots are not loops: Setup's `oneShots` table files
      them into `d` (`k` 83, `s` 52, `cp` 31, `perc` 20 — so `\k.hits` has real
      kicks) and the same table excludes them from the breaks index; `Chops`/`CHOPS`
      folders are skipped by default. `Break.list("…")` searches; `brk` suggests on
      a near miss. `SetupCheck.scd` verifies the whole path on a live server.
      Inference: 445 tempos read from filename tags, 796 from duration (worth a
      listen), 5 still fall back to 120 bpm (`Break.list` shows `fallback`).
- [ ] **Calibration by ear** (John, no deadline): play `Setup/BreakTour.scd`; report
      dead zones in the `grind` curve; rename words that do not sit right; decide
      whether this becomes a painting-register applicator and what `hue` would mean
      for a break (the HSV axes are deliberately omitted for now — CONVENTIONS rule 3
      allows a def to omit an axis it has no meaning for).
- **Done when**: built and verified — done. The two open boxes are John's, not the
  build's.

## Phase 2 — Painting register (dropped 2026-08-19, REVIVED and BUILT 2026-11-10)

Dropped by John's ruling of August (D8 in Music-Robot's DECISIONS.md: the flexible
layer underneath is the better language) and revived by John on 2026-11-10, with
the flexible layer kept as the language it sits on. Built as the `Paint` class in
the quark plus words on Symbol, Pattern and NodeProxy (`classes/Paint.sc`,
`classes/extPaint.sc`; help `Classes/Paint`; tests `TestPaint.run`). The grammar is
the one resolved in July (Design Notes, "Color grammar"): colour = pigment, tool =
applicator = one voice, pitch/time stay music words, placement is the stroke's.

Goal: the perceptual layer over Phase 1. Timbre/texture words become colours and
tools; pitch/time stay music-language.

- [x] Colour type: a coordinate in the HSV space every voice already speaks (hue =
      angle on the voice's timbre wheel, sat = hue-identity strength, val = light —
      CONVENTIONS rule 3), plus a spread; each event samples the tube's
      neighbourhood. `Paint.color` reads a palette name, `[h, s, v]`, an Event or a
      `Color`. Eleven tubes named after the screen colour wheel (red … magenta,
      grey, white, black), because the timbre coordinates are the screen colour.
- [x] Tools = one voice each, applied in time: `brush` (sustained, `\brush`),
      `mark` (discrete events, `\mark`), `dab` (rhythmic touches, `\mark`), `drip`
      (Dust-like touches, `\mark`), `spray` (grain cloud, `\spray` / `\sprayb`),
      `wash` (bed, `\wash`). `\orange.brush("Cm7 G7")` = `brush(\orange, "Cm7 G7")`;
      every tool returns a plain Pbind tagged `\syn_brush` / `\syn_material` /
      `\syn_color`. `Paint.tools` rebinds a tool to any def that speaks the axes.
- [x] Perceptual sculpt verbs: `.darker` `.lighter` `.paler` `.saturate` `.warmer`
      `.cooler` (step sizes) and `.paint(colour)`, on patterns (a Pbindf stepping
      from the carried value or the voice's SynthDesc default) and on proxies (a
      pattern source is reassigned; a synth source has its `hue`/`sat`/`val`
      controls moved — drone recipes join by naming them). Warmer/cooler step toward
      orange/blue the shorter way round the wheel.
- [x] `mix(a, b, x)` on colours (hue the shorter way round); `Paint.palette[\dusk] =
      \orange.mix(\violet, 0.6)`. Canvas ops `thin`, `glaze`, `bleed`, `scrape`:
      **not built** — `feeds` (bleed), `fx` (glaze) and `stop`/`hush` (scrape)
      already cover the mechanisms; a painter's names for them wait for calibration.
- [x] Broadcast: every painted stroke goes out under `/syn/paint/<tool>/` as amp,
      pitch, notes, size, dur, hue, sat, val and count, one value per address — the
      HSV pun on the wire (Phase 4 namespace, one new family).
- [ ] **Calibration** (John's, on his own schedule): play `Tutorial-Paint.scd`;
      rename tubes and tools by ear; kill words that die; harden survivors. The
      lexicon is discovered, not specified. The voices other than `\brush` still
      carry provisional axis semantics (their file headers say so), so colours on
      them are cousins of the brush's, not clones — the queue in Design Notes.
- **Done when**: colours/tools/mix compile and evaluate correctly (build gate —
  done: `TestPaint` + `TestBroadcast`, and `TutorialCheck` plays lesson 14);
  calibration then refines the lexicon whenever John plays.

## Phase 3 — The Board + laptop gesture (≈ 1–2 weeks)

Goal: controls materialize with the signals; hands get continuous surfaces.

- [ ] Named-controls audit: every verb (Phase 1 and the breaks words) passes rule #2;
      Spec registry complete.
- [ ] **The Board**: persistent dock window from Setup — row per active proxy (name,
      vol, meter, auto-sliders from named controls), rebuilding on spawn/rebind,
      two-way sync. Study NdefGui/NdefMixer internals first; steal, don't rebuild.
- [ ] MultiTouchPad quark evaluation on current macOS (private API risk — timebox
      it); if dead, `pad(\x/\y)` + Board sliders suffice.
- [ ] Optional: KeyState gate words on reserved keys; NdefPreset scene save/morph
      words (parameter interpolation across whole scenes; Phase 2's `mix()` is
      colour-only and does not need it).
- **Done when**: the Board builds rows for live proxies with two-way-synced sliders,
  and `pad()` words compile and map correctly.

## Phase 4 — Broadcast: everything musical, out to a VJ (BUILT November 2026)

Goal: a second machine (a VJ on Resolume/MadMapper, over Ethernet) receives
everything musically meaningful on the canvas, with **zero words typed mid-set** —
configured once in Setup, then watching the ProxySpace on its own. Full success
parameters: **`~/Tools/Synesthesia/Broadcast Manifest.md`** (the manifest says what
done looks like, not the build order).

- [x] Events: one OSC message per sounding hit/note from every brush, timed to the
      audible onset (±10 ms, compensating `s.latency`). Built: the brushes tag their
      Pbinds, Broadcast wraps the default Event's `play` (so a performer's own
      `\callback` still runs) and schedules the send on SystemClock by `~latency`;
      a brush in a stopped proxy sends nothing. Measured against the stub on
      localhost: the number is in the manifest's as-built note.
- [x] Continuous: every control-rate proxy on its own stable address at ~30 Hz, plus
      tempo and beat phase; discovered automatically. Built: one hidden kr proxy
      running a SendReply, rebuilt quant-aligned when a beat-rate walk finds the set
      changed; a Spec-normalised twin stream where a Spec is registered (pad, follow,
      mapExp/mapLin now register one).
- [x] Stems: one stereo channel pair per audible proxy (stable index for the session,
      follows audibility through `.stop`/`hush`), out through an aggregate device to
      SonoBus/JackTrip. Main mix always on stem 0. Built as gain-tracking taps (the
      manifest's second mechanism; the reason is in the class comment); the main mix
      is an InFeedback synth at the head of the root node.
- [x] Setup-time surface only (`Broadcast.start/stop/status`); never breaks the music
      — every failure degrades to "the VJ gets less", with one warning. The commented
      `Broadcast.start` line is in `Setup/Setup.scd`.
- [x] Verification: `TestBroadcast` (pure functions), `Setup/BroadcastReceiver.scd`
      (the stub, runs in a second sclang on either machine), `Setup/BroadcastCheck.scd`
      (the acceptance walkthrough read out of the guide itself, timing, stop/play/
      swap/clear stability, the negative test). Docs: `Classes/Broadcast`, the guide's
      "Playing with a VJ", a holistic rewrite of the reference.
- [ ] Settle the manifest's open questions with the collaborator before the OSC
      namespace freezes (which streams, native vs normalized values, timetags —
      `timetags: true` already exists for a receiver that honours them — and the
      SonoBus channel ceiling). John's, not the build's.
- [x] **Requested by John, 2026-11-09 and 2026-11-11, after first contact with
      TouchDesigner** — built 2026-11-11:
      - One value per address. The OSC In CHOP keeps one channel per address and
        only its last value, so a six-argument message read as `brush1 … brush6`,
        a chord's four notes collapsed to one, and a hit repeating the same amp and
        index never moved a channel. Now `/syn/hit/<folder>/trig`, `/amp`, `/index`,
        `/dur`; `/syn/note/<def>/trig`, `/amp`, `/notes` (the MIDI notes lowest first
        lowest first, padded with 0 only to the voice's widest chord), `/dur`; the same plus `/hue`, `/sat`, `/val` under
        `/syn/paint/<tool>/`. John's second look (2026-11-11) cut `pitch`, `size`,
        `degree`/`degrees` and a rising `count`: a VJ wants a pulse, so `trig` is 1 on
        the onset and 0 after the pulse width (`pulse:` on start, 50 ms, shortened
        to half the gap for fast voices), and `dur` is seconds.
      - `/syn/beat` renamed `/syn/bar` (a phase); `/syn/half`, `/quarter`, `/eighth`
        and `/sixteenth` are pulses fired from the clock on every boundary of that
        note value (`Broadcast.phases`, `pulsesAt`).
- [ ] Still open from the same look: helper proxies stream under generated names
      (`syn_padx`, `syn_sig1`, `k_env`), and a proxy assigned from one
      (`~cut = pad(\x).mapExp(...)`) streams twice, with its 0..1 twin only on the
      generated name. A `.brk` voice sends no events (only a stem).
- **Done when**: the manifest's acceptance walkthrough passes — the Guides/Synesthesia
  "first session" evaluated line by line with a receiver stub listening, every
  sound-making line on the wire with no extra typing — plus its negative test
  (unreachable receiver: audio indistinguishable from Broadcast off). **Done**:
  `Setup/BroadcastCheck.scd` is that walkthrough and passes headless. The one open
  box is the collaborator conversation.

What this replaces from the earlier plan: 4a's painting-word OSC (`/paint/...`) is
moot with Phase 2 dropped, and its analysis taps become Broadcast's continuous and
stem streams. 4b–4c (a Processing renderer on this machine) are not part of
Broadcast, which puts visual generation on the receiving machine; whether a local
renderer is still wanted for shows without a VJ is open. The earlier items are kept
below for reference.

### Superseded plan (painting protocol + Processing renderer)

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

- **MultiTouchPad** uses a private macOS API — may be dead on current OS; timebox the
  evaluation (Phase 3), fallback is fine.
- **MediaPipe Python packaging** — wheel availability on new macOS/Python versions;
  bootstrap script must pin versions (Phase 5a).
- **SC IDE limits** — no inline widgets (Board is a window, not in-code sliders);
  KeyState words conflict with typing (reserved keys only).
- **Scope creep** — Phases 3–5 are each optional layers on a playable Phase 1.
  If momentum stalls, ship Phase 1 and play it.
- **The sample library lives outside the repo** (`library` in Setup.scd, an absolute
  path on this Mac). Setup skips it cleanly where it is absent — another machine, or
  Music-Robot's Pi — but then `hits` and `brk` have nothing to play there.
- **Broadcast's transport is unproven** — SonoBus's per-connection channel ceiling is
  undocumented; test the full stem count on the VJ's machine before a show
  (JackTrip is the fallback).
Resolved: **quark name** (Synesthesia, Phase 0); **ProxyChain vs custom .fx** (slots
10+ and a recipe registry — ProxyChain wants to own the proxy; Phase 1d);
**unmerged branches** (`breaks-machine` here and `breaks` in the quark were
fast-forwarded into `main` on 2026-11-09, so Music-Robot's pull requests to the
quark — its D9 — will target a current `main`).

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
