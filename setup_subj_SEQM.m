function setup_subj_SEQM(subjID, pattern_learned, pattern_novel, num_train_runs)

% Write experiment desc text files for SEQ fMRI experiment Multisyllabic branch.
% By Haochen W. @ Guenther Lab, Jul 4 2023
%
% INPUTs:
%   subjID (e.g., 'SEQM101')
%   pattern_learned: 'a' or 'b' or 'c' or 'd'
%   pattern_novel: 'a' or 'b' or 'c' or 'd'
%       *The pairs of 'a/b' and 'c/d' refer to the same stimulus list but repeat 
%       *different 6-syllable words different times (2 or 3 times, counterbalanced).
%   num_train_runs: number of training runs divided by 2 sessions. 
%       *For example, [3, 2] denotes 3 training sessions on day 1 and 2 on day 2.
%
% OUTPUTs:
%   desc-stimulus.txt files
%   desc-conditions.txt files (only if applicable)
%
% Example:
%   setup_subj_SEQM('SEQM902', 'b', 'd', [4 1])


projpath = 'C:\\Users\\splab\\Documents\\SEQ_Multi';
subjPath = fullfile(projpath, sprintf('sub-%s', subjID));
if isfolder(subjPath)
    error('Subject folder sub-%s already exists.', subjID);
end


%% Error-proof subject groups
if find(strcmp({'a', 'b'}, pattern_learned)) ~= 0
    if find(strcmp({'a', 'b'}, pattern_novel)) ~= 0
        error('pattern_novel should be "c" or "d".');
    end
elseif find(strcmp({'c', 'd'}, pattern_learned)) ~= 0
    if find(strcmp({'c', 'd'}, pattern_novel)) ~= 0
        error('pattern_novel should be "a" or "b".');
    end
end

%% Assign stimuli list and prepare indices
stimuli = load(fullfile('.', 'stimuli', 'SEQM_master.mat'));

indices = 1:30;
switch pattern_learned
    case 'a'
        lidx = indices(mod(indices,6)>=1 & mod(indices,6)<=3);
        Lwords = stimuli.testAB;
        Trainwords = stimuli.trainAB;
    case 'b'
        lidx = indices(mod(indices,6)>=1 & mod(indices,6)<=3) + 15;
        lidx(lidx>30) = lidx(lidx>30)-30;
        Lwords = stimuli.testAB;
        Trainwords = stimuli.trainAB;
    case 'c'
        lidx = indices(mod(indices,6)>=1 & mod(indices,6)<=3);
        Lwords = stimuli.testCD;
        Trainwords = stimuli.trainCD;
    case 'd'
        lidx = indices(mod(indices,6)>=1 & mod(indices,6)<=3) + 15;
        lidx(lidx>30) = lidx(lidx>30)-30;
        Lwords = stimuli.testCD;
        Trainwords = stimuli.trainCD;
    otherwise
        error('Unrecognized pattern_learned %s', pattern_learned);
end

switch pattern_novel
    case 'a'
        nidx = indices(mod(indices,6)>=1 & mod(indices,6)<=3);
        Nwords = stimuli.testAB;
    case 'b'
        nidx = indices(mod(indices,6)>=1 & mod(indices,6)<=3) + 15;
        nidx(nidx>30) = nidx(nidx>30)-30;
        Nwords = stimuli.testAB;
    case 'c'
        nidx = indices(mod(indices,6)>=1 & mod(indices,6)<=3);
        Nwords = stimuli.testCD;
    case 'd'
        nidx = indices(mod(indices,6)>=1 & mod(indices,6)<=3) + 15;
        nidx(nidx>30) = nidx(nidx>30)-30;
        Nwords = stimuli.testCD;
    otherwise
        error('Unrecognized pattern_novel %s', pattern_novel);
end

Pracwords = stimuli.prac;
PPNwords = stimuli.ppN;

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
data = load(fullfile('.','design_matrix','SEQ_Multi_beh_prepost.mat')); seqPrepost = data.design;
for i = 1:2
    taskpath = fullfile(projpath, sprintf('sub-%s', subjID),sprintf('ses-%d', i),'beh','prepost');
    if ~isfolder(taskpath); mkdir(taskpath); end
    cpath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-1_task-prepost_desc-conditions.txt',subjID,i));
    spath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-1_task-prepost_desc-stimulus.txt',subjID,i));

    seq = seqPrepost(i, :);
    [order1, order2] = deal(randperm(30),randperm(30));

    cID = fopen(cpath, 'w');
    sID = fopen(spath, 'w');
    
    id1 = 1;id2 = 1;
    for ridx = 1:size(seqPrepost, 2)
        switch seq(ridx)
            case 1
                fprintf(cID, 'T\n');
                fprintf(sID, '%s\n', Lwords{order1(id1)});
                id1 = id1+1;
            case 2
                fprintf(cID, 'N\n');
                fprintf(sID, '%s\n', PPNwords{order2(id2)});
                id2 = id2+1;
        end
    end
    fclose(sID);
    fclose(cID);
end

%% train
for i = 1:sum(num_train_runs)
    if i > num_train_runs(1); sesID = 2; else; sesID = 1; end
    taskpath = fullfile(projpath, sprintf('sub-%s', subjID),sprintf('ses-%d', sesID),'beh','training');
    if ~isfolder(taskpath); mkdir(taskpath); end
    spath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-%d_task-training_desc-stimulus.txt', subjID, sesID, i));

    order = [];
    for j = 1:10
        this_order = randperm(numel(Trainwords));
        while j ~= 1 && order(end) == this_order(1)
            this_order = randperm(numel(Trainwords));
        end
        order = [order this_order];
    end
    
    sID = fopen(spath, 'w');
   
    for ridx = 1:60
        fprintf(sID, '%s\n', Trainwords{order(ridx)});
    end
    fclose(sID);
end

%% test
sesID = 2;
taskpath = fullfile(projpath, sprintf('sub-%s', subjID),sprintf('ses-%d', sesID),'beh','test');
if ~isfolder(taskpath); mkdir(taskpath); end
logpath = fullfile(taskpath, sprintf('sub-%s_ses-%d_task-test_desc-writing-logs_%s.txt',subjID, sesID,string(datetime(now,'ConvertFrom','datenum')).replace({' ', ':'},'-')));
logPointer = fopen(logpath, 'w');
fprintf(logPointer, 'pattern_learned: %s, pattern_novel: %s', pattern_learned, pattern_novel);
data = load(fullfile('.','design_matrix','SEQ_Multi_fMRI_test.mat')); seqTest = data.design;

for i = 1:size(seqTest, 1)
    cpath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-%d_task-test_desc-conditions.txt',subjID, sesID,i));
    spath = fullfile(taskpath, sprintf('sub-%s_ses-%d_run-%d_task-test_desc-stimulus.txt',subjID, sesID,i));

    seq = seqTest(i, :);

    lidx = lidx(randperm(length(lidx)));
    nidx = nidx(randperm(length(nidx)));
    
    cID = fopen(cpath, 'w');
    sID = fopen(spath, 'w');
    
    idl = 1; idn = 1;
    for ridx = 1:size(seqTest, 2)
        switch seq(ridx)
            case 1 % trained
                fprintf(cID, 'L\n');
                fprintf(sID, '%s\n', Lwords{lidx(idl)});
                idl = idl+1;
            case 2 % novel
                fprintf(cID, 'N\n');
                fprintf(sID, '%s\n', Nwords{nidx(idn)});
                idn = idn+1;
            case 3 % rest
                fprintf(cID, 'NULL\n');
                fprintf(sID, 'NULL\n');
        end
    end
    fclose(sID);
    fclose(cID);
    
    lidx = lidx + 5;
    lidx(lidx>30) = lidx(lidx>30)-30;

    nidx = nidx + 5;
    nidx(nidx>30) = nidx(nidx>30)-30;

end

end