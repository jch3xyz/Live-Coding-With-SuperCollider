// BroadcastReceiver — a stand-in for the VJ's machine. Listens on one UDP port and
// logs every message under the Broadcast root with a timestamp, so you can see
// exactly what Resolume or MadMapper would see, and so BroadcastCheck.scd can
// measure the event timing against it.
//
// Run it in a SECOND sclang (a second IDE window, or headless), on this machine or
// on the receiving one:
//
//   /Applications/SuperCollider.app/Contents/MacOS/sclang Setup/BroadcastReceiver.scd
//
// then, in the performing sclang:  Broadcast.start(NetAddr("127.0.0.1", 57130))
//
// Settings come from the environment, so a script can drive it:
//   SYN_BC_PORT     the port to listen on            (default 57130)
//   SYN_BC_ROOT     the namespace root to log         (default /syn)
//   SYN_BC_LOG      a file to append every line to    (default: post window only)
//   SYN_BC_SECONDS  exit after this many seconds      (default: run until stopped)
//   SYN_BC_QUIET    "1" to log to the file only, not the post window
//
// Each line is:  <unix seconds, 4 dp>  <address>  <args...>
// The time is the arrival time — or, for a bundle with a timetag, the timetag — in
// Unix seconds, so logs from two machines line up once their clocks do.

(
var port = ("SYN_BC_PORT".getenv ? "57130").asInteger;
var root = "SYN_BC_ROOT".getenv ? "/syn";
var logPath = "SYN_BC_LOG".getenv;
var seconds = "SYN_BC_SECONDS".getenv;
var quiet = "SYN_BC_QUIET".getenv == "1";
// sclang's own clock (Main.elapsedTime, thread seconds, OSC arrival times) is
// seconds since the process started; this offset turns it into Unix time
var epoch0 = Date.getDate.rawSeconds - Main.elapsedTime;
var file = logPath !? { File(logPath, "a") };
var count = 0, perAddress = IdentityDictionary.new;
var fmt = { |x| if(x.isFloat) { x.round(0.0001).asString } { x.asString } };

if(file.notNil and: { file.isOpen.not }) {
	("BroadcastReceiver: cannot write " ++ logPath).warn;
	file = nil;
};

if(thisProcess.openUDPPort(port).not) {
	("BroadcastReceiver: cannot open port " ++ port ++ " — is another receiver running?").warn;
	file !? { file.write("# BroadcastReceiver FAILED: port " ++ port ++ " in use\n"); file.close };
	0.exit;
};
thisProcess.addOSCRecvFunc({ |msg, time, replyAddr, recvPort|
	var address = msg[0].asString, line;
	if(recvPort == port and: { address.beginsWith(root) }) {
		line = (epoch0 + time).round(0.0001).asString ++ "  " ++ address
			++ "  " ++ msg.copyToEnd(1).collect(fmt).join(" ");
		count = count + 1;
		perAddress[msg[0]] = (perAddress[msg[0]] ? 0) + 1;
		if(quiet.not) { line.postln };
		file !? { file.write(line ++ "\n"); file.flush };
	};
});

("BroadcastReceiver: listening on port " ++ port ++ " for " ++ root ++ "/*"
	++ (logPath !? { " → " ++ logPath } ? "")).postln;
// a comment line marks the log as live, so a script knows the stub is listening
file !? { file.write("# BroadcastReceiver ready on port " ++ port ++ "\n"); file.flush };

seconds !? {
	SystemClock.sched(seconds.asFloat, {
		("BroadcastReceiver: " ++ count ++ " message(s) on " ++ perAddress.size
			++ " address(es)").postln;
		perAddress.keys.asArray.sort.do { |k| ("  " ++ k ++ "  " ++ perAddress[k]).postln };
		file !? { file.close };
		0.exit;
		nil   // a number here would reschedule this function while the process winds down
	});
};
)
