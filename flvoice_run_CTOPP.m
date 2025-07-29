function flvoice_run_CTOPP(varargin)
% FLVOICE_RUN runs modified CTOPP sessions: Nonword Repetition (NR) or
% Memory for Digits (MD) tests
%
% USE SUBJECT ID "PRAC" FOR PRACTICE RUNS OF ALL SUBJECTS
%
% INPUT:
%    [audiopath]/[task]/desc-stimulus.txt           : INPUT list of stimulus NAMES W/ suffix
%    [audiopath]/[task]/desc-stimulus_prac.txt      : same as above, for practice trials
%    [audiopath]/[task]/desc-conditions.txt         : INPUT list of correct answers (numbers or nonwords)
%    [audiopath]/[task]/desc-conditions_prac.txt    : same as above, for practice trials
%    [audiopath]/[task]                             : path for audio stimulus files (.wav)
%    The above should match names in stimulus.txt
%
%    NOTE that for both NR and MD, stimulus/condition list should have same lengths.
% 
% OUTPUT:
%    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-audio.mat        : OUTPUT audio data (see FLVOICE_IMPORT for format details) 
%
% AUDIO RECORDING SEQUENCE (without scanning): (repeat for each trial)
%
% |                              |------ RECORDING ----------------------------(<=D3)---|          
% |- PLAY SOUND STIMULUS ---|      |                  |----SUBJECT SPEECH-----|           |    |- SOUND STIMULUS (next trial) 
% |   stimulus time         |      |  reaction time   |  production duration  |           |    |   stimulus time ...   
% |                         |--D1--|                  |-------------------D2--------------|-D5-|
% |                         |      |------------------------------------(<=D3)------------|    |
% v                         |      v                  |                                        v 
% stimulus starts           v      GO signal          v                                        next stimulus starts 
%                           stimulus ends             voice onset              
%
%
% FLVOICE_RUN(option_name1, option_value1, ...)
% specifies additional options:
%       root                        : root directory [pwd]
%       audiopath                   : directory for audio stimuli [pwd/stimuli/audio]
%       subject                     : subject ID ['TEST01']
%       session                     : session number [1]
%       run                         : run number [1]
%       task                        : task name [''] (MUST select from 'nr' or 'md')
%       gender                      : subject gender ['unspecified']
%       scan                        : true/false include scanning segment in experiment sequence [0] 
%       timePostStim                : time (s) from end of the audio stimulus presentation to the GO signal (D1 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [.25 .75] 
%       timePostOnset               : time (s) from subject's voice onset to the scanner trigger (or to pre-stimulus segment, if scan=false) (D2 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [4.5] 
%       timeMax                     : maximum time (s) before GO signal and scanner trigger (or to pre-stimulus segment, if scan=false) (D3 in schematic above) (recording portion in a trial may end before this if necessary to start scanner) [6] 
%       timeScan                    : (if scan=true) duration (s) of scan (D4 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [1.6] 
%       timePreStim                 : time (s) from end of scan to start of next trial stimulus presentation (D5 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [.75] 
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

global FLAG_CONT_TO_NXT

% create structure to save experimental parameters
expParams=struct(...
    'root', 'C:\Users\splab\Documents\SEQ_SUB', ...
    'audiopath', fullfile(pwd, 'stimuli', 'audio'), ...
    'subject','TEST01',...
    'session', 1, ...
    'run', 1,...
    'task', '', ...
    'gender', 'unspecified', ...
    'scan', false, ...
    'timePostStim', [2 3],... % 'timePostStim', [0.25 0.75],...
    'timePostOnset', 9,...        % 'timePostOnset', 4.5,...
    'timeScan', 1.6,...
    'timePreStim', .75,...
    'timeMax', 12, ... % 'timeMax', 6, ... 
    'rmsThresh', .02,...
    'rmsBeepThresh', .1,...
    'rmsThreshTimeOnset', .02,...
    'rmsThreshTimeOffset', [.25 .25],...
    'prescan', true, ...
    'minVoiceOnsetTime', 0.4, ...
    'ipatDur', 4.75,...         %   prescan IPAT duration
    'smsDur', 7,...             %   prescan SMS duration
    'deviceMic','',...
    'deviceHead','',...
    'deviceScan','');

for n=1:2:numel(varargin)-1, 
    assert(isfield(expParams,varargin{n}),'unrecognized option %s',varargin{n});
    expParams.(varargin{n})=varargin{n+1};
end

ET = tic;
if ispc, [nill,host]=system('hostname');
else [nill,host]=system('hostname -f');
end
host=regexprep(host,'\n','');
expParams.computer = host;

if strcmp(host, '677-GUE-WL-0009')
    default_fontsize = 10;
else
    default_fontsize = 15;
end

try, a=audioDeviceReader('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strINPUT=[str{:}]; end;
audiodevreset;
info=audiodevinfo;
strOUTPUT={info.output.Name};

% Look for default input and output indices
ipind = find(contains(strINPUT, 'Analogue')&contains(strINPUT, 'Focusrite'));
opind = find(contains(strOUTPUT, 'Speakers')&contains(strOUTPUT, 'Focusrite'));
tgind = 1;%find(contains(strOUTPUT, 'Playback')&contains(strOUTPUT, 'Focusrite'));

% GUI for user to modify options
fnames=fieldnames(expParams);
fnames=fnames(~ismember(fnames,{'root', 'audiopath', 'subject', 'session', 'run', 'task', 'gender', 'scan', 'deviceMic','deviceHead','deviceScan'}));
for n=1:numel(fnames)
    val=expParams.(fnames{n});
    if ischar(val), fvals{n}=val;
    elseif isempty(val), fvals{n}='';
    else fvals{n}=mat2str(val);
    end
end

out_dropbox = {'root', 'audiopath', 'subject', 'session', 'run', 'task', 'gender', 'scan'};
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
uicontrol(thfig,'style','text','units','norm','position',[.1,.9,.8,default_width],'string','Experiment information:','backgroundcolor','w','fontsize',default_fontsize,'fontweight','bold');

ht_list = {};
for ind=1:size(out_dropbox,2)
    uicontrol(thfig,'style','text','units','norm','position',[.1,.75-(ind-2)*default_intvl,.35,default_width],'string',[out_dropbox{ind}, ':'],'backgroundcolor','w','fontsize',default_fontsize-1,'fontweight','bold','horizontalalignment','right');
    ht_list{ind} = uicontrol(thfig,'style','edit','units','norm','position',[.5,.75-(ind-2)*default_intvl,.4,default_width],'string', fvals_o{ind}, 'backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1,'callback',@thfig_callback3);
end

ht1=uicontrol(thfig,'style','popupmenu','units','norm','position',[.1,.75-8*default_intvl,.4,default_width],'string',fnames,'value',1,'fontsize',default_fontsize-1,'callback',@thfig_callback1);
ht2=uicontrol(thfig,'style','edit','units','norm','position',[.5,.75-8*default_intvl,.4,default_width],'string','','backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1,'callback',@thfig_callback2);

uicontrol(thfig,'style','text','units','norm','position',[.1,.75-9*default_intvl,.35,default_width],'string','Microphone:','backgroundcolor','w','fontsize',default_fontsize-1,'fontweight','bold','horizontalalignment','right');
ht3a=uicontrol(thfig,'style','popupmenu','units','norm','position',[.5,.75-9*default_intvl,.4,default_width],'string',strINPUT,'value',ipind,'backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1);

uicontrol(thfig,'style','text','units','norm','position',[.1,.75-10*default_intvl,.35,default_width],'string','Sound output:','backgroundcolor','w','fontsize',default_fontsize-1,'fontweight','bold','horizontalalignment','right');
ht3b=uicontrol(thfig,'style','popupmenu','units','norm','position',[.5,.75-10*default_intvl,.4,default_width],'string',strOUTPUT,'value',opind,'backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1);

ht3c0=uicontrol(thfig,'style','text','units','norm','position',[.1,.75-11*default_intvl,.35,default_width],'string','Scanner trigger:','backgroundcolor','w','fontsize',default_fontsize-1,'fontweight','bold','horizontalalignment','right');
ht3c=uicontrol(thfig,'style','popupmenu','units','norm','position',[.5,.75-11*default_intvl,.4,default_width],'string',strOUTPUT,'value',tgind,'backgroundcolor',1*[1 1 1],'fontsize',default_fontsize-1);

uicontrol(thfig,'style','pushbutton','string','Start','units','norm','position',[.1,.01,.38,.10],'callback','uiresume','fontsize',default_fontsize-1);
uicontrol(thfig,'style','pushbutton','string','Cancel','units','norm','position',[.51,.01,.38,.10],'callback','delete(gcbf)','fontsize',default_fontsize-1);
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
expParams.deviceScan=strOUTPUT{get(ht3c,'value')};
delete(thfig);
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

if strcmp(expParams.task,'')
    disp('Please specify task name [nr: nonword repetition / md: memory for digits]')
    return
end

% locate files
filepath = fullfile(expParams.root, sprintf('sub-%s',expParams.subject), sprintf('ses-%d',expParams.session),'beh', expParams.task);
mkdir(filepath)

if strcmp(expParams.subject, 'PRAC') % practice runs
    Input_audname  = fullfile(expParams.audiopath, expParams.task, 'desc-stimulus_prac.txt');
    Input_condname  = fullfile(expParams.audiopath, expParams.task, 'desc-conditions_prac.txt');
else % actual runs
    Input_audname  = fullfile(expParams.audiopath, expParams.task, 'desc-stimulus.txt');
    Input_condname  = fullfile(expParams.audiopath, expParams.task, 'desc-conditions.txt');
end

Output_name = fullfile(filepath,sprintf('sub-%s_ses-%d_run-%d_task-%s_desc-audio.mat',expParams.subject, expParams.session, expParams.run, expParams.task));
assert(~isempty(dir(Input_audname)), 'unable to find input file %s',Input_audname);
if ~isempty(dir(Output_name))&&~isequal('Yes - overwrite', questdlg(sprintf('This subject %s already has an data file for this ses-%d_run-%d (task: %s), do you want to over-write?', expParams.subject, expParams.session, expParams.run, expParams.task),'Answer', 'Yes - overwrite', 'No - quit','No - quit')), return; end
% read audio files and condition labels
Input_files=regexp(fileread(Input_audname),'[\n\r]+','split');
Input_files_temp=Input_files(cellfun('length',Input_files)>0);
Input_files=arrayfun(@(x)fullfile(expParams.audiopath, expParams.task, x), Input_files_temp);
ok=cellfun(@(x)exist(x,'file'), Input_files);
assert(all(ok), 'unable to find files %s', sprintf('%s ',Input_files{~ok}));
[Input_sound,Input_fs]=cellfun(@audioread, Input_files,'uni',0);

if isempty(dir(Input_condname))
    [nill,Input_conditions]=arrayfun(@fileparts,Input_files,'uni',0);
else
    Input_conditions=regexp(fileread(Input_condname),'[\n\r]+','split');
    Input_conditions=Input_conditions(cellfun('length',Input_conditions)>0);
    assert(numel(Input_files)==numel(Input_conditions),'unequal number of lines/trials in %s (%d) and %s (%d)',Input_audname, numel(Input_files), Input_condname, numel(Input_conditions));
end
expParams.numTrials = length(Input_conditions); % pull out the number of trials from the stimList

Input_duration=cellfun(@(a,b)numel(a)/b, Input_sound, Input_fs);
meanInput_duration=mean(Input_duration(Input_duration>0));
[Input_sound{Input_duration==0}]=deal(zeros(ceil(44100*meanInput_duration),1)); % fills empty audiofiles with average-duration silence ('NULL' CONDITIONS)
[Input_fs{Input_duration==0}]=deal(44100);
[Input_conditions{Input_duration==0}]='NULL';

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
    disp(char(arrayfun(@(n)sprintf('Device #%d: %s ',n,info.output(n).Name),1:numel(info.output),'uni',0)));
    if isempty(expParams.deviceHead),
        ID=input('HEADPHONES output device # : ');
        expParams.deviceMic=strOUTPUT{ID};
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
stimID=info.output(ID).ID;
beepPlayer = audioplayer(twav, tfs, 24, info.output(ID).ID);
if expParams.scan,
    if ~ismember(expParams.deviceScan, strOUTPUT), expParams.deviceScan=strOUTPUT{find(strncmp(lower(expParams.deviceScan),lower(strOUTPUT),numel(expParams.deviceScan)),1)}; end
    assert(ismember(expParams.deviceScan, strOUTPUT), 'unable to find match to deviceScan name %s',expParams.deviceScan);
    [ok,ID]=ismember(expParams.deviceScan, strOUTPUT);
    [twav, tfs] = audioread(fullfile(fileparts(which(mfilename)),'flvoice_run_trigger.wav')); % read in sine wav file to trigger the scanner
    triggerPlayer = audioplayer(twav, tfs, 24, info.output(ID).ID);
end

% checks values of timing variables
assert(all(isfinite(expParams.timePostStim))&ismember(numel(expParams.timePostStim),[1,2]), 'timePostStim field must have one or two elements');
assert(all(isfinite(expParams.timePostOnset))&ismember(numel(expParams.timePostOnset),[1,2]), 'timePostOnset field must have one or two elements');
assert(all(isfinite(expParams.timeScan))&ismember(numel(expParams.timeScan),[1,2]), 'timeScan field must have one or two elements');
assert(all(isfinite(expParams.timePreStim))&ismember(numel(expParams.timePreStim),[1,2]), 'timePreStim field must have one or two elements');
assert(all(isfinite(expParams.timeMax))&ismember(numel(expParams.timeMax),[1,2]), 'timeMax field must have one or two elements');
if numel(expParams.timePostStim)==1, expParams.timePostStim=expParams.timePostStim+[0 0]; end
if numel(expParams.timePostOnset)==1, expParams.timePostOnset=expParams.timePostOnset+[0 0]; end
if numel(expParams.timeScan)==1, expParams.timeScan=expParams.timeScan+[0 0]; end
if numel(expParams.timePreStim)==1, expParams.timePreStim=expParams.timePreStim+[0 0]; end
if numel(expParams.timeMax)==1, expParams.timeMax=expParams.timeMax+[0 0]; end
expParams.timePostStim=sort(expParams.timePostStim);
expParams.timePostOnset=sort(expParams.timePostOnset);
expParams.timeScan=sort(expParams.timeScan);
expParams.timePreStim=sort(expParams.timePreStim);
expParams.timeMax=sort(expParams.timeMax);
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
nexttrl=uicontrol(rtfig,'style','pushbutton','string','Finish this trial','units','norm','position',[.6,.01,.31,.05],'callback',@nxtTrial,'fontsize',default_fontsize-1);
set(nexttrl,'visible','off');

% set up picture display
annoStr = setUpVisAnnot_HW();
    
pause(1);
CLOCK=[];                               % Main clock (not yet started)

save(Output_name, 'expParams');

%Initialize trialData structure
trialData = struct;

set(annoStr.Plus, 'Visible','on');

%% LOOP OVER ACTUAL TRIALS
correct = [];
comments = '';
for ii = 1:length(Input_files) 

    FLAG_CONT_TO_NXT = 0;    

    % set up trial (see subfunction at end of script)
    %[trialData, annoStr] = setUpTrial(expParams, annoStr, stimName, condition, trialData, ii);
    % print progress to window
    fprintf('\nRun %d, trial %d/%d, Stimulus: <strong> %s </strong>\n', expParams.run, ii, expParams.numTrials, Input_conditions{ii});
    correct_ext = [nan nan nan correct];
    Recent_history = [correct_ext(length(correct_ext)-2:length(correct_ext))]
    trialData(ii).stimName = Input_files{ii};
    trialData(ii).condLabel = Input_conditions{ii};
%     trialData(ii).timeStim = numel(Input_sound{ii})/Input_fs{ii}; 
    trialData(ii).timeStim = size(Input_sound{ii},1)/Input_fs{ii}; 
    trialData(ii).timePostStim = expParams.timePostStim(1) + diff(expParams.timePostStim).*rand; 
    trialData(ii).timePostOnset = expParams.timePostOnset(1) + diff(expParams.timePostOnset).*rand; 
    trialData(ii).timeScan = expParams.timeScan(1) + diff(expParams.timeScan).*rand; 
    trialData(ii).timePreStim = expParams.timePreStim(1) + diff(expParams.timePreStim).*rand; 
    trialData(ii).timeMax = expParams.timeMax(1) + diff(expParams.timeMax).*rand; 
    stimPlayer = audioplayer(Input_sound{ii},Input_fs{ii}, 24, stimID);
    SpeechTrial=~strcmp(trialData(ii).condLabel,'NULL');

    % set up variables for audio recording and voice detection
    prepareScan=0.250*(expParams.scan~=0); % if scanning, end recording 250ms before scan trigger
    recordLen= trialData(ii).timeMax-prepareScan; % max total recording time
    nSamples = ceil(recordLen*expParams.sr);
    time = 0:1/expParams.sr:(nSamples-1)/expParams.sr;
    recAudio = zeros(nSamples,1);       % initialize variable to store audio
    nMissingSamples = 0;                % cumulative n missing samples between frames
    beepDetected = 0;
    voiceOnsetDetected = 0;             % voice onset not yet detected
    frameCount = 1;                     % counter for # of frames (starting at first frame)
    endIdx = 0;                         % initialize idx for end of frame
    voiceOnsetState = [];
    beepOnsetState = [];
        
    % set up figure for real-time plotting of audio signal of next trial
    set(micTitle,'string',sprintf('%s run %d trial %d condition:           %s', expParams.subject, expParams.run, ii, trialData(ii).condLabel));
        
    if isempty(CLOCK),TIME_TRIAL_START=0;end
    %t = timer;
    %t.StartDelay = 0.050;   % Delay between timer start and timer function
    %t.TimerFcn = @(myTimerObj, thisEvent)play(beepPlayer); % Timer function plays GO signal
    setup(deviceReader) % note: moved this here to avoid delays in time-sensitive portion

    if isempty(CLOCK)
        CLOCK = ManageTime('start');                        % resets clock to t=0 (first-trial start-time)
        TIME_TRIAL_START = 0;
    else % note: THIS IS TIME LANDMARK #1: BEGINNING OF STIMULUS PRESENTATION: at this point the code will typically wait for ...???
        ok=ManageTime('wait', CLOCK, TIME_TRIAL_START);     % waits for next-trial start-time
%         if ~ok, fprintf('i am late for this trial stimulus presentation time\n'); end
    end
    play(stimPlayer);
    TIME_TRIAL_ACTUALLYSTART=ManageTime('current', CLOCK); % actual time stimulus starts
    TIME_STIM_END = TIME_TRIAL_ACTUALLYSTART + trialData(ii).timeStim;           % stimulus ends
    TIME_GOSIGNAL_START = TIME_STIM_END + trialData(ii).timePostStim;          % GO signal time
    disp('playing stimulus...')
    figure(rtfig)
    set(micLine,'visible','off');drawnow;
        
    ok=ManageTime('wait', CLOCK, TIME_GOSIGNAL_START);     % waits for GO signal time
    [nill, nill] = deviceReader(); % note: this line may take some random initialization time to run; audio signal start (t=0) will be synchronized to the time when this line finishes running
    play(beepPlayer)
    disp('recording Response...')
    set(annoStr.Plus, 'color','g');drawnow;
    set(nexttrl,'visible','on'); 
    TIME_GOSIGNAL_ACTUALLYSTART=ManageTime('current', CLOCK); % actual time for GO signal 
    TIME_VOICE_START = TIME_GOSIGNAL_ACTUALLYSTART + nonSpeechDelay;                   % expected voice onset time
    TIME_SCAN_START = TIME_GOSIGNAL_ACTUALLYSTART + trialData(ii).timeMax;



    while endIdx < nSamples && ~FLAG_CONT_TO_NXT
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
            trialData(ii).beepTime = beepTime;

            % look for voice onset in previous onsetWindow
            [voiceOnsetDetected, voiceOnsetTime, voiceOnsetState]  = detectVoiceOnset(recAudio(begIdx+numOverrun:endIdx+numOverrun), expParams.sr, expParams.rmsThreshTimeOnset, rmsThresh, minVoiceOnsetTime, voiceOnsetState);
            % update voice onset time based on index of data passed to voice onset function

            if voiceOnsetDetected
                voiceOnsetTime = voiceOnsetTime + (begIdx+numOverrun)/expParams.sr - beepTime;
                TIME_VOICE_START = TIME_GOSIGNAL_ACTUALLYSTART + voiceOnsetTime; % note: voiceonsetTime marks the beginning of the minThreshTime window
                nonSpeechDelay = .5*nonSpeechDelay + .5*voiceOnsetTime;  % running-average of voiceOnsetTime values, with alpha-parameter = 0.5 (nonSpeechDelay = alpha*nonSpeechDelay + (1-alph)*voiceOnsetTime; alpha between 0 and 1; alpha high -> slow update; alpha low -> fast update)
                TIME_SCAN_START =  TIME_VOICE_START + trialData(ii).timePostOnset;
                nSamples = min(nSamples, ceil((TIME_SCAN_START-TIME_GOSIGNAL_ACTUALLYSTART-prepareScan)*expParams.sr)); % ends recording 250ms before scan time (or timeMax if that is earlier)
                % add voice onset to plot
                set(micLine,'value',voiceOnsetTime + beepTime,'visible','on');
                drawnow update
            end

        end

        frameCount = frameCount+1;

    end
    
    set(nexttrl,'visible','off'); 
    commandwindow

    if SpeechTrial && voiceOnsetDetected == 0, fprintf('warning: voice was expected but not detected (rmsThresh = %f)\n',rmsThresh); end
    release(deviceReader); % end recording
    set(annoStr.Plus, 'color','w');drawnow;
    %stop(t);
    %delete(t);

    %% save voice onset time and determine how much time left before sending trigger to scanner
    if voiceOnsetDetected == 0 %if voice onset wasn't detected
        trialData(ii).onsetDetected = 0;
        trialData(ii).voiceOnsetTime = NaN;
        trialData(ii).nonSpeechDelay = nonSpeechDelay;
    else
        trialData(ii).onsetDetected = 1;
        trialData(ii).voiceOnsetTime = voiceOnsetTime;
        trialData(ii).nonSpeechDelay = NaN;
    end

    TIME_SCAN_ACTUALLYSTART=nan;
    TIME_SCAN_END = nan;
%     NEXTTRIAL = TIME_SCAN_START + trialData(ii).timePreStim;

    trialData(ii).timingTrial = [TIME_TRIAL_START; TIME_TRIAL_ACTUALLYSTART; TIME_GOSIGNAL_START; TIME_GOSIGNAL_ACTUALLYSTART; TIME_VOICE_START; TIME_SCAN_START; TIME_SCAN_ACTUALLYSTART; TIME_SCAN_END]; % note: we also prefer to record absolute times for analyses of BOLD signal
%     TIME_TRIAL_START = NEXTTRIAL; 

    % % adapt rmsThresh
    % if 1, %isfield(expParams,'voiceCal')&&expParams.voiceCal.threshType == 1
    %     if SpeechTrial   % If the current trial is not a baseline trial
    %         rmsFF=.90; winDur=.002; winSize=ceil(winDur*expParams.sr); % note: match rmsFF and rmsFrameDur values to those in detectVoiceOnset.m
    %         rms=sqrt(mean(reshape(recAudio(1:floor(nSamples/winSize)*winSize),winSize,[]).^2,1));
    %         rms=filter(1,[1 -rmsFF],(1-rmsFF)*rms); % note: just like "rms(1)=0+(1-rmsFF)*rms(1); for n=2:numel(rms), rms(n)=rmsFF*rms(n-1)+(1-rmsFF)*rms(n); end"
    %         if  voiceOnsetDetected    % voice onset detected
    %             minRms = prctile(rms,10);
    %             maxRms = prctile(rms(max(1,ceil(voiceOnsetTime/winDur)):end),90);
    %         else
    %             minRms = 0;
    %             maxRms = prctile(rms,90);
    %         end
    %         tmpRmsThresh = minRms + (maxRms-minRms)/10;
    %         rmsThresh = .9*rmsThresh + .1*tmpRmsThresh;
    %     end
    % end

    %% save for each trial
    trialData(ii).s = recAudio(1:nSamples);
    trialData(ii).fs = expParams.sr;
    if SpeechTrial&&voiceOnsetDetected, trialData(ii).reference_time = voiceOnsetTime;
    else trialData(ii).reference_time = nonSpeechDelay;
    end
    trialData(ii).percMissingSamples = (nMissingSamples/(recordLen*expParams.sr))*100;
    this_correct = 9;
    while this_correct ~= 0 && this_correct ~= 1
        this_correct = input('Correct? [1/0]');
        if isempty(this_correct);this_correct=9;end
    end
    
    TIME_RESULT_RECORDED = ManageTime('current', CLOCK);
    NEXTTRIAL = TIME_RESULT_RECORDED + trialData(ii).timePreStim;
    TIME_TRIAL_START = NEXTTRIAL; 

    trialData(ii).correct = this_correct;
    correct = [correct this_correct];

    if length(correct) >= 3 && sum(correct(length(correct)-2:length(correct))) == 0
        fprintf('\n<strong>3 errors in a row detected.</strong>');
        confirm = input('\nProceed with decision: [C]hange previous logs/[E]Exit\n', 's');
        if confirm == 'c' || confirm == 'C'
            fprintf('For trial %d ~ %d: %s, %s, %s\n', ii-2, ii, Input_conditions{ii-2}, Input_conditions{ii-1}, Input_conditions{ii});
            over=false;
            while ~over
                new_results = input('new results e.g., "[0 1 0]", w/o quotes:');
                for j = 1:3
                    index = ii - 3 + j;
                    if new_results(j) ~= 0 && new_results(j) ~= 1, break; end
                    if new_results(j)
                        correct(length(correct)-3+j) = 1;
                        comments = strcat(comments, 'Results changed for trial ', int2str(index), ' from 0 to 1. ');
                    end
                    if j == 3, over=true; end
                end
            end
        else
            tData = trialData(ii);
            fName_trial = fullfile(filepath,sprintf('sub-%s_ses-%d_run-%d_task-%s_trial-%d.mat',expParams.subject, expParams.session, expParams.run, expParams.task,ii));
            save(fName_trial,'tData');
            break
        end
    end

    %JT save update test 8/10/21
    % save only data from current trial
    tData = trialData(ii);

    % fName_trial will be used for individual trial files (which will
    % live in the run folder)
    fName_trial = fullfile(filepath,sprintf('sub-%s_ses-%d_run-%d_task-%s_trial-%d.mat',expParams.subject, expParams.session, expParams.run, expParams.task,ii));
    save(fName_trial,'tData');
end

newcom = input('Type any additional comments:', 's');
comments = strcat(comments, 'Operator comments: ', newcom);

save(Output_name, 'expParams', 'trialData', 'correct', 'comments');
fprintf('Test %s completed with score %d', expParams.task, sum(correct));


%% end of experiment
close all

% experiment time
expParams.elapsed_time = toc(ET)/60;    % elapsed time of the experiment
fprintf('\nElapsed Time: %f (min)\n', expParams.elapsed_time)

% % number of trials with voice onset detected
% onsetCount = nan(expParams.numTrials,1);
% for j = 1: expParams.numTrials
%     onsetCount(j) = trialData(j).onsetDetected;
% end
% numOnsetDetected = sum(onsetCount);    
% 
% fprintf('Voice onset detected on %d/%d trials', numOnsetDetected, expParams.numTrials);
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
    
    if state.count >= onDur*Fs/Incr, 
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

function nxtTrial(src, event)
    global FLAG_CONT_TO_NXT
    FLAG_CONT_TO_NXT = 1;
end



