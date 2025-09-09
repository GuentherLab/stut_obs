% Script to play recording from one single trial
% Note that you should not load the combined result file (*audio.mat)

% Load the trial result you want to listex

load(['C:\ieeg_stut\sub-example\ses-1\beh\jackson20\'...
    'sub-example_ses-1_run-01_task-jackson20_trial-3.mat']);

% load(['C:\ieeg_stut\sub-stutobs-pilot001\ses-1\beh\jackson20\run01\'...
%     'sub-stutobs-pilot001_ses-1_run-01_task-jackson20_trial-2.mat']);

info=audiodevinfo;
player=audioplayer(tData.s, tData.fs, 24, info.output(1).ID);
play(player)