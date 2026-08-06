# SynthDef Conventions

How to write a SynthDef that integrates with this system (the Synesthesia
vocabulary now, the color language next). Setup loads **every `.scd` file in this
folder** at boot, alphabetically. One def per file; filename = def name
(`sinfb.scd` defines `\sinfb`). This document is the contract; the seed defs
(`bplay.scd`, `bplaym.scd`) are reference implementations.

## Why these rules exist

The color layer will describe sounds as coordinates — hue/value/saturation mapped
onto timbre. A color can only be *portable across instruments* if every instrument
speaks the same control names over the same ranges. So the deepest rule is:

> **Shared macro axes, normalized 0..1, interpreted locally.**
> Every def exposes the same perceptual knobs; each def decides internally what
> its version of "brighter" or "grittier" means. The color layer never needs to
> know a def's private ranges.

(This is the Mutable Instruments architecture — Plaits' `harm/timbre/morph`,
Rings' `struct/bright/damp` are exactly this — which is also why mi-UGens
integrate almost for free.)

## The rules

1. **Naming.** Short lowercase symbol; file matches def name. Families may share
   a prefix (players: `bplay`, `bplaym`).

2. **Universal args.** Every def: `out = 0`, `amp`, `pan`. Every *pitched* def
   names its pitch arg **`freq`** (this is what lets `\deg`/`\chord` and the
   scale machinery drive it). Buffer defs take `buf`, `rate`, `pos` (0..1 start
   position).

3. **The color axes** (the contract — finalized as HSV geometry, July 2026;
   brush.scd is the reference implementation). Named `hue`, `sat`, `val`, all
   0..1, and implemented as a COUPLED space, not three independent wires:
   - **`hue`** — an ANGLE on the def's timbre wheel: distinct "primary" stations
     crossfaded circularly, wrapping (hue 0 = hue 1). Equal steps should feel
     equally salient.
   - **`sat`** — hue-identity strength. 1 = vivid: tight, focused, resonant,
     with *neon* heat (drive) at the extreme top. 0 = GREY: the wheel collapses
     to a blurred, noise-veiled, characterless wash — moving hue at sat 0 does
     (almost) nothing. Blur/wander/instability belong to LOW sat, not high.
   - **`val`** — light. 0 = BLACK: a filter floor below the fundamental where
     every hue converges to the same dark thump (subtractive synthesis contains
     black natively). Mid: detail and envelope contrast grow with light.
     1 = full light + air (with sat low, that corner is WHITE: airy noise
     brilliance).
   - **Required couplings**: hue expression scales with sat (grey degeneracy);
     sat expression scales with val (dark mutes vividness); val's floor
     overrides everything (black point). Where a def has a modulation ecology,
     its rates/depths/targets should shift by region — grey churns, vivid is
     calm, dark breathes slowly.
   A def with no meaningful axis omits it — the color layer skips what isn't
   there. Percussive defs may realize the geometry per-event rather than
   continuously.

4. **Every synth can die.** Event voices: `doneAction: 2` on a percussive or
   windowed envelope (`atk`, `rel` args; `Env.perc` negative curvature for
   drums). Sustained voices: `gate = 1` + `Env.adsr`/`Env.asr` with
   `doneAction: 2` so Pbind `\legato` works. Buffer players keep the failsafe
   timeout (a `rel`-capped window) so reversed/slow playback can't strand nodes.
   *(Legacy cautionary tales: `henonc` shipped with an envelope that was never
   applied — its synths lived forever; `warp1` had no doneAction at all.)*

5. **No environment capture, no magic sample rates.** Never reference `s`, `p`,
   or any interpreter/environment variable inside a def (legacy `lplay` baked
   the boot-time tempo into the compiled def). Tempo-aware defs take tempo as an
   arg (patterns can supply it). Never hardcode 44100 — use
   `BufSampleRate.ir(buf)`, `BufRateScale.ir(buf)`, `BufFrames.ir(buf)`,
   `SampleRate.ir`. *(Every legacy player hardcoded 44100.)*

6. **Channel correctness.** Mono signal → `Pan2.ar(sig, pan, amp)`. Stereo
   signal → `Balance2.ar(sig[0], sig[1], pan, amp)`. Never `Pan2` a stereo
   array — it expands to four output channels. *(Legacy `vplay` wrote buses
   0–3.)*

6b. **Know your source's spatial semantics.** The system is headed for an
   always-3D spatial backend (decoder chosen at Setup per detected system:
   binaural on 2 channels, rig decode on more). For that to work per-instrument:
   a *point source* keeps its core signal **mono**, with `Pan2` only as the
   final, swappable output line — width, if wanted, should be a parameter
   (decorrelation amount), not a baked image, so it stays steerable and
   collapses correctly on any rig. *Inherently-stereo* sources (stereo buffers,
   chorus/dual-detune images) are legitimate — they will be placed as a stereo
   pair spread around their direction. What's forbidden is accidental,
   structural stereo: hard-panned internals that can neither narrow nor move.
   Distance cues (attenuation, air LPF, wet/dry) are the spatial stage's job —
   never build them into a def.

7. **Every performative arg has a Spec.** Shared names (`hue`, `sat`, `val`,
   `atk`, `rel`, `dec`, `sus`, `pos`, `rate`, `hold`, `dens`, `size`, `width`,
   and the brush-style module surface `sub`/`air`/`fenv`/`track`/`drift`/`bow`/
   `smear`) live canonically in `00_specs.scd` (loads first); a def registers a
   Spec locally only for args unique to it. This is what auto-GUI (the Board),
   presets, and color recipes read. Naming note: `rel` always means a release
   time — a lifetime cap is `hold` (see bplay). Axis defaults sit at the def's
   natural voice (typically sat ~0.6, val ~0.5, hue at its home station).

8. **Plugin tiers.** Default is **Tier 0: stock UGens only** — maximum
   portability. **Tier 1** is a curated whitelist of installed, arm64-healthy,
   documented plugins that earn their dependency; a def using one states it in
   its header. Current whitelist:
   - *mi-UGens*: MiPlaits, MiRings, MiClouds, MiBraids, MiVerb, MiWarps,
     MiElements, MiOmi, MiGrids, MiTides, MiMu. **Never MiRipples** — its server
     binary is missing from this install (class compiles, synths fail).
   - *sc3-plugins*: DFM1 (TJUGens); JPverb, Greyhole, ComplexRes, DiodeRingMod
     (DEINDUGens); Gendy4/5, TGrains2/3, GaussTrig, MoogLadder, RLPFD, Streson
     (BhobUGens); Friction, Squiz, WaveLoss (MCLDUGens); Decimator,
     SmoothDecimator, CrossoverDistortion, Disintegrator (DistortionUGens);
     MembraneCircle/MembraneHexagon (MembraneUGens); GravityGrid2 (SLUGens);
     MdaPiano (MdaUGens); DNoiseRing (ChaosUGens); SVF, BMoog (BlackrainUGens).
   - **Never PortedPlugins** — x86_64 binaries, dead on this machine.
   Stock stand-ins when avoiding Tier 1: MoogFF ≈ DFM1; Latch + MantissaMask ≈
   Decimator; Shaper/Fold/.tanh ≈ CrossoverDistortion; Klank/Ringz ≈ Membrane*.

9. **Header comment.** Every file starts with: what it sounds like, its family,
   its tier (and plugin deps if Tier 1), and one example line
   (`Pbind(\instrument, \x, ...)` or the Synesthesia word that plays it).

## Families and their envelope conventions

| Family | Envelope | Tool/word it serves |
|---|---|---|
| buffer players (`bplay`, `bplaym`, …) | windowed, failsafe-capped | `hits`, `rec` captures, future `spray` |
| percussive voices (drums, plucks, stabs) | `Env.perc`, self-freeing | `hits`-style patterns, `dab`, `drip` |
| sustained voices (pads, tones) | gated `adsr`, `\legato`-friendly | `deg`, `chord`, `brush` |
| grain voices (`GrainSin`/`GrainFM`/`GrainBuf`-based) | windowed or gated | `spray`, `wash` |
| texture/chaos voices | gated, `LeakDC` mandatory | `wash`, abstract material |

Drone *recipes* (Synesthesia `droneRecipes`) are functions, not SynthDefs — but
they follow the same macro-axis names, so colors apply to both.

## Template

```supercollider
// \name — one line on the sound. Family: percussive voice. Tier 0 (stock).
// Try: Pbind(\instrument, \name, \degree, Pseq([0,3,5],inf), \dur, 0.5)

Spec.add(\bright, [0, 1]);
Spec.add(\grit, [0, 1]);

SynthDef(\name, { |out = 0, freq = 220, amp = 0.3, pan = 0,
	atk = 0.005, rel = 0.4, bright = 0.5, grit = 0|
	var env = EnvGen.ar(Env.perc(atk, rel, curve: -4), doneAction: 2);
	var sig = /* source, using freq */;
	sig = /* apply bright: e.g. MoogFF.ar(sig, freq * bright.linexp(0, 1, 2, 24)) */;
	sig = SelectX.ar(grit, [sig, (sig * (1 + (grit * 8))).tanh]);
	Out.ar(out, Pan2.ar(sig * env, pan, amp));
}).add;
```
