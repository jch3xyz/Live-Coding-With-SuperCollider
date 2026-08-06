// Shared control Specs for the palette (loads first — filenames sort alphabetically).
// This file is the CANONICAL home for shared arg names (CONVENTIONS.md rule 7);
// a def registers a Spec locally only for args unique to it.
//
// THE COLOR AXES (the contract, finalized July 2026):
//   \hue — 0..1 as an ANGLE on the def's timbre wheel (wraps: 0 and 1 are the same
//          place; distinct "primary" stations crossfaded circularly)
//   \sat — hue-identity strength: 0 = grey wash (hue inaudible), ~0.6 natural,
//          1 = vivid/focused, extreme top = neon heat
//   \val — light: 0 = black (filter floor, hue/sat collapse), mid = detail,
//          1 = full light + air. val also scales how much sat can express.
// Defs implement these as COUPLED mappings (see CONVENTIONS.md), not three wires.

Spec.add(\hue,   [0, 1]);   // circular — wraps at the ends
Spec.add(\sat,   [0, 1]);
Spec.add(\val,   [0, 1]);
Spec.add(\width, [0, 1]);
Spec.add(\pos,   [0, 1]);
Spec.add(\dens,  [1, 80, \exp]);
Spec.add(\size,  [0.01, 0.5, \exp]);
Spec.add(\atk,   [0.001, 8, \exp]);
Spec.add(\dec,   [0.01, 8, \exp]);
Spec.add(\sus,   [0, 1]);
Spec.add(\rel,   [0.01, 12, \exp]);
Spec.add(\hold,  [0.1, 60, \exp]);
Spec.add(\rate,  ControlSpec(-4, 4, \lin, 0, 1));

// brush tier-3 (standalone-module surface)
Spec.add(\sub,   [0, 1]);
Spec.add(\air,   [0, 1]);
Spec.add(\fenv,  [0, 1]);
Spec.add(\track, [0, 1]);
Spec.add(\drift, [0, 1]);
Spec.add(\bow,   [0, 1]);
Spec.add(\smear, [0, 1]);
