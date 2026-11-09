//Boilerplate code for basic live coding functionality

(
var setupDir = thisProcess.nowExecutingPath.dirname;

//The sample library, outside this repo. Mostly drum loops (indexed for the breaks
//machine below), plus a few packs of single hits, which `oneShots` files into d
//under the short keys the docs use. Anything not listed in `oneShots` is treated
//as loops. Setup still boots on a machine without the library; it just skips it.
var library = "~/Studio/Assets/Audio Samples/Breaks".standardizePath;
var oneShots = [
	"k"    -> ["Gems From The Crates/Kicks",
		"The Drum Broker - International Breaks & Essential Kicks/The Drum Broker - Essential Kicks"],
	"s"    -> ["Gems From The Crates/Snares"],
	"cp"   -> ["Gems From The Crates/Claps"],
	"perc" -> ["Gems From The Crates/Percussion"]
];

//every audio file in one folder (not its subfolders), as Buffers.
//includesEqual, NOT includes: Collection:includes tests identity, so
//["wav"].includes("wav") is false and every folder loaded empty.
var readFolder = { |path|
	PathName(path).files
		.select { |f| ["wav", "aiff", "aif", "flac"].includesEqual(f.extension.toLower) }
		.collect { |sf| Buffer.read(s, sf.fullPath) }
};

//free all running processes
Buffer.freeAll;
ServerTree.removeAll;
ServerQuit.removeAll;
Tdef.removeAll;

//Log every evaluation this session (auto-transcript; mine for vocabulary later)
History.start;

//Audio devices (this Mac). Verification gates set topEnvironment[\setupGate] = true
//before loading this file: system default output, no input, no recording file.
if(topEnvironment[\setupGate] == true) {
	Server.default.options.inDevice_(nil).outDevice_(nil).numInputBusChannels_(0);
} {
	Server.default.options.inDevice_("MacBook Pro Microphone");
	Server.default.options.outDevice_("WH-1000XM5");
};


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
		d.add(folder.folderName -> readFolder.(folder.fullPath));
	};
	//one-shots from the library join any local folder of the same key
	//(the path is also left in topEnvironment for SetupCheck.scd to verify)
	topEnvironment[\sampleLibrary] = if(File.exists(library)) { library };
	if(File.exists(library)) {
		oneShots.do { |pair|
			d[pair.key] = (d[pair.key] ? []) ++ pair.value.collect { |sub|
				readFolder.(library +/+ sub)
			}.flatten;
		};
	};
	s.sync;
	("Samples: " ++ d.size ++ " key(s) — "
		++ d.keys.asArray.sort.collect { |k| k ++ "[" ++ d[k].size ++ "]" }.join(" ")).postln;

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
		//Then the library: indexed, not loaded (each loop loads the first time it
		//plays). The one-shot folders filed into d above are skipped by their own
		//name (fileName: the last path segment — folderName would be the PARENT's),
		//so the oneShots table is the only list to keep up to date.
		if(File.exists(library)) {
			\Break.asClass.addLibrary(library,
				exclude: oneShots.collect(_.value).flatten.collect { |sub|
					PathName(library +/+ sub).fileName
				});
		};
		s.sync;
	};

	//loads snippets from setup folder (intentionally empty for now)
	(setupDir +/+ "Snippets.scd").load;
	s.sync;

	//activate StageLimiter - Part of the BatLib quark
	//No s.freeAll after this: the server was just rebooted, so there is nothing to
	//free, and freeAll re-creates the default group asynchronously (initTree forks
	//on AppClock). The returns below were built into a group that didn't exist
	//yet, and the limiter only survived a 10 ms race. SetupCheck.scd guards this.
	StageLimiter.activate;
	s.sync;

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
	//(skipped for gates: prepareForRecord creates the file on disk)
	if(topEnvironment[\setupGate] != true) {
		s.prepareForRecord(PathName(setupDir).parentPath +/+ "Recordings/" +/+ "SC_" ++ Date.getDate.format("%y%m%d_%H%M%S") ++ ".wav");
		s.sync;
		"Ready to record!".postln;
	};

});
)

//Date.getDate.format("%y%m%d_%H%M%S").postln

//(PathName(thisProcess.nowExecutingPath.dirname).parentPath +/+ "Recordings/" +/+ "SC_" ++ Date.getDate.format("%y%m%d_%H%M%S") ++ ".wav").postln
