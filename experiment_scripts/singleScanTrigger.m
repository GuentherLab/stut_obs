%% Script to test the scanner trigger
%
% Sends a single trigger
clear;close all;
try, a=audioDeviceWriter('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strOUTPUT=[str{:}]; end;
tgind = find(contains(strOUTPUT, 'Playback')&contains(strOUTPUT, 'Focusrite'));
tgind=1;
trigread = dsp.AudioFileReader(fullfile(fileparts(which(mfilename)),'flvoice_run_trigger.wav'), 'SamplesPerFrame', 2048);
trigwrite = audioDeviceWriter('SampleRate',trigread.SampleRate,'Device',strOUTPUT{tgind});

% send trigger pulse
while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
fprintf('Trigger signal sent.\n');
pause(1)
release(trigwrite);release(trigread);