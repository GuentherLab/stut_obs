function setup_subj_SIT(subjID, runID, conditions, order)

projpath = 'SIT-Pilot';
subjPath = fullfile(projpath, sprintf('sub-SITpilot0%s', subjID));
% if isfolder(subjPath)
%     error('Subject folder sub-%s already exists.', subjID);
% end

%% Assign stimuli list and prepare indices
stimuli = load(fullfile('.', 'stimuli', 'SIT_master.mat'));


taskpath = fullfile(projpath, sprintf('sub-SITpilot0%s', subjID),sprintf('ses-%d', 1),'test');
if ~isfolder(taskpath); mkdir(taskpath); end
spath = fullfile(taskpath, sprintf('sub-SITpilot0%s_ses-1_run-%s_task-test_desc-stimulus.txt',subjID,runID));
cpath = fullfile(taskpath, sprintf('sub-SITpilot0%s_ses-1_run-%s_task-test_desc-conditions.txt',subjID,runID));

% order = make_random_sit(8,0,2,[6,6,6,6,6,6,6,6],1)

sID = fopen(spath, 'w');
cID = fopen(cpath, 'w');

shuffled_stimuli = struct();

for i = 1:numel(conditions)
    field = conditions{i};
    stim_list = stimuli.(field);  % Assuming this is a cell array
    shuffled_stimuli.(field) = stim_list(randperm(numel(stim_list)));
end

for ridx = 1:12
    fieldname = conditions{order(ridx)};
    
    % Pop the first unused item
    stim_list = shuffled_stimuli.(fieldname);
    if isempty(stim_list),
        error('No more items left in stimuli.%s', fieldname);
    end
    
    random_item = stim_list{1};
    shuffled_stimuli.(fieldname)(1) = [];
    
    % Write to files
    fprintf(sID, '%s\n', random_item);
    fprintf(cID, '%s\n', fieldname);
end

fclose(sID);
fclose(cID);

end