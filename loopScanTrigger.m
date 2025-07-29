%% Script to test the scanner trigger
%
% Sends an infinite loop of triggers spaced 0.2 s apart
clear;close all;
try, a=audioDeviceWriter('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strOUTPUT=[str{:}]; end;
tgind = find(contains(strOUTPUT, 'Playback')&contains(strOUTPUT, 'Focusrite'));
trigread = dsp.AudioFileReader(fullfile(fileparts(which(mfilename)),'flvoice_run_trigger.wav'), 'SamplesPerFrame', 2048);
trigwrite = audioDeviceWriter('SampleRate',trigread.SampleRate,'Device',strOUTPUT{tgind});

% send trigger pulse
while 1
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    pause(0.2)
end