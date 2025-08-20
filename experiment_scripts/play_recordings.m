% Script to play recording from one single trial
% Note that you should not load the combined result file (*audio.mat)

% Load the trial result you want to listen
load('sub-TEST02/ses-1/beh/md/sub-TEST02_ses-1_run-1_task-md_trial-24.mat');
info=audiodevinfo;
player=audioplayer(tData.s, tData.fs, 24, info.output(1).ID);
play(player)