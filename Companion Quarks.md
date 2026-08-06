# Companion Quarks

Ideas for separate quarks built and used in tandem with the core live-coding quark
(see "Design Notes.md" for that). Each is a perception→signal bridge AND a conceptual
statement about what counts as musical input. Shared architecture for all of them:
external helper process (Python/browser) → OSC → control buses → **named-controls
substrate** (same interface as trackpad/GUI/future MIDI).

**The organizing insight:** while live coding, the hands and eyes-on-screen are
occupied — the *free* channels are the face, the voice, the body, the heart, and
other people. Every quark below harvests a channel that typing leaves free.

---

## 1. MediaPipe quark (landmarks: hands / face / pose) — first build

Feasibility: HIGH (weekend-to-week). The TouchDesigner .tox precedent: even TD
doesn't embed MediaPipe — it hosts the JS build and streams data in; we do the same
shape with Python (`mediapipe` + `python-osc`, ~50–100 lines, 30fps) or the
GPU-accelerated browser build.

- Helper owns camera + inference on its own core; never touches the audio thread.
- Quark: launches/supervises helper (`.unixCmd`, auto-reconnect), OSC→buses,
  smoothing (lag/median), Specs.
- Ship a **derived-feature vocabulary**, not 21 raw points: pinch distance, hand
  openness, hand x/y/z, wrist velocity, mouth-open, head tilt. Words:
  `hand(\right, \pinch).exp(200, 8000)`, `face(\mouthOpen)`.
- **Face Landmarker outputs 52 blendshapes natively** (jawOpen, browInnerUp,
  mouthSmile… each 0–1) — continuous, performable controls out of the box, and the
  substrate for the emotion quark below.
- Latency ≈ 40–70ms: great for continuous control, mushy for percussive triggers —
  no air-drumming.
- macOS camera permission goes to the launching process (one-time prompt); packaging
  pain is the Python env — bootstrap a venv/uv on install.
- Camera starts in Setup → hands are ambient signals; zero performance commands.
- Synergy: same landmark stream feeds the Processing visuals (one bridge, two
  consumers). In-house precedent: co34pt's SerialToOSC (Help 6.2).
- No well-known MediaPipe quark exists — real community-contribution potential.

## 2. Emotion tracker (face) — "the performer's affect is the score"

Feasibility: HIGH, and mostly a *mapping* layer on top of quark #1.
- Route A (recommended): skip discrete emotion labels; map blendshape combinations to
  **continuous valence/arousal axes**. Discrete 7-class emotion output is jumpy and
  reductive as a control signal; two smooth affect axes are much better musical
  material (arousal → energy/density, valence → harmony/timbre).
- Route B: landmarks → small classifier (precedent: MekhyW/Facial-Emotion-
  Classification — MediaPipe landmarks + scikit-learn, "very fast"). Use classifier
  *probabilities* as continuous signals rather than the argmax label.
- Works on whoever the camera sees: performer, dancer, audience member.

## 3. Voice emotion (tone) — "how you speak matters more than what"

Feasibility: MEDIUM-HIGH. Standard tool: **openSMILE** (open-source audio feature
extractor, supports incremental on-line processing; eGeMAPS feature set → valence/
arousal regression). Live-demo precedent: LIVE_SER (mic → Keras SER in real time).
- Research note from the survey: **voice carries arousal better; face carries valence
  better** — quarks #2 and #3 are natural fusion partners, not alternatives.
- Also the cheap version: raw prosody (pitch contour, loudness, speech rate) via
  standard SC analysis UGens on a mic proxy — no ML at all, still expressive.

## 4. Motion / dance tracking — "the dancer is the instrumentalist"

Feasibility: HIGH for skeletons; the design work is in the features.
- Skeleton sources: MediaPipe Pose/BlazePose (33 landmarks), MoveNet (fastest),
  OpenPose (multi-person). Ready-made OSC bridges exist: **LivePose** (multiple
  algorithms → OSC/websocket, with filters like "arms-up" triggers) and **PoseOSC**
  (`poses/0/leftWrist/position` address scheme).
- THE precedent to study: **EyesWeb** (Camurri, InfoMus Genoa, free, 25 years of
  research on exactly this — dance → music). Its core lesson: don't map joint
  coordinates; map **expressive qualities** — Quantity of Motion, Contraction Index,
  fluidity, impulsiveness (Laban effort qualities). Derived expressive features are
  to pose what pinch-distance is to hand landmarks.
- For collaboration: point the camera at the dancer; their body becomes a bank of
  signals the coder patches live. Multi-person (OpenPose) → ensemble.

## 5. Physiology: heart rate via webcam (rPPG) — "the involuntary enters the music"

Feasibility: MEDIUM (it works, it's noisy). Remote photoplethysmography reads pulse
from skin-color micro-variations in face video (Eulerian magnification family);
multiple open-source implementations; in-the-wild accuracy r ≈ 0.6–0.75.
- Musically: pulse → tempo/pulse of a layer; HRV → slow drift. Noise is aesthetic
  here, not a bug.
- The conceptually rich part: **closed loop** — the music changes the performer's
  (audience's?) heart rate, which changes the music. Biofeedback as form.
- Breathing rate from chest motion/optical flow is the same family and easier.

## 6. Gaze tracking — "attention is the controller"

Feasibility: MEDIUM-HIGH. WebGazer.js (browser, self-calibrating), or MediaPipe
iris landmarks + small regression (several open repos, e.g. Python-Gaze-Face-Tracker).
- The live-coding-specific killer app: **gaze as selector while hands stay on the
  keyboard** — look at a proxy's row on the Board to make it the target of the next
  gesture/knob. Solves "hands are busy typing" directly.
- Accuracy is coarse (screen regions, not pixels) — design for zones, not points.

## 7. The mapping glue: Wekinator / FluCoMa — "mappings by demonstration"

Not sensors — the layer that makes all of the above *playable*.
- **Wekinator** (Fiebrink): OSC in → trained mapping → OSC out. Instead of hand-coding
  blendshape→parameter math, demonstrate: make a face, set the drone how you want it,
  record example pairs, train regression; also classification + temporal patterns.
- **FluCoMa** (Fluid Corpus Manipulation): the same ML natively *inside* SC
  (MLPRegressor, KMeans, etc.) — no external app; plus corpus tools/concatenative
  synthesis that suit the abstract-sound practice anyway. Likely the better long-term
  home; Wekinator is the faster experiment.

## 8. Grab bag (cheap, conceptually fun)

- **Optical flow / frame motion energy** — no skeleton; ambient movement of a room or
  audience → texture density. The audience as sensor.
- **Object detection (YOLO-family)** — objects placed on a table enter the frame and
  are sonified: tangible objects as program state, camera-only reacTable.
- **Color tracking** — colored cards held up as faders/selectors; painterly and
  legible to an audience.
- **Blendshape event triggers** — wink/brow-raise as discrete events (scene advance).
  High comedy risk; use deliberately.
- **Keystroke dynamics** — the typing itself (rate, bursts, pauses) as a signal;
  sonifying the act of coding. Zero extra hardware, maximally self-referential.

## Architecture decision: CV helpers broadcast; Processing subscribes (July 2026)

Question raised: write the CV in Processing so tracking visuals composite directly
into the visualizer? Answer: **don't move inference into the renderer — make the
helper a broadcaster with multiple subscribers.** OSC goes to two destinations
(SC's langPort AND the Processing sketch's port): SC gets control signals, Processing
gets the same landmarks to draw skeletons/hands into the visuals. No either/or, and
the quark stays community-shareable (SC class + helper is self-contained; a quark
shipping a Python/JS helper is normal — the TD .tox ships a JS app).

- Camera frames (not just landmarks) for visuals: one process should own the camera —
  the helper — and share frames to Processing via **Syphon** (macOS GPU texture
  sharing; Processing has a Syphon library, Python bindings exist). Two processes
  opening one camera is fragile on macOS.
- Technical reality check on MediaPipe *in* Processing: MediaPipe's desktop Java
  story is the weakest of its builds. If self-contained sketches are ever wanted:
  cansik's **Deep Vision** Processing library (pose/hand/face), or **OpenCV for
  Processing** (optical flow, blob/face detection); in p5.js, **ml5.js** wraps
  MediaPipe trivially. But the broadcaster pattern remains the recommended shape.
- The visualizer sketch thus renders three OSC streams: painting-gesture protocol
  from SC (see Design Notes.md), audio analysis taps, CV landmark broadcast.

## Cross-cutting notes

- All quarks are OSC producers into the same named-controls substrate — sensors are
  interchangeable with trackpad/GUI/MIDI at the mapping layer.
- Fusion beats single-sensor: face-valence + voice-arousal; pose + heart rate.
- Every helper is a separate process: crashes drop control data, never audio.
- Publish independently; each is useful to non-live-coders too.
