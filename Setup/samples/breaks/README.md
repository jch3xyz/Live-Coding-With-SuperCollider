# breaks/ — drop your drum loops here

Every folder inside `Setup/samples/` whose name starts with **`breaks`** is scanned at
boot by `Break.scan` and becomes tempo-locked, choppable material. So `breaks/`,
`breaks175/`, and `breaks-jungle/` all work, and you can split your collection across
several folders.

Tutorial: SuperCollider help browser → **Guides/Breaks**.

## What to put here

Whole drum-loop recordings — one loop per file. `wav`, `aiff`, `aif`, `flac`
(`mp3` cannot be read by SuperCollider). Stereo is fine; each file is loaded as a
mono mixdown, because the grain engine requires a mono buffer and the system's
spatial rule wants mono cores anyway.

## Naming matters, because tempo is not in the audio

A file does not say what tempo it was recorded at, so the tempo is inferred in this
order:

1. **a bpm-tagged number in the filename** — `amen_175bpm.wav`, `loop-175-BPM.wav`,
   `bpm140.wav`. This is the reliable route; unrelated numbers such as freesound IDs
   are ignored (`250093__amfe__175bpm-loop.wav` reads as 175, not 250093).
2. **a tagged or plausible number in the folder name** — `breaks175/`.
3. **the duration**, assuming the file is cut to a whole number of beats, preferring
   the most break-plausible reading.

The file's **key** — what you type mid-set — is its filename, lowercased with
punctuation collapsed. So `amen.wav` gives you `~d.brk(\amen)`, and a 60-character
download gives you a 60-character symbol. Short filenames are worth the rename, or
use the sidecar below.

## Correcting and renaming: `_breaks.scd`

Run `Break.list` to see what was inferred; the `from` column tells you which rule
fired, so a guess is never invisible. Fix anything wrong once:

```supercollider
\amen.bpm_(172);      // this loop is 172 bpm
\amen.len_(8);        // this loop is 8 beats long
```

Either call writes a `_breaks.scd` file in this folder, which is merged over the
inference at every boot. It is plain, hand-editable SuperCollider, and its `key:`
field also renames a break — which is how an unwieldy download gets a name you can
actually type:

```supercollider
Dictionary[
	"250093__amfe__175bpm-amen-punchy-loop.wav" -> (key: 'amen', bpm: 175, beats: 4),
	"ragged_live_take.wav" -> (key: 'take1', beats: 7)
]
```

`beats` is the number the engine actually uses. If a break sounds like it is running
at half or double speed, that is a wrong beat count — fix it with `len_`, not with
`speed`.

## Nothing here yet?

The tutorial's opening section builds a working break out of the sound that ships
with SuperCollider, so you can learn the whole vocabulary before you have a library.

Note that these folders are also picked up by the ordinary sample loader into `d`,
so `d["breaks"]` still works with `bplay` and `\breaks.hits(...)` as before.
