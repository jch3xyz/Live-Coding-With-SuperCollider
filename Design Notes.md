# System Design Notes

Status: design phase, pre-implementation. Started July 2026.

Goal: evolve the live coding setup toward the flexibility and immediacy of a musical
instrument. Guiding principle: **keep the keyboard for deciding; pre-build or
physically map everything else.** Each intervention should cost one gesture, not one
paragraph of code.

## Workflow improvements (audio)

1. **MIDI-in control layer** — map controller knobs/faders to control-rate proxies in
   Setup so continuous parameters become physical gestures:
   ```supercollider
   ~c1 = {\v.kr(0.5).lag(0.1)};
   MIDIdef.cc(\k1, {|val| ~c1.set(\v, val/127)});
   // use anywhere: RLPF.ar(sig, ~c1.ar.linexp(0,1,200,8000))
   // or in patterns via BenoitLib's Pkr(~c1)
   ```
   Also `MIDIdef.noteOn` for a genuinely played keyboard voice on top of patterns.
   Note: Setup_MIDI.scd currently only does MIDI *out* (Scarlett 2i4).

2. **One-keystroke live sampler** — snippet that records N bars of `SoundIn` into a
   Buffer and adds it to `d["live"]`, immediately playable through `bplay`/`vplay`/
   `warp1`. Capture-and-manipulate: play a phrase, chop it seconds later.

3. **Fatten the snippet library** — active Snippets.scd has 3 entries; `Snippets
   copy.scd` (co34pt's, ~40 entries) has drums, Euclid generators, FX sends, drones,
   MIDI. Merge, then grow: every sound reached for twice becomes a keyword.
   Snippets = muscle memory / learned licks.

4. **Standing FX architecture in Setup** — instantiate `~verb`, `~delay`, `~master`
   send/return chains at setup with levels at zero, so mid-set routing is one short
   line (or a knob via #1), never construction work.

5. **Quantization as rhythmic safety** — `p.quant = 4` (or per-proxy) so rebinds land
   on the next bar; evaluate whenever the code is ready and it still sounds
   deliberate. Pair with per-proxy `fadeTime` (short for drums, long for pads).

6. **Safety net + memory** — `History.start` in Setup logs every evaluation
   (auto-transcript of the improvisation, feeds Past Sets). A musical panic gesture
   that fades instead of cutting: `p.activeProxies.do(_.stop(8))` bound to a snippet
   or MIDI button, instead of Cmd-period.

## Language layer

Thesis: the real project is a **language** — drastically reduce SC's verbosity while
keeping its flexibility, staying inside the "live coding in SuperCollider" paradigm
(unlike TidalCycles/ixi, which build a closed surface on top and trade flexibility away).

Design rules:
- **Terseness as sugar, not as a wall**: every terse form must evaluate to a plain SC
  object (Pattern, Function, NodeProxy), so terse and verbose SC compose freely in one
  expression. Escape hatches at every level. (JITLib itself is the precedent — a class
  library that changed the feel of the language without removing anything.)
- **Frequency earns brevity**: mine History logs + Past Sets for the most-typed
  constructs; those get words. Match token size to decision size — one musical
  decision = one token (`\k.hits(3,8)` vs a seven-key Pbind).

Mechanisms in sclang, by invasiveness (staged adoption path):
1. Snippets (ddwSnippets) — textual macros; compress typing, not meaning; don't compose. Stage one only.
2. Factory functions — cheap builders, clunky call syntax.
3. **Class extensions + custom classes in a personal quark** (`+ Symbol { hits {...} }`) —
   the core move; git-versioned; e.g. `~k = \k.hits(3,8)` returns a real Pbind wired to
   `d` and `bplay` conventions.
4. Custom event types (`Event.addEventType`) — hook every note; doubles as the visuals
   event tap (play + OSC mirror in one event type).
5. Operator overloading on own classes (`<>`-style combinators).
6. Mini-notation as String methods — `"x.x.".beats` → Pseq; ~30-line parser, returns patterns.
7. Interpreter preprocessor (`thisProcess.interpreter.preProcessor`) — full custom
   notation embedded in SC, untouched code passes through (the Bacalao/ixi mechanism).
   Global and fragile; last 10%, only where a notation earns it.

### Conceptual starting point (July 2026)

Goal is **drone/modular/abstract sound** approached the way abstract visuals are
approached in painting — not dance music. The draw of SC over Tidal-style layers is
"**programming the speaker directly**": reducing layers of mediation between performer
and the digital signal. Regular on-beat tempo patterns are still necessary, but
workflow inspiration comes from Help 5 (Non-pattern Techniques: drones, modular proxy
patching, feedback, fx routing) more than from the pattern chapters. Quark development
plan: lean heavily into the personal quark; snippets evolve over time by further
shortening the most frequently used phrases.

### Cycle-paradigm analysis (TidalCycles / Strudel)

The core of the paradigm: a pattern is a **pure function of cyclical time** (Tidal:
time is "cyclical and not linear"; patterns are "predictable," can backtrack/
fastforward). Events are derived by querying, not stored. Everything follows from this.

Worth stealing:
- **A shared temporal frame** patterns align to — but as a grid patterns *opt into*
  (p.clock + quant), not a container everything lives in.
- **Patterns as transformable values** — higher-order verbs (fast/rev/every/jux) that
  act on whole musical objects; complexity from composed transformations, not bigger
  data structures.
- **Notation length ∝ musical density** (mini-notation subdividing the frame).
- **Uniformity** — one mental model; in Tidal "everything is a pattern"; ours is
  closer to "everything is a signal."
- **Queryability → free visuals**: pure patterns can be rendered without playing
  (Strudel pianoroll). Maps to our event tap (#3) for the pattern layer; the stateful
  drone layer must be visualized from audio analysis (tap #1) instead.

Restrictive (and why we invert it):
- **The event/signal wall**: Tidal emits discrete OSC events to SuperDirt; synthesis
  is behind a wall. Signal topology — routing, feedback, self-oscillation, audio-rate
  interconnection — is not addressable from the language. This is exactly what
  "programming the speaker" needs and what JITLib proxies already give us.
- **Time-as-loop vs time-as-flow**: aperiodic, evolving, non-repeating material
  (drones, morphing textures, chaos) must be faked as long cycles; continuous signals
  are second-class, sampled at event onsets. For our music, continuous is primary.
- **Statelessness = no memory**: pure patterns can't accumulate — no evolving feedback
  state, no "the sound I've been sculpting for ten minutes." NodeProxy persistence
  (edit = crossfaded re-sculpt of a living object) is the canvas; Tidal replaces the
  pattern wholesale.
- **Fixed topology** (d1..d16 orbits, per-event fx params) vs live rewiring.
- **Grid gravity**: everything quantized to the cycle; rubato/free time foreign.

The inversion — the quark's paradigm: **the patch is the canvas, patterns are brushes.**
Tidal = patterns first, signals behind a wall. Ours = persistent signal graph first
(ProxySpace), with pattern material as one kind of exciter/modulator of that graph.
Two word-families for the vocabulary:
1. **Graph words** (canvas): spawn/route/insert/feed/fade — drone stacks, filter
   insertion, feedback amounts, operating on proxies (Help 5 workflow).
2. **Time words** (brushes): euclid/step-notation/transform verbs producing Pbinds on
   the shared clock.
Plus **bridge words** both directions: pattern→signal (Pkr, envelope followers) and
signal→pattern (thresholds, control values into patterns). Note: SC's Demand-rate
UGens (Dseq etc.) are patterns *inside* the signal graph at audio rate — patterns as
signals, the most literal "programming the speaker" and a uniquely SC unification the
Tidal paradigm can't express.

**Foundational vocabulary sketch** lives in `Vocabulary Sketch.scd` (repo root):
graph words (\dfm.drone / .stack, .fx/.unfx, .feeds, .send, .fade, .duck), time words
(\k.hits step-strings + euclid, \sinfb.deg degree-strings, .fast/.slow/.sometimes/.jux),
bridge words (.follow, .duck, knob().exp, .pat, \saw.dseq demand-rate sequences,
rec() live capture), control words (bpm, grid, hush, rec as bare Interpreter
extensions). All forms return plain SC objects; raw SC composes anywhere.

### Register design: perceptual words over engineering words (brainstorm, July 2026)

> **2026-11-09:** the painting register this section argues for was dropped on
> 2026-08-19 (Music-Robot DECISIONS D8). The engineering register built in Phase 1
> turned out to be the better language. Kept as the reasoning of record.
>
> **2026-11-10:** revived by John and built, over the engineering register rather
> than instead of it: the `Paint` class in the quark (Roadmap Phase 2, as built).
> The grammar below ("Color grammar", resolved July 2026) is what was built; the
> HSV axes are the ones finalized in CONVENTIONS rule 3. What was not built: the
> canvas ops (thin, glaze, bleed, scrape) and register nudging by value — explicit
> pitch always wins, and darkness is light alone.

Tension: systems vs computer-audio vs music vs painting language. Resolution principle:
**use each domain's language where that domain is how the thing is actually
perceived.** Timbre is perceived, not computed → perceptual/painting words. Rhythm is
counted → music/number words (bpm, grid, euclid stay). Wiring is topological → systems
words (feeds, send). The substrate (named controls, buses) stays engineering and
mostly invisible. The registers coexist in one expression because everything returns
plain SC objects.

Why enigmatic words for timbre: the real verbosity is **semantic distance** — intention
arrives as "warmer, rougher," and a language whose words are warm/rough removes the
translation step. Technical timbre description is famously bad ("spectral centroid
1200 Hz" vs "orange"). Precedent: Kandinsky/Scriabin/Messiaen color-sound systems —
personal, inconsistent with each other, and that's fine: the lexicon only has to stay
consistent with itself (your orange must stay orange).

The pigment × applicator model (where the metaphor actually holds):
- **Colors = timbral material**: a color names a *region* of timbre space (recipe +
  parameter ranges, with internal variation — pigment is never flat). Possible internal
  logic: HSV as timbre coordinates — hue = spectral family (warm/sawish ↔ hollow ↔
  pure ↔ metallic/inharmonic), value = register/brightness, saturation = purity ↔
  noise/roughness. Gives sculpt verbs in perceptual space: `.darker`, `.paler`,
  `.warmer`, `.saturate(0.2)`. Finite palette like real tubes of paint (~8–12), mixed
  rather than enumerated.
- **Tools = application in time** (John: "finite set of tools: brushes, spray cans,
  markers"): brush = sustained stroke (drone/legato), spray = granular cloud, mark =
  discrete precise events (patterns), knife = broad sudden smear (swept noise), wash =
  diffuse bed, dab = single hit, drip = sparse stochastic events (Dust).
  **sound = pigment × applicator**: `spray(\orange)`, `mark(\blue, "x..x")`,
  `wash(\grey)`.
- **Canvas operations**: layer (proxies), mix (preset/parameter interpolation — the
  NdefPreset morph substrate makes color-mixing literally implementable), thin
  (dilute = more space/less density), glaze (transparent master tint fx), bleed
  (feedback), scrape (fade/remove), smudge (blur: reverb/detune), varnish (master chain).

Where the metaphor genuinely breaks: **pitch/harmony** (color mixing ≠ chord theory)
and **meter** — keep music language there (ChordSymbol2, ~r, scales, bpm/grid).

### Color grammar (resolved July 2026)

The roles, settled: **color = pigment, tool = applicator, instrument = medium,
placement = stroke coordinate.** Neither color nor action IS the instrument:

- **Color** is a coordinate vector — (morph ← hue, bright ← value, grit ←
  saturation) + register tendency — resolved as control values.
- **Tool = instrument, one-to-one (John's correction, adopted July 2026)**: each
  tool owns ONE wide-gamut voice and its envelope (mark/dab → the percussive
  voice, brush → the sustained voice, spray/wash → the grain voice). Color is an
  HSV-mapped neighborhood **within that instrument's parameter space** — never a
  selector across SynthDefs. Rationale: SynthDef boundaries are discrete; you
  cannot crossfade or interpolate across them, so hue-as-def-selector would make
  `mix()`, `.darker`, preset morphs, and future hue-modulation undefined. One
  def per tool keeps every color operation continuous parameter movement.
  Consequence: tool voices must be wide-gamut "macro voices" (big morph range).
  Nuance: MiPlaits' `engine` is discrete and sampled per-trigger — fine for
  per-event tools (mark/dab: each hit can sit at a different hue), but a brush
  note cannot morph across engines mid-note; a stock SelectX-gamut voice can.
  Continuity-of-morph vs breadth-of-gamut is a real axis in the voice choice.
- **Pitch/time stay music words**: degrees/chords/durs ride in the tool call
  unchanged (`brush(\blue, "0 3 5 7", 0.5)`); value/darkness nudges register but
  explicit pitch always wins.
- **Placement is NOT a color axis** — it's where the stroke lands: an optional
  `at:` argument with a default (center), patternable. Pan today, 3D placement
  after the spatial phase. Belongs to the tool call / stroke, not the pigment.

### Spatial audio direction (July 2026)

**One mental model, always (John, July 2026): placement is 3D from the
performer's seat at all times.** Configuration is Setup's job, not a mindset
switch: at boot the output stage picks a decoder from the detected/declared
system — 2 channels → **binaural (HRTF) by default**, >2 → the declared speaker
rig decode (ambisonic or VBAP). The language always speaks
azimuth/elevation/distance; only the decoder changes per venue.

Spatial semantics (not mono dogma): a **point source is a mono core + width
metadata**. Width/spread is a placement-time parameter (decorrelation or
stereo-pair angle around the direction), so it stays steerable — it can narrow
with distance and collapse correctly onto any rig. Inherently-stereo material
(stereo buffers, chorus/dual-detune images) is legitimate and placeable: encoded
as a stereo pair spread ±width° around its direction. The rule is "know your
source's spatial semantics," not "everything must be mono." Distance cues
(attenuation, air LPF, wet/dry ratio) are provided uniformly by the spatial
stage — another reason placement lives at the canvas layer, never in defs.

Candidates: **ATK** (FOA, established, HRTF kernels), **SC-HOA** (higher-order +
IEM binaural), **Mosca** (batteries-included scenes), VBAP for irregular rigs.

### Mutable Instruments stance (revised July 2026)

John relaxed stock-first (it was a DAW-era pay-for-VSTs holdover; FOSS changes
the calculus — versions can be pinned, users can install deps). Portability and
single-point-of-failure objections withdrawn by John (accepting that an
OS/architecture break needs a source rebuild, not just a version pin —
PortedPlugins-style). Remaining live question: **monoculture** (Plaits' sound is
recognizable — benefit or hindrance TBD by ear).

**RESOLVED (John, July 2026): Plaits rejected as foundation on architectural
grounds** — the system's top layer IS "engines behind three macros"; building it
on Plaits duplicates the thesis one layer down and surrenders the gamut design.
Stock UGens are the base. The continuity-vs-gamut "trade-off" dissolves: gamut is
something we architect as a continuous path, not something we buy pre-curated.
MI modules remain available later as *alternate media* behind the same contract
(MiRings for resonators, MiClouds for granular) — optional organs, never spine.

### Tool voices — palette v1 design (July 2026)

Principle: **gamut per voice = a composed path of continuous transformations**
(FM ratio/index, feedback, folding, pulse-width/sync, filter Q, trigger
regularity), never engine-switching; crossfade seams only at spectrally-similar
waypoints. No single voice tries to cover everything — the union across tools
covers the field; the same color on different tools are cousins, not clones
(pigment on canvas vs paper). drip carries no voice of its own — it is the mark
voice under stochastic scheduling (tools = voice × time-behavior; some share).

- **mark/dab voice** (perc env): 2-op PM core; morph = mod ratio path harmonic →
  bell → metal (continuous linexp 1→~7.2); bright = FM index (env-scaled: hits
  open brighter) + tracking LPF; grit = fold/tanh drive + noise-splash transient.
  Covers woody pluck → kalimba/EP → bell → metallic clang.
- **brush voice** (gated adsr, legato): generalized bpfsaw — detuned VarSaw pair;
  morph = width (tri↔saw↔pulse) then sync/fold amount; bright = MoogFF/BPF
  center (freq-tracked, exp); grit = drive + stochastic instability (LFNoise
  filter-wander, shimmer) — roughness as instability, not just distortion.
- **spray voices** (grain): synthetic (GrainFM/GrainSin, no buffer) and buffer
  (GrainBuf) variants — the spray tool picks by argument. morph = grain-source
  ratio path (synthetic) / position-scatter & rate (buffer); bright = grain
  spectral center; grit = trigger regularity (periodic↔Dust) + per-grain pitch
  scatter; width = per-grain pan spread.
- **wash voice** (long gated env): noise → resonance continuum; morph = colored
  noise → comb/Klank resonance mix (atonal → pitched-at-root); bright = spectral
  tilt; grit = crackle/Dust mix + slow modulation depth. Takes freq (deg-able)
  but defaults to sitting at ~r.
- **drums** (dedicated small defs — pitch-sweep envelopes are drum-specific
  structure): kick/snare/hat/tom/metal from the audit's verified stock recipes,
  each speaking bright/grit + a per-drum morph (kick: sweep depth/character;
  snare: shell↔noise; hat: metallic↔white).

**AXES FINALIZED (July 2026): `hue` / `sat` / `val`, implemented as HSV GEOMETRY,
not three sliders** (John's directive: navigating the space must feel like
navigating a colorspace). The contract, now in CONVENTIONS.md rule 3:
- hue = ANGLE on a wrapping timbre wheel of "primary" stations (hue 0 = hue 1);
- sat = hue-identity strength: 0 = GREY (wheel collapses to a blurred noise-
  veiled wash; hue inaudible), 1 = vivid/focused/resonant, extreme = neon drive;
  blur/wander/instability belong to LOW sat (desaturation IS blur);
- val = light: 0 = BLACK (filter floor below the fundamental — all hues converge;
  subtractive synthesis contains black natively), mid = contrast/detail, 1 = air
  (sat-low + val-high = WHITE noise-brilliance);
- required couplings: hue×sat, sat×val, val floor overrides all; modulation
  ecology rates/depths shift by region ("the weather changes as you move").

**\brush rebuilt as the reference implementation** (July 2026): 5-voice ensemble
core w/ per-note random drift, 5-station wheel (saw/pulse/glass/living-sync/
vowel), grey bed, filter section w/ envelope+keytracking, bow articulation
(env-slope chiff), mono smear chorus, sub/air scaffolding, neon stage, region-
dependent tide. Tier-3 surface: sub/air/fenv/track/drift/bow/smear. NRT-verified:
stations matched ~2dB, grey degeneracy holds, black -10dB floor, no clipping.
Remaining synths keep renamed args w/ PROVISIONAL old semantics until each gets
its own HSV rework (queue: mark → spray/sprayb → wash → drums).

Costs, honestly: the lexicon must be internalized like an instrument (practice the
palette); debugging is harder when words name percepts not mechanisms — mitigated by
register-dropping (every color/tool word expands to the descriptive layer, which
remains available). Audience legibility is a *bonus*: `spray(\orange)` projects
better than `Pbjorklund2(3,8)/4`.

Next experiment (before committing): define ~6 colors + ~5 tools as quick presets over
existing SynthDefs and play — calibrate meanings by ear, then harden. The lexicon is
discovered, not specified.

### Harmony: ChordSymbol2 (Help/ChordSymbol2, John's fork of triss/ChordSymbol)

Named chords/notes as Symbols that embed directly in pattern streams
(`embedInStream` override): `Pseq([\Cm7, \fs, \g])` just works in a `\note` key;
`[\Em7, \G].chordProg`, inversions `\C_e`. John's additions (confirmed by diff vs
original): **(1) `asFreqs`/`asFreq`** (+ `chordProgFreqs`/`noteProgFreq`) — chord
symbols → frequency arrays; **(2) octave-digit syntax** — `\Cm7_3_2` = C minor 7,
octave 3, duration 2 (`name_octave|inversion_dur` parsing rewrite).

Vocabulary implications:
- The **harmony bucket's notation already exists** — don't invent bracket-chords in
  deg-strings; use chord symbols for named harmony, deg-strings for scale-degree melody.
- `asFreqs` is a harmony→canvas **bridge word John already built**:
  `\dfm.stack(\Cm9_2.asFreqs)` = a drone that is a chord.
- Decide the **pitch currency**: his additions + root-as-signal + freq-arg SynthDefs
  all point to **frequency as the lingua franca**, with degrees/chords as notations
  that resolve to freqs.

### Functionality quarks shortlist (no new sounds/fx; July 2026 survey)

Top tier:
- **JITLibExtensions** — ProxyChain (named ordered fx slots ≈ the .fx/.unfx design,
  already exists), ProxyPreset/NdefPreset (preset storage + *morphing* between proxy
  states = scene words), ProxySubmix, NdefMixer. Study before building graph words.
- **Modality-toolkit (MKtl)** — device-independent controller layer (MIDI/HID/OSC);
  the `knob()` gesture layer nearly for free.
- **Influx** — few-to-many entangled mappings (2 knobs → weighted control of N params);
  macro-gestures for the canvas; very aligned with abstract-sound goal.
- **miSCellaneous_lib** — PbindFx (per-event fx graphs), **PSx streams (stateful
  patterns that remember across evaluations — answers the statelessness critique on
  the pattern side)**, DX crossfade suite.
- **ddwChucklib-livecode** (Harkins, same author as ddwSnippets) — full live-coding
  notation layer inside SC; prior art to study alongside Bacalao.

Second tier: Connection (declarative bindings), NodeSnapshot (inspect running node
tree), SafetyNet (maintained StageLimiter alternative), ddwVoicer (voice management
for playing SynthDefs from a MIDI keyboard), KeyPlayer (computer keyboard as
controller), TuningLib / ScalaTunings (microtonal; already using et53 etc.).
Note: BenoitLib, Bacalao, ChordSymbol are not in the official quarks directory —
install by URL.

### Vocabulary buckets (worksheet — John fills in regular actions per bucket)

1. **Spawn** — bring a sounding object into existence (drones, pattern voices, grains,
   live input). Seeds: `\dfm.drone`, `\dfm.stack`, `\k.hits`, `\live.grains`.
2. **Sculpt** — transform one object in place. Seeds: `.fx/.unfx`, `.wide`, `.dc`, `.fade`.
3. **Wire** — topology between objects. Seeds: `.feeds`, `.send`, `<>>`, `.duck`.
4. **Time** — the grid and transformations of pattern material. Seeds: `bpm`, `grid`,
   `.fast/.slow`, `.sometimes`, `.jux`.
5. **Harmony** — pitch material: root, scale, chords, tunings. Seeds: `~r`, `n.scale`,
   ChordSymbol2 symbols, `.asFreqs`.
6. **Bridge** — conversions between signal/pattern/event domains. Seeds: `.follow`,
   `.pat`, `\saw.dseq`, `.asFreqs`.
7. **Gesture** — physical input and capture. **Laptop-first (decided July 2026): no
   external MIDI controller planned for now — maximize the laptop.** Seeds: trackpad
   as server-side signal (`pad(\x)` over MouseX/MouseY.kr; MultiTouchPad quark for
   multi-finger on macOS), KeyState.kr / KeyPlayer for keyboard gates, auto-GUI
   sliders (see Auto-GUI section), `rec` capture. MIDI hardware later maps onto the
   same named controls with no redesign.
8. **Scene/Memory** — state over time: snapshots, morphs, sections, history. Seeds:
   NdefPreset morphing, `History.start`, set-file sections.
9. **Meta/Safety** — the frame: hush, solo/mute, levels, introspection, limiting.
   Seeds: `hush`, `.vol`, NodeSnapshot, SafetyNet.

### Auto-GUI: controls materialize with the signals (Strudel-sliders, SC-native)

Same design rule as visuals: **the GUI generates itself from the sound code** — no GUI
words in the performance vocabulary. Make an lpf, get a cutoff slider.

Two design moves:
1. **Lift literals to named controls.** Every quark verb declares params as named
   controls with registered Specs instead of baking numbers: `.fx(\lpf, 800)`
   internally creates `\lpf_freq.kr(800)` + `Spec.add(\lpf_freq, [40,12000,\exp])`.
   Named controls become THE interface; GUI, trackpad, future MIDI-learn, patterns,
   and presets (NdefPreset morphing) are all just clients of the same substrate.
2. **The Board**: one persistent dock window created in Setup that watches ProxySpace —
   a row per active proxy (name, vol, meter, auto-sliders for its named controls),
   rebuilding as proxies spawn/rebind. Two-way sync (slider→.set, code .set→slider).

What already exists (don't build from scratch): JITLib's NdefGui/`~a.gui` auto-builds
two-way-synced sliders from named controls + the global Spec registry; ProxyMixer
(already in Setup) and JITLibExtensions' NdefMixer are the reference implementations.
Also: autogui quark, Conductor (Kuivila; CV objects + auto GUI), CVCenter (by URL, not
in directory: widgets + MIDI/OSC-learn around control values), MagicPreset.
Strudel's *inline-in-code* sliders are a CodeMirror editor feature the SC IDE can't do —
the Board is the SC-native equivalent.

Laptop-native gesture layer (no MIDI hardware for now):
- **Trackpad as server-side signal**: MouseX/MouseY.kr — zero setup, zero GUI, the most
  direct hands-on-signal; sugar `pad(\x).exp(200,8000)`. **MultiTouchPad quark** (macOS):
  multi-finger x/y/pressure from the trackpad (private API — verify on current macOS).
- **KeyState.kr** — keys as server-side gates (careful: typing code fires them; reserve
  specific keys or modifiers). KeyPlayer for lang-side mappings.
- WsGUI / webRTCgui quarks: phone browser as extra touch surface over the network, no
  hardware.

### Companion quarks

Perception-as-control-surface quark ideas (MediaPipe landmarks, face/voice emotion,
dance/pose tracking, rPPG heart rate, gaze, ML mapping glue, etc.) are tracked
separately in **"Companion Quarks.md"** — this file stays focused on the core
live-coding quark. Shared contract: every companion is an OSC producer feeding the
named-controls substrate defined here.

Quark integration policy: adopt incrementally per bucket (each quark adds classes and
potential extension-method collisions), pinned as dependencies in the personal quark
file — not all at once.

Prior art inside the paradigm — study before building:
- **Bacalao** (Glen Fraser/totalgee) — closest realization of the thesis: Tidal-style terse
  strings via preprocessor, but everything is a real SC pattern. Decide: extend or replace.
- **Steno** (Rohrhuber) — concatenative one-letter synth-graph language; tersity for the
  signal/drone side.
- **ixi lang** (Magnusson) — in SC but a closed surface; the cautionary tale.
- **AlgaLib** — alternate proxy layer with parameter interpolation everywhere.

## Visuals direction

Constraint: **no separate video commands during performance.** Visuals must generate
themselves from the audio or from the audio commands. Build the mapping layer once in
Setup, like SynthDefs; visuals are a *function of* audio state, not a second
instrument.

Three tap points, in order of increasing semantic richness:

1. **Master signal analysis** — analysis synth at the tail of the node tree
   (`Amplitude`, `Pitch`, `Onsets`, FFT features on `In.ar(0,2)`) + `SendReply` →
   OSC out. Works with everything ever played, zero coupling to how sound was made.
2. **Per-proxy taps** — each proxy gets its own analysis chain; per-part visual
   identity.
3. **Event/pattern layer** — mirror every Pbind event over OSC (e.g. `\callback` key
   in the default event type, added once in a house style or snippet). Full
   semantics: instrument, degree, dur, amp — things audio analysis can't recover.

> **2026-11-09:** both the painting register and this protocol are history. The
> painting layer was dropped on 2026-08-19 (Music-Robot DECISIONS D8: the flexible
> layer is the language), and visuals now go out as **Broadcast** — events, control
> values and per-proxy stems streamed to a VJ machine, with visual generation on
> that machine (`~/Tools/Synesthesia/Broadcast Manifest.md`; Roadmap Phase 4). The
> three tap points above survive almost unchanged as Broadcast's three streams. The
> text below is kept as the record of the July design.

**The painting protocol (July 2026 — supersedes analysis-only visuals):** the painting
register doubles as the visual system's wire format. Every painting word (`spray`,
`mark`, `wash`, `mix`, `thin`, `bleed`, `scrape`, `hush`…) emits its semantic form
over OSC as it executes — `/paint/spray [id, hsv, params]` — and the Processing
sketch implements the *same vocabulary visually* (spray = particle cloud, mark =
discrete stamps, glaze = translucent tint layer, scrape/hush = fade). One utterance,
two renderers: sound and image are projections of the same gesture stream. The
music/audio/systems registers stay silent on the wire — visuals listen only to the
painting layer.

The HSV pun is exact and free: the color's timbre coordinates (hue = spectral family,
value = register, saturation = purity/roughness) ARE its screen color. The
sound↔image mapping isn't designed; it's shared.

Three OSC streams into one sketch: (1) painting-gesture events = structure,
(2) audio analysis taps = continuous life (each visual object rides its proxy's
amplitude), (3) CV landmark broadcast = bodies (see Companion Quarks.md). Result:
flexible but highly identifiable house-style visuals, still zero video commands.

Options considered:

- **Built-in (scope/FreqScope/Pen+UserView)**: zero to low effort. Fullscreen
  `s.scope` in X/Y (Lissajous) mode behind a translucent IDE is co34pt's approach
  (Help 6.1) and is fully automatic. Oscilloscope-music (X/Y) is the purest form of
  "video = exact equivalent of the synthesis" — the audio literally draws the image.
  Custom sclang visualizers via `UserView`+`Pen` driven by SendReply data are
  possible but CPU-bound 2D, no shaders — limited ceiling.
- **OSC bridge → Processing (chosen direction to explore)**: oscP5 on the Processing
  side, taps 1–3 above on the SC side. Unlocks GPU: GLSL shaders, 3D, particles,
  video/camera, Syphon out to projection tools. Best realistic realization of the
  "video synth mirroring audio synthesis" ideal: a shader whose uniforms are the
  streamed audio features — the mapping *is* the instrument. Hydra is a lower-effort
  alternative in the same architecture (audio-reactive video synth in the browser).
- **Native C++ video synth inside SuperCollider: ruled out.** scsynth is a real-time
  audio DSP process with no GPU context; a video UGen would block the RT audio
  thread. The architecturally correct native design is a *separate* video server
  speaking OSC (precedent: the long-abandoned SCGraph project) — which is exactly
  what Processing-over-OSC already provides without forking C++.
