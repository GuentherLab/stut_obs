 %%% AM script for reformatting behavior scoring trialtables so that Jason can run them in fmri analyis pipeline

% also make run table with summary stats

%$$$ condition key: 
% 1 = Observed_fluent
% 2 = Observed_dysfluent
% 3 = Observed_Baseline 
% 4 = Unobserved_fluent
% 5 = Unobserved_dysfluent
% 6 = Unobserved_Baseline
% 7 = Exclude


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

runs = table(runrange','VariableNames',{'run'}); 
for run = runrange
    runstring = sprintf(['%0',num2str(num_run_digits),'d'], run); % add zero padding
    filestring = sprintf('sub-%s_ses-%d_task-%s_run-%s_',sub, ses, task, runstring); % string to be used in multiple file names

    full_trialtable_filename = [dirs.task, filesep, filestring, 'trials.tsv']; % trial info; baseline+speech
    trials = readtable(full_trialtable_filename, 'FileType','text', 'Delimiter','tab');
    ntrials = height(trials);

    % trial with behavioral scoring info; may be missing baseline trials
    trialtable_beh_scoring_filename = [dirs.annot_sub, filesep, filestring, 'beh_scoring.tsv']; 
    trials_beh_scoring = readtable(trialtable_beh_scoring_filename, 'FileType','text'); 
    trials.condition_idx = nan(ntrials,1); 
    
    for itrial = 1:ntrials
        this_trialnum = trials.trialnum(itrial);

        % add behavioral scoring info
        beh_match = trials_beh_scoring.trialnum == this_trialnum; % find appropriate row
        if ~nnz(beh_match) == 0 % if there's a matching scored trial
            trials.stuttered(itrial) = trials_beh_scoring.stuttered(beh_match); % copy from scoring table
            trials.ambiguous(itrial) = trials_beh_scoring.ambiguous(beh_match); % copy from scoring table
            trials.unusable_trial(itrial) = trials_beh_scoring.unusable_trial(beh_match); % copy from scoring table
            trials.scoring_notes{itrial} = trials_beh_scoring.notes{beh_match}; % copy from scoring table
        end

        % for condition (observed vs unobserved), assume it's the same as the first trial in the run
        trials.observed(itrial) = trials_beh_scoring.observed_condition(1); 

        
        %%%%% add numerical codes to be used in fmri analysis
        
        % 1 = Observed_fluent
        if ~trials.unusable_trial(itrial)
            if trials.observed(itrial)
                if ~isempty(trials.question{itrial}) % if speech trial
                    if ~trials.stuttered(itrial)
                        trials.condition_idx(itrial) = 1; 

        % 2 = Observed_dysfluent
                    elseif trials.stuttered(itrial)
                        trials.condition_idx(itrial) = 2; 
                    end

        % 3 = Observed_Baseline 
                elseif isempty(trials.question{itrial}) % empty question indicates baseline trial
                    trials.condition_idx(itrial) = 3; 
            end

        % 4 = Unobserved_fluent
            elseif ~trials.observed(itrial)
                if ~isempty(trials.question{itrial}) % if speech trial
                    if ~trials.stuttered(itrial)
                        trials.condition_idx(itrial) = 4; 

        % 5 = Unobserved_dysfluent
                    elseif trials.stuttered(itrial)
                        trials.condition_idx(itrial) = 5; 
                    end

        % 6 = Unobserved_Baseline
                elseif isempty(trials.question{itrial}) % empty question indicates baseline trial
                    trials.condition_idx(itrial) = 6; 
                end
            end

        % 7 = Exclude
        elseif trials.unusable_trial(itrial)
            trials.condition_idx(itrial) = 7; 
        end

        if isnan(trials.condition_idx(itrial))
            error(['Failed to assign condition index to trial ', num2str(this_trialnum), ' , run ' runstring])
        end
    end

    trials.trial_idx_analysis = trials.trialnum - 1; % trial number used in Jason's fmri analysis; this is trialnum minus 1
    trials = movevars(trials,...
        {'trial_idx_analysis','condition_idx','trialnum','question','answer','n_syls','observed','unusable_trial','stuttered','ambiguous'},...
        'Before',1);
    table_savepath = [dirs.annot_sub, filesep, filestring, 'fmri_analysis_conditions.tsv']; 
    writetable(trials, [table_savepath],"FileType","text",'Delimiter','tab')


    runs.observed(run) = trials_beh_scoring.observed_condition(1);
    trials_usable = trials(~trials.unusable_trial,:); 
    trials_speech = trials_usable(~isnan(trials_usable.timePostOnset),:);
    runs.stut_prop(run) = mean(trials_speech.stuttered);
    runs.trials{run} = trials; 

end