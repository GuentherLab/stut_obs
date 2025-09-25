%%%%% compile stutobs trial data files into a table
% in the future, we should make this table auotamatically from the flvoice_run script
% must start in dir with trialdata files

clear

sub = 'STUTObsPilot003';
ses = 1;
task = 'jackson20';
runrange = [1:4] ;

num_run_digits = 2; 
[dirs, host] = set_paths_stut_obs();
dirs.annot_sub = [dirs.annot, filesep, 'sub-',sub]; 
dirs.sub = [dirs.data, filesep, 'sub-',sub];
dirs.ses = [dirs.sub, filesep, 'ses-',num2str(ses)]; 
dirs.task = [dirs.ses, filesep, 'beh', filesep,task]; 

for run = runrange
    runstring = sprintf(['%0',num2str(num_run_digits),'d'], run); % add zero padding
    dirs.run = [dirs.task, filesep, 'run-',runstring]; 
    filestring = sprintf('sub-%s_ses-%d_task-%s_run-%s_',sub, ses, task, runstring); % string to be used in multiple file names
    table_savepath = [dirs.task, filesep, filestring, 'trials.tsv'];

    d = dir(dirs.run); allfiles = {d(~[d.isdir]).name}; clear d % get filenames in working dir
    trialfiles = allfiles(~cellfun(@isempty, regexp(allfiles, 'trial-\d+\.mat$')));
    nfiles = length(trialfiles); 
    
    % get info from qa-list
    unique_answers_file  = fullfile(dirs.task,[filestring, 'qa-list.tsv']);
    unique_qa = readtable(unique_answers_file,'FileType','text');

    trials = table; 
    
    for itrial = 1:nfiles
        % next line assumes trials start at 1 and we aren't missing any trial files
        trialfilename = [dirs.run, filesep, filestring, 'trial-',num2str(itrial), '.mat']; 
        load(trialfilename)
        trials = [trials; struct2table(tData,'AsArray',true)];


    end
    trials.trialnum = [1:nfiles]';
    
            % add info from qa-list
    for itrial = 1:nfiles
            trialq = trials.question{itrial};
            if ~isempty(trialq) % if not baseline trial
                qa_table_match = trialq == string(unique_qa.question);
                trials.answer{itrial} = unique_qa.answer{qa_table_match}; 
                trials.n_syls(itrial) = unique_qa.n_syls(qa_table_match); 
                
            end
          
    end
    
        % % % % save as mat with multi element variables in table
        % % % save([table_savename,'.mat'], 'trials')
        
        
        % remove multi element and other variables and save as .tsv
        trials_no_nested = removevars(trials,{'timingTrial','s', 'fs'});
        trials_no_nested = movevars(trials_no_nested,{'trialnum','question','answer','n_syls'},'Before',1);
        writetable(trials_no_nested, [table_savepath],"FileType","text",'Delimiter','tab')
end



