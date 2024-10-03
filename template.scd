//Run setup code
("Setup/Setup.scd").loadRelative;

//Set snippets to a hotkey if you haven't already
DDWSnippets.learn

//Change global fade time
p.fadeTime = 4;

//Change tempo
p.clock.tempo = 120/60;

//Start or resume recording
s.record;
//Pause recording
s.pauseRecording;
//Stop recording
s.stopRecording;


//Begin
