function timingAnalyze(matFile)
    
load(matFile);

nTrial = size(trialData, 2);

intervals=[];for i = 2:nTrial; intervals = [intervals trialData(i).timingTrial(3)-trialData(i-1).timingTrial(13)];end;
figure;plot(intervals, 'o-', 'linewidth', 2);title('TIME\_SCAN\_END -> TIME\_STIM\_ASTART, lower better, around 0.25');

proc=[];for i = 1:nTrial; proc = [proc trialData(i).timingTrial(3)-trialData(i).timingTrial(2)];end;
figure;plot(proc, 'o-', 'linewidth', 2);title('TIME\_STIM\_START-> TIME\_STIM\_ASTART, lower better');

fix1=[];for i = 1:nTrial; fix1 = [fix1 trialData(i).timingTrial(4)-trialData(i).timingTrial(3)];end;
figure;plot(fix1, 'o-', 'linewidth', 2);title('TIME\_STIM\_ASTART-> TIME\_SOUND\_START, 0.50(SEQS)/0(SEQM)');

stimplaydelay =[];for i = 1:nTrial; stimplaydelay = [stimplaydelay trialData(i).timingTrial(5)-trialData(i).timingTrial(4)];end;
figure;plot(stimplaydelay, 'o-', 'linewidth', 2);title('TIME\_SOUND\_START-> TIME\_SOUND\_ASTART, lower better');

stim=[];for i = 1:nTrial; stim = [stim trialData(i).timingTrial(6)-trialData(i).timingTrial(5)];end;
figure;plot(stim, 'o-', 'linewidth', 2);title('TIME\_SOUND\_ASTART-> TIME\_SOUND\_END, 0.48(SEQS)/various(SEQM)');

fix2=[];for i = 1:nTrial; fix2 = [fix2 trialData(i).timingTrial(7)-trialData(i).timingTrial(6)];end;
figure;plot(fix2, 'o-', 'linewidth', 2);title('TIME\_SOUND\_END-> TIME\_ALLSTIM\_END, 0.47(SEQS)/0(SEQM)');

postim=[];for i = 1:nTrial; postim = [postim trialData(i).timingTrial(8)-trialData(i).timingTrial(7) - trialData(i).timePostStim];end;
figure;plot(postim, 'o-', 'linewidth', 2);title('TIME\_ALLSTIM\_END-> TIME\_GO\_START - timePostStim, 0');

godelay=[];for i = 1:nTrial; godelay = [godelay trialData(i).timingTrial(9)-trialData(i).timingTrial(8)];end;
figure;plot(godelay, 'o-', 'linewidth', 2);title('TIME\_GO\_START-> TIME\_GO\_ASTART, lower better');

reactTimeVal=[];for i = 1:nTrial; reactTimeVal = [reactTimeVal trialData(i).timingTrial(10)-trialData(i).timingTrial(9)];end;
figure;plot(reactTimeVal, 'o-', 'linewidth', 2);title('TIME\_GO\_ASTART-> TIME\_VOICE\_START, same as reality');

reactTimeMiss=[];for i = 1:nTrial; reactTimeMiss = [reactTimeMiss trialData(i).timingTrial(10)-trialData(i).timingTrial(9)- trialData(i).voiceOnsetTime];end;
figure;plot(reactTimeMiss, 'o-', 'linewidth', 2);title('TIME\_GO\_ASTART-> TIME\_VOICE\_START - voiceOnsetTime, 0');

scanwait=[];for i = 1:nTrial; scanwait = [scanwait trialData(i).timingTrial(11)-trialData(i).timingTrial(10)];end;
figure;plot(scanwait, 'o-', 'linewidth', 2);title('TIME\_VOICE\_START-> TIME\_SCAN\_START, 4.5 for speech trials');

trigdelay=[];for i = 1:nTrial; trigdelay = [trigdelay trialData(i).timingTrial(12)-trialData(i).timingTrial(11)];end;
figure;plot(trigdelay, 'o-', 'linewidth', 2);title('TIME\_SCAN\_START-> TIME\_SCAN\_ASTART, lower better');

scandur = [];for i = 1:nTrial; scandur = [scandur trialData(i).timingTrial(13)-trialData(i).timingTrial(12)];end;
figure;plot(scandur, 'o-', 'linewidth', 2);title('TIME\_SCAN\_ASTART-> TIME\_SCAN\_END, 1.60');

reality2 = [];for i = 1:nTrial; reality2 = [reality2 trialData(i).timingTrial(12)-trialData(i).timingTrial(10)];end;
figure;plot(reality2, 'o-', 'linewidth', 2);title('TIME\_VOICE\_START-> TIME\_SCAN\_ASTART, same as reality');

%%
delay = [];
for ii = 1:nTrial
    if isnan(trialData(ii).voiceOnsetTime)
        expdur = trialData(ii).timePreSound + trialData(ii).timeStim + trialData(ii).timePostSound +  trialData(ii).timePostStim + trialData(ii).timeMax + trialData(ii).timeScan;
    else
        expdur = trialData(ii).timePreSound + trialData(ii).timeStim + trialData(ii).timePostSound +  trialData(ii).timePostStim + trialData(ii).voiceOnsetTime + trialData(ii).timePostOnset + trialData(ii).timeScan;
    end
    delay = [delay trialData(ii).timingTrial(13)-trialData(ii).timingTrial(2)-expdur];
end
figure;plot(delay, 'o-', 'linewidth', 2);title('Total delay, lower better');

end