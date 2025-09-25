%%% INPUTs ===============================================================

sub = 'STUTObsPilot003';
ses = 1;
task = 'jackson20';

num_run_digits = 2; 
nTrial = 60; 

[dirs, host] = set_paths_stut_obs(); 
dirs.sub = [dirs.data, filesep, 'sub-',sub];
dirs.ses = [dirs.sub, filesep, 'ses-',num2str(ses)]; 
dirs.task = [dirs.ses, filesep, 'beh', filesep,task]; 
dirs.audio_trial_files = [dirs.derivatives, filesep, 'sub-',sub, filesep, 'trial-audio']; % need to update this path

if ~exist(dirs.audio_trial_files)
    mkdir(dirs.audio_trial_files)
end

for run = [1:4] 
    runstring = sprintf(['%0',num2str(num_run_digits),'d'], run); % add zero padding
    filestring = sprintf('sub-%s_ses-%d_run-%s_task-%s_',sub, ses, runstring, expParams.task); % string to be used in multiple file names
    for itrial = 1:2:nTrial % skip interleaved baseline trials
        dirs.run = [dirs.task, filesep, 'run-',runstring];
        load([dirs.run, filesep, filestring,'trial-',num2str(itrial), '.mat']); 
        
        % sti = strrep(strrep(desc{j}, '/', '-'), '\', '-');
        fname =  [dirs.audio_trial_files, filesep, filestring,'trial-',num2str(itrial), '_video.wav'];
        audiowrite(fname, tData.s, tData.fs);
        % waitbar(j/nTrial, f, sprintf('Progress: %d %%', floor(j/nTrial*100)));
    end
end
