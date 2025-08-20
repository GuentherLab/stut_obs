varnames = {'SSS','SSC','SCS','SCC','CSS','CSC','CCS','CCC'};
num_strings = 6;

for i = 1:length(varnames)
    fin_str = string(varnames{i}) + '/';
    % prefix = [fin_str '/'];
    strings = cell(1, num_strings);
    stim_str = string(varnames{i});

    for j = 1:num_strings
        final_str = fin_str + stim_str + '0' + string(j);
        strings{j} = [char(final_str)];
    end

    assignin('base', varnames{i}, strings);
end

save('stimuli/SIT_master.mat', 'SSS','SSC','SCS','SCC','CSS','CSC','CCS','CCC');
