function setup_subj_SEQS(subjID, group_learned, group_prepost, num_train_runs)

% Write experiment desc text files for SEQ fMRI experiment Sub-syllabic branch.
% By Haochen W. @ Guenther Lab, Jul 4 2023
%
% INPUTs:
%   subjID (e.g., 'SEQS201')
%   group_learned: 'a' or 'b' or 'c' or 'd'
%   group_prepost: 'a' or 'b' or 'c' or 'd'
%       * The rest two groups that are not group_learned or group_prepost
%       * will be used as novel stimuli in fMRI sessions
%   num_train_runs: number of training runs divided by 2 sessions. 
%       *For example, [5, 1] denotes 5 training sessions on day 1 and 1 on day 2.
%
% OUTPUTs:
%   desc-stimulus.txt files
%   desc-conditions.txt files (only if applicable)
%
% Example:
%   setup_subj_SEQS('SEQS902', 'b', 'd', [5 1])


projpath = 'C:\\Users\\splab\\Documents\\SEQ_SUB';
subjPath = fullfile(projpath, sprintf('sub-%s', subjID));
if isfolder(subjPath)
    error('Subject folder sub-%s already exists.', subjID);
end

%% Error-proof subject groups
if strcmp(group_learned, group_prepost)
    error('group_learned should be different from group_prepost.');
end

%% Assign stimuli list and prepare indices
stimuli = load(fullfile('.', 'stimuli', 'SEQS_master.mat'));

switch group_learned
    case {'a', 'b', 'c', 'd'}
        FLwords = eval(sprintf('stimuli.FL%s', upper(group_learned)));
        fLCwords = eval(sprintf('stimuli.LC%s_l', upper(group_learned)));
        bLCwords = eval(sprintf('stimuli.PP%s', upper(group_learned)));
    otherwise
        error('Unrecognized group_learned %s', group_learned);
end

switch group_prepost
    case {'a', 'b', 'c', 'd'}
        fNgroups = setdiff({'a', 'b', 'c', 'd'}, {group_learned, group_prepost});
        fNwords = [eval(sprintf('stimuli.FL%s', upper(fNgroups{1}))) ...
                   eval(sprintf('stimuli.FL%s', upper(fNgroups{2}))) ...
                   eval(sprintf('stimuli.LC%s_s', upper(fNgroups{1}))) ...
                   eval(sprintf('stimuli.LC%s_s', upper(fNgroups{2})))];
        bNwords = eval(sprintf('stimuli.LC%s_l', upper(group_prepost)));
    otherwise
        error('Unrecognized group_learned %s', group_prepost);
end

Pracwords = stimuli.practice;

%% practice
taskpath = fullfile(projpath, sprintf('sub-%s', subjID),sprintf('ses-%d', 1),'beh','practice');
if ~isfolder(taskpath); mkdir(taskpath); end
spath = fullfile(taskpath, sprintf('sub-%s_ses-1_run-1_task-practice_desc-stimulus.txt',subjID));

order = 1:numel(Pracwords); %randperm(numel(Pracwords));

sID = fopen(spath, 'w');

for ridx = 1:numel(Pracwords)
    fprintf(sID, '%s\n', Pracwords{order(ridx)});
end
fclose(sID);

%% prepost
data = load(fullfile('.','design_matrix','SEQ_SUB_beh_prepost.mat')); seqPrepost = data.design;
for i = 1:2
    taskpath = fullfile(projpath, sprintf('sub-%s', subjID),sprintf('ses-%d', i),'beh','prepost');
    if ~isfolder(taskpath); mkdir(taskpath); end
    cpath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-1_task-prepost_desc-conditions.txt',subjID,i));
    spath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-1_task-prepost_desc-stimulus.txt',subjID,i));

    seq = seqPrepost(i, :);
    orderFL = [];
    for j = 1:4
        this_order = randperm(numel(FLwords));
        while j ~= 1 && order(end) == this_order(1)
            this_order = randperm(numel(FLwords));
        end
        orderFL = [orderFL this_order];
    end
    [orderLC, orderN] = deal(randperm(numel(bLCwords)),randperm(numel(bNwords)));

    cID = fopen(cpath, 'w');
    sID = fopen(spath, 'w');
    
    id1 = 1;id2 = 1;id3 = 1;
    for ridx = 1:size(seqPrepost, 2)
        switch seq(ridx)
            case 1
                fprintf(cID, 'FL\n');
                fprintf(sID, '%s\n', FLwords{orderFL(id1)});
                id1 = id1+1;
            case 2
                fprintf(cID, 'LC\n');
                fprintf(sID, '%s\n', bLCwords{orderLC(id2)});
                id2 = id2+1;
            case 3
                fprintf(cID, 'N\n');
                fprintf(sID, '%s\n', bNwords{orderN(id3)});
                id3 = id3+1;
        end
    end
    fclose(sID);
    fclose(cID);
end

%% train
for i = 1:sum(num_train_runs)
    if i > num_train_runs(1); sesID = 2; else; sesID = 1; end
    taskpath = fullfile(projpath, sprintf('sub-%s', subjID),sprintf('ses-%d', sesID),'beh','train');
    if ~isfolder(taskpath); mkdir(taskpath); end
    spath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-%d_task-train_desc-stimulus.txt', subjID, sesID, i));

    order = [];
    for j = 1:10
        this_order = randperm(numel(FLwords));
        while j ~= 1 && order(end) == this_order(1)
            this_order = randperm(numel(FLwords));
        end
        order = [order this_order];
    end
    
    sID = fopen(spath, 'w');
   
    for ridx = 1:10*numel(FLwords)
        fprintf(sID, '%s\n', FLwords{order(ridx)});
    end
    fclose(sID);
end

%% test
sesID = 2;
taskpath = fullfile(projpath, sprintf('sub-%s', subjID),sprintf('ses-%d', sesID),'beh','test');
if ~isfolder(taskpath); mkdir(taskpath); end
logpath = fullfile(taskpath, sprintf('sub-%s_ses-%d_task-test_desc-writing-logs_%s.txt',subjID, sesID,string(datetime(now,'ConvertFrom','datenum')).replace({' ', ':'},'-')));
logPointer = fopen(logpath, 'w');
fprintf(logPointer, 'group_learned: %s, group_prepost: %s', group_learned, group_prepost);
data = load(fullfile('.','design_matrix','SEQ_SUB_fMRI_test.mat')); seqTest = data.design;

for i = 1:size(seqTest, 1)
    cpath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-%d_task-test_desc-conditions.txt',subjID, sesID,i));
    spath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-%d_task-test_desc-stimulus.txt',subjID, sesID,i));

    seq = seqTest(i, :);
    
    orderFL = [];
    for j = 1:4
        this_order = randperm(numel(FLwords));
        while j ~= 1 && order(end) == this_order(1)
            this_order = randperm(numel(FLwords));
        end
        orderFL = [orderFL this_order];
    end
    [orderLC, orderN] = deal(randperm(numel(fLCwords)),randperm(numel(fNwords)));
    
    cID = fopen(cpath, 'w');
    sID = fopen(spath, 'w');
    
    id1 = 1; id2 = 1; id3 = 1;
    for ridx = 1:size(seqTest, 2)
        switch seq(ridx)
            case 1 % FL
                fprintf(cID, 'FL\n');
                fprintf(sID, '%s\n', FLwords{orderFL(id1)});
                id1 = id1+1;
            case 2 % LC
                fprintf(cID, 'LC\n');
                fprintf(sID, '%s\n', fLCwords{orderLC(id2)});
                id2 = id2+1;
            case 3 % N
                fprintf(cID, 'N\n');
                fprintf(sID, '%s\n', fNwords{orderN(id3)});
                id3 = id3+1;
            case 4 % rest
                fprintf(cID, 'NULL\n');
                fprintf(sID, 'NULL\n');
        end
    end
    fclose(sID);
    fclose(cID);
end

end