function seqs = make_random_seq(nType, lastRest, maxRep, nTrial, nSeq)
% Inputs ==================================================================================================
% nType: number of trial types, including rest (nonspeech), if exists, e.g., 2
% lastRest: boolean, whether the last trial type is rest (nonspeech)
% maxRep: maximum number of repetitions allowed (will not apply to rest which doesn't allow any repetition)
% nTrial: vector of trial numbers for each trial type, e.g., [10, 15]
% nSeq: number of sequences you want to generate
% =========================================================================================================

    seqs = zeros(nSeq, sum(nTrial));

    for i = 1:nSeq
        meetCri = false;
        merge = zeros(1, sum(nTrial));
        if lastRest
            while ~meetCri
                disp('try')
                this_seq = [];
                for ty = 1:nType-1
                    this_seq = [this_seq repelem(ty, 1, nTrial(ty))];
                end
                order = rand(1, sum(nTrial(1:end-1)));
                [R, I] = sort(order);
                this_seq = this_seq(I);
                
                gaps = 1:sum(nTrial(1:end-1))-1;
                order = rand(1, sum(nTrial(1:end-1))-1);
                [R, I] = sort(order);
                gaps = gaps(I);
                [gaps, I] = sort(gaps(1:nTrial(end)));
                gaps = [gaps nan];
    
                next_gap = gaps(1) + 1;
                tidx = 1;
                gidx = 2;
                for midx = 1:sum(nTrial)
                    if midx ~= next_gap; merge(midx) = this_seq(tidx);tidx=tidx+1;
                    else; merge(midx) = nType; next_gap = gaps(gidx) + gidx; gidx=gidx+1;
                    end
                end
    
                meetCri = max(diff(find([true, diff(merge)~=0, true]))) < maxRep + 1;
            end
        else
            while ~meetCri
                disp('try')
                this_seq = [];
                for ty = 1:nType
                    this_seq = [this_seq repelem(ty, 1, nTrial(ty))];
                end
                order = rand(1, sum(nTrial));
                [R, I] = sort(order);
                merge = this_seq(I);

                meetCri = max(diff(find([true, diff(merge)~=0, true]))) < maxRep + 1;
            end
        end
        seqs(i, :) = merge;
    end
end
