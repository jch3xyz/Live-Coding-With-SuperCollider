//Run setup code
("Setup/Setup.scd").loadRelative;


//Set snippets to a hotkey if you haven't already
DDWSnippets.learn


//Change global fade time
p.fadeTime = 4;


//Change tempo
p.clock.tempo = 120/60;


//Choose a random scale
(n = ();
n.scale = Scale.choose;)


//Begin

~sin = {SinOsc.ar([80, 82],mul: 0.5)}
~sin.play
~sin.stop

~grain = {GrainIn.ar(2, Dust.kr(15), LFNoise1.kr(0.1).range(0.025, 0.25), ~sin, LFNoise1.kr(10))}

~grainin = {GrainIn.ar(2, Dust.kr(30), LFNoise1.kr(0.1).range(0.01, 0.25), SoundIn.ar(), LFNoise1.kr(10))}

~grain.play
~grain.stop

~grainin.play


