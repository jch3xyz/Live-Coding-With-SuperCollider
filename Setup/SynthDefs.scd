/*

coï¿¥ï¾¡pt SynthDef library

used as part of howto_co34pt_livecode

*/
(
/*

vplaym: enveloped mono buffer player
For mono buffers only

Arguments:

out = Channel out
buf = Buffer index
rate = Speed of playback
amp = volume
pan = pan (stereo)
atk = attack
rel = release
pos = position to start playback from 0 to 1

*/

SynthDef(\vplaym,
	{arg out = 0, buf = 0, rate = 1, amp = 0.5, pan = 0, atk=0.01, rel=1, pos=0;
		var sig, env;
		sig = Pan2.ar(PlayBuf.ar(1,buf,BufRateScale.ir(buf) * rate,1,BufDur.kr(buf)*pos*44100,doneAction:2),pan);
		env = EnvGen.ar(Env.linen(0.0,rel,0.0,1));
		sig = sig * env;
		sig = sig * amp;
		Out.ar(out,sig);
}).add;

/*

vplay: enveloped stereo buffer player
For stereo buffers only
The default is to have no attack, as I use this to create a 'chopped-up' effect

Arguments:

out = Channel out
buf = Buffer index
rate = Speed of playback
amp = volume
pan = pan (stereo)
atk = attack
sus = sustain
rel = release
pos = position to start playback from 0 to 1

*/

SynthDef(\vplay,
	{arg out = 0, buf = 0, rate = 1, amp = 0.5, pan = 0, atk=0.0, sus=1, rel= 0, pos=0;
		var sig, env;
		sig = Pan2.ar(PlayBuf.ar(2,buf,BufRateScale.ir(buf) * rate,1,BufDur.kr(buf)*pos*44100,doneAction:2),pan);
		env = EnvGen.ar(Env.linen(atk,sus,rel,1),doneAction:2);
		sig = sig * env;
		sig = sig * amp;
		Out.ar(out,sig);
}).add;

/*

wtabl: wavetable synth using looped buffers via PlayBuf

out = channel out
buf = buffer index. This should be a wavetable buffer, but it *can* be anything
freq = frequency of the buffer, this can be used in conjunction with scale/degree/octave
amp = volume
pan = pan in stereo
atk = attack
rel = release

*/

SynthDef(\wtabl,
	{arg out = 0, buf = 0, freq = 300, amp = 0.5, pan = 0, atk=0.01, rel=1;
		var sig, env;
		sig = Pan2.ar(PlayBuf.ar(1,buf,BufRateScale.ir(buf) *freq,1,0,1),pan);
		env = EnvGen.ar(Env.perc(atk,rel),doneAction:2);
		sig = sig * env;
		sig = sig * amp;
		Out.ar(out,sig);
}).add;

(
//SynthDef based on an overdriven DFM1 - this is very CPU intensive
//Using resonance values of >1 only will sound the freq value and detune it.
//good for stabs, but is buggy
SynthDef(\dfm1, {
	arg out = 0, freq = 440,mul = 0.5, res = 1,type = 0, noise = 0.0003, atk = 0.01, rel = 1;
	var sig, env;
	env = EnvGen.ar(Env.perc(atk,rel),doneAction:2);
	sig = DFM1.ar(SinOsc.ar,freq,res,1,type,noise,mul);
	sig = sig*env;
	Out.ar(out,Splay.ar([sig]));
}).add;
);

/*

bplay: basic stereo buffer player
This is the bread and butter of my SynthDef library
Designed for simple repeated playback of stereo buffers inside of a pattern
TODO: This - Stereo samples are currently mixed down to mono and positioned in a stereo field by using the Pan2 Ugen. I'm going to correct this soon

out = channel out
buf = buffer index
rate = rate of playback (or pitch)
amp = volume
pan = stereo panning of sample
pos = position of playback (usually not used)
rel = release (usually not used, this is only really in case I accidentally play a sample backwards, and need the synth to free at some point in the future, or schedule very long samples to be played. This is a security measure in case I box my processor.)

*/

SynthDef(\bplay,
	{arg out = 0, buf = 0, rate = 1, amp = 0.5, pan = 0, pos = 0, rel=15;
		var sig,env ;
		sig = Mix.ar(PlayBuf.ar(2,buf,BufRateScale.ir(buf) * rate,1,BufDur.kr(buf)*pos*44100,doneAction:2));
		env = EnvGen.ar(Env.linen(0.0,rel,0),doneAction:2);
		sig = sig * env;
		sig = sig * amp;
		Out.ar(out,Pan2.ar(sig,pan));
}).add;

/*

bplaym: basic mono buffer player
Designed for simple repeated playback of mono buffers inside of a pattern

out = channel out
buf = buffer index
rate = rate of playback (or pitch)
amp = volume
pan = stereo panning of sample
pos = position of playback (usually not used)
rel = release (usually not used, this is only really in case I accidentally play a sample backwards, and need the synth to free at some point in the future, or schedule very long samples to be played. This is a security measure in case I box my processor.)

*/

SynthDef(\bplaym,
	{arg out = 0, buf = 0, rate = 1, amp = 0.5, pan = 0, pos = 0, rel=15;
		var sig,env ;
		sig = Pan2.ar(PlayBuf.ar(1,buf,BufRateScale.ir(buf) * rate,1,BufDur.kr(buf)*pos*44100,doneAction:2),pan);
		env = EnvGen.ar(Env.linen(0.0,rel,0),doneAction:2);
		sig = sig * env;
		sig = sig * amp;
		Out.ar(out,sig);
}).add;

/*

bplaymr: basic reversed mono buffer player
plays back a mono sample in reverse. I designed this for a specific instance but kept it in the setupfile because why not. It takes away some of the extra work needed to schedule the playing of backward sample within my other SynthDefs

out = channel out
buf = buffer index
rate = rate of playback (or pitch)
amp = volume
pan = stereo panning of sample
pos = position of playback (usually not used)
rel = release (usually not used, this is only really in case I accidentally play a sample backwards, and need the synth to free at some point in the future, or schedule very long samples to be played. This is a security measure in case I box my processor.)

*/


SynthDef(\bplaymr,
	{arg out = 0, buf = 0, rate = 1, amp = 0.5, pan = 0, pos = 0, rel=3;
		var sig,env ;
		sig = Pan2.ar(PlayBuf.ar(1,buf,rate.neg,1,BufDur.kr(buf)*44100-2,doneAction:2),pan);
		env = EnvGen.ar(Env.linen(0.0,rel,0),doneAction:2);
		sig = sig * env;
		sig = sig * amp;
		Out.ar(out,sig);
}).add;

/*

lplay - a looping player for stereo samples that uses the dur value to automatically pitch samples for looping over a given number of beats. I built this to grab a bunch of drum loops and percussion loops at roughly the correct tempo and use them at the clock rate of my set.

out = channel out
buf = buffer index
amp = volume
pan = stereo panning
rel = release (mostly here to prevent runaway PlayBufs)
dur = duration, in beats, that you would like your sample scaled to. For example a sample played over 8 beats would have a dur of 8 specified. Note that this repitches the sample in order to scale it to the correct beat, so it could end up at a _very_ different pitch

*/
SynthDef(\lplay,
	{arg out = 0, buf = 0, amp = 0.5, pan = 0, rel=15, dur = 8;
		var sig,env ;
		sig = Mix.ar(PlayBuf.ar(2,buf,BufRateScale.ir(buf) * ((BufFrames.ir(buf)/s.sampleRate)*p.clock.tempo/dur),1,0,doneAction:2));
		env = EnvGen.ar(Env.linen(0.0,rel,0),doneAction:2);
		sig = sig * env;
		sig = sig * amp;
		Out.ar(out,Pan2.ar(sig,pan));
}).add;

/*

bpfsaw: an instrument by Eli Fieldsteel as part of his SuperCollider tutorial series
A detuned slow-enveloped saw wave which sounds lush and beautiful, especially with some extended chords
Has a lot of arguments,

atk = attack
sus = sustain
rel = release
ts = timescale of the envelope
c1 = start of envelope curve
c2 = end of envelope curve
freq = frequency
detune = detuning (multiple of frequency), works well with low values, higher ones get quite silly
pan = panning in stereo
cfhzmin = minimum modulation of filter frequency
cfhzmax = maximum modulation of filter frequency
cfmin = minimum filter frequency
cfmax = maximum filter frequency
rqmin = controls filter sweeping. Lower values = greater effects of filtering
rqmax = controls filter sweeping. Lower values = greater effects of filtering
lsf = frequency at which low shelf is activated
ldb = low shelf boost (in dB) - gets really glitchy over around 16 dB, but sounds great so I keep it high
amp = volume
out = channels out

*/

(
SynthDef(\bpfsaw, {
	arg atk=2, sus=0, rel=3, ts=1, c1=1, c2=(-1), freq=500, detune=0.02, pan=0, cfhzmin=0.1, cfhzmax=0.3, cfmin=500, cfmax=2000, rqmin=0.1, rqmax=0.2, lsf=200, ldb=0, amp=1, out=0;
	var sig, env;
	env = EnvGen.kr(Env([0,1,1,0],[atk,sus,rel],[c1,0,c2]),timeScale:ts,doneAction:2);
	sig = Saw.ar(freq*{LFNoise1.kr(0.5,detune).midiratio}!2);
	sig = BPF.ar(
		sig,
		{LFNoise1.kr(
			LFNoise1.kr(4).exprange(cfhzmin,cfhzmax)
		).exprange(cfmin,cfmax)}!2,
		{LFNoise1.kr(0.1).exprange(rqmin,rqmax)}!2
	);
	sig = BLowShelf.ar(sig,lsf,0.5,ldb);
	sig = Balance2.ar(sig[0],sig[1],pan);
	sig = sig*env*amp;
	Out.ar(out,sig);
}).add;
);

/*

henonN: using the non-interpolated Henon Ugen as a synth
Contains a LeakDC Ugen to stop any DC bias in the signal from disturbing the rest of the mix
Arguments for a, b, x0 and x1 are at their default values which gives a periodic signal, and only slight deviation will change the properties of the signal a LOT.
The non-interpolated version gives the most 'harsh' signal

it uses the equation x(n+2) = 1 - a * x(n+1)^2 + b * x(n)

freq = frequency
a = a
b = b
x0 = first value of x
x1 = second value of x
atk = attack
sus = sustain
rel = release
ts = timescale
out = channels out
pan = panning in stereo
amp = volume

*/

(
SynthDef(\henon,
	{arg freq=440,a=1.3,b=0.3,x0=0.30501993062401,x1=0.20938865431933,atk=0.01,sus=1,rel=1,ts=1,out=0,pan=0,amp=0.3;
		var sig,env;
		sig = HenonN.ar(freq,a,b,x0,x1,amp);
		env = EnvGen.ar(Env.linen(atk,sus,rel),1,1,0,ts,2);
		sig = LeakDC.ar(sig);
		sig = sig*env;
		Out.ar(out,Pan2.ar(sig,pan));
}).add;
);

/*

henonC: using the cubic-interpolated Henon Ugen as a synth
Contains a LeakDC Ugen to stop any DC bias in the signal from disturbing the rest of the mix
Arguments for a, b, x0 and x1 are at their default values which gives a periodic signal, and only slight deviation will change the properties of the signal a LOT.
The cubic-interpolated version gives the most 'soft' signal

it uses the equation x(n+2) = 1 - a * x(n+1)^2 + b * x(n)

freq = frequency
a = a
b = b
x0 = first value of x
x1 = second value of x
atk = attack
sus = sustain
rel = release
ts = timescale
out = channels out
pan = panning in stereo
amp = volume

*/

(
SynthDef(\henonc,
	{arg freq=440,a=1.3,b=0.3,x0=0.30501993062401,x1=0.20938865431933,atk=0.01,sus=1,rel=1,ts=1,out=0,pan=0,amp=0.3;
		var sig,env;
		sig = HenonC.ar(freq,a,b,x0,x1,amp);
		sig = LeakDC.ar(sig);
		Out.ar(out,Pan2.ar(sig,pan));
}).add;
);

/*

warp1: a SynthDef to leverate Warp1 (my favourite granular buffer player) within patterns
I don't use this that much, as Warp1 is much better suited going straight into ProxySpace and modulated by Ugens, but it's in here in case it is useful within a Pmono
The arguments are quite convoluted, and they can be much better understood by looking at Warp1's helpfile

buf = buffer number
channels = number of channels of the buffer
rate = rate of playback of grains
size = window size of grains
env = envelope number of grains
olap = overlap of grains
rand = random playback window of grains
interp = interpolation (4 = cubic)
poslag = lag in the position for use within a Pmono (in seconds)
ratelag = lag in the rate for use within a Pmono (in seconds)
out = channels out
sizelag = lag in the window size for use within a Pmono (in seconds)
pan = pan within a stereo field
amp = volume

*/

(
SynthDef(\warp1,
	{arg buf=0, channels=2, pos=0, rate=1, size=0.2, env= -1, olap=8, rand=0, interp=4, poslag=0, ratelag=0, out=0, sizelag=0, pan=0, amp=0.5;
		var sig;
		sig = Warp1.ar(2,buf,Lag.kr(pos,poslag),Lag.kr(rate,ratelag),Lag.kr(size,sizelag),env,olap,rand,interp,1);
		Out.ar(out,Pan2.ar(sig,pan,amp));
}).add;
);


/*

bpfbuf: a synth created by Eli Fieldsteel as part of his SuperCollider tutorials series
Plays looped buffers through a band pass filter, and in the tutorial is used to create pitched 'clouds' of percussion
I don't use this one much, but it can be very useful.

atk = attack
sus = sustain
rel = release
c1 = start of the envelope curve
c2 = end of the envelope curve
buf = buffer index
rate = rate of buffer played
pos = start position
freq = frequency of buffer player
rq = Q of Band Pass Filter
bpfmix = amount of band pass filter included in signal
pan = pan in the stereo field
amp = volume
out = channels out

*/

(
SynthDef(\bpfbuf, {
	arg atk=0, sus=0, rel=3, c1=1, c2=(-1),
	buf=0, rate=1, pos=0, freq=440, rq = 1,
	bpfmix=0, pan=0, amp=1, out=0;
	var sig, env;
	env = EnvGen.kr(Env([0,1,1,0],[atk,sus,rel],[c1,0,c2]),doneAction:2);
	sig = PlayBuf.ar(1, buf, rate*BufRateScale.ir(buf), startPos:pos);
	sig = XFade2.ar(sig, BPF.ar(sig, freq, rq, 1/rq.sqrt), bpfmix*2-1);
	sig = sig * env;
	sig = Pan2.ar(sig,pan,amp);
	Out.ar(out,sig);
}).add;
);

/*

sinfb: General purpose SinOscFB Ugen designed to mutate between pure sine waves and noise using the feedback argument.
A SynthDef that gets heavy use from me, works well for bass, chords and melody.

freq = frequency
atk = attack
sus = sustain
rel = release
fb = feedback (generally useful values are from 0-2, with 0 being pure sine waves and 2-20 being noise. More info on this in 'Between Pitch and Noise' section of guides)
amp = volume
out = channels out
pan = panning in stereo

*/

(
SynthDef(\sinfb, {
	arg freq = 440, atk = 0.01, sus = 0, rel = 1, fb = 0, amp = 0.3, out = 0, pan=0;
	var sig, env;
	env = EnvGen.ar(Env.linen(atk,sus,rel),1,1,0,1,2);
	sig = SinOscFB.ar(freq,fb,1);
	sig = sig*env;
	Out.ar(out,Pan2.ar(sig,pan,amp));
}).add;
);

/*

ring1: a Ringz-based synth which is inspired by this: http://sccode.org/1-1b
ring2, ring3 and ring4 represent the other tones used in this example, but I don't use them. They have been left in in case I would like to use the original combination of frequencies
the .tanh gives a wonderful squelch when driven very hard, and at low frequencies it resembles an acid bass

f = frequency (the reason this isn't freq is because it doesn't seem to work)
a = amplitude of Ringz (before the final multiplier so that a heavily distorted signal can be later scaled by amp)
d = duration of envelope on Ringz
pan = Pan in stereo
amp = overall volume
out = channels out

*/

SynthDef(\ring1,
	{
		arg f = 45, a = 9, d = 0.6, pan = 0, amp = 1, out = 0;
		var sig, env;
		env = Line.kr(0,1,d);
		env = FreeSelfWhenDone.kr(env);
		sig = Impulse.ar(0);
		sig = Ringz.ar(sig,f,d,a);
		Out.ar(out,Pan2.ar(sig.tanh,pan) * amp)
	};
).add;
SynthDef(\ring2,
	{
		arg f = 9000, a = 2, d = 0.1, amp = 1, pan = 2, out = 0;
		var sig, env;
		env = Line.kr(0,1,d);
		env = FreeSelfWhenDone.kr(env);
		sig = Impulse.ar(0);
		sig = Ringz.ar(sig,f,d,a);
		Out.ar(out,Pan2.ar(sig.tanh,pan) * amp)
	};
).add;
SynthDef(\ring3,
	{
		arg f = 50, a = 3, d = 1, pan = 0, amp = 1, out = 0;
		var sig, env;
		env = Line.kr(0,1,d);
		env = FreeSelfWhenDone.kr(env);
		sig = Impulse.ar(0);
		sig = Ringz.ar(sig,f,d,a);
		Out.ar(out,Pan2.ar(sig.tanh,pan) * amp)
	};
).add;
SynthDef(\ring4,
	{
		arg f = 8000, a = 1, d = 0.3, pan = 0, amp = 1, out = 0;
		var sig, env;
		env = Line.kr(0,1,d);
		env = FreeSelfWhenDone.kr(env);
		sig = Impulse.ar(0);
		sig = Ringz.ar(sig,f,d,a);
		Out.ar(out,Pan2.ar(sig.tanh,pan) * amp)
	};
).add;

/*
//this needs to be re-evaluated every time there is a note played - so it needs work.
//not working thus far
SynthDef(\randomChaos,
	{ arg out = 0, atk = 0, rel = 0.1, sus = 0;
		var sig, env, chaosUgen, chaosUgenPick;
		env = EnvGen.ar(Env.linen(atk,sus,rel),doneAction:2);
		chaosUgen = ChaosGen.allSubclasses;
		sig = chaosUgen[rrand(0,10)].ar;
		sig = sig*env;
		Out.ar(out,Pan2.ar(sig));
}).add;
*/

///////////////////////////////////////////////////////////////////////////
/*    SuperDirt Synths */
///////////////////////////////////////////////////////////////////////////

//808 Style Kick/Bass with optional FM
//too tonal to be used as a standard kick, more like bass
//fm = modulator frequency of PMOsc
//voice = pmindex of PMOsc; fm gets multiplied by this number
//susstain = sustain of the envelope

SynthDef(\bellkick, {
  arg out, pan, freq = 65, fm = 0, speed = 0.3, voice = 1, sustain = 1, pitch2 = 0.00;
  var beater, source, env;

  env = Env.perc(0.005, sustain).ar(Done.freeSelf);

  source = Line.ar(freq * 2, freq, 0.02);
  source = PMOsc.ar(source, fm, voice);
  source = LPF.ar(source, 1000);

  beater = WhiteNoise.ar(pitch2.clip);
  beater = HPF.ar(beater, 500);
  beater = LPF.ar(beater, XLine.ar(6000, 500, speed.clip * 0.1));
  beater = beater * Env.perc.ar;

  Out.ar(out, Pan2.ar((source + beater) * 3.dbamp, pan, env));
},
metadata: (
  credit: "Renick Bell",
  category: \drums,
  tags: [\pitched, \bass, \sos]
)).add;


// physical modeling of a vibrating string, using a delay line (CombL) excited by an intial pulse (Impulse)
// To make it a bit richer, I've combined two slightly detuned delay lines
// "accelerate" is used for a pitch glide, and "sustain" changes the envelope timescale
(
	SynthDef(\supermandolin, {|out, sustain=1, pan, accelerate, freq, detune=0.2 |
		var env = EnvGen.ar(Env.linen(0.002, 0.996, 0.002, 1,-3), timeScale:sustain, doneAction:2);
		var sound = Decay.ar(Impulse.ar(0,0,0.1), 0.1*(freq.cpsmidi)/69) * WhiteNoise.ar;
		var pitch = freq * Line.kr(1, 1+accelerate, sustain);
		sound = CombL.ar(sound, 0.05, pitch.reciprocal*(1-(detune/100)), sustain)
		+ CombL.ar(sound, 0.05, pitch.reciprocal*(1+(detune/100)), sustain);
		Out.ar(out, Pan2.ar(sound, pan, env))
	}).add
);


// an example of additive synthesis, building up a gong-like noise from a sum of sine-wave harmonics
// notice how the envelope timescale and amplitude can be scaled as a function of the harmonic frequency
// "voice" provides something like a tone knob, and "decay" adjusts how the harmonics decay
// as in the other SynthDefs, "sustain" affects the overall envelope timescale and "accelerate" for pitch glide
// for a demo, try this in Tidal
// d1 $ n (slow 2 $ fmap (*7) $ run 8) # s "supergong" # decay "[1 0.2]/4" # voice "[0.5 0]/8"
(
	SynthDef(\supergong,{|out, sustain=1, pan, accelerate, freq, voice=0, decay=1, amp=1 |
		// lowest modes for clamped circular plate
		var freqlist =[1.000,  2.081,  3.414,  3.893,  4.995,  5.954,  6.819,  8.280,  8.722,  8.882, 10.868, 11.180, 11.754,
			13.710, 13.715, 15.057, 15.484, 16.469, 16.817, 18.628]**1.0;
		var tscale = 100.0 / freq / (freqlist**(2-clip(decay,0,2)));
		var ascale =freqlist**clip(voice,0,4);
		var sound = Mix.arFill(15, {arg i; EnvGen.ar(Env.perc(0.01*tscale[i], 0.5*tscale[i], 0.2*ascale[i] ), timeScale:sustain*5)
			* SinOsc.ar(freq * freqlist[i] * Line.kr(1, 1+accelerate, sustain))});
		Out.ar(out, Pan2.ar(sound*amp, pan))
	}).add
);


// waveguide mesh, hexagonal drum-like membrane
(
	SynthDef(\superhex,{|out, rate=1, sustain=1, pan, freq, accelerate |
		var env = EnvGen.ar(Env.linen(0.02, 0.96, 0.02, 1,-3), timeScale:sustain, doneAction:2);
		var tension = 0.05*freq/400 * Line.kr(1,accelerate+1, sustain);
		var loss = 1.0 - (0.01 * rate / freq);
		var sound = MembraneHexagon.ar(Decay.ar(Impulse.ar(0,0,1), 0.01), tension, loss);
		Out.ar(out, Pan2.ar(sound, pan, env))
	}).add
);


// The next four synths respond to the following parameters in addition to gain, pan, n, and all the "effect" parameters
// (including attack, hold, and release).  Default values in parentheses.
//
// sustain - scales overall duration
// decay(0) - amount of decay after initial attack
// accelerate(0) - pitch glide
// semitone(12) - how far off in pitch the secondary oscillator is (need not be integer)
// pitch1(1) - filter frequency scaling multiplier, the frequency itself follows the pitch set by "n"
// rate(1)- LFO rate
// lfo(1) - how much the LFO affects the filter frequency
// resonance(0.2) - filter resonance
// voice(0.5) - depends on the individual synth

// a moog-inspired square-wave synth; variable-width pulses with filter frequency modulated by an LFO
// "voice" controls the pulse width (exactly zero or one will make no sound)
(
	SynthDef(\supersquare, {|out, rate=1, decay=0, sustain=1, pan, accelerate, freq,
		voice=0.5, semitone=12, resonance=0.2, lfo=1, pitch1=1|
		var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
		var basefreq = freq* Line.kr(1, 1+accelerate, sustain);
		var basefreq2 = basefreq / (2**(semitone/12));
		var lfof1 = min(basefreq*10*pitch1, 22000);
		var lfof2 = min(lfof1 * (lfo + 1), 22000);
		var sound = (0.7 * Pulse.ar(basefreq, voice)) + (0.3 * Pulse.ar(basefreq2, voice));
		sound = MoogFF.ar(
			sound,
			SinOsc.ar(basefreq/64*rate, 0).range(lfof1,lfof2),
			resonance*4);
		sound = sound.tanh * 2;
		Out.ar(out, Pan2.ar(sound, pan, env));
	}).add
);


// a moog-inspired sawtooth synth; slightly detuned saws with triangle harmonics, filter frequency modulated by LFO
// "voice" controls a relative phase and detune amount
(
	SynthDef(\supersaw, {|out, rate=1, decay=0, sustain=1, pan, accelerate, freq,
		voice=0.5, semitone=12, resonance=0.2, lfo=1, pitch1=1|
		var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
		var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
		var basefreq2 = basefreq * (2**(semitone/12));
		var lfof1 = min(basefreq*10*pitch1, 22000);
		var lfof2 = min(lfof1 * (lfo + 1), 22000);
		var sound = MoogFF.ar(
			(0.5 * Mix.arFill(3, {|i|  SawDPW.ar(basefreq * ((i-1)*voice/50+1), 0)})) + (0.5 * LFTri.ar(basefreq2, voice)),
			LFTri.ar(basefreq/64*rate, 0.5).range(lfof1,lfof2),
			resonance*4);
		sound = sound.tanh*2;
		Out.ar(out, Pan2.ar(sound, pan, env));
	}).add
);


// a moog-inspired PWM synth; pulses multiplied by phase-shifted pulses, double filtering with an envelope on the second
// "voice" controls the phase shift rate
(
	SynthDef(\superpwm, {|out, rate=1, decay=0, sustain=1, pan, accelerate, freq,
		voice=0.5, semitone=12, resonance=0.2, lfo=1, pitch1=1|
		var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
		var env2 = EnvGen.ar(Env.pairs([[0,0.1],[0.1,1],[0.4,0.5],[0.9,0.2],[1,0.2]], -3), timeScale:sustain/rate);
		var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
		var basefreq2 = basefreq / (2**(semitone/12));
		var lfof1 = min(basefreq*10*pitch1, 22000);
		var lfof2 = min(lfof1 * (lfo + 1), 22000);
		var sound = 0.7 * PulseDPW.ar(basefreq) * DelayC.ar(PulseDPW.ar(basefreq), 0.2, Line.kr(0,voice,sustain)/basefreq);
		sound = 0.3 * PulseDPW.ar(basefreq2) * DelayC.ar(PulseDPW.ar(basefreq2), 0.2, Line.kr(0.1,0.1+voice,sustain)/basefreq) + sound;
		sound = MoogFF.ar(sound, SinOsc.ar(basefreq/32*rate, 0).range(lfof1,lfof2), resonance*4);
		sound = MoogFF.ar(sound, min(env2*lfof2*1.1, 22000), 3);
		sound = sound.tanh*5;
		Out.ar(out, Pan2.ar(sound, pan, env));
	}).add
);


// "voice" scales the comparator frequencies, higher values will sound "breathier"
(
	SynthDef(\supercomparator, {|out, rate=1, decay=0, sustain=1, pan, accelerate, freq,
		voice=0.5, resonance=0.5, lfo=1, pitch1=1|
		var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
		var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
		var sound = VarSaw.ar(basefreq, 0, Line.ar(0,1,sustain));
		var freqlist =[ 1.000, 2.188,  5.091,  8.529,  8.950,  9.305, 13.746, 14.653, 19.462, 22.003, 24.888, 25.991,
			26.085, 30.509, 33.608, 35.081, 40.125, 42.023, 46.527, 49.481]**(voice/5);
		sound = Splay.arFill(16, {|i| sound > LFTri.ar(freqlist[i])}, 1);
		sound = MoogFF.ar(
			sound,
			pitch1 * 4 * basefreq + SinOsc.ar(basefreq/64*rate, 0, lfo*basefreq/2) + LFNoise2.ar(1,lfo*basefreq),
			LFNoise2.ar(0,0.1,4*resonance));
		Out.ar(out, Pan2.ar(0.5*sound, pan, env));
	}).add
);


// tuning fork
(
SynthDef(\superfork, {|out, sustain=1, pan, freq, accelerate=0|
	var sound, env;
	freq = freq * Line.kr(1, 1+accelerate, sustain);
	env = EnvGen.ar(Env.linen(0.001, 0.998, 0.001), timeScale:sustain, doneAction:2);
	sound = 0.2 * SinOsc.ar([1.0, 6.1, 16.7, 20.1] * freq) * XLine.ar([0.3, 1, 1.3, 2], [1e-4, 1e-7, 1e-6, 1e-7], sustain*[4,4,0.5,0.333]);
	Out.ar(out, Pan2.ar(sound, pan, env));
}).add
);


// vibraphone simulation, adapted with some help from Kevin Larke's thesis Real Time Vibraphone Pitch and Timbre Classification
// "decay" - use larger values to damp higher harmonics (default 0)
// "velocity" - higher velocity will brighten the sound a bit (default 1)
// "accelerate" - for a linear pitch bend
// "modamp" - amplitude of the tremolo (0-2 is OK, default 1)
// "modfreq" - frequency of the tremolo (default 7)
// "detune" - adjusts a high harmonic to give the sound a different character
(
SynthDef(\supervibe, {|out, sustain=1, decay=0, pan, freq, accelerate=0, velocity=1,
	modamp=1, modfreq=7.0, detune=0 |
	// most envelope shaping is done with XLines later, this envelope is just to clean up overall
	var env = EnvGen.ar(Env.linen(0.001, 0.998, 0.001), timeScale:sustain, doneAction:2);
	var sound, mod, freqs, hifreqs, decays;
	freqs = freq * Line.kr(1, 1+accelerate, sustain) * [1, 4, 10, 13.75+detune];
	hifreqs = freq * Line.kr(1, 1+accelerate, sustain) * [19.2, 20, 21.2];
	mod = SinOsc.kr(modfreq, Rand(0,2pi)).range(1-([0.5,0.3,0.3,0.5]*modamp),1);
	sound = 0.3 * [1, 1.1*velocity, 0.6*velocity*velocity, 0.5*velocity] * SinOsc.ar(freqs);
	decays = [1, 0.7*exp(-1.0*decay), 0.5*exp(-1.0*decay), 0.4*exp(-1.0*decay)];
	sound = XLine.ar(1e-6, 1, 1/freqs) * XLine.ar(1, 1e-6, decays*4*sustain) * sound * mod; // main attacks and decays
	sound = (XLine.ar(0.3*(velocity+1e-6),1e-6,0.02) * SinOsc.ar(hifreqs)).sum + sound.sum; // hi frequency onset
	Out.ar(out, Pan2.ar(sound, pan, env));
}).add
);


// 6-op FM synth (DX7-like)
//
// Works a bit different from the original DX7.  Instead of algorithms, you set the amount
// of modulation every operator receives from other operators and itself (feedback), virtually
// providing an endless number of possible combinations (algorithms).
//
// Responds to
//   voice (preset number: [0] is user-defined; [1-5] are randomly generated presets).
//   lfofreq (overall pitch modulation frequency)
//   lfodepth (overall pitch modulation amplitude)
//
// Each operator responds to
//   amp (operator volume - becomes carrier)
//   ratio (frequency ratio)
//   detune (in Hz)
//   eglevel[1-4] (4 envelope generator levels)
//   egrate[1-4] (4 envelope generator rates)
//
// The syntax for operator arguments is <argumentName + opIndex>[modulatorIndex | egIndex]
//
// For example:
// amp1 1      (op1 as carrier with full volume)
// ratio2 2.3  (op2 frequency ratio)
// mod11 0.5   (op1 feedback)
// mod12 0.78  (op1 modulation amount by op2)
// detune1 0.2 (op1 detune)
// eglevel12 0.1  (op1 EG level2)
// egrate11 0.01  (op1 EG rate1) -- WARNING: higher values go FASTER!
(
SynthDef(\superfm, {
	var sustain = \sustain.kr(1);
	var lfofreq = \lfofreq.kr(1);
	var lfodepth = \lfodepth.kr(0);
	var freq = \freq.kr(440);
	var tremolo = 1 + (LFTri.kr(lfofreq) * lfodepth);
	var out = \out.kr(0);
	var pan = \pan.kr(0);
	var voice = \voice.kr(0);
	// overall envelope
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1, -3), timeScale:sustain, doneAction:2);
	// operator output levels
	var amps = Array.fill(6, { |i| (\amp++(i+1)).asSymbol.kr(1)});
	// operator frequency ratios
	var ratios = Array.fill(6, {|i| (\ratio++(i+1)).asSymbol.kr(1)});
	// operator frequency detuners
	var detunes = Array.fill(6, {|i| (\detune++(i+1)).asSymbol.kr(rand2(0.1))});
	// feedback -- for presets only
	var feedback = \feedback.kr(0.0);
	// operator envelopes
	var eglevels = Array.fill(6, {|i|
		Array.fill(4, { |n| (\eglevel++(i+1)++(n+1)).asSymbol.kr(1) })
	});
	var egrates = Array.fill(6, {|i| [
		// Supercollider envelopes use seconds for the durations of segments.
		// So higher values mean transitions are slower.
		// DX7s envelopes use rates, which is the inverse of time, 1/time.
		// Higher values in DX7 mean transitions are faster.
		max(0.1 / ((\egrate++(i+1)++1).asSymbol).ir(10), 0.001),
		max(0.1 / ((\egrate++(i+1)++2).asSymbol).ir(0.3), 0.001),
		max(0.1 / ((\egrate++(i+1)++3).asSymbol).ir(0.1), 0.001),
		max(0.1 / ((\egrate++(i+1)++4).asSymbol).ir(0.1), 0.001),
	]});
	// modulation matrix
	var mods = Array.fill2D(6, 6, { |r, c|
		(\mod++(r+1)++(c+1)).asSymbol.kr(0) * if(r == c, feedback, 1)
	});
	var presets = SelectX.kr(voice, [
		[ // user-defined
			ratios,	detunes, amps, eglevels, egrates, mods,
		],
	] ++
	// randomly generated presets
	Array.fill(5, { [
		// ratios
		Array.fill(6, {
			[0.25, 0.5, 1, 2, 3, 4, 5, 6, 7, 11.rand + 1, 13.rand + 1, 15.rand + 1].wchoose(
				[1, 2, 8, 4, 3, 0.5, 0.5, 0.5, 0.5, 0.25, 0.25, 0.25].normalizeSum)
		}),
		// detunes
		Array.fill(6, { rand2(7) }),
		// amps
		Array.fill(6, { 1.0.rand * 0.5.coin.asInteger }),
		// EG levels
		Array.fill2D(6, 4, {1.0.rand}),
		// EG rates
		Array.fill2D(6, 4, {1.0.rand}),
		// mods
		Array.fill2D(6, 6, {|r,c| 1.0.rand * 0.25.coin.asInteger * if(r == c, feedback, 1)}),
	]})
	);

	var envs = Array.fill(6, { |i|
		EnvGen.kr(
			Env.new(
				// EG levels
				[0]++Array.fill(4, { |n| presets[3][i][n] }),
				// EG rates
				Array.fill(4, { |n| presets[4][i][n] })
			),
			timeScale:sustain,
		);
	});

	var ctls = Array.fill(6, { |i|
		[freq * tremolo * presets[0][i] + presets[1][i], 0, envs[i]]
	});

	var sound = FM7.ar(ctls, presets[5]) * amps;
	sound = Mix.ar(sound) * (-15.dbamp);
	Out.ar(out, Pan2.ar(sound, pan, env));
}).add;
);


// Retrieved from http:sccode.org/1-5aD
// DrumSynths SC Example - SOS Drums by Renick Bell, renick_at_gmail.com
// recipes from Gordon Reid in his Sound on Sound articles
// SOStom — http:www.soundonsound.com/sos/Mar02/articles/synthsecrets0302.asp
// Modified by Bruno Ruviaro and Josh Mitchell 8/19.
// Adapted to SuperDirt by Aleksandr Yakunichev, hi@ya.codes
//
// voice - controls modulation input phase in radians (min: 0, max: your sanity)
(
SynthDef(\sostoms, {
  arg out, pan, sustain = 0.5, freq = 261.626, voice = 0.5;
  var envelope, source;

  source = PMOsc.ar(Saw.ar(freq * 0.9), freq * 0.85, voice, mul: 6.dbamp);
  source = source + SinOsc.ar([freq, freq * 0.8]);
  source = Mix.ar(source);
  source = LeakDC.ar(source + Crackle.ar(2)) * (-3).dbamp;

  envelope = Env.perc(0.005, sustain, (-4).dbamp, -6).ar(Done.freeSelf);

  Out.ar(out, Pan2.ar(source, pan, envelope));
},
metadata: (
  credit: "Renick Bell",
  category: \drums,
  tags: [\pitched, \tom, \sos]
)).add;
);

// live audio input stereo
(
SynthDef(\in2, { |out, soundin = 0, sustain = 1, pan, inputFadeTime = 0.03|
	var env, sound;
	env = Env.linen(inputFadeTime, sustain - (2 * inputFadeTime), inputFadeTime).kr;
	sound = SoundIn.ar([0, 1] + soundin); // stereo in
	sound = sound * env;
	Out.ar(out, Pan2.ar(sound, pan));
}).add;
);

// live audio input mono
(
SynthDef(\in1, { |out, soundin = 0, sustain = 1, pan, inputFadeTime = 0.03|
	var env, sound;
	env = Env.linen(inputFadeTime, sustain - (2 * inputFadeTime), inputFadeTime).kr;
	sound = SoundIn.ar(soundin); // mono in
	sound = sound * env;
	Out.ar(out, Pan2.ar(sound, pan));
}).add;
);

// pitch shifted live audio input stereo
(
SynthDef(\inr2, { |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset, inputFadeTime = 0.03, soundin=0|
	var env, sound, rate, phase;
	env = Env.linen(inputFadeTime, sustain - (2 * inputFadeTime), inputFadeTime).kr;
	phase = Line.ar(begin, end, sustain);
	rate = (begin + 1) * (speed + Sweep.kr(1, accelerate)) * freq / 440;
	sound = SoundIn.ar([0, 1] + soundin); // stereo in
	sound = sound * env;
	sound = PitchShift.ar(sound, 0.1, rate, 0.02, 0.01);
	Out.ar(out, Pan2.ar(sound, pan));
}).add;
);

// pitch shifted live audio input mono
(
SynthDef(\inr1, { |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset, inputFadeTime = 0.03, soundin=0|
	var env, sound, rate, phase;
	env = Env.linen(inputFadeTime, sustain - (2 * inputFadeTime), inputFadeTime).kr;
	phase = Line.ar(begin, end, sustain);
	rate = (begin + 1) * (speed + Sweep.kr(1, accelerate)) * freq / 440;
	sound = SoundIn.ar(soundin); // mono in
	sound = sound * env;
	sound = PitchShift.ar(sound, 0.1, rate, 0.02, 0.01);
	Out.ar(out, Pan2.ar(sound, pan));
}).add;
);

// gabor grain
(
SynthDef(\gabor, { |out, sustain = 0.03, freq = 440, pan = 0, width = 0.3|
	var env, sound;
	sound = SinOsc.ar(freq, 0.5pi);
	env = LFGauss.ar(sustain, width, loop: 0).range(0, 1);
	Out.ar(out, Pan2.ar(env * sound, pan));
}).add;
);

///////////////////////////////////////////////////////////////////////////
/*    Originals   */
///////////////////////////////////////////////////////////////////////////


//Simple Hi-Hats made from white noise
//rel = release; longer release times turn it into an open hat

SynthDef(\hats, {
	    arg out=0, rel=0.025, pan=0, amp=1;
		var noise, env;

		noise = WhiteNoise.ar;

		env = EnvGen.kr(Env.perc(0, rel), doneAction: 2);

		Out.ar(out, Pan2.ar(noise, pan, env * amp));
	}).add;

)
