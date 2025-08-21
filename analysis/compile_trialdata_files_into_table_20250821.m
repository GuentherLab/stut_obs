%%%%% compile stutobs trial data files into a table
% in the future, we should make this table auotamatically from the flvoice_run script
% must start in dir with trialdata files

sub = 'pilot012';
ses = '2';
run = '02';
task = 'jackson20';

table_savename = ['sub-',sub, '_ses-',ses, '_task-',task, '_run-',run, '_trials'];

d = dir; allfiles = {d(~[d.isdir]).name}; clear d % get filenames in working dir
trialfiles = allfiles(~cellfun(@isempty, regexp(allfiles, 'trial-\d+\.mat$')));
nfiles = length(trialfiles); 

trials = table; 

for itrial = 1:nfiles
    % next line assumes trials start at 1 and we aren't missing any trial files
    trialfilename = ['sub-',sub, '_ses-',ses, '_task-',task, '_run-',run, '_trial-',num2str(itrial), '.mat']; 
    load(trialfilename)
    trials = [trials; struct2table(tData,'AsArray',true)];
end

% save as mat with multi element variables in table
save([table_savename,'.mat'], 'trials')


% remove multi element variables and save as .tsv
trials_no_nested = removevars(trials,{'timingTrial','s'});
writetable(trials_no_nested, [table_savename, '.tsv'],"FileType","text",'Delimiter','tab')



