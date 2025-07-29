%%% INPUTs ===============================================================
subjID = 'SEQM901';
sesID = 2;
proj = 'SEQ-Multisyllabic';
basePath = '/Users/leon/Documents/BU/SCC/Experiments/SEQM/';
outputPath = '/Users/leon/Downloads/';
tsk = 'test';

start_run_num = 1;
end_run_num = 6;


%%% MAIN =================================================================
mkdir(sprintf('%s/sub-%s/ses-%d/beh/%s/',outputPath, subjID, sesID, tsk));
for i = start_run_num : end_run_num
    data = load(sprintf('%s/sub-%s/ses-%d/beh/%s/sub-%s_ses-%d_run-%d_task-test_desc-audio.mat',basePath, subjID, sesID, tsk, subjID, sesID,i));
    desc_file = sprintf('%s/sub-%s/ses-%d/beh/%s/sub-%s_ses-%d_run-%d_task-test_desc-stimulus.txt',basePath, subjID, sesID, tsk, subjID, sesID, i);
    desc = regexp(fileread(desc_file),'[\n\r]+','split');
    nTrial = size(data.trialData,2);
    f = waitbar(0, sprintf('Run %d', i));
    for j = 1:nTrial
        sti = strrep(strrep(desc{j}, '/', '-'), '\', '-');
        fname = sprintf('%s/sub-%s/ses-%d/beh/%s/sub-%s_ses-%d_run-%d_trial-%s_task-test_%s_response.wav',outputPath, subjID, sesID, tsk, subjID, sesID,i,pad(num2str(j), 2, 'left', '0'),sti);
        audiowrite(fname, data.trialData(j).s, data.trialData(j).fs);
        waitbar(j/nTrial, f, sprintf('Progress: %d %%', floor(j/nTrial*100)));
    end
    close(f)
end