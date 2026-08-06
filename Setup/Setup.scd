//Boilerplate code for basic live coding functionality

(
var setupDir = thisProcess.nowExecutingPath.dirname;

//free all running processes
Buffer.freeAll;
ServerTree.removeAll;
ServerQuit.removeAll;
Tdef.removeAll;

//Log every evaluation this session (auto-transcript; mine for vocabulary later)
History.start;

Server.default.options.inDevice_("MacBook Pro Microphone");

Server.default.options.outDevice_("WH-1000XM5");



//Set the sample rate to match your system
s.options.sampleRate = 44100;
//increase number of buffers the server has access to for loading samples
s.options.numBuffers = 1024 * 16;
//increase the memory available to the server
s.options.memSize = 8192 * 64;
//boot the server
s.reboot;
//start proxyspace
p=ProxySpace.push(s);
//start tempo clock
p.makeTempoClock;
//give proxyspace a tempo
p.clock.tempo = 2;
//Set a global fade time
p.fadeTime = 4;
//Rebinds land on the next bar (set to 0 to disable)
p.quant = 4;
//Create the proxy mixer
ProxyMixer.new(p);
//Make a level meter
//s.meter;

//Load the samples, synthdefs, and snippets
s.waitForBoot({
	3.wait;
	//Load samples: every folder inside Setup/samples/ becomes a key in d.
	//No "sets" — the whole library is globally available. Empty is fine.
	d = Dictionary.new;
	PathName(setupDir +/+ "samples").folders.do { |folder|
		d.add(folder.folderName -> folder.files
			.select { |f| ["wav", "aiff", "aif", "flac"].includes(f.extension.toLower) }
			.collect { |sf| Buffer.read(s, sf.fullPath) });
	};
	s.sync;
	("Samples: " ++ d.size ++ " folder(s) loaded").postln;

	//Load every SynthDef file in Setup/SynthDefs/ (one def per file;
	//see SynthDefs/CONVENTIONS.md for how to write one)
	(setupDir +/+ "SynthDefs" +/+ "*.scd").pathMatch.do { |path| path.load };
	s.sync;
	("SynthDefs: " ++ SynthDescLib.global.synthDescs.size ++ " defs known").postln;

	//Load the breakbeat library: every folder named breaks* inside Setup/samples/
	//becomes tempo-tagged, mono, choppable material. Guarded so this file still
	//boots if the Synesthesia quark is not installed.
	if(\Break.asClass.notNil) {
		\Break.asClass.scan(setupDir +/+ "samples");
		s.sync;
	};

	//loads snippets from setup folder (intentionally empty for now)
	(setupDir +/+ "Snippets.scd").load;
	s.sync;

	//activate StageLimiter - Part of the BatLib quark
	StageLimiter.activate;
	s.sync;
	s.freeAll;

	//Standing FX returns: always present, silent until fed.
	//Feed by adding sources, e.g. ~verbIn.add({~k.ar * 0.3});
	~verbIn = {Silent.ar(2)};
	~verb = {GVerb.ar(Mix.ar(~verbIn.ar), 60, 5, 0.6, drylevel: 0) * 0.5};
	~verb.play;
	~delayIn = {Silent.ar(2)};
	//dotted-eighth delay at current tempo (re-evaluate if tempo changes)
	~delay = {CombC.ar(~delayIn.ar, 2, 3/(4*p.clock.tempo), 4)};
	~delay.play;
	s.sync;
	"Setup done!".postln;

	//Prepare to record and set the file path to save the recording
	s.prepareForRecord(PathName(setupDir).parentPath +/+ "Recordings/" +/+ "SC_" ++ Date.getDate.format("%y%m%d_%H%M%S") ++ ".wav");
	s.sync;
	"Ready to record!".postln;

});
)

//Date.getDate.format("%y%m%d_%H%M%S").postln

//(PathName(thisProcess.nowExecutingPath.dirname).parentPath +/+ "Recordings/" +/+ "SC_" ++ Date.getDate.format("%y%m%d_%H%M%S") ++ ".wav").postln
