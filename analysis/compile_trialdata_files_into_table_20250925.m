%%%%% compile stutobs trial data files into a table
% in the future, we should make this table auotamatically from the flvoice_run script
% must start in dir with trialdata files

sub = 'pilot012';
ses = '2';
task = 'jackson20';
runrange = [1:4] 

[dirs, host] = set_paths_stut_obs();
dirs.annot_sub = [dirs.annot, filesep, 'sub-',sub]; 
dirs.sub = [dirs.data, filesep, 'sub-',sub];
dirs.ses = [dirs.sub, filesep, 'ses-',num2str(ses)]; 
dirs.task = [dirs.ses, filesep, 'beh', filesep,task]; 

for run = runrange
    runstring = sprintf(['%0',num2str(num_run_digits),'d'], run); % add zero padding
    filestring = sprintf('sub-%s_ses-%d_run-%s_task-%s_',sub, ses, runstring, expParams.task); % string to be used in multiple file names
    table_savename = ['sub-',sub, '_ses-',ses, '_task-',task, '_run-',runstring, '_trials'];
    

    d = dir; allfiles = {d(~[d.isdir]).name}; clear d % get filenames in working dir
    trialfiles = allfiles(~cellfun(@isempty, regexp(allfiles, 'trial-\d+\.mat$')));
    nfiles = length(trialfiles); 
    
    trials = table; 
    
    for itrial = 1:nfiles
        % next line assumes trials start at 1 and we aren't missing any trial files
        trialfilename = ['sub-',sub, '_ses-',ses, '_task-',task, '_run-',runstring, '_trial-',num2str(itrial), '.mat']; 
        load(trialfilename)
        trials = [trials; struct2table(tData,'AsArray',true)];
    end
    
    % save as mat with multi element variables in table
    save([table_savename,'.mat'], 'trials')
    
    
    % remove multi element variables and save as .tsv
    trials_no_nested = removevars(trials,{'timingTrial','s'});
    writetable(trials_no_nested, [table_savename, '.tsv'],"FileType","text",'Delimiter','tab')
end



