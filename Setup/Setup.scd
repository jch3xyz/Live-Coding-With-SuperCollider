//Boilerplate code for basic live coding functionality

(
//free all running processes
Buffer.freeAll;
ServerTree.removeAll;
ServerQuit.removeAll;
Tdef.removeAll;

//Set the sample rate to match your system
s.options.sampleRate = 48000;
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
//Create the proxy mixer
ProxyMixer.new(p);
//Make a level meter
//s.meter;

//Load the samples, synthdefs, and snippets
s.waitForBoot({
	3.wait;
	//Load samples into Buffers and organize them in a dictionary d
	d = Dictionary.new;
	d.add(\foldernames -> PathName(thisProcess.nowExecutingPath.dirname +/+ "samples/set1").entries);
	for (0, d[\foldernames].size-1,
		{arg i; d.add(d[\foldernames][i].folderName -> d[\foldernames][i].entries.collect({
			arg sf;
			Buffer.read(s,sf.fullPath);
		});
	)});
	s.sync;

	//load synthdefs from setup folder
	("SynthDefs.scd").loadRelative;
	"SynthDefs loaded!".postln;
	s.sync;

	//loads snippets from setup folder
	("Snippets.scd").loadRelative;
	"Snippets loaded!".postln;
	s.sync;

	//activate StageLimiter - Part of the BatLib quark
	StageLimiter.activate;
	s.sync;
	s.freeAll;
	"Setup done!".postln;

	//Prepare to record and set the file path to save the recording
	s.prepareForRecord(PathName(thisProcess.nowExecutingPath.dirname).parentPath +/+ "Recordings/" +/+ "SC_" ++ Date.getDate.format("%y%m%d_%H%M%S") ++ ".wav");
	s.sync;
	"Ready to record!".postln;

}).start;
)

//Date.getDate.format("%y%m%d_%H%M%S").postln

//(PathName(thisProcess.nowExecutingPath.dirname).parentPath +/+ "Recordings/" +/+ "SC_" ++ Date.getDate.format("%y%m%d_%H%M%S") ++ ".wav").postln
