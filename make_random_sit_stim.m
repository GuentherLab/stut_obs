function [seqs stim_order] = make_random_sit_stimuli(nType, lastRest, maxRep, nTrial, nSeq)
% make_random_seq generates random sequences of trial types with constraints.
%
% Inputs:
%   nType    - Number of trial types, including rest (e.g., 2 if speech + rest)
%   lastRest - Boolean (true/false): If true, the last trial type is rest (nonspeech)
%   maxRep   - Maximum allowed consecutive repetitions of the same (non-rest) trial type
%   nTrial   - Vector specifying the number of trials for each type (e.g., [10, 15])
%   nSeq     - Number of random sequences to generate
%
% Output:
%   seqs     - nSeq x sum(nTrial) matrix, each row is a random sequence
%  stim_order - nSeq x sum(nTrial) matrix of stimulus IDs (1-6 for active conditions, 0 for rest)
%
% Sequence Acceptability Criteria:
%   1. No sequence contains more than 'maxRep' consecutive repetitions of the same trial type.
%      - For example, if maxRep = 2, then no three or more identical trials appear in a row.
%   2. If 'lastRest' is true, rest trials (coded as the last type) are inserted between non-rest trials,
%      never consecutively, and never at the start or end unless required by nTrial.
%   3. The total number of each trial type in the sequence matches the numbers specified in nTrial.
%   4. All sequences are randomly ordered, subject to the above constraints.
%
% The function attempts random shuffles until all criteria are satisfied for each sequence.
%
% example: 
%   s = make_random_sit(8,0,2,[6,6,6,6,6,6,6,6],100)
%   Generates 100 run vectors of 8 conditions repeated 6 times (48 trials 
%    with no non-speech condition in pseudorandom order with no more than 
%    2 consecutive trials of the same condition
%   
%


    seqs = zeros(nSeq, sum(nTrial)); % Preallocate output matrix for all sequences

    for i = 1:nSeq % Loop over number of sequences to generate
        meetCri = false; % Flag to check if sequence meets repetition criteria
        merge = zeros(1, sum(nTrial)); % Preallocate temporary sequence
        if lastRest
            % If the last trial type is 'rest', handle insertion of rest trials specially
            while ~meetCri
                disp('try') % For debugging: show each attempt
                this_seq = [];
                % Build a vector of all non-rest trials (types 1 to nType-1)
                for ty = 1:nType-1
                    this_seq = [this_seq repelem(ty, 1, nTrial(ty))];
                end
                % Randomly shuffle non-rest trials
                order = rand(1, sum(nTrial(1:end-1)));
                [~, I] = sort(order);
                this_seq = this_seq(I);

                % Randomly select insertion points for rest trials
                gaps = 1:sum(nTrial(1:end-1))-1; % Possible insertion points between trials
                order = rand(1, sum(nTrial(1:end-1))-1);
                [~, I] = sort(order);
                gaps = gaps(I);
                [gaps, I] = sort(gaps(1:nTrial(end))); % Select nTrial(end) unique gaps for rests
                gaps = [gaps nan]; % Add nan as sentinel for last gap

                % Merge trials and insert rest at selected gaps
                next_gap = gaps(1) + 1; % Next position to insert rest
                tidx = 1; % Index for non-rest trials
                gidx = 2; % Index for gaps
                for midx = 1:sum(nTrial)
                    if midx ~= next_gap
                        merge(midx) = this_seq(tidx); % Place non-rest trial
                        tidx = tidx + 1;
                    else
                        merge(midx) = nType; % Insert rest trial (coded as nType)
                        next_gap = gaps(gidx) + gidx; % Update next gap position
                        gidx = gidx + 1;
                    end
                end

                % Check if the sequence meets the maxRep constraint
                % (find runs of same trial, ensure none exceeds maxRep)
                meetCri = max(diff(find([true, diff(merge)~=0, true]))) < maxRep + 1;
            end
        else
            % If there is no special rest trial handling
            while ~meetCri
                disp('try') % For debugging: show each attempt
                this_seq = [];
                % Build vector of all trials for all types
                for ty = 1:nType
                    this_seq = [this_seq repelem(ty, 1, nTrial(ty))];
                end
                % Randomly shuffle all trials
                order = rand(1, sum(nTrial));
                [~, I] = sort(order);
                merge = this_seq(I);

                % Check maxRep constraint for all trial types
                meetCri = max(diff(find([true, diff(merge)~=0, true]))) < maxRep + 1;
            end
        end
        seqs(i, :) = merge; % Store the valid sequence
        % Generate stimulus IDs for this sequence
        stim_order_seq = zeros(1, sum(nTrial));
        unique_conditions = unique(merge);
        
        for cond = unique_conditions
            if cond == nType && lastRest
                % Assign 0 to rest trials
                stim_order_seq(merge == cond) = 0;
            else
                % Get trials for current condition
                cond_trials = sum(merge == cond);
                
                % Create pseudorandom stimulus sequence
                n_blocks = ceil(cond_trials/6);
                stim_ids = repmat(1:6, 1, n_blocks);
                stim_ids = stim_ids(randperm(length(stim_ids)));
                
                % Assign first 'cond_trials' IDs to current condition
                stim_order_seq(merge == cond) = stim_ids(1:cond_trials);
            end
        end
        
        stim_order(i,:) = stim_order_seq;
    end
end
