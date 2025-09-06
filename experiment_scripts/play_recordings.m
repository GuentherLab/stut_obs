% Script to play recording from one single trial
% Note that you should not load the combined result file (*audio.mat)

% Load the trial result you want to listen
load(['C:\ieeg_stut\sub-stutobs-pilot001\ses-1\beh\jackson20\run1\'...
    'sub-stutobs-pilot001_ses-1_run-01_task-jackson20_trial-14.mat']);
info=audiodevinfo;
player=audioplayer(tData.s, tData.fs, 24, info.output(1).ID);
play(player)