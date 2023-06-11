//Run setup code
("Setup/Setup.scd").loadRelative;


//Set snippets to a hotkey if you haven't already
DDWSnippets.learn


//Change global fade time
p.fadeTime = 4;


//Change tempo
p.clock.tempo = 120/60;


//Choose a random scale
~scale = Scale.choose;


//Begin


