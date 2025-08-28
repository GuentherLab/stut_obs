function flvoice_run(varargin)
close all;

CMRR = true;

% set priority for matlab to high for running experiments
system(sprintf('wmic process where processid=%d call setpriority "high priority"', feature('getpid')));

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
% specifies additional options:
%       visual                      : type of visual presentation ['figure']
%       root                        : root directory [pwd]
%       textpath                    : directory for audio stimuli [pwd/stimuli/text/Adults]
%       figurespath                 : directory for visual stimuli [pwd/stimuli/figures/Adults]
%       subject                     : subject ID ['TEST01']
%       session                     : session number [1]
%       run                         : run number [1]
%       task                        : task name ['jackson20']
%       gender                      : subject gender ['unspecified']
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

if strcmp(host, '677-GUE-WL-0009')
    default_fontsize = 10;
else
    default_fontsize = 15;
end

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
function preCall1(varargin)
    [fileName, filePath] = uigetfile('./config/*.json', 'Select .json file');
    fileFull = [filePath fileName];
    if isequal(fileName,0)
        return
    else
        set(prePath, 'String', fileFull);
    end
end

% checks if file paths exist
function preCall2(varargin)
    path = get(prePath, 'String');
    assert(~isempty(dir(path)), 'unable to find input file %s',path);
    if ~isempty(dir(path))
        expRead=spm_jsonread(path);
        uiresume;
        preFlag = true;
    end
end

delete(presfig);

% create structure to save experimental parameters
if preFlag
    expParams = expRead;
else % if no preset config file defined
    expParams=struct(...
        'visual', 'orthography', ...
        'root', 'C:\ieeg_stut', ...
        'textpath', fullfile(pwd, 'stimuli', 'text'), ...
        'subject','sub-example',...
        'session', 1, ...
        'run', 1,...
        'task', 'jackson20', ...
        'scan', true, ...
        'gender', 'unspecified', ...
        'repetitions_per_qa_per_block', 1, ...
        'shuffle_within_block', true, ...
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
        'rectColor', [0 1 0] ...      % RGB color of rectangle [R G B] (0-1 scale)
        );
end

expParams.computer = host;

for n=1:2:numel(varargin)-1, 
    assert(isfield(expParams,varargin{n}),'unrecognized option %s',varargin{n});
    expParams.(varargin{n})=varargin{n+1};
end

try, a=audioDeviceReader('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strINPUT=[str{:}]; end;
try, a=audioDeviceWriter('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strOUTPUT=[str{:}]; end;

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

strVisual={'orthography'};

% GUI for user to modify options
fnames=fieldnames(expParams);
fnames=fnames(~ismember(fnames,{'visual', 'root', 'textpath', 'subject', 'session', 'run', 'task', 'gender',...
    'repetitions_per_qa_per_block','shuffle_within_block','show_question_orthography', 'scan', 'deviceMic','deviceHead','deviceScan'}));
for n=1:numel(fnames)
    val=expParams.(fnames{n});
    if ischar(val), fvals{n}=val;
    elseif isempty(val), fvals{n}='';
    else fvals{n}=mat2str(val);
    end
end

% expParams.condition_blocks = {'observed';'unobserved';'observed';'unobserved'}; % move these params to json config
expParams.condition_blocks = {'unobserved';'observed';'observed';'unobserved'}; % move these params to json config
% expParams.condition_blocks = {'unobserved'}; 
% expParams.condition_blocks = {'observed';'observed';'observed'};
% expParams.condition_blocks = {'unobserved';'unobserved';'unobserved'};
% expParams.condition_blocks = {'observed'}

out_dropbox = {'visual', 'root', 'textpath', 'subject', 'session', 'run', 'task', 'gender', 'scan'};
for n=1:numel(out_dropbox)
    val=expParams.(out_dropbox{n});
    if ischar(val), fvals_o{n}=val;
    elseif isempty(val), fvals_o{n}='';
    else fvals_o{n}=mat2str(val);
    end
end

default_width = 0.04; %0.08;
default_intvl = 0.05; %0.10;

thfig=dialog('units','norm','position',[.3,.3,.3,.5],'windowstyle','normal','name','FLvoice_run options','color','w','resize','on');
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
expParams.deviceMic=strINPUT{get(ht3a,'value')};
expParams.deviceHead=strOUTPUT{get(ht3b,'value')};

if expParams.scan % skip this assignment if we're not scanning; if focusrite is not connected, it generates error here
    expParams.deviceScan=strOUTPUT{get(ht3c,'value')};
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

CLOCKp = ManageTime('start');
TIME_PREPARE = 0.5; % Waiting period before experiment begin (sec)
set(annoStr.Stim, 'String', 'Preparing...');
set(annoStr.Stim, 'Visible','on');

% root path is where the subject description files are
filepath = [expParams.root, filesep, sprintf('sub-%s',expParams.subject), filesep, sprintf('ses-%d',expParams.session),...
    filesep, 'beh', filesep, expParams.task];
unique_answers_file  = fullfile(filepath,sprintf('sub-%s_ses-%d_run-%s_task-%s_qa-list.tsv',expParams.subject, expParams.session, expParams.runstring, expParams.task));
Output_name = fullfile(filepath,sprintf('sub-%s_ses-%d_run-%s_task-%s_desc-presentation.mat',expParams.subject, expParams.session, expParams.runstring, expParams.task));
if ~isempty(dir(Output_name))&&~isequal('Yes - overwrite',...
        questdlg(sprintf('This subject %s already has an data file for this ses-%d_run-%s (task: %s), do you want to over-write?',...
        expParams.subject, expParams.session, expParams.runstring, expParams.task),...
        'Answer', 'Yes - overwrite', 'No - quit','No - quit')), return; 
end

% read text files and condition labels
% % % % % % % % % % % % % % % % % Input_files=regexp(fileread(Input_textname),'[\n\r]+','split');



expParams.nblocks = length(expParams.condition_blocks); 
unique_qa = readtable(unique_answers_file,'FileType','text');
n_unique_qa = height(unique_qa); 
expParams.ntrials_per_block = n_unique_qa * expParams.repetitions_per_qa_per_block; 
expParams.ntrials = expParams.nblocks * expParams.ntrials_per_block;
celcol = cell(expParams.ntrials,1); 
trials = table([1:expParams.ntrials]', celcol,celcol, repelem(expParams.condition_blocks, expParams.ntrials_per_block, 1), 'VariableNames',...
                {'trialnum',    'question','answer', 'condition'} );


for iblock = 1:expParams.nblocks
    blockinds = 1 + expParams.ntrials_per_block*[iblock-1]  : expParams.ntrials_per_block*iblock; % trialinds within this block
    block_trials_qa = repmat(unique_qa, expParams.repetitions_per_qa_per_block, 1); % copy each word expParams.repetitions_per_qa_per_block times
    if expParams.shuffle_within_block
        block_trials_qa = block_trials_qa(randperm(height(block_trials_qa)), :); % shuffle within block
    end
    trials(blockinds,{'question','answer','stimfile'}) = block_trials_qa(:,{'question','answer','stimfile'}); % fill into trials for this block
    % % % % % % % % % % % % trials.condition(blockinds) = expParams.condition_blocks{iblock}; 
end



% % % % % % % % % % % % % % % % stimreads=cell(size(Input_files));
% % % % % % % % % % % % % % % % stimreads(NoNull) = cellfun(@(x)fileread(x),Input_files(NoNull),'uni',0);
sileread = dsp.AudioFileReader(fullfile(expParams.textpath, 'silent.wav'), 'SamplesPerFrame', 2048);

% % % % % % % if isempty(dir(Input_condname))
% % % % % % %     [nill,Input_conditions]=arrayfun(@fileparts,Input_files,'uni',0);
% % % % % % % else
% % % % % % %     Input_conditions=regexp(fileread(Input_condname),'[\n\r]+','split');
% % % % % % %     Input_conditions=Input_conditions(cellfun('length',Input_conditions)>0);
% % % % % % %     assert(numel(Input_files)==numel(Input_conditions),'unequal number of lines/trials in %s (%d) and %s (%d)',unique_answers_file, numel(Input_files), Input_condname, numel(Input_conditions));
% % % % % % % end
% % % % % % % expParams.ntrials = length(Input_conditions); % pull out the number of trials from the stimList

% create random number stream so randperm doesn't call the same thing everytime when matlab is opened
s = RandStream.create('mt19937ar','seed',sum(100*clock));
RandStream.setGlobalStream(s);

% set audio device variables: deviceReader: mic input; beepPlayer: beep output; triggerPlayer: trigger output
if isempty(expParams.deviceMic)
    disp(char(arrayfun(@(n)sprintf('Device #%d: %s ',n,strINPUT{n}),1:numel(strINPUT),'uni',0))); ID=input('MICROPHONE input device # : ');
    expParams.deviceMic=strINPUT{ID};
end
if ~ismember(expParams.deviceMic, strINPUT), expParams.deviceMic=strINPUT{find(strncmp(lower(expParams.deviceMic),lower(strINPUT),numel(expParams.deviceMic)),1)}; end
assert(ismember(expParams.deviceMic, strINPUT), 'unable to find match to deviceMic name %s',expParams.deviceMic);
if isempty(expParams.deviceHead)||(expParams.scan&&isempty(expParams.deviceScan))
    disp(char(arrayfun(@(n)sprintf('Device #%d: %s ',n,strOUTPUT{n}),1:numel(strOUTPUT),'uni',0)));
    if isempty(expParams.deviceHead),
        ID=input('HEADPHONES output device # : ');
        expParams.deviceHead=strOUTPUT{ID};
    end
    if expParams.scan&&isempty(expParams.deviceScan)
        ID=input('SCAN TRIGGER output device # : ');
        expParams.deviceScan=strOUTPUT{ID};
    end
end
% set up device reader settings for accessing audio signal during recording
expParams.sr = 48000;            % sample frequenct (Hz)
frameDur = .050;                 % frame duration in seconds
expParams.frameLength = expParams.sr*frameDur;      % framelength in samples
deviceReader = audioDeviceReader(...
    'Device', expParams.deviceMic, ...
    'SamplesPerFrame', expParams.frameLength, ...
    'SampleRate', expParams.sr, ...
    'BitDepth', '24-bit integer');

% set up sound output players
if ~ismember(expParams.deviceHead, strOUTPUT), expParams.deviceHead=strOUTPUT{find(strncmp(lower(expParams.deviceHead),lower(strOUTPUT),numel(expParams.deviceHead)),1)}; end
assert(ismember(expParams.deviceHead, strOUTPUT), 'unable to find match to deviceHead name %s',expParams.deviceHead);
[ok,ID]=ismember(expParams.deviceHead, strOUTPUT);
[twav, tfs] = audioread(fullfile(fileparts(which(mfilename)),'flvoice_run_beep.wav'));
beepdur = numel(twav)/tfs;

beepread = dsp.AudioFileReader(fullfile(fileparts(which(mfilename)),'flvoice_run_beep.wav'), 'SamplesPerFrame', 2048);
headwrite = audioDeviceWriter('SampleRate',beepread.SampleRate,'Device',expParams.deviceHead);

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

%% LOOP OVER TRIALS
for itrial = 1:expParams.ntrials

    fprintf('\nRun %s, trial %d/%d\n', expParams.runstring, itrial, expParams.ntrials);
    set(annoStr.Plus, 'Visible','on');

    % trial specific timing parameters with jitter on
    trialData(itrial).question = trials.question{itrial};
    trialData(itrial).condition = trials.condition{itrial};
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

    % print current and upcoming stimulus questions on command line for the investigator to read
    % print trial number and total trials
    if itrial ~= expParams.ntrials % if not last trial
        next_trial_string = ['\n\n      Next trial''s question/answer will be:\n ''', trials.question{itrial+1}, ''' /// ''', trials.answer{itrial+1}, ''''];
    elseif itrial == expParams.ntrials % if last trial
        next_trial_string = '';
    end
    fprintf([...
        '\nThis trial''s stimulus question: ''', trials.question{itrial}, '''', ...
        '\n      Answer = ''',trials.answer{itrial}, '''',...
        '\n\n      ........ Trial ', num2str(itrial), '/' num2str(expParams.ntrials), ', Run ', num2str(expParams.runstring), ...
        next_trial_string,...
        '\n      As you finish asking this trial''s question, please press Spacebar to start the anticipation period',...
        '\n']);


    SpeechTrial=~strcmp(trialData(itrial).condition,'NULL');


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
    set(micTitle,'string',sprintf('%s %s run %s trial %d condition: %s', expParams.subject, expParams.task, expParams.runstring, itrial, trialData(itrial).condition));
    setup(deviceReader) % note: moved this here to avoid delays in time-sensitive portion

    if isempty(CLOCK)
        CLOCK = ManageTime('start');                        % resets clock to t=0 (first-trial start-time)
        TIME_TRIAL_START = 0;
        TIME_STIM_START = 0;
    else
        TIME_TRIAL_START = ManageTime('current', CLOCK);
    end

    ok=ManageTime('wait', CLOCK, TIME_STIM_START);
    % start of the trial
    TIME_TEXT_ACTUALLYSTART = ManageTime('current', CLOCK);
    
    if ~ok, fprintf('i am late for this trial TIME_TRIAL_START\n'); end
    set(annoStr.Plus, 'Visible','off');        
    set(annoStr.Stim, 'color', 'w');
    
    % Check condition to determine what to display


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


    switch trials.condition{itrial}
        case 'unobserved'
            % TIME_SOUND_START = TIME_STIM_ACTUALLYSTART + trialData(ii).timePreSound;
            % ok=ManageTime('wait', CLOCK, TIME_SOUND_START - stimoffset);
            % ok=ManageTime('wait', CLOCK, TIME_SOUND_START);
            stim_q_file = [dirs.projrepo, filesep, 'stimuli', filesep,'audio', filesep, trials.stimfile{itrial}, '.mp3']; 
            [Input_sound, Input_fs] = audioread(stim_q_file); 
            % stimPlayer = audioplayer(Input_sound,Input_fs, 24, stimID);
            stimPlayer = audioplayer(Input_sound,Input_fs, 24);
            play(stimPlayer);
            % sttInd=1; endMax=size(Input_sound, 1); while sttInd<endMax; headwrite(Input_sound(sttInd:min(sttInd+2047, endMax))); sttInd=sttInd+2048; end; reset(headwrite);
            TIME_SOUND_ACTUALLYSTART = ManageTime('current', CLOCK);
            % while ~isDone(stimread); sound=stimread();headwrite(sound);end;release(stimread);reset(headwrite);
            %%% add code here to display the text files
            TIME_SOUND_END = TIME_SOUND_ACTUALLYSTART + trialData(itrial).timeStim;           % stimulus ends
            if ~ok, fprintf('i am late for this trial TIME_SOUND_START\n'); end
        case    'observed'

        otherwise 
            error('unrecognized behavioral task condition')
    end

    TIME_TEXT_END = TIME_TEXT_ACTUALLYSTART + trialData(itrial).timeStim;           % stimulus ends
    if ~ok, fprintf('i am late for this trial TIME_TEXT_END\n'); end

    TIME_GOSIGNAL_START = TIME_TEXT_END;          % GO signal time
    set(micLine,'visible','off');set(micLineB,'visible','off');drawnow;
        
    ok=ManageTime('wait', CLOCK, TIME_GOSIGNAL_START - beepoffset);     % waits for recorder initialization time
    [nill, nill] = deviceReader(); % note: this line may take some random initialization time to run; audio signal start (t=0) will be synchronized to the time when this line finishes running
    if ~ok, fprintf('i am late for this trial TIME_GOSIGNAL_START - beepoffset\n'); end
    
    ok=ManageTime('wait', CLOCK, TIME_GOSIGNAL_START);     % waits for GO signal time
    % GO signal goes with beep
    while ~isDone(beepread); sound=beepread();headwrite(sound);end;reset(beepread);reset(headwrite);
    set(annoStr.Plus, 'Visible','off'); % remove fixcross
    set(annoStr.Stim, 'Visible','off'); % remove stim question orthography if it's there (unobserved condition)
    set(annoStr.GoRect, 'Visible', 'on');  % <-- SHOW GREEN RECTANGLE

    TIME_GOSIGNAL_ACTUALLYSTART = ManageTime('current', CLOCK); % actual time for GO signal 
    if ~ok, fprintf('i am late for this trial TIME_GOSIGNAL_START\n'); end

    % reaction time
    TIME_VOICE_START = TIME_GOSIGNAL_ACTUALLYSTART + nonSpeechDelay;                   % expected voice onset time

    TIME_SCAN_START = TIME_GOSIGNAL_ACTUALLYSTART + SpeechTrial * trialData(itrial).timeMax + (1-SpeechTrial)*expParams.timeNULL;

    % if SpeechTrial (when condition not null), numSamples we record for
    % is nSamples else nSamplesNULL
    endSamples = SpeechTrial * nSamples + (1-SpeechTrial)*nSamplesNULL;
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

        % plot audio data
        set(micSignal, 'xdata',time, 'ydata',recAudio(1:numel(time)))
        drawnow()
    
        % voice onset exclusion
        minVoiceOnsetTime = max(0, expParams.minVoiceOnsetTime-(begIdx+numOverrun)/expParams.sr);
        
        % detect beep onset
        if SpeechTrial && beepDetected == 0 && expParams.minVoiceOnsetTime > (begIdx+numOverrun)/expParams.sr
            % look for beep onset
            [beepDetected, bTime, beepOnsetState]  = detectVoiceOnset(recAudio(begIdx+numOverrun:endIdx+numOverrun), expParams.sr, expParams.rmsThreshTimeOnset, rmsBeepThresh, 0, beepOnsetState);
            if beepDetected
                beepTime = bTime + (begIdx+numOverrun)/expParams.sr; 
                set(micLineB,'value',beepTime,'visible','on');
            end
        elseif SpeechTrial && voiceOnsetDetected == 0,% && frameCount > onsetWindow/frameDur
            if ~beepDetected; beepTime = 0; disp('Beep not detected. Assign beepTime = 0.'); end
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
                drawnow update
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
    if SpeechTrial && voiceOnsetDetected == 0, fprintf('warning: voice was expected but not detected (rmsThresh = %f)\n',rmsThresh); end
    release(deviceReader); % end recording
    
    % Hide stimulus regardless of condition
    set(annoStr.Stim, 'color','w');
    set(annoStr.Stim, 'Visible','off');
    % % % % % % % % % % % % set(annoStr.Plus, 'color','r');
    % % % % % % % % % % % % set(annoStr.Plus, 'Visible','on');

    % For observed condition, 
    % For unobserved condition, show the red fixation cross as normal


    if expParams.show_question_orthography
            set(annoStr.Stim, 'String', stimread);
            set(annoStr.Stim, 'Visible', 'On');
    elseif ~expParams.show_question_orthography % the fixation cross was never turned off
            % For observed condition, keep the white fixation cross
            set(annoStr.Plus, 'color','r');  
            set(annoStr.Plus, 'Visible','on');
    end


    set(annoStr.GoRect, 'Visible', 'off');  % <-- HIDE GREEN RECTANGLE

            

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
        if ~ok, fprintf('i am late for this trial TIME_SCAN_START\n'); end
        
        if SpeechTrial; intvs = [intvs TIME_SCAN_START - TIME_GOSIGNAL_START]; expParams.timeNULL = mean(intvs); end

        if isnan(trialData(itrial).voiceOnsetTime)
            expdur = trialData(itrial).timePreStim + trialData(itrial).timeStim + trialData(itrial).timeNoOnset + trialData(itrial).timeScan + 0.5 + nonSpeechDelay; % add the other average wait time if no onset
        else
            expdur = trialData(itrial).timePreStim + trialData(itrial).timeStim + voiceOnsetTime + trialData(itrial).timePostOnset + trialData(itrial).timeScan + 0.5;
        end
        fprintf('\nThis trial elapsed Time: %.3f (s), expected duration: %.3f (s)\n', NEXTTRIAL - TIME_STIM_START, expdur);
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
    if SpeechTrial&&voiceOnsetDetected, trialData(itrial).reference_time = voiceOnsetTime;
    else trialData(itrial).reference_time = nonSpeechDelay;
    end
    trialData(itrial).percMissingSamples = (nMissingSamples/(recordLen*expParams.sr))*100;

    %JT save update test 8/10/21
    % save only data from current trial
    tData = trialData(itrial);

    % fName_trial will be used for individual trial files (which will
    % live in the run folder)
    fName_trial = fullfile(filepath,sprintf('sub-%s_ses-%d_run-%s_task-%s_trial-%d.mat',expParams.subject, expParams.session, expParams.runstring, expParams.task,itrial));
    save(fName_trial,'tData');
end

release(headwrite);
release(beepread);
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

        

