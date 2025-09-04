function flvoice_run_fmri(varargin)
close all;

% Resolve script directory for relative files (config, wavs, etc.)
SCRIPT_DIR = fileparts(mfilename('fullpath'));

% Default root per-OS (Windows path in your code breaks on macOS)
if ispc
    default_root = 'C:\ieeg_stut';
else
    default_root = fullfile(getenv('HOME'), 'ieeg_stut');
end


CMRR = true;

% set priority for matlab to high for running experiments
pid = feature('getpid');
if ispc
    system(sprintf('wmic process where processid=%d call setpriority "high priority"', pid));
else
    % Best effort on macOS/Linux; ignore if not permitted
    system(sprintf('renice -n -5 -p %d >/dev/null 2>&1', pid));
end

beepoffset = 0.100;
num_run_digits = 2; % number of digits to include in run number labels in filenames

% FLVOICE_RUN runs audio recording&scanning session
% [task]: 'jackson20'
% 
% AUDIO RECORDING&SCANNING SEQUENCE: (repeat for each trial)
%
% |                                                  |------ RECORDING -------------------------------------|          
% |  wait   |- PLAY SOUND STIMULUS ---|  wait   |      |                  |----SUBJECT SPEECH-----|           |--SCANNING-|    |-  STIMULUS (next trial) 
% |        ORTHOGRAPHIC STIMULUS (if any)       |      |  reaction time   |  production duration  |           |           |    |   stimulus time ...   
% |---D6----|                         |---D7----|--D1--|                  |-------------------D2--------------|----D4-----|-D5-|
% |                                             |      |------------------------------------(<=D3)------------|           |    |
% v                                             |      v                  |                                   v           |    v 
% stimulus starts                               v      GO signal          v                                   scanner     v    next stimulus starts 
%                                               stimulus ends             voice onset                         starts      scanner ends 
%
% AUDIO RECORDING SEQUENCE (without scanning): (repeat for each trial)
%
% |                                                  |------ RECORDING ----------------------------(<=D3)---|          
% |  wait   |- PLAY SOUND STIMULUS ---|  wait   |      |                  |----SUBJECT SPEECH-----|           |    |-  STIMULUS (next trial) 
% |        ORTHOGRAPHIC STIMULUS (if any)       |      |  reaction time   |  production duration  |           |    |   stimulus time ...   
% |---D6----|                         |---D7----|--D1--|                  |-------------------D2--------------|-D5-|
% |                                             |      |------------------------------------(<=D3)------------|    |
% v                                             |      v                  |                                        v 
% stimulus starts                               v      GO signal          v                                        next stimulus starts 
%                                               stimulus ends             voice onset              
%
%
% FLVOICE_RUN(option_name1, option_value1, ...)
% specifies additional options:% for audio stim shared across subjects
%       root                        : root directory [pwd]
%       audio_common_path            : % for audio stim shared across subjects
%       subject                     : subject ID ['TEST01']
%       session                     : session number [1]
%       run                         : run number [1]
%       task                        : task name ['jackson20']
%       scan                        : true/false include scanning segment in experiment sequence [1] 
%       timePostStim                : time (s) from end of the text stimulus presentation to the GO signal (D1 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [.25 .75] 
%       timePostOnset               : time (s) from subject's voice onset to the scanner trigger (or to pre-stimulus segment, if scan=false) (D2 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [4.5] 
%       timeMax                     : maximum time (s) before GO signal and scanner trigger (or to pre-stimulus segment, if scan=false) (D3 in schematic above) (recording portion in a trial may end before this if necessary to start scanner) [5.5] 
%       timeScan                    : (if scan=true) duration (s) of scan (D4 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [1.6] 
%       timePreStim                 : time (s) from end of scan to start of next trial stimulus presentation (D5 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [.25] 
%       timePreSound                : time (s) from start of orthographic presentation to the start of sound stimulus (D6 in schematic above) [.5]
%       timePostSound               : time (s) from end of sound stimulus to the end of orthographic presentation (D7 in schematic above) [.47]
%       minVoiceOnsetTime           : time (s) to exclude from onset detection (use when beep sound is recorded)
%       prescan                     : (if scan=true) true/false include prescan sequence at the beginning of experiment [1] 
%       rmsThresh                   : voice onset detection: initial voice-onset root-mean-square threshold [.02]
%       rmsBeepThresh               : voice onset detection: initial voice-onset root-mean-square threshold [.1]
%       rmsThreshTimeOnset          : voice onset detection: mininum time (s) for intentisy to be above RMSThresh to be consider voice-onset [0.1] 
%       rmsThreshTimeOffset         : voice offset detection: mininum time (s) for intentisy to be above and below RMSThresh to be consider voice-onset [0.25 0.25] 
%       ipatDur                     : prescan sequence: prescan IPAT duration (s) [4.75] 
%       smsDur                      : prescan sequence: prescan SMS duration (s) [7] 
%       deviceMic                   : device name for sound input (microphone) (see audiodevinfo().input.Name for details)
%       deviceHead                  : device name for sound output (headphones) (see audiodevinfo().output.Name for details) 
%       deviceScan                  : device name for scanner trigger (see audiodevinfo().output.Name for details)
%


% wait for 4.5 seconds and if they don't speak cut the trial short.
% current prestim is very very low. Increase it
% change expParams to be stored values.

ET = tic;
[dirs, host] = set_paths_stut_obs(); % set project paths and get computer name
% Use helper function outputs to prefill defaults shown in the GUI
default_root = dirs.data;
default_audio_common = fullfile(dirs.stim,'audio');   % <- uses dirs.stim (not projrepo)
default_config_dir = dirs.config;                     % used by the file picker

default_fontsize = 12;

% select json files
preFlag = false;
expRead = {};
presfig=dialog('units','norm','position',[.3,.3,.3,.1],'windowstyle','normal','name','Load preset parameters','color','w','resize','on');
uicontrol(presfig,'style','text','units','norm','position',[.05, .475, .6, .35],...
    'string','Select preset exp config file (.json):','backgroundcolor','w','fontsize',default_fontsize-2,'fontweight','bold','horizontalalignment','left');
prePath=uicontrol('Style', 'edit','Units','norm','FontUnits','norm','FontSize',0.5,'HorizontalAlignment', 'left','Position',[.55 .55 .3 .3],'Parent',presfig);
preBrowse=uicontrol('Style', 'pushbutton','String','Browse','Units','norm','FontUnits','norm','FontSize',0.5,'Position',[.85 .55 .15 .3],'Parent',presfig, 'Callback',@preCall1);
preConti=uicontrol('Style', 'pushbutton','String','Continue','Units','norm','FontUnits','norm','FontSize',0.5,'Position',[.3 .12 .15 .3],'Parent',presfig, 'Callback',@preCall2);
preSkip=uicontrol('Style', 'pushbutton','String','Skip','Units','norm','FontUnits','norm','FontSize',0.5,'Position',[.55 .12 .15 .3],'Parent',presfig, 'Callback','uiresume');

uiwait(presfig);
ok=ishandle(presfig);
if ~ok, return; end

% gets json files
function preCall1(~,~)
    [fileName, filePath] = uigetfile(fullfile(default_config_dir,'*.json'), 'Select .json file');
    if isequal(fileName,0), return; end
    set(prePath, 'String', fullfile(filePath, fileName));
end

% checks if file paths exist
function preCall2(varargin)
    cfgPath = get(prePath, 'String');
    assert(exist(cfgPath,'file')==2, 'unable to find input file %s', cfgPath);
    expRead = spm_jsonread(cfgPath);
    preFlag = true;
    uiresume;
end

delete(presfig);

% create structure to save experimental parameters
if preFlag
    expParams = expRead;
else % if no preset config file defined
    expParams=struct(...
        'root', 'C:\ieeg_stut', ...
        'audio_common_path', [dirs.projrep, filesep, 'stimuli', filesep, 'audio'], ... % for audio stim shared across subjects
        'subject','sub-example',...
        'session', 1, ...
        'run', 1,...
        'scan', true, ...
        'play_question_audio_stim',false,... % play (unobserved condition) or don't play (observed condition) the audio quesiton stim
        'repetitions_per_unique_qa', 1, ...
        'shuffle_qa_order', true, ... % specifically affects stim order, not baseline trials
        'max_unique_qa_repeats',2, ... % max consecutive repeats of a given QA stim, before baseline trials are mixed in
        'baseline_trials_proportion',0.5,... % proportion of all trials that are baseline trials
        'baseline_trials_evenly_spaced',true,.... % whether baseline trals are evenly spaced or shuffled
        'max_basetrial_repeats',2,... % don't let there be more than this many no-speech trials in row
        'cover_camera_when_nospeech',true, ... % cover the left side of screen w/ figure where camera is outside of speech epochs
        'show_question_orthography', false, ...
        'timeStim', [2 2.5],...
        'timePostOnset', 3.5,...
        'timePreStim', 0.5,...
        'timeMax', 6.5, ...
        'timeNoOnset', 3.0, ...
        'timeScan', 1.6, ...
        'rmsThresh', .02,... %'rmsThresh', .05,...
        'rmsBeepThresh', .1,...
        'rmsThreshTimeOnset', .02,...% 'rmsThreshTimeOnset', .10,...
        'rmsThreshTimeOffset', [.25 .25],...
        'prescan', true, ...
        'minVoiceOnsetTime', 0.4, ...
        'ipatDur', 5.00,...         %   prescan IPAT duration
        'smsDur', 7,...             %   prescan SMS duration
        'deviceMic','',...
        'deviceHead','', ...
        'deviceScan','', ...
        'rectWidthProp', 0.8, ...      % rectangle width as proportion of screen width
        'rectHeightProp', 0.6, ...     % rectangle height as proportion of screen height  
        'rectColor', [0 1 0], ...      % RGB color of rectangle [R G B] (0-1 scale)
        'task', 'jackson20' ...
        );
        % Fill in remaining directory defaults from dirs
        expParams.config    = dirs.config;
        expParams.stim      = dirs.stim;
        expParams.projrepo  = dirs.projrepo;
        expParams.deriv     = dirs.derivatives;
end

% --- Backfill any fields missing from older JSON presets (must be before GUI lists) ---
if ~isfield(expParams,'cover_camera_when_nospeech'), expParams.cover_camera_when_nospeech = true;  end
if ~isfield(expParams,'play_question_audio_stim'),   expParams.play_question_audio_stim   = false; end
if ~isfield(expParams,'show_question_orthography'),  expParams.show_question_orthography  = false; end

% visual sizing/colors in case JSON lacks them
if ~isfield(expParams,'rectWidthProp'),  expParams.rectWidthProp  = 0.8;    end
if ~isfield(expParams,'rectHeightProp'), expParams.rectHeightProp = 0.6;    end
if ~isfield(expParams,'rectColor'),      expParams.rectColor      = [0 1 0];end

% device fields (keep as empty strings if unknown)
if ~isfield(expParams,'deviceMic'),  expParams.deviceMic  = ''; end
if ~isfield(expParams,'deviceHead'), expParams.deviceHead = ''; end
if ~isfield(expParams,'deviceScan'), expParams.deviceScan = ''; end

% --- ensure monitorGain exists even when loaded from JSON ---
if ~isfield(expParams,'monitorGain') || ~isscalar(expParams.monitorGain) || ~isfinite(expParams.monitorGain)
    expParams.monitorGain = 0.8;   % default monitoring level (0..1)
end

% Normalize paths for macOS
if ismac
    % root
    if ~isfield(expParams,'root') || startsWith(expParams.root,'C:\') || contains(expParams.root,'\')
        expParams.root = default_root;                      % dirs.data
    end
    % audio_common_path
    if ~isfield(expParams,'audio_common_path') || startsWith(expParams.audio_common_path,'C:\') || contains(expParams.audio_common_path,'\')
        expParams.audio_common_path = default_audio_common; % fullfile(dirs.stim,'audio')
    end
end

expParams.computer = host;

for n=1:2:numel(varargin)-1, 
    assert(isfield(expParams,varargin{n}),'unrecognized option %s',varargin{n});
    expParams.(varargin{n})=varargin{n+1};
end

try, a=audioDeviceReader('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strINPUT=[str{:}]; end;
try, a=audioDeviceWriter('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strOUTPUT=[str{:}]; end;

S = audiodevinfo;  % built-in: returns struct with .input/.output arrays
if ~exist('strINPUT','var') || isempty(strINPUT)
    strINPUT  = {S.input.Name};   % cellstr of input device names
end
if ~exist('strOUTPUT','var') || isempty(strOUTPUT)
    strOUTPUT = {S.output.Name};  % cellstr of output device names
end

% If still empty, bail with a clear message
if isempty(strINPUT)
    error('No audio input devices found. Plug in a mic or check System Settings > Sound > Input.');
end
if isempty(strOUTPUT)
    error('No audio output devices found. Connect headphones/speakers or check System Settings > Sound > Output.');
end

%%%%% set audio input, stim output, and trigger devices
% get focusrite device input number
ipind = find(contains(strINPUT, 'Analogue')&contains(strINPUT, 'Focusrite'));
% get focusrite device output number
opind = find(contains(strOUTPUT, 'Speakers')&contains(strOUTPUT, 'Focusrite'));

 % if focusrite not found, use computer-specific audio in/out
if isempty(ipind)
    switch host
        case {'677-GUE-WL-0010','amsmeier'} % AM work/personal laptop
            ipind = find(contains(strINPUT, 'Default'));
            opind = find(contains(strOUTPUT, 'Default'));
    end
end

% get trigger device number
tgind = find(contains(strOUTPUT, 'Playback')&contains(strOUTPUT, 'Focusrite'));

% GUI for user to modify options
fnames=fieldnames(expParams);
fnames = fnames(~ismember(fnames,{ ...
    'root','subject','session','run','task', ...
    'repetitions_per_unique_qa','shuffle_qa_order','max_unique_qa_repeats', ...
    'baseline_trials_proportion','baseline_trials_evenly_spaced','max_basetrial_repeats', ...
    'cover_camera_when_nospeech','play_question_audio_stim','show_question_orthography', ...
    'timeStim','timePostOnset','timePreStim','timeMax','timeNoOnset','timeScan', ...
    'scan','deviceMic','deviceHead','deviceScan'}));
for n=1:numel(fnames)
    val = expParams.(fnames{n});
    if ischar(val), fvals{n}=val;
    elseif isempty(val), fvals{n}='';
    else fvals{n}=mat2str(val);
    end
end

out_dropbox = {'root','subject','session','run','task', ...
    'play_question_audio_stim', ...                  
    'repetitions_per_unique_qa','shuffle_qa_order','max_unique_qa_repeats', ...
    'baseline_trials_proportion','baseline_trials_evenly_spaced','max_basetrial_repeats', ...
    'cover_camera_when_nospeech','show_question_orthography', ...  
    'timeStim','timePostOnset','timePreStim','timeMax','timeNoOnset','timeScan', ...
    'scan','deviceMic','deviceHead','deviceScan'};

for n=1:numel(out_dropbox)
    val = expParams.(out_dropbox{n});
    if ischar(val), fvals_o{n}=val;
    elseif isempty(val), fvals_o{n}='';
    else fvals_o{n}=mat2str(val);
    end
end

default_width = 0.02;
default_intvl = 0.03; 

thfig=dialog('units','norm','position',[.2,.1,.6,.9],'windowstyle','normal','name','Experiment options','color','w','resize','on');
uicontrol(thfig,'style','text','units','norm','position',[.1,.92,.8,default_width],...
    'string','Experiment information:','backgroundcolor','w','fontsize',default_fontsize,'fontweight','bold');

ht_txtlist = {};
ht_list = {};
for ind=1:size(out_dropbox,2)
    ht_txtlist{ind} = uicontrol(thfig,'style','text','units','norm','position',[.1,.75-(ind-3)*default_intvl,.35,default_width],...
        'string',[out_dropbox{ind}, ':'],'backgroundcolor','w','fontsize',default_fontsize-1,'fontweight','bold','horizontalalignment','right');
    ht_list{ind} = uicontrol(thfig,'style','edit','units','norm','position',[.5,.75-(ind-3)*default_intvl,.4,default_width],...
        'string', fvals_o{ind}, 'backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1,'callback',@thfig_callback3);
end

% pop up menu that presents timing options
ht1=uicontrol(thfig,'style','popupmenu','units','norm','position',[.1,.75-8*default_intvl,.4,default_width],...
    'string',fnames,'value',1,'fontsize',default_fontsize-1,'callback',@thfig_callback1);
ht2=uicontrol(thfig,'style','edit','units','norm','position',[.5,.75-8*default_intvl,.4,default_width],...
    'string','','backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1,'callback',@thfig_callback2);

% --- Ensure device lists exist and indices are valid (minimal mac-safe fix) ---
S = audiodevinfo;                 % built-in; returns struct with .input / .output

% Make sure lists are non-empty cell arrays of char
if ~exist('strINPUT','var') || isempty(strINPUT),  strINPUT  = {S.input.Name};  end
if ~exist('strOUTPUT','var') || isempty(strOUTPUT), strOUTPUT = {S.output.Name}; end
if isempty(strINPUT),  strINPUT  = {'<No input devices found>'};  end
if isempty(strOUTPUT), strOUTPUT = {'<No output devices found>'}; end

% Pick initial indices (must be scalar between 1..numel(list))
% Try your preferred matches, fall back to 1
ipind = find(contains(strINPUT,  'Analogue') & contains(strINPUT,'Focusrite'), 1, 'first');
if isempty(ipind), ipind = find(contains(strINPUT,'Default'), 1, 'first'); end
if isempty(ipind), ipind = 1; end
ipind = max(1, min(ipind, numel(strINPUT)));

opind = find(contains(strOUTPUT, 'Speakers') & contains(strOUTPUT,'Focusrite'), 1, 'first');
if isempty(opind), opind = find(contains(strOUTPUT,'Default'), 1, 'first'); end
if isempty(opind), opind = 1; end
opind = max(1, min(opind, numel(strOUTPUT)));

tgind = find(contains(strOUTPUT, 'Playback') & contains(strOUTPUT,'Focusrite'), 1, 'first');
if isempty(tgind), tgind = 1; end
tgind = max(1, min(tgind, numel(strOUTPUT)));

% displays input devices
uicontrol(thfig,'style','text','units','norm','position',[.1,.75-9*default_intvl,.35,default_width],...
    'string','Microphone:','backgroundcolor','w','fontsize',default_fontsize-1,'fontweight','bold','horizontalalignment','right');
ht3a=uicontrol(thfig,'style','popupmenu','units','norm','position',[.5,.75-9*default_intvl,.4,default_width],...
    'string',strINPUT,'value',ipind,'backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1);

% displays output devices
uicontrol(thfig,'style','text','units','norm','position',[.1,.75-10*default_intvl,.35,default_width],...
    'string','Sound output:','backgroundcolor','w','fontsize',default_fontsize-1,'fontweight','bold','horizontalalignment','right');
ht3b=uicontrol(thfig,'style','popupmenu','units','norm','position',[.5,.75-10*default_intvl,.4,default_width],...
    'string',strOUTPUT,'value',opind,'backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1);

% displays trigger devices
ht3c0=uicontrol(thfig,'style','text','units','norm','position',[.1,.75-11*default_intvl,.35,default_width],...
    'string','Scanner trigger:','backgroundcolor','w','fontsize',default_fontsize-1,'fontweight','bold','horizontalalignment','right');
ht3c=uicontrol(thfig,'style','popupmenu','units','norm','position',[.5,.75-11*default_intvl,.4,default_width],...
    'string',strOUTPUT,'value',tgind,'backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1);

uicontrol(thfig,'style','pushbutton','string','Start','units','norm','position',[.1,.01,.38,.10],'callback','uiresume','fontsize',default_fontsize-1);
uicontrol(thfig,'style','pushbutton','string','Cancel','units','norm','position',[.51,.01,.38,.10],'callback','delete(gcbf)','fontsize',default_fontsize-1);

% if not scan, do not display trigger devices selection
if ~expParams.scan, set([ht3c0,ht3c],'visible','off'); end

thfig_callback1;
    function thfig_callback1(varargin)
        tn=get(ht1,'value');
        set(ht2,'string',fvals{tn});
    end
    function thfig_callback2(varargin)
        tn=get(ht1,'value');
        fvals{tn}=get(ht2,'string');
    end
    function thfig_callback3(varargin)
        for tn=1:size(out_dropbox,2)
            if strcmp(out_dropbox{tn}, 'visual'), continue; end
            fvals_o{tn}=get(ht_list{tn}, 'string');
            if strcmp(out_dropbox{tn},'scan')
                if isequal(str2num(fvals_o{tn}),0), set([ht3c0,ht3c],'visible','off'); 
                else set([ht3c0,ht3c],'visible','on'); 
                end
            end
        end
    end

uiwait(thfig);
ok=ishandle(thfig);
if ~ok, return; end
% Assign chosen devices from GUI (safe indexing)
idx = get(ht3a,'value');
idx = max(1, min(idx, numel(strINPUT)));
expParams.deviceMic = strINPUT{idx};

idx = get(ht3b,'value');
idx = max(1, min(idx, numel(strOUTPUT)));
expParams.deviceHead = strOUTPUT{idx};

if expParams.scan
    idx = get(ht3c,'value');
    idx = max(1, min(idx, numel(strOUTPUT)));
    expParams.deviceScan = strOUTPUT{idx};
end

delete(thfig);

% save the configured values to expParams
for n=1:numel(fnames)
    val=fvals{n};
    if ischar(expParams.(fnames{n})), expParams.(fnames{n})=val;
    elseif isempty(val), expParams.(fnames{n})=[];
    else
        assert(~isempty(str2num(val)),'unable to interpret string %s',val);
        expParams.(fnames{n})=str2num(val);
    end
end
for n=1:numel(out_dropbox)
    val=fvals_o{n};
    if ischar(expParams.(out_dropbox{n})), expParams.(out_dropbox{n})=val;
    elseif isempty(val), expParams.(out_dropbox{n})=[];
    else
        assert(~isempty(str2num(val)),'unable to interpret string %s',val);
        expParams.(out_dropbox{n})=str2num(val);
    end
end
expParams.runstring = sprintf(['%0',num2str(num_run_digits),'d'], expParams.run); % add zero padding

% visual setup
anno_op.rectWidthProp = expParams.rectWidthProp;
anno_op.rectHeightProp = expParams.rectHeightProp;
anno_op.rectColor = expParams.rectColor; 
annoStr = setUpVisAnnot_HW([0 0 0], anno_op);

% Questioner window (left-justified layout, includes .goRect cue)
qop = anno_op; qop.visible = 'off';
anno_qustnr = setUpVisAnnot_HW_left_justified([0 0 0], qop);

% Place questioner window on left half of primary monitor (like 2nd)
mp = get(0,'MonitorPositions'); if isempty(mp), mp = get(0,'ScreenSize'); end
prim = mp(1,:);
fig_width  = prim(3) / 2;
fig_height = prim(4) * 0.7;
XPos = prim(3) / 2;
YPos = prim(4) * 0.3;
anno_qustnr.hfig.Position = [XPos YPos fig_width fig_height];
anno_qustnr.hfig.Visible  = 'on';

% --- Camera-blocker window positioned to the LEFT of the main stim figure ---
% Primary monitor geometry
mp = get(0,'MonitorPositions'); 
if isempty(mp), mp = get(0,'ScreenSize'); end
if isvector(mp), prim = mp; else, prim = mp(1,:); end   % [x y w h]

% Main stim figure position (works regardless of fields on annoStr)
mainFig = ancestor(annoStr.Stim, 'figure');
mainPos = get(mainFig, 'Position');          % [x y w h]

% Block the area to the left of the main stim window
cam_blocker_x   = prim(1);
cam_blocker_w   = max(1, mainPos(1) - prim(1));
cam_blocker_pos = [cam_blocker_x, mainPos(2), cam_blocker_w, mainPos(4)];

hfig_cam_blocker = figure('Visible','off','NumberTitle','off','Color',[0 0 0], ...
    'Position', cam_blocker_pos, 'MenuBar','none','ToolBar','none');

if isfield(expParams,'cover_camera_when_nospeech') && expParams.cover_camera_when_nospeech
    hfig_cam_blocker.Visible = 'on';
end

CLOCKp = ManageTime('start');
TIME_PREPARE = 0.5; % Waiting period before experiment begin (sec)
set(annoStr.Stim, 'String', 'Preparing...');
set(annoStr.Stim, 'Visible','on');

%%%%%%%% only turn on timing warnings on commandline for debugging or in unobserved condition; otherwise is distracting for experimenter
show_timing_warnings = expParams.play_question_audio_stim; % 'play_question_audio_stim' is true only in unobserved condition

%%% option to display the upcoming trial on the commandline.... generally unnecessary/distracting during the observed condition
upcoming_trial_on_commandline = 0; 

%% load stim list
% root path is where the subject description files are
dirs.ses = [expParams.root, filesep, sprintf('sub-%s',expParams.subject), filesep, sprintf('ses-%d',expParams.session)];
dirs.stim_audio = [dirs.ses, filesep, 'stim_audio']; 
dirs.task = [dirs.ses, filesep, 'beh', filesep, expParams.task]; 
unique_answers_file  = fullfile(dirs.task,sprintf('sub-%s_ses-%d_run-%s_task-%s_qa-list.tsv',expParams.subject, expParams.session, expParams.runstring, expParams.task));
Output_name = fullfile(dirs.task,sprintf('sub-%s_ses-%d_run-%s_task-%s_desc-presentation.mat',expParams.subject, expParams.session, expParams.runstring, expParams.task));
if ~isempty(dir(Output_name))&&~isequal('Yes - overwrite',...
        questdlg(sprintf('This subject %s already has an data file for this ses-%d_run-%s (task: %s), do you want to over-write?',...
        expParams.subject, expParams.session, expParams.runstring, expParams.task),...
        'Answer', 'Yes - overwrite', 'No - quit','No - quit')), return; 
end

%% create trial table
unique_qa = readtable(unique_answers_file,'FileType','text');
n_unique_qa = height(unique_qa); 
expParams.n_speech_trials = n_unique_qa * expParams.repetitions_per_unique_qa; 

% make list of speech trials, shuffle if specified
trials_speech = repelem(unique_qa, expParams.repetitions_per_unique_qa, 1);
if expParams.shuffle_qa_order
    trials_speech = trials_speech(randperm(height(trials_speech)), :);

    % check for stim repeats
    qa_sequence_lengths = accumarray(cumsum([true; ~strcmp(trials_speech.answer(1:end-1), trials_speech.answer(2:end))]), 1); % sequences of repeated qa stim trials 
    max_repeated_qa = max(qa_sequence_lengths); 

     % if we exceed max unique repeats, then reshuffle
    while max_repeated_qa > expParams.max_unique_qa_repeats
        trials_speech = trials_speech(randperm(height(trials_speech)), :);; % reshuffle
        qa_sequence_lengths = accumarray(cumsum([true; ~strcmp(trials_speech.answer(1:end-1), trials_speech.answer(2:end))]), 1); % sequences of repeated qa stim trials 
        max_repeated_qa = max(qa_sequence_lengths); 
    end

end

% add baseline trials
    % formula:    baseprop / [1-baseprop] = nbase/[nspeech]..... nbase = nspeech * [baseprop / (1-baseprop)]
expParams.n_base_trials = round(expParams.n_speech_trials * expParams.baseline_trials_proportion / [1-expParams.baseline_trials_proportion]); 
expParams.ntrials = expParams.n_speech_trials + expParams.n_base_trials; 
trials_speech.basetrial(1:height(trials_speech)) = false; 
baserow = trials_speech(1,:);
    baserow.question{1} = '';
    baserow.answer{1} = '';
    baserow.n_syls(1) = NaN;
    baserow.basetrial = true; 
if expParams.baseline_trials_evenly_spaced
    % linearly space baseline trials
    start_base_trial = max([2 expParams.ntrials/expParams.n_base_trials]); % start base trials later than speech trials; trial 1 is never base
    baseinds = round(linspace(start_base_trial, expParams.ntrials, expParams.n_base_trials));
    isbase = false(expParams.ntrials,1); 
    isbase(baseinds) = true; 
elseif ~expParams.baseline_trials_evenly_spaced
    isbase = [false(expParams.n_speech_trials,1); true(expParams.n_base_trials,1)];
    isbase = isbase(randperm(length(isbase),length(isbase)), :); % shuffle base trial locations
    base_sequence_lengths = diff(find([0; diff(isbase)])); % sequences of repeated baseline trials 
    max_repeated_base = max(base_sequence_lengths); 

     % if the first trial is a baseline trial, or if we exceed max baseline trials, then reshuffle
    while isbase(1)   ||   max_repeated_base > expParams.max_basetrial_repeats
        isbase = isbase(randperm(length(isbase),length(isbase)), :); % reshuffle
        base_sequence_lengths = diff(find([0; diff(isbase)])); % sequences of repeated baseline trials 
        max_repeated_base = max(base_sequence_lengths); 
    end
end
trials = table; 
trials(isbase,:) = repmat(baserow, expParams.n_base_trials, 1); % fill in baseline trials
trials(~isbase,:) = trials_speech; % fill in speech trials

expParams.sr = 48000;            % sample frequenct (Hz)
frameDur = .050;                 % frame duration in seconds
% --- Low-latency global frame size ---
FRAME = 256;                     % try 128; 64 if rock solid; 256 if CPU is tight
expParams.frameLength = FRAME;   % keep reader/writer/beep aligned


% === PRELOAD ALL AUDIO FILES (low-latency setup) ===
stim_q_file_extension = 'mp3';
fprintf('Preloading all question audio stimuli...\n');
preloadedAudio = cell(height(trials),1);

for ii = 1:height(trials)
    if trials.basetrial(ii)     % skip baseline trials
        preloadedAudio{ii} = [];
        continue;
    end

    stim_q_file = fullfile(dirs.stim_audio, [trials.stimfile{ii} '.' stim_q_file_extension]);
    [aud, fs_in] = audioread(stim_q_file);

    % Resample to match experiment SR
    if fs_in ~= expParams.sr
        aud = resample(aud, expParams.sr, fs_in);
    end

    % Force stereo
    if size(aud,2) == 1
        aud = [aud aud];
    end

    preloadedAudio{ii} = aud;
end
fprintf('Finished preloading %d audio stimuli.\n', height(trials));
% --- Prebuffer beep once, matched to FRAME ---
FRAME = expParams.frameLength;  % keep everything on the same frame size
[beepWav, beepFs] = audioread(fullfile(fileparts(which(mfilename)),'flvoice_run_beep.wav'));
if beepFs ~= expParams.sr
    beepWav = resample(beepWav, expParams.sr, beepFs);
end
if size(beepWav,2) == 1
    beepWav = [beepWav beepWav]; % force stereo
end
pad = mod(-size(beepWav,1), FRAME);
if pad > 0
    beepWav(end+1:end+pad, :) = 0;      % pad to multiple of FRAME
end
% store as frames: (#frames x (2*FRAME)), then slice to FRAME x 2 later
beepFrames = reshape(beepWav.', 2*FRAME, []).';
beepGain = 0.25;
beepFrames = beepGain * beepFrames;
beepActive = false;      % state flag used in trial loop
beepIdx = 1;             % frame index into beepFrames

%%
sileread = dsp.AudioFileReader(fullfile(expParams.audio_common_path, 'silent.wav'), 'SamplesPerFrame', 2048);

% --- Use GUI selections; validate and fallback without CLI prompts ---
% If GUI values are empty or out of range, fall back to first available

% Mic
if ~exist('strINPUT','var') || isempty(strINPUT)
    error('No audio input devices found.');
end
if isempty(expParams.deviceMic) || ~ismember(expParams.deviceMic, strINPUT)
    % try partial match, else first entry
    pm = find(strncmpi(expParams.deviceMic, strINPUT, max(1,numel(expParams.deviceMic))), 1, 'first');
    if ~isempty(pm)
        expParams.deviceMic = strINPUT{pm};
    else
        expParams.deviceMic = strINPUT{1};
    end
end

% Headphones
if ~exist('strOUTPUT','var') || isempty(strOUTPUT)
    error('No audio output devices found.');
end
if isempty(expParams.deviceHead) || ~ismember(expParams.deviceHead, strOUTPUT)
    pm = find(strncmpi(expParams.deviceHead, strOUTPUT, max(1,numel(expParams.deviceHead))), 1, 'first');
    if ~isempty(pm)
        expParams.deviceHead = strOUTPUT{pm};
    else
        expParams.deviceHead = strOUTPUT{1};
    end
end

% Scanner trigger (only if scanning)
if expParams.scan
    if isempty(expParams.deviceScan) || ~ismember(expParams.deviceScan, strOUTPUT)
        pm = find(strncmpi(expParams.deviceScan, strOUTPUT, max(1,numel(expParams.deviceScan))), 1, 'first');
        if ~isempty(pm)
            expParams.deviceScan = strOUTPUT{pm};
        else
            % If nothing sensible, use same as headphones (or first output)
            expParams.deviceScan = expParams.deviceHead;
        end
    end
end

% set up device reader settings for accessing audio signal during recording
deviceReader = audioDeviceReader(...
    'Device', expParams.deviceMic, ...
    'SamplesPerFrame', FRAME, ...
    'SampleRate', expParams.sr, ...
    'BitDepth', '24-bit integer');

% set up sound output players
if ~ismember(expParams.deviceHead, strOUTPUT), expParams.deviceHead=strOUTPUT{find(strncmp(lower(expParams.deviceHead),lower(strOUTPUT),numel(expParams.deviceHead)),1)}; end
assert(ismember(expParams.deviceHead, strOUTPUT), 'unable to find match to deviceHead name %s',expParams.deviceHead);
[ok,ID]=ismember(expParams.deviceHead, strOUTPUT);
[twav, tfs] = audioread(fullfile(fileparts(which(mfilename)),'flvoice_run_beep.wav'));
beepdur = numel(twav)/tfs;

headwrite = audioDeviceWriter( ...
    'SampleRate', expParams.sr, ...
    'SupportVariableSizeInput', true, ...
    'BufferSize', FRAME, ...
    'Device', expParams.deviceHead);
setup(headwrite, zeros(FRAME,2)); 
if expParams.scan
    if ~ismember(expParams.deviceScan, strOUTPUT), expParams.deviceScan=strOUTPUT{find(strncmp(lower(expParams.deviceScan),lower(strOUTPUT),numel(expParams.deviceScan)),1)}; end
    assert(ismember(expParams.deviceScan, strOUTPUT), 'unable to find match to deviceScan name %s',expParams.deviceScan);
    [ok,ID]=ismember(expParams.deviceScan, strOUTPUT);
    [twav, tfs] = audioread(fullfile(fileparts(which(mfilename)),'flvoice_run_trigger.wav')); % read in sine wav file to trigger the scanner
    trigdur = numel(twav)/tfs;
    trigread = dsp.AudioFileReader(fullfile(fileparts(which(mfilename)),'flvoice_run_trigger.wav'), 'SamplesPerFrame', 2048);
    trigwrite = audioDeviceWriter('SampleRate',trigread.SampleRate,'Device',expParams.deviceScan);
end

% checks values of timing variables
expParams.beepoffset = beepoffset;

assert(all(isfinite(expParams.timeStim))&ismember(numel(expParams.timeStim),[1,2]), 'timeStim field must have one or two elements');
assert(all(isfinite(expParams.timePostOnset))&ismember(numel(expParams.timePostOnset),[1,2]), 'timePostOnset field must have one or two elements');
assert(all(isfinite(expParams.timeScan))&ismember(numel(expParams.timeScan),[1,2]), 'timeScan field must have one or two elements');
assert(all(isfinite(expParams.timePreStim))&ismember(numel(expParams.timePreStim),[1,2]), 'timePreStim field must have one or two elements');
assert(all(isfinite(expParams.timeMax))&ismember(numel(expParams.timeMax),[1,2]), 'timeMax field must have one or two elements');
assert(all(isfinite(expParams.timeNoOnset))&ismember(numel(expParams.timeNoOnset),[1,2]), 'timeNoOnset field must have one or two elements');
if numel(expParams.timeStim)==1, expParams.timeStim=expParams.timeStim+[0 0]; end
if numel(expParams.timePostOnset)==1, expParams.timePostOnset=expParams.timePostOnset+[0 0]; end
if numel(expParams.timeScan)==1, expParams.timeScan=expParams.timeScan+[0 0]; end
if numel(expParams.timePreStim)==1, expParams.timePreStim=expParams.timePreStim+[0 0]; end
if numel(expParams.timeMax)==1, expParams.timeMax=expParams.timeMax+[0 0]; end
if numel(expParams.timeNoOnset)==1, expParams.timeNoOnset=expParams.timeNoOnset+[0 0]; end
expParams.timeStim=sort(expParams.timeStim);
expParams.timePostOnset=sort(expParams.timePostOnset);
expParams.timeScan=sort(expParams.timeScan);
expParams.timePreStim=sort(expParams.timePreStim);
expParams.timeMax=sort(expParams.timeMax);
expParams.timeNoOnset=sort(expParams.timeNoOnset);
rmsThresh = expParams.rmsThresh; % params for detecting voice onset %voiceCal.rmsThresh; % alternatively, run a few iterations of testThreshold and define rmsThreshd here with the resulting threshold value after convergence
rmsBeepThresh = expParams.rmsBeepThresh;
% nonSpeechDelay = .75; % initial estimate of time between go signal and voicing start
nonSpeechDelay = .5; % initial estimate of time between go signal and voicing start

% set up figure for real-time plotting of audio signal of next trial
rtfig = figure('units','norm','position',[.1 .2 .4 .5],'menubar','none');
micSignal = plot(nan,nan,'-', 'Color', [0 0 0.5]);
micLine = xline(0, 'Color', [0.984 0.352 0.313], 'LineWidth', 3);
micLineB = xline(0, 'Color', [0.46 1 0.48], 'LineWidth', 3);
micTitle = title('', 'Fontsize', default_fontsize-1, 'interpreter','none');
xlabel('Time(s)');
ylabel('Sound Pressure');


pause(1);
save(Output_name, 'expParams');


%% pre scans
if expParams.scan && expParams.prescan && ~CMRR
    fprintf('\nStarting prescans\n');
    psTime = tic;
    fprintf('\nPrescan IPAT 1, duration %.2f seconds\n', expParams.ipatDur);
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.ipatDur+0.1);
    fprintf('\nPrescan IPAT 2, duration %.2f seconds\n', expParams.ipatDur);
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.ipatDur);
    fprintf('\nPrescan SMS, duration %.2f seconds\n', expParams.smsDur);
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.smsDur);
    fprintf('\nPrescan dummy scan 1, duration %.2f seconds\n', expParams.timeScan(1));
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.timeScan(1));
    fprintf('\nPrescans complete\n\n');
elseif expParams.scan && expParams.prescan && CMRR
    fprintf('\nStarting prescans\n');
    psTime = tic;
    fprintf('\nPrescan 1, duration %.2f seconds\n', expParams.ipatDur);
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.ipatDur+0.1);
    fprintf('\nPrescan 2, duration %.2f seconds\n', expParams.ipatDur);
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.ipatDur);
    fprintf('\nPrescan 3, duration %.2f seconds\n', expParams.ipatDur);
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.ipatDur);
    fprintf('\nPrescan 4, duration %.2f seconds\n', expParams.smsDur);
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.smsDur);
    fprintf('\nPrescan dummy scan 1, duration %.2f seconds\n', expParams.timeScan(1));
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.timeScan(1)+0.1);
    fprintf('\nPrescan dummy scan 2, duration %.2f seconds\n', expParams.timeScan(1));
    %play(triggerPlayer)
    while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
    toc(psTime);
    pause(expParams.timeScan(1)+0.1);
    fprintf('\nPrescans complete\n\n');
end
pause(1);
save(Output_name, 'expParams');


%Initialize trialData structure
trialData = struct;

% waits for TIME_PREPARE set to 0.5seconds
ok=ManageTime('wait', CLOCKp, TIME_PREPARE);
set(annoStr.Stim, 'Visible','off');     % Turn off preparation page

% gets current time
TIME_PREPARE_END=ManageTime('current', CLOCKp);

set(annoStr.Stim, 'String', 'READY');
set(annoStr.Stim, 'Visible','on');

while ~isDone(sileread); sound=sileread();headwrite(sound);end;release(sileread);reset(headwrite);

ok=ManageTime('wait', CLOCKp, TIME_PREPARE_END+2);
set(annoStr.Stim, 'Visible','off');     % Turn off preparation page
CLOCK=[];                               % Main clock (not yet started)
expParams.timeNULL = expParams.timeMax(1) + diff(expParams.timeMax).*rand;
intvs = [];
beepActive = false;

% Pre-warm audio system with silent audio
fprintf('Pre-warming audio system...\n');
silentFrame = zeros(FRAME, 2); % Stereo silent frame
for i = 1:10 % Send a few silent frames to initialize
    headwrite(silentFrame);
end
fprintf('Audio system warmed up.\n');
%% LOOP OVER TRIALS
for itrial = 1:expParams.ntrials

    % % % % % % % % % % % % % % % % % % fprintf('\nRun %s, trial %d/%d\n', expParams.runstring, itrial, expParams.ntrials);
    set(annoStr.Plus, 'Visible','on');

    % trial specific timing parameters with jitter on
    trialData(itrial).question = trials.question{itrial};
    if strcmp(trials.question{itrial}, 'NULL'); 
        trialData(itrial).display = 'yyy'; 
    end
    trialData(itrial).timeStim = expParams.timeStim(1) + diff(expParams.timeStim).*rand; % time white text is displayed
    trialData(itrial).timePostOnset = expParams.timePostOnset(1) + diff(expParams.timePostOnset).*rand; % time after voice onset we record
    trialData(itrial).timePreStim = expParams.timePreStim(1) + diff(expParams.timePreStim).*rand; % time before the next stimulus is presented
    trialData(itrial).timeMax = expParams.timeMax(1) + diff(expParams.timeMax).*rand; % Maximum time we record
    trialData(itrial).timeScan = expParams.timeScan(1) + diff(expParams.timeScan).*rand; % Scan time
    trialData(itrial).timeCoolOff = 0.5; % Post scan cool off
    trialData(itrial).timeNoOnset = expParams.timeNoOnset(1) + diff(expParams.timeNoOnset).*rand; % time we wait for voice onset and stop the current trial post this

    stimread = trials.question{itrial}; 

    % print current trial stim command line for the investigator to read... also (optionally) upcoming stimulus questions
    % print trial number and total trials
    if upcoming_trial_on_commandline     &&       itrial ~= expParams.ntrials % if not last trial and option turned on
        next_trial_string = ['\n\n      Next trial''s question/answer will be:\n ''', trials.question{itrial+1}, ''' /// ''', trials.answer{itrial+1}, ''''];
    else % if last trial
        next_trial_string = '';
    end

    if ~trials.basetrial(itrial)
        % Prepare beep to be mixed live in the frame loop (no pauses)
    beepActive = true;
    beepIdx = 1;

    set(anno_qustnr.Plus, 'Visible', 'off');
    set(anno_qustnr.Stim, 'Visible', 'off');
    set(anno_qustnr.goRect, 'Visible', 'on');
    end

% --- decide what to present this trial & camera-blocker state ---
if trials.basetrial(itrial)
    experimenter_cue_string = '(BASELINE TRIAL - NO QUESTION)';
    cam_blocker_state = tern(expParams.cover_camera_when_nospeech,'on','off');
else
    experimenter_cue_string = trials.question{itrial};
    cam_blocker_state = 'off';
end

set(anno_qustnr.Stim, 'String', experimenter_cue_string);
set(anno_qustnr.Stim, 'Visible', 'on');
hfig_cam_blocker.Visible = cam_blocker_state;

% (optional) next_trial_string like your 2nd script
if itrial < expParams.ntrials
    next_trial_string = sprintf('\n\n      Next trial''s question/answer will be:\n ''%s'' /// ''%s''', ...
        trials.question{itrial+1}, trials.answer{itrial+1});
else
    next_trial_string = '';
end

fprintf(['\n', experimenter_cue_string, ' ........ trial ', num2str(itrial), '/', num2str(expParams.ntrials), ...
    '\n      [[[[''',trials.answer{itrial}, ''']]]]', '\n\n', next_trial_string, '\n']);


    prepareScan=0.250*(expParams.scan~=0); % if scanning, end recording 250ms before scan trigger
    % set up variables for audio recording and voice detection
    recordLen= trialData(itrial).timeMax-prepareScan; % max total recording time
    recordLenNULL = expParams.timeNULL-prepareScan;
    nSamples = ceil(recordLen*expParams.sr);
    nSamplesNULL = ceil(recordLenNULL*expParams.sr);
    time = 0:1/expParams.sr:(nSamples-1)/expParams.sr;
    recAudio = zeros(nSamples,1);       % initialize variable to store audio
    nMissingSamples = 0;                % cumulative n missing samples between frames
    beepDetected = 0;
    voiceOnsetDetected = 0;             % voice onset not yet detected
    frameCount = 1;                     % counter for # of frames (starting at first frame)
    endIdx = 0;                         % initialize idx for end of frame
    voiceOnsetState = [];
    beepOnsetState = [];
    RT = 0.5; % reaction time to process change of signal to red
        
    % set up figure for real-time plotting of audio signal of next trial
    figure(rtfig);
    set(micTitle,'string',sprintf('%s %s run %s trial %d ', expParams.subject, expParams.task, expParams.runstring, itrial));
    setup(deviceReader) % note: moved this here to avoid delays in time-sensitive portion

    if isempty(CLOCK)
        CLOCK = ManageTime('start');    % resets clock to t=0 (first-trial start-time)
        TIME_TRIAL_START = 0;
        TIME_STIM_START = 0;
    else
        TIME_TRIAL_START = ManageTime('current', CLOCK);
    end

    ok=ManageTime('wait', CLOCK, TIME_STIM_START);
    % start of the trial
    TIME_TEXT_ACTUALLYSTART = ManageTime('current', CLOCK);
    


    %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
    if show_timing_warnings
        if ~ok, fprintf('i am late for this trial TIME_TRIAL_START\n'); end
    end
    
    
    set(annoStr.Plus, 'Visible','off');        
    set(annoStr.Stim, 'color', 'w');
    
    % determine what to display
    if expParams.show_question_orthography
        % Display the orthography stimulus as normal
        set(annoStr.Stim, 'String', stimread);
        set(annoStr.Stim, 'Visible', 'On');
    elseif ~expParams.show_question_orthography
        % Keep the white fixation cross visible (don't change it)
        % The fixation cross should already be visible from before
        % Just make sure the stimulus text is not shown
        set(annoStr.Stim, 'Visible', 'Off');
        % Keep the Plus (fixation cross) visible
        set(annoStr.Plus, 'Visible', 'on');
        set(annoStr.Plus, 'color', 'w');  % ensure it's white
    end
    
    % if unobserved condition, and it's a speech trial, play audio question file
    if expParams.play_question_audio_stim && ~trials.basetrial(itrial)
        % TIME_SOUND_START = TIME_STIM_ACTUALLYSTART + trialData(ii).timePreSound;
        % ok=ManageTime('wait', CLOCK, TIME_SOUND_START - stimoffset);
        % ok=ManageTime('wait', CLOCK, TIME_SOUND_START);
        stim_q_file_extension = 'mp3';
        stim_q_file = [dirs.stim_audio, filesep, trials.stimfile{itrial}, '.', stim_q_file_extension]; % audio file for this trial
        % === Low-latency playback from preloaded buffer ===
        stimAudio = preloadedAudio{itrial};   % N x 2, SR matches
        if ~isempty(stimAudio)
            pad = mod(-size(stimAudio,1), FRAME);
            if pad>0, stimAudio(end+1:end+pad,:) = 0; end
        end
        TIME_SOUND_ACTUALLYSTART = ManageTime('current', CLOCK);
        TIME_SOUND_END = TIME_SOUND_ACTUALLYSTART + trialData(itrial).timeStim;

        % sttInd=1; endMax=size(Input_sound, 1); while sttInd<endMax; headwrite(Input_sound(sttInd:min(sttInd+2047, endMax))); sttInd=sttInd+2048; end; reset(headwrite);
        TIME_SOUND_ACTUALLYSTART = ManageTime('current', CLOCK);
        % while ~isDone(stimread); sound=stimread();headwrite(sound);end;release(stimread);reset(headwrite);
        TIME_SOUND_END = TIME_SOUND_ACTUALLYSTART + trialData(itrial).timeStim;           % stimulus ends

        %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
        % if show_timing_warnings
        %     if ~ok, fprintf('i am late for this trial TIME_SOUND_START\n'); end
        % end
    end
    % Initialize stim audio playback variables
    stimAudio = [];
    stimAudioFrameIdx = 1;
    
    if expParams.play_question_audio_stim && ~trials.basetrial(itrial)
        stimAudio = preloadedAudio{itrial}; % N x 2 stereo, sample rate matches expParams.sr
        % Pad stimAudio to multiple of FRAME for neat frame slicing
        pad = mod(-size(stimAudio,1), FRAME);
        if pad > 0
            stimAudio(end+1:end+pad, :) = 0;
        end
    end

    TIME_TEXT_END = TIME_TEXT_ACTUALLYSTART + trialData(itrial).timeStim;           % stimulus ends

    %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
    % if show_timing_warnings
    %     if ~ok, fprintf('i am late for this trial TIME_TEXT_END\n'); end
    % end
    TIME_GOSIGNAL_START = TIME_TEXT_END;          % GO signal time
    set(micLine,'visible','off');set(micLineB,'visible','off');drawnow;
        
    ok=ManageTime('wait', CLOCK, TIME_GOSIGNAL_START - beepoffset);     % waits for recorder initialization time
    [nill, nill] = deviceReader(); % note: this line may take some random initialization time to run; audio signal start (t=0) will be synchronized to the time when this line finishes running
    
    %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
    if show_timing_warnings
        if ~ok, fprintf('i am late for this trial TIME_GOSIGNAL_START - beepoffset\n'); end
    end
    ok=ManageTime('wait', CLOCK, TIME_GOSIGNAL_START);     % waits for GO signal time

    % play beep and switch to visual go cue if it's a speech trial
if ~trials.basetrial(itrial)
    beepActive = true;   % start emitting beep frames in the frame loop
    beepIdx = 1;

    set(anno_qustnr.goRect,'Visible','off');
    set(anno_qustnr.Plus,  'color','r');
    set(anno_qustnr.Plus,'Visible','on');
end


    TIME_GOSIGNAL_ACTUALLYSTART = ManageTime('current', CLOCK); % actual time for GO signal 

    if ~trials.basetrial(itrial)
       fprintf('\n ------- GREEN GO CUE NOW ONSCREEN, PLAYING BEEP --------\n\n')
    end

    %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
    if show_timing_warnings
        if ~ok, fprintf('i am late for this trial TIME_GOSIGNAL_START\n'); end
    end

    % reaction time
    TIME_VOICE_START = TIME_GOSIGNAL_ACTUALLYSTART + nonSpeechDelay;                   % expected voice onset time

    TIME_SCAN_START = TIME_GOSIGNAL_ACTUALLYSTART + trials.basetrial(itrial) * trialData(itrial).timeMax + (1-trials.basetrial(itrial))*expParams.timeNULL;

    endSamples = trials.basetrial(itrial) * nSamples + (1-trials.basetrial(itrial))*nSamplesNULL;
    while endIdx < endSamples
        % find beginning/end indices of frame
        begIdx = (frameCount*expParams.frameLength)-(expParams.frameLength-1) + nMissingSamples;
        endIdx = (frameCount*expParams.frameLength) + nMissingSamples;

        % read audio data
        [audioFromDevice, numOverrun] = deviceReader();     % read one frame of audio data % note: audio t=0 corresponds to first call to deviceReader, NOT to time of setup(...)
        numOverrun = double(numOverrun);    % convert from uint32 to type double
        if numOverrun > 0, recAudio(begIdx:begIdx+numOverrun-1) = 0; end      % set missing samples to 0
        recAudio(begIdx+numOverrun:endIdx+numOverrun) = audioFromDevice;    % save frame to audio vector
        nMissingSamples = nMissingSamples + numOverrun;     % keep count of cumulative missng samples between frames

        % 1) mic block (FRAME x 2)
        micBlock = audioFromDevice;
        if size(micBlock,2) == 1, micBlock = [micBlock micBlock]; end
        micBlock = expParams.monitorGain * micBlock;
        
        % 2) beep block from prebuffered frames (FRAME x 2), if active
        if beepActive
            bPacked = beepFrames(beepIdx, :);
            b = reshape(bPacked, [2, FRAME]).';
            beepIdx = beepIdx + 1;
            if beepIdx > size(beepFrames,1)
                beepActive = false;
            end
            baseMix = micBlock + b;
        else
            baseMix = micBlock;
        end
        
        % 3) stim audio playback mixing
        if ~isempty(stimAudio) && stimAudioFrameIdx <= size(stimAudio,1)
            stimFrame = stimAudio(stimAudioFrameIdx : stimAudioFrameIdx+FRAME-1, :);
            stimAudioFrameIdx = stimAudioFrameIdx + FRAME;
            mix = baseMix + stimFrame;  % mix stim audio frame in
        else
            mix = baseMix;
        end
        
        % 4) write mixed frame to output device
        headwrite(mix);

        % plot audio data
if mod(frameCount, 16) == 0
    set(micSignal, 'xdata', time, 'ydata', recAudio(1:numel(time)));
    drawnow limitrate   % or: drawnow nocallbacks
end

    
        % voice onset exclusion
        minVoiceOnsetTime = max(0, expParams.minVoiceOnsetTime-(begIdx+numOverrun)/expParams.sr);
        
        % detect beep onset
        if trials.basetrial(itrial) && beepDetected == 0 && expParams.minVoiceOnsetTime > (begIdx+numOverrun)/expParams.sr
            % look for beep onset
            [beepDetected, bTime, beepOnsetState]  = detectVoiceOnset(recAudio(begIdx+numOverrun:endIdx+numOverrun), expParams.sr, expParams.rmsThreshTimeOnset, rmsBeepThresh, 0, beepOnsetState);
            if beepDetected
                beepTime = bTime + (begIdx+numOverrun)/expParams.sr; 
                set(micLineB,'value',beepTime,'visible','on');
            end
        elseif trials.basetrial(itrial) && voiceOnsetDetected == 0,% && frameCount > onsetWindow/frameDur
            if ~beepDetected; beepTime = 0; 
               %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
                if show_timing_warnings
                    disp('Beep not detected. Assign beepTime = 0.'); 
                end
            end
            trialData(itrial).beepTime = beepTime;

            % look for voice onset in previous onsetWindow
            [voiceOnsetDetected, voiceOnsetTime, voiceOnsetState]  = detectVoiceOnset(recAudio(begIdx+numOverrun:endIdx+numOverrun), expParams.sr, expParams.rmsThreshTimeOnset, rmsThresh, minVoiceOnsetTime, voiceOnsetState);
            % update voice onset time based on index of data passed to voice onset function

            if voiceOnsetDetected
                voiceOnsetTime = voiceOnsetTime + (begIdx+numOverrun)/expParams.sr - beepTime;
                TIME_VOICE_START = TIME_GOSIGNAL_ACTUALLYSTART + voiceOnsetTime; % note: voiceonsetTime marks the beginning of the minThreshTime window
                nonSpeechDelay = .5*nonSpeechDelay + .5*voiceOnsetTime;  % running-average of voiceOnsetTime values, with alpha-parameter = 0.5 (nonSpeechDelay = alpha*nonSpeechDelay + (1-alph)*voiceOnsetTime; alpha between 0 and 1; alpha high -> slow update; alpha low -> fast update)
                TIME_SCAN_START =  TIME_VOICE_START + trialData(itrial).timePostOnset;
                nSamples = min(nSamples, ceil((TIME_SCAN_START-TIME_GOSIGNAL_ACTUALLYSTART-prepareScan)*expParams.sr)); % ends recording 250ms before scan time (or timeMax if that is earlier)
                endSamples = nSamples;
                % add voice onset to plot
                set(micLine,'value',voiceOnsetTime + beepTime,'visible','on');
            else
                CURRENT_TIME = ManageTime('current', CLOCK);
                if CURRENT_TIME - TIME_GOSIGNAL_ACTUALLYSTART - prepareScan > trialData(itrial).timeNoOnset + nonSpeechDelay
                    endSamples = endIdx;
                    TIME_SCAN_START = CURRENT_TIME;
                end
            end
         

        end

        frameCount = frameCount+1;

    end
    %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
    if show_timing_warnings
        if trials.basetrial(itrial) && voiceOnsetDetected == 0, fprintf('warning: voice was expected but not detected (rmsThresh = %f)\n',rmsThresh); end
    end
    release(deviceReader); % end recording
    
    % Hide stimulus regardless of condition
    set(annoStr.Stim, 'color','w');
    set(annoStr.Stim, 'Visible','off');


    % end-of-trial visual stim for speech trials
    if ~trials.basetrial(itrial)
        set(anno_qustnr.Plus,'Visible','off');
        set(anno_qustnr.Stim,'Visible','off');
        set(anno_qustnr.goRect,'Visible','on');
       fprintf('\n ------- RED STOP GO CUE NOW ONSCREEN -------- \n\n')
    end


    

          
    %% save voice onset time and determine how much time left before sending trigger to scanner
    if voiceOnsetDetected == 0 %if voice onset wasn't detected
        trialData(itrial).onsetDetected = 0;
        trialData(itrial).voiceOnsetTime = NaN;
        trialData(itrial).nonSpeechDelay = nonSpeechDelay;
    else
        trialData(itrial).onsetDetected = 1;
        trialData(itrial).voiceOnsetTime = voiceOnsetTime;
        trialData(itrial).nonSpeechDelay = NaN;
    end

    if expParams.scan % note: THIS IS TIME LANDMARK #2: BEGINNING OF SCAN: if needed consider placing this below some or all the plot/save operations below (at this point the code will typically wait for at least ~2s, between the end of the recording to the beginning of the scan)
        ok = ManageTime('wait', CLOCK, TIME_SCAN_START + RT);
        %playblocking(triggerPlayer);
        while ~isDone(trigread); sound=trigread();trigwrite(sound);end;reset(trigread);reset(trigwrite);
        TIME_SCAN_ACTUALLYSTART=ManageTime('current', CLOCK);
        TIME_SCAN_END = TIME_SCAN_ACTUALLYSTART + trialData(itrial).timeScan;
        NEXTTRIAL = TIME_SCAN_END + trialData(itrial).timePreStim;
        
        %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
        if show_timing_warnings
            if ~ok, fprintf('i am late for this trial TIME_SCAN_START\n'); end
        end
        if trials.basetrial(itrial); intvs = [intvs TIME_SCAN_START - TIME_GOSIGNAL_START]; expParams.timeNULL = mean(intvs); end

        if isnan(trialData(itrial).voiceOnsetTime)
            expdur = trialData(itrial).timePreStim + trialData(itrial).timeStim + trialData(itrial).timeNoOnset + trialData(itrial).timeScan + 0.5 + nonSpeechDelay; % add the other average wait time if no onset
        else
            expdur = trialData(itrial).timePreStim + trialData(itrial).timeStim + voiceOnsetTime + trialData(itrial).timePostOnset + trialData(itrial).timeScan + 0.5;
        end
        %%%%%%%% only turn on below output for debugging or in unobserved condition; otherwise is distracting for experimenter
        if show_timing_warnings
            fprintf('\nThis trial elapsed Time: %.3f (s), expected duration: %.3f (s)\n', NEXTTRIAL - TIME_STIM_START, expdur);
        end
    else
        TIME_SCAN_ACTUALLYSTART=nan;
        %TIME_TRIG_RELEASED = nan;
        TIME_SCAN_END = nan;
        NEXTTRIAL = TIME_SCAN_START + trialData(itrial).timePreStim;
    end

        
    trialData(itrial).timingTrial = [TIME_TRIAL_START;TIME_TEXT_ACTUALLYSTART;TIME_TEXT_END;TIME_GOSIGNAL_START;TIME_GOSIGNAL_ACTUALLYSTART;TIME_VOICE_START;TIME_SCAN_START;TIME_SCAN_ACTUALLYSTART;TIME_SCAN_END];
    expParams.timingTrialNames = split('TIME_TRIAL_START;TIME_TEXT_ACTUALLYSTART;TIME_TEXT_END;TIME_GOSIGNAL_START;TIME_GOSIGNAL_ACTUALLYSTART;TIME_VOICE_START;TIME_SCAN_START:TIME_SCAN_ACTUALLYSTART;TIME_SCAN_END;');
    
    TIME_STIM_START = NEXTTRIAL;

    %% save for each trial
    trialData(itrial).s = recAudio(1:nSamples);
    trialData(itrial).fs = expParams.sr;
    if trials.basetrial(itrial) && voiceOnsetDetected, trialData(itrial).reference_time = voiceOnsetTime;
    else trialData(itrial).reference_time = nonSpeechDelay;
    end
    trialData(itrial).percMissingSamples = (nMissingSamples/(recordLen*expParams.sr))*100;

    %JT save update test 8/10/21
    % save only data from current trial
    tData = trialData(itrial);

    % fName_trial will be used for individual trial files (which will
    % live in the run folder)
    fName_trial = fullfile(dirs.task,sprintf('sub-%s_ses-%d_run-%s_task-%s_trial-%d.mat',expParams.subject, expParams.session, expParams.runstring, expParams.task,itrial));
    save(fName_trial,'tData');
end

release(headwrite);
if expParams.scan
    release(trigwrite);
    release(trigread);
end


%% end of experiment
close all

% experiment time
expParams.elapsed_time = toc(ET)/60;    % elapsed time of the experiment
fprintf('\nElapsed Time: %f (min)\n', expParams.elapsed_time)
save(Output_name, 'expParams', 'trialData');

% number of trials with voice onset detected
onsetCount = nan(expParams.ntrials,1);
for j = 1: expParams.ntrials
    onsetCount(j) = trialData(j).onsetDetected;
end
numOnsetDetected = sum(onsetCount);    

fprintf('Voice onset detected on %d/%d trials\n', numOnsetDetected, expParams.ntrials);
end


function [voiceOnsetDetected, voiceOnsetTime, state]  = detectVoiceOnset(samples, Fs, onDur, onThresh, minVoiceOnsetTime, state)
% function [voiceOnsetDetected, voiceOnsetTime]  = detectVoiceOnset(samples, Fs, onDur, onThresh, minVoiceOnsetTime)
% 
% Function to detect onset of speech production in an audio recording.
% Input samples can be from a whole recording or from individual frames.
%
% INPUTS        samples                 vector of recorded samples
%               Fs                      sampling frequency of samples
%               onDur                   how long the intensity must exceed the
%                                       threshold to be considered an onset (s)
%               onThresh                onset threshold
%               minVoiceOnsetTime       time (s) before which voice onset
%                                       cannot be detected (due to
%                                       anticipation errors, throat
%                                       clearing etc) - often set to .09 at
%                                       beginning of recording/first frame
%
% OUTPUTS       voiceOnsetDetected      0 = not detected, 1 = detected
%               voiceOnsetTime          time (s) when voice onset occurred
%                                       (with respect of first sample)
%
% Adapted from ACE study in Jan 2021 by Elaine Kearney (elaine-kearney.com)
% Matlab 2019a 
%
%%

% set up parameters
winSize = ceil(Fs * .002);                  % analysis window = # samples per 2 ms (matched to Audapter frameLen=32 samples @ 16KHz)
Incr = ceil(Fs * .002);                     % # samples to increment by (2 ms)
rmsFF = 0.90;                               % forgetting factor (Audapter's ma_rms computation)
BegWin = 1;                                 % first sample in analysis window
EndWin = BegWin + winSize -1;               % last sample in analysis window
voiceOnsetDetected = false;                 % voice onset (not yet detected)
voiceOnsetTime = [];                        % variable for storing voice onset time
if nargin<5||isempty(minVoiceOnsetTime), minVoiceOnsetTime = 0; end % minimum voice onset time
if nargin<6||isempty(state), state=struct('rms',0,'count',0); end   % rms: last-call rms value; count: last-call number of supra-threshold rms values

% main loop
while EndWin <= length(samples)
    
    dat = samples(BegWin:EndWin);
    %dat = detrend(dat, 0);                 % legacy step: removes mean value from data in analysis window
    %dat = convn(dat,[1;-.95]);             % legacy step: applies a high pass filter to the data
                                            % and may reduce sensitivity to production onset,
                                            % especially if stimulus starts with a voiceless consonant
    int = mean(dat.^2);                      % mean of squares
    state.rms =  rmsFF*state.rms+(1-rmsFF)*sqrt(int);            % calculate moving-average rms (calcRMS1 function)
    if state.rms > onThresh && BegWin > minVoiceOnsetTime*Fs
        state.count = state.count + 1;
    else
        state.count = 0;
    end
    
    % criteria for voice onset:
    % (1) onThresh must have been continuously exceeded for the duration of onDur
    % (2) time of voice onset is greater than minVoiceOnsetTime
    
    if state.count >= onDur*Fs/Incr
        voiceOnsetDetected = true;                              % onset detected
        voiceOnsetTime = (BegWin-(state.count-1)*Incr-1)/Fs;    % time when onThresh was first reached
        break
    end
    
    % increment analysis window and iteration by 1 (until voice onset detected)
    BegWin = BegWin + Incr;          
    EndWin = EndWin + Incr;                
end

end


function out = ManageTime(option, varargin)
% MANAGETIME time-management functions for real-time operations
%
% CLCK = ManageTime('start');             initializes clock to t=0
% T = ManageTime('current', CLCK);        returns current time T (measured in seconds after t=0)
% ok = ManageTime('wait', CLCK, T);       waits until time = T (measured in seconds after t=0)
%                                         returns ok=false if we were already passed T
%
% e.g.
%  CLCK = ManageTime('start');
%  ok = ManageTime('wait', CLCK, 10);
%  disp(ManageTime('current', CLCK));
%  disp(ManageTime('current', CLCK));
%  disp(ManageTime('current', CLCK));
%

DEBUG=false;
switch(lower(option))
    case 'start',
        out=clock;
    case 'wait'        
        out=true;
        t0=varargin{1};
        t1=varargin{2};
        t2=etime(clock,t0);
        if DEBUG, fprintf('had %f seconds to spare\n',t1-t2); end
        if t2>t1, out=false; return; end % i am already late
        if t1-t2>1, pause(t1-t2-1); end % wait until ~1s to go (do not waste CPU)
        while etime(clock,t0)<t1, end % wait until exactly the right time (~ms prec)
    case 'current'
        t0=varargin{1};
        out=etime(clock,t0);
end
end
function y = tern(cond,a,b), if cond, y=a; else, y=b; end, end