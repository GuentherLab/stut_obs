function testMicHeadphones(varargin)
close all;
% varargin:
% "type" : '20s' or 'regular'
% 
% set priority for matlab to high for running experiments
system(sprintf('wmic process where processid=%d call setpriority "high priority"', feature('getpid')));

HW_testing = false;

beepoffset = 0.100;
num_run_digits = 2; % number of digits to include in run number labels in filenames; probably should be 2
default_fontsize = 12;

% INPUT:
%    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-stimulus.txt     : INPUT list of stimulus NAMES W/O suffix (one trial per line; enter the string NULL or empty audiofiles for NULL -no speech- conditions)
%    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-conditions.txt   : (optional) INPUT list of condition labels (one trial per line)
%                                                                                                                     if unspecified, condition labels are set to stimulus filename
%    [audiopath]/[task]/                       : path for audio stimulus files (.wav)
%    [figurespath]/                            : path for image stimulus files (.png) [if any]
%    The above should match names in stimulus.txt
%
% OUTPUT:
%    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-audio.mat        : OUTPUT audio data (see FLVOICE_IMPORT for format details) 
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
%       subject                     : subject ID ['TEST01']
%       session                     : session number [1]
%       run                         : run number [1]
%       task                        : task name ['jackson20']
%       scan                        : true/false include scanning segment in experiment sequence [1] 
%       timePostOnset               : time (s) from subject's voice onset to the scanner trigger (or to pre-stimulus segment, if scan=false) (D2 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [4.5] 
%       timeMax                     : maximum time (s) between GO signal and scanner trigger (or to pre-stimulus segment, if scan=false) (D3 in schematic above) (recording portion in a trial may end before this if necessary to start scanner) [5.5] 
%       timeMaxBaseline             : duration range (s) between 'GO onset' [trial start] and scan start for baseline trials
%       timeScan                    : (if scan=true) duration (s) of scan (D4 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [1.6] 
%       timePreStim                 : time (s) from end of scan to start of next trial stimulus presentation (D5 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [.25] 
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

%% load config parameters from file
close all force; ET = tic;
[dirs, host] = set_paths_stut_obs(); % set project paths and get computer name

% set priority for matlab to high for running experiments
system(sprintf('wmic process where processid=%d call setpriority "high priority"', feature('getpid')));

% select json files
preFlag = false;
expRead = {};

% if only 1 varargin was provided and it's not an empty string, treat it as the name of a config file in the config dir
if numel(varargin) == 1 && ~isempty(varargin{1})
    config_file = [dirs.config, filesep, varargin{1}, '.json']; 
    assert(exist(config_file), 'unable to find input config file %s',config_file);
    expRead=spm_jsonread(config_file);
else % if no config filename provided, open menu to select one
    presfig=dialog('units','norm','position',[.3,.3,.3,.1],'windowstyle','normal','name','Load preset parameters','color','w','resize','on');
    uicontrol(presfig,'style','text','units','norm','position',[.05, .475, .6, .35],...
        'string','Select preset exp config file (.json):','backgroundcolor','w','fontsize',default_fontsize-2,'fontweight','bold','horizontalalignment','left');
    prePath=uicontrol('Style', 'edit','Units','norm','FontUnits','norm','FontSize',0.5,'HorizontalAlignment', 'left','Position',[.55 .55 .3 .3],'Parent',presfig);
    preBrowse=uicontrol('Style', 'pushbutton','String','Browse','Units','norm','FontUnits','norm','FontSize',0.5,...
        'Position',[.85 .55 .15 .3],'Parent',presfig, 'Callback',@preCall1);
    preConti=uicontrol('Style', 'pushbutton','String','Continue','Units','norm','FontUnits','norm','FontSize',0.5, ...
        'Position',[.3 .12 .15 .3],'Parent',presfig, 'Callback',@preCall2);
    preSkip=uicontrol('Style', 'pushbutton','String','Skip','Units','norm','FontUnits','norm','FontSize',0.5,...
        'Position',[.55 .12 .15 .3],'Parent',presfig, 'Callback','uiresume');
    
    uiwait(presfig);
    ok=ishandle(presfig);
    if ~ok, return; end
    delete(presfig);
end


% function that gets json files
function preCall1(varargin)
    [fileName, filePath] = uigetfile([dirs.config, filesep, '*.json'], 'Select .json file'); 
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
    assert(~isempty(dir(path)), 'unable to find input config file %s',path);
    if ~isempty(dir(path))
        expRead=spm_jsonread(path);
        uiresume;
        preFlag = true;
    end
end


%% make expParams parameters structure, look for audio devices
% create structure to save experimental parameters
if preFlag
    expParams = expRead;
else % if no preset config file defined
    expParams=struct(...
        'root', 'C:\ieeg_stut', ...
        'subject','example',...
        'session', 1, ...
        'run', 1,...
        'scan', true, ...
        'play_question_audio_stim',false,... % play (unobserved condition) or don't play (observed condition) the audio quesiton stim
        'repetitions_per_unique_qa', 2, ...
        'shuffle_qa_order', true, ... % specifically affects stim order, not baseline trials
        'max_unique_qa_repeats',2, ... % max consecutive repeats of a given QA stim, before baseline trials are mixed in
        'baseline_trials_proportion',0.5,... % proportion of all trials that are baseline trials
        'baseline_trials_evenly_spaced',true,.... % whether baseline trals are evenly spaced or shuffled
        'max_basetrial_repeats',2,... % don't let there be more than this many no-speech trials in row
        'cover_camera_when_nospeech',true, ... % cover the left side of screen w/ figure where camera is outside of speech epochs
        'show_question_orthography', false, ...
        'timeStim', [3 3.5],...
        'timePostOnset', 3.5,...
        'timePreStim', 0.5,...
        'timeMax', 6.5, ...
        'timeMaxBaseline', [5.5 6.5],... % duration range (s) between 'GO onset' [trial start] and scan start for baseline trials
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
        'deviceMic','Analogue 1 + 2 (2- Focusrite USB Audio)',... % subject microphone
        'deviceHead','Speakers (2- Focusrite USB Audio)', ... % audio output to subject (headphones or speaker)
        'deviceScan','Playback 3 + 4 (2- Focusrite USB Audio)', ... % audio channel to send triggers to scanner
        'rectWidthProp', 0.8, ...      % rectangle width as proportion of screen width
        'rectHeightProp', 0.6, ...     % rectangle height as proportion of screen height  
        'rectColor', [0 1 0], ...      % RGB color of rectangle [R G B] (0-1 scale)
        'task', 'jackson20' ...
        );
end

expParams.computer = host;
expParams.audio_common_path = dirs.audio_common; % for audio stim shared across subjects
expParams.recordingToScanBuffer = 0.25; % end the audio recording of subject mic this early (sec) to give buffer before scan trigger
expParams.type = 'regular';
expParams.proj = '';

for n=1:2:numel(varargin)-1, 
    assert(isfield(expParams,varargin{n}),'unrecognized option %s',varargin{n});
    expParams.(varargin{n})=varargin{n+1};
end

if strcmp(expParams.type, '20s')
    expParams.timePostOnset = 20;
    expParams.timeMax = 20;
elseif ~strcmp(expParams.type, 'regular')
    disp('Unrecognized test type (should be "20s" or "regular")');
end

try, a=audioDeviceReader('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strINPUT=[str{:}]; end;
% audiodevreset;
% info=audiodevinfo;
% strOUTPUT={info.output.Name};
try, a=audioDeviceWriter('Device','asdf'); catch me; str=regexp(regexprep(me.message,'.*Valid values are:',''),'"([^"]*)"','tokens'); strOUTPUT=[str{:}]; end;

% Look for default input and output indices
if HW_testing
    ipind = 1;
    opind = 2;
    tgind = 1;
    %expParams.audiopath = '/Users/leon/Documents/GitHub/SEQ-SUB/stimuli';
else
    ipind = find(contains(strINPUT, 'Analogue')&contains(strINPUT, 'Focusrite'));
    opind = find(contains(strOUTPUT, 'Speakers')&contains(strOUTPUT, 'Focusrite'));
    tgind = find(contains(strOUTPUT, 'Playback')&contains(strOUTPUT, 'Focusrite'));
end



expParams.deviceMic=strINPUT{ipind};
expParams.deviceHead=strOUTPUT{opind};
expParams.deviceScan=strOUTPUT{tgind};

% visual setup
if expParams.show_question_orthography
    annoStr = setUpVisAnnot_HW([1 1 1]);
else
    annoStr = setUpVisAnnot_HW([0 0 0]);
end

CLOCKp = ManageTime('start');
TIME_PREPARE = 0.5; % Waiting period before experiment begin (sec)
set(annoStr.Stim, 'String', 'Preparing...');
set(annoStr.Stim, 'Visible','on');



audiofile = [dirs.audio_common, filesep, 'q_female_name.mp3'];
[Input_sound{1}, Input_fs{1}]=audioread(audiofile);
Input_conditions = {'unobserved'};


stimreads{1}=dsp.AudioFileReader(audiofile, 'SamplesPerFrame', 2048);
sileread = dsp.AudioFileReader([expParams.audio_common_path, filesep, 'silent.wav'], 'SamplesPerFrame', 2048);

expParams.numTrials = length(Input_conditions); % pull out the number of trials from the stimList


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
    %disp(char(arrayfun(@(n)sprintf('Device #%d: %s ',n,info.output(n).Name),1:numel(info.output),'uni',0)));
    disp(char(arrayfun(@(n)sprintf('Device #%d: %s ',n,strOUTPUT{n}),1:numel(strOUTPUT),'uni',0)));
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
beepdur = numel(twav)/tfs;
%stimID=info.output(ID).ID;
%beepPlayer = audioplayer(twav*0.2, tfs, 24, info.output(ID).ID);
beepread = dsp.AudioFileReader(fullfile(fileparts(which(mfilename)),'flvoice_run_beep.wav'), 'SamplesPerFrame', 2048);
%headwrite = audioDeviceWriter('SampleRate',beepread.SampleRate,'Device',expParams.deviceHead, 'SupportVariableSizeInput', true, 'BufferSize', 2048);
headwrite = audioDeviceWriter('SampleRate',beepread.SampleRate,'Device',expParams.deviceHead);

if expParams.scan,
    if ~ismember(expParams.deviceScan, strOUTPUT), expParams.deviceScan=strOUTPUT{find(strncmp(lower(expParams.deviceScan),lower(strOUTPUT),numel(expParams.deviceScan)),1)}; end
    assert(ismember(expParams.deviceScan, strOUTPUT), 'unable to find match to deviceScan name %s',expParams.deviceScan);
    [ok,ID]=ismember(expParams.deviceScan, strOUTPUT);
    [twav, tfs] = audioread(fullfile(fileparts(which(mfilename)),'flvoice_run_trigger.wav')); % read in sine wav file to trigger the scanner
    trigdur = numel(twav)/tfs;
    %triggerPlayer = audioplayer(twav, tfs, 24, info.output(ID).ID);
    trigread = dsp.AudioFileReader(fullfile(fileparts(which(mfilename)),'flvoice_run_trigger.wav'), 'SamplesPerFrame', 2048);
    trigwrite = audioDeviceWriter('SampleRate',trigread.SampleRate,'Device',expParams.deviceScan);
end

% checks values of timing variables
expParams.beepoffset = beepoffset;

assert(all(isfinite(expParams.timePostOnset))&ismember(numel(expParams.timePostOnset),[1,2]), 'timePostOnset field must have one or two elements');
assert(all(isfinite(expParams.timeScan))&ismember(numel(expParams.timeScan),[1,2]), 'timeScan field must have one or two elements');
assert(all(isfinite(expParams.timePreStim))&ismember(numel(expParams.timePreStim),[1,2]), 'timePreStim field must have one or two elements');
assert(all(isfinite(expParams.timeMax))&ismember(numel(expParams.timeMax),[1,2]), 'timeMax field must have one or two elements');
if numel(expParams.timePostOnset)==1, expParams.timePostOnset=expParams.timePostOnset+[0 0]; end
if numel(expParams.timeScan)==1, expParams.timeScan=expParams.timeScan+[0 0]; end
if numel(expParams.timePreStim)==1, expParams.timePreStim=expParams.timePreStim+[0 0]; end
if numel(expParams.timeMax)==1, expParams.timeMax=expParams.timeMax+[0 0]; end
expParams.timePostOnset=sort(expParams.timePostOnset);
expParams.timeScan=sort(expParams.timeScan);
expParams.timePreStim=sort(expParams.timePreStim);
expParams.timeMax=sort(expParams.timeMax);
rmsThresh = expParams.rmsThresh; % params for detecting voice onset %voiceCal.rmsThresh; % alternatively, run a few iterations of testThreshold and define rmsThreshd here with the resulting threshold value after convergence
rmsBeepThresh = expParams.rmsBeepThresh;
% nonSpeechDelay = .75; % initial estimate of time between go signal and voicing start
nonSpeechDelay = .5; % initial estimate of time between go signal and voicing start

% set up figure for real-time plotting of audio signal of next trial
rtfig = figure('units','norm','position',[.1 .2 .9 .5],'menubar','none');
micSignal = plot(nan,nan,'-', 'Color', [0 0 0.5]);
micLine = xline(0, 'Color', [0.984 0.352 0.313], 'LineWidth', 3);
micLineB = xline(0, 'Color', [0.46 1 0.48], 'LineWidth', 3);
micTitle = title('', 'Fontsize', default_fontsize, 'interpreter','none');
xlabel('Time(s)', 'Fontsize', default_fontsize-1);
% xticklabels('Fontsize', default_fontsize-1);
ylabel('Sound Pressure', 'Fontsize', default_fontsize-1);
% yticklabels('Fontsize', default_fontsize-1);
nexttrl=uicontrol(rtfig,'style','pushbutton','string','Skip to Next','units','norm','position',[.6,.01,.15,.05],'callback',@nxtTrial,'fontsize',default_fontsize-1);
conti=uicontrol(rtfig,'style','pushbutton','string','Next','units','norm','position',[.8,.01,.15,.05],'callback','uiresume','fontsize',default_fontsize-1);
set(nexttrl,'visible','off');
set(conti,'visible','off');



% set up picture display

% % % % % % % % % % % % % if expParams.show_question_orthography, imgBuf = arrayfun(@(x)imread(All_figures{x}), 1:length(All_figures),'uni',0); end
    
%Initialize trialData structure
trialData = struct;

ok=ManageTime('wait', CLOCKp, TIME_PREPARE);
set(annoStr.Stim, 'Visible','off');     % Turn off preparation page
TIME_PREPARE_END=ManageTime('current', CLOCKp);

set(annoStr.Stim, 'String', 'READY');
set(annoStr.Stim, 'Visible','on');
while ~isDone(sileread); sound=sileread();headwrite(sound);end;release(sileread);reset(headwrite);
ok=ManageTime('wait', CLOCKp, TIME_PREPARE_END+2);
set(annoStr.Stim, 'Visible','off');     % Turn off preparation page
CLOCK=[];                               % Main clock (not yet started)


%% LOOP OVER TRIALS
% for ii = 1:expParams.numTrials
while 1
    FLAG_CONT_TO_NXT = 0;    
    ii = 1;

    % set up trial (see subfunction at end of script)
    %[trialData, annoStr] = setUpTrial(expParams, annoStr, stimName, condition, trialData, ii);
    % print progress to window
%     fprintf('\nRun %d, trial %d/%d\n', expParams.run, ii, expParams.numTrials);
    set(annoStr.Plus, 'Visible','on');
%     trialData(ii).stimName = Input_files{ii};
    trialData(ii).condLabel = Input_conditions{ii};
%     [fp, nm, ext] = fileparts(Input_files{ii});
    trialData(ii).display = Input_conditions{ii};
%     trialData(ii).display = nm;
%     trialData(ii).timeStim = numel(Input_sound{ii})/Input_fs{ii}; 
    trialData(ii).timeStim = size(Input_sound{ii},1)/Input_fs{ii}; 
    trialData(ii).timePostOnset = expParams.timePostOnset(1) + diff(expParams.timePostOnset).*rand; 
    trialData(ii).timeScan = expParams.timeScan(1) + diff(expParams.timeScan).*rand; 
    trialData(ii).timePreStim = expParams.timePreStim(1) + diff(expParams.timePreStim).*rand; 
    trialData(ii).timeMax = expParams.timeMax(1) + diff(expParams.timeMax).*rand; 
    %stimPlayer = audioplayer(Input_sound{ii},Input_fs{ii}, 24, stimID);
    stimread = stimreads{ii};
    SpeechTrial=~strcmp(trialData(ii).condLabel,'NULL');
%     SpeechTrial=~strcmp(trialData(ii).condLabel,'S');

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
    figure(rtfig);
    set(micTitle,'string',sprintf('testMicHeadphones, stimulus: %s', trialData(ii).condLabel));
        
    %t = timer;
    %t.StartDelay = 0.050;   % Delay between timer start and timer function
    %t.TimerFcn = @(myTimerObj, thisEvent)play(beepPlayer); % Timer function plays GO signal
    setup(deviceReader) % note: moved this here to avoid delays in time-sensitive portion

    if isempty(CLOCK)
        CLOCK = ManageTime('start');                        % resets clock to t=0 (first-trial start-time)
        TIME_TRIAL_START = 0;
        TIME_STIM_START = 0;
    else
        TIME_TRIAL_START = ManageTime('current', CLOCK);
    end
    
    ok=ManageTime('wait', CLOCK, TIME_STIM_START);
    TIME_STIM_ACTUALLYSTART = ManageTime('current', CLOCK);
    if expParams.show_question_orthography
        set(annoStr.Plus, 'Visible','off');
        set(annoStr.Stim, 'String', {trialData(ii).display});
        set(annoStr.Stim, 'Visible','on');
        drawnow;
    end
    if ~ok, fprintf('i am late for this trial TIME_STIM_START\n'); end

    TIME_SOUND_START = TIME_STIM_ACTUALLYSTART;
    %ok=ManageTime('wait', CLOCK, TIME_SOUND_START - stimoffset);
    ok=ManageTime('wait', CLOCK, TIME_SOUND_START);
    %for reference: stimPlayer = audioplayer(Input_sound{ii},Input_fs{ii}, 24, stimID);
    %play(stimPlayer);
    %sttInd=1; endMax=size(Input_sound{ii}, 1); while sttInd<endMax; headwrite(Input_sound{ii}(sttInd:min(sttInd+2047, endMax))); sttInd=sttInd+2048; end; reset(headwrite);
    TIME_SOUND_ACTUALLYSTART = ManageTime('current', CLOCK);
    while ~isDone(stimread); sound=stimread();headwrite(sound);end;release(stimread);reset(headwrite);
    TIME_SOUND_END = TIME_SOUND_ACTUALLYSTART + trialData(ii).timeStim;           % stimulus ends
    if ~ok, fprintf('i am late for this trial TIME_SOUND_START\n'); end
    
    TIME_ALLSTIM_END = TIME_SOUND_END;
    ok=ManageTime('wait', CLOCK, TIME_ALLSTIM_END);
    if expParams.show_question_orthography
        set(annoStr.Stim, 'Visible','off');
        set(annoStr.Plus, 'Visible','on');
        drawnow;
    end
    if ~ok, fprintf('i am late for this trial TIME_ALLSTIM_END\n'); end        

    TIME_GOSIGNAL_START = TIME_ALLSTIM_END;          % GO signal time
    set(micLine,'visible','off');set(micLineB,'visible','off');drawnow;
        
    ok=ManageTime('wait', CLOCK, TIME_GOSIGNAL_START - beepoffset);     % waits for recorder initialization time
    [nill, nill] = deviceReader(); % note: this line may take some random initialization time to run; audio signal start (t=0) will be synchronized to the time when this line finishes running
    if ~ok, fprintf('i am late for this trial TIME_GOSIGNAL_START - beepoffset\n'); end
        
    ok=ManageTime('wait', CLOCK, TIME_GOSIGNAL_START);     % waits for GO signal time
    %playblocking(beepPlayer)
    while ~isDone(beepread); sound=beepread();headwrite(sound);end;reset(beepread);reset(headwrite);
    %TIME_GOSIGNAL_RELEASED = ManageTime('current', CLOCK);
    %TIME_GOSIGNAL_ACTUALLYSTART = TIME_GOSIGNAL_RELEASED - beepdur; % actual time for GO signal 
    TIME_GOSIGNAL_ACTUALLYSTART = ManageTime('current', CLOCK); % actual time for GO signal 
    set(annoStr.Plus, 'color','g');drawnow
    if ~ok, fprintf('i am late for this trial TIME_GOSIGNAL_START\n'); end
    TIME_VOICE_START = TIME_GOSIGNAL_ACTUALLYSTART + nonSpeechDelay;                   % expected voice onset time
    TIME_SCAN_START = TIME_GOSIGNAL_ACTUALLYSTART + trialData(ii).timeMax;
    set(nexttrl,'visible','on'); 


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
    if SpeechTrial && voiceOnsetDetected == 0, fprintf('warning: voice was expected but not detected (rmsThresh = %f)\n',rmsThresh); end
    release(deviceReader); % end recording
    
    % % % % % % % % % % % % % % % % % % % % switch expParams.visual
    % % % % % % % % % % % % % % % % % % % %     case 'fixpoint'
    % % % % % % % % % % % % % % % % % % % %         set(annoStr.Plus, 'color','w');
    % % % % % % % % % % % % % % % % % % % %     case 'figure'
    % % % % % % % % % % % % % % % % % % % %         imshow([], 'Parent', annoStr.Pic);
    % % % % % % % % % % % % % % % % % % % %     case 'orthography'
    % % % % % % % % % % % % % % % % % % % %         set(annoStr.Plus, 'color','w');
    % % % % % % % % % % % % % % % % % % % % end
    
    if ~FLAG_CONT_TO_NXT
        set(conti,'visible','on');
        uiwait(rtfig);
        ok=ishandle(rtfig);
        if ~ok, return; end
    end
    set(conti,'visible','off');
    set(nexttrl,'visible','off'); 
   
end
release(headwrite);
release(beepread);
if expParams.scan
    release(trigwrite);
    release(trigread);
end
% save(Output_name, 'expParams', 'trialData');


%% end of experiment
close all

% experiment time
expParams.elapsed_time = toc(ET)/60;    % elapsed time of the experiment
fprintf('\nElapsed Time: %f (min)\n', expParams.elapsed_time)


end


function [voiceOnsetDetected, voiceOnsetTime, state]  = detectVoiceOnset(samples, Fs, onDur, onThresh, minVoiceOnsetTime, state)
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



