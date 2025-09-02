function [dirs, host] = set_paths_ieeg_stut()
% [paths, host] = set_paths_ieeg_stut()
%
% setting up directory paths for project
%

beep off

%
project = 'ieeg_stut'; % for data dirs, not software dir
pilotstring = [project filesep 'data' filesep 'pilot'];

%% Determine hostname of system
% This section looks for the 'local' hostname of the computer running the
% script (based on the computer's OS).

if ispc % If running on a Windows
    [~,host] = system('hostname');
    host     = deblank(host);
    
    % set priority for matlab to high for running experiments
    system(sprintf('wmic process where processid=%d call setpriority "high priority"',feature('getpid')));
    
elseif ismac % If running on a Mac
    [~,host] = system('scutil --get LocalHostName');
    host     = deblank(host);
    
elseif isunix % If running on Linux
    [~,host] = system('hostname -s');  % Needs to be tested on Linux machine
    host     = deblank(host);
end


%% Set appropriate directories for code, data input and output, based on system hostname.
if strncmpi('scc-x02', host, 3) % Using SCC
    
    % on SCC, keep code in 'project' and subbject data in 'projectnb'
    dirs.projrepo = ['/project/busplab/software/stut_obs'];
    dirs.data = ['/projectnb/busplab/Experiments/', project];
    dirs.pilot = fullfile('/projectnb/busplab/Experiments/', pilotstring);
    dirs.conn = '/project/busplab/software/conn'; 
    dirs.spm = '/project/busplab/software/spm12'; 

else % analyzing on a local machine
    switch host
            
        case {'MSI','677-GUE-WL-0010', 'amsmeier'} % Andrew Meier laptop
            pkgdir = 'C:\docs\code';
            dirs.projrepo = [pkgdir filesep 'stut_obs']; 
            dirs.spm = [pkgdir filesep 'spm12'];
            dirs.conn = [pkgdir filesep 'conn'];
            dirs.data = ['C:\ieeg_stut'];  % source data
           
        otherwise
            disp('Directory listings are not set up for this computer. Please check that your hostname is correct.');
            return
    end

end



%% paths common to all hosts
% ...... these don't all need to be added to the path; save for later reference

% stimuli
dirs.stim = [dirs.projrepo, filesep, 'stimuli'];
dirs.config = fullfile(dirs.projrepo, 'config');  % configuration files
dirs.derivatives = [dirs.data, filesep, 'der']; % derivatives of source data

%% add paths to folders and subfolders
paths_to_add = {dirs.projrepo;...
                % dirs.derivatives;...
                dirs.spm;...
                % paths.conn;...
                [dirs.projrepo filesep 'util'];...
                % [dirs.projrepo filesep 'analysis'];...
                [dirs.projrepo filesep 'experiment_scripts'];...
                };
genpaths_to_add = {  %%%% add these dirs and all recursive subdirs
                    };

genpaths_to_remove = {}; % remove these dirs and all recursive subdirs

genpaths_to_add = cellfun(@genpath,genpaths_to_add,'UniformOutput',false); 
genpaths_to_remove = cellfun(@genpath,genpaths_to_remove,'UniformOutput',false);

addpath(paths_to_add{:})
if ~isempty(genpaths_to_add)
    addpath(genpaths_to_add{:})
end
if ~isempty(genpaths_to_add)
    rmpath(genpaths_to_remove{:})
end
