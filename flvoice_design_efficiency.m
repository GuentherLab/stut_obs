function out = flvoice_design_efficiency(varargin)
% FLVOICE_DESIGN_EFFICIENCY estimates design efficiency of scanning session run using FLVOICE_RUN
%
% AUDIO RECORDING&SCANNING SEQUENCE: (repeat for each trial)
%
% |                              |------ RECORDING -------------------------------------|          
% |- PLAY SOUND STIMULUS ---|      |                  |----SUBJECT SPEECH-----|           |--SCANNING-|    |- SOUND STIMULUS (next trial) 
% |   stimulus time         |      |  reaction time   |  production duration  |           |           |    |   stimulus time ...   
% |----------D0-------------|--D1--|                  |-------------------D2--------------|----D4-----|-D5-|
% |                         |      |------------------------------------(<=D3)------------|           |    |
% v                         |      v                  |                                   v           |    v 
% stimulus starts           v      GO signal          v                                   scanner     v    next stimulus starts 
%                           stimulus ends             voice onset                         starts      scanner ends 
%
% SYNTAX:
%
% FLVOICE_DESIGN_EFFICIENCY('option_name1',option_value1, 'option_name2',option_value2, ...)
%
% POSSIBLE OPTION NAMES:
%
%   (parameters related to experiment paradigm)
%     conditions                 : 1 x N unique numbers (numbers ranging from 1 to M) or labels (M unique labels) identifying each trial type (e.g. {'A', 'B', 'A', 'B', 'A', B'} or [1, 2, 1, 2, 1, 2] for a sequence containing six trials in a recurring AB sequence)
%                                  alternatively, nested array defining different stimulus presentation orders to be tested (e.g. { {'A', 'B', 'A', 'B'}, {'A', 'A', 'B', 'B'} ... }
%     timeStimulus               : (D0) time (s) from stimulus starts to stimulus ends (one value for fixed duration, two values for minimum-maximum range of random times) [1 2]
%     timePostStim               : (D1) time (s) from end of the audio stimulus presentation to the GO signal (D1 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [.25 .75] 
%     timePostOnset              : (D2) time (s) from subject's voice onset to the scanner trigger (or to pre-stimulus segment, if scan=false) (D2 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [4.5] 
%     timeMax                    : (D3) maximum time (s) before GO signal and scanner trigger (or to pre-stimulus segment, if scan=false) (D3 in schematic above) (recording portion in a trial may end before this if necessary to start scanner) [6] 
%     timeScan                   : (D4) duration (s) of scan (D4 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [1.6] 
%     timePreStim                : (D5) time (s) from end of scan to start of next trial stimulus presentation (D5 in schematic above) (one value for fixed time, two values for minimum-maximum range of random times) [.75] 
%     nScans                     : number of sequential scan acquisitions per trial (1)
%   (parameters related to the expected subject response)
%     timeReaction               : time (s) from GO signal to start of SUBJECT SPEECH segment (one value for fixed duration, two values for minimum-maximum range of random times) [.1 .2]
%     timeProduction             : duration (s) of SUBJECT SPEECH segment (one value for fixed duration, two values for minimum-maximum range of random times) [1 2]
%   (parameters related to statistical inferences)
%     contrast                   : contrast vector(s) (1 x M) values specifying between-conditions contrast of interest (enter multiple rows to evaluate multiple contrasts) (default: contrasts comparing pairwise all conditions)
%     nRuns                      : number of functional runs (repetitions of above experiment paradigm) [1]
%   (design efficiency estimation options)
%     nRepeat                    : (when timing parameters include ranges of values) number of random timing repetitions to evaluate [100]
%     options                    : additional options/parameters passed to flvoice_design_efficiency_glm (e.g. {'hparam',200} see "help flvoice_design_efficiency_glm" for details)
%     doDisp                     : 1/0 display design matrix timing information [true]
%
% OUTPUT:
% 
% out = flvoice_design_efficiency(...)
%    returns structure with fields:
%     Efficiency                 : design efficiency (expected T-stat @ SNR=1)
%     DesignMatrix               : GLM design matrix for fMRI data (resampled at fMRI acquisition times)
%     DesignRaw                  : high-resolution GLM design matrix (100Hz uniformly sampled)
%
% EXAMPLE:
%
% out = flvoice_design_efficiency(...
%               'conditions',   repmat({'A','B'},1,20), ...
%               'timeScan',     2.0, ...
%               'timeReaction', [.10 1.5]);
%


options=struct(...
    'conditions',{{}},...
    'timeStimulus',[1 2],...
    'timePostStim', [.25 .75],...
    'timePostOnset', 4.5,...
    'timeMax', 6, ...
    'timeScan', 1.6,...
    'timePreStim', .75,...
    'timeReaction',[.1 .2],...
    'timeProduction',[1 2],...
    'contrast',[],...
    'nRuns',1,...
    'nScans',1,...
    'nRepeat',100,...
    'doDisp',true,...
    'options',{{}});

for n=1:2:numel(varargin)-1, 
    assert(isfield(options,varargin{n}),'unrecognized option %s',varargin{n});
    options.(varargin{n})=varargin{n+1};
end

anyrange=false;
for fieldn=reshape(fieldnames(options),1,[]),
    if ~isempty(regexp(fieldn{1},'^time')),
        if numel(options.(fieldn{1}))==1, options.(fieldn{1})=repmat(options.(fieldn{1}),1,2); end
        assert(ismember(numel(options.(fieldn{1})),[1,2]),'enter 1 or 2 values in field %s',fieldn{1});
        options.(fieldn{1})=round(options.(fieldn{1})*1000); % converts to ms units and rounds
        anyrange=anyrange|diff(options.(fieldn{1}))>0; 
    end
end
Nrepeat=options.nRepeat;
if ~anyrange, Nrepeat=1; end

assert(~isempty(options.conditions),'enter condition labels in ''conditions'' field')
maxTime=inf;
Ns=size(options.conditions,2);
Neval=size(options.conditions,1);
[uCondLabel,nill,iCondLabel]=unique(options.conditions);
iCondLabel=reshape(iCondLabel,size(options.conditions));
Nc=numel(uCondLabel);

rscurrent=rand('seed');rand('seed',0);
Tall=zeros(1,Neval);
for nrepeat=1:Nrepeat
    I=[]; % stimulus presentations
    N=[]; % scanner acquisitions
    tstart=0;                                            % stimulus presentation starts (ms)
    for ns=1:Ns
        if tstart>maxTime, break; end

        tgo=tstart+options.timeStimulus(1)+round(rand*diff(options.timeStimulus)) ... % (D0+D1) Go signal
            +options.timePostStim(1)+round(rand*diff(options.timePostStim));
        tmax = tgo+options.timeMax(1)+round(rand*diff(options.timeMax)); % (D3) latest possible scanner trigger
        t1 = tgo+options.timeReaction(1)+round(rand*diff(options.timeReaction)); % Subject production starts
        t2 = t1+options.timeProduction(1)+round(rand*diff(options.timeProduction)); % Subject production ends here
        tscan = t1+options.timePostOnset(1)+round(rand*diff(options.timePostOnset)); % (D2) optimal scanner trigger
        tscan=min(tscan, tmax); % scanner starts
        I(t1+1:t2,1)=ns;
        for nseq=1:options.nScans
            tscanends=tscan+options.timeScan(1)+round(rand*diff(options.timeScan)); % (D4) scanner ends
            N(tscan+1:tscanends,1)=options.nScans*(ns-1)+nseq;
            tscan=tscanends;
        end
        tstart = tscanends+options.timePreStim(1)+round(rand*diff(options.timePreStim)); % (D5) next trial starts
    end
    Ns=Nc*ceil(ns/Nc);

    for neval=1:Neval
        if ~isempty(options.conditions)
            conditions=full(sparse(1:ns,iCondLabel(neval,:),1));
        else
            conditions = kron(eye(Nc),ones(Ns/Nc,1));
            conditions = conditions(randperm(Ns),:);
            conditions=conditions(1:ns,:);
        end
        idx=find(I>0);
        maxt=max(size(I,1),size(N,1));
        X=zeros(maxt,Nc);
        X(I>0,1:Nc)=conditions(I(I>0),:);
        SCAN=zeros(maxt,1);
        SCAN(1:numel(N))=N;
        % X=zeros(ns,Nc+1);
        % X(I>0,1:Nc)=conditions(I(I>0),:);
        % X(SCAN>0,Nc+1)=1; % scanner effect
        if 1 % resample to dt
            dt=0.01;
            SCAN((dt/.001)*ceil(numel(SCAN)/(dt/.001)),1)=0;
            X(numel(SCAN),end)=0;
            SCAN=mode(reshape(SCAN,10,[]),1)';
            X=shiftdim(mean(reshape(X,10,[],size(X,2)),1),1);
        else
            dt=.001;
            X(numel(SCAN),end)=0;
        end
        if ~isempty(options.contrast), 
            assert(size(options.contrast,2)==Nc,'unexpected number of columns in ''contrast'' field (expected %d, found %d)',Nc, size(options.contrast,2));
            C=options.contrast;
        else 
            C=[]; for n1=1:Nc, for n2=n1+1:Nc, C=[C; ((1:Nc)==n1)-((1:Nc)==n2)]; end; end
        end
        if options.nRuns>1
            X=kron(eye(options.nRuns),X);
            C=repmat(C,1,options.nRuns)/options.nRuns;
            SCAN=reshape(repmat(SCAN,1,options.nRuns)+(SCAN>0)*max(SCAN)*(0:options.nRuns-1),[],1);
        end
        [T, X1, X2, X3] = flvoice_design_efficiency_glm(X, C, 'scans', SCAN, 'dt',dt, options.options{:});
        Tall(neval)=Tall(neval)+T;
        if nrepeat==Nrepeat
            T=Tall(neval)/Nrepeat;
            fprintf('%d stimulus, total time %.1f s, design efficiency = %.3f\n', Ns, tstart/1e3, T);
            out.Efficiency(neval)=T;
            out.DesignRaw{neval}=X1;
            out.DesignMatrix{neval}=X3;
        end
    end
end
rand('seed',rscurrent);

if options.doDisp
    [nill,idx]=max(X,[],2);
    idx(nill==0)=0;
    idx(SCAN>0)=size(X,2)+1;
    clf; image(dt*(0:numel(SCAN)-1),1,1+idx'); set(gca,'ydir','normal'); hold all; plot(dt*(0:numel(SCAN)-1),1+.5*X1(:,1:end-1),'-','linewidth',2); plot(dt*(0:numel(SCAN)-1),1+.5*X1(:,end),':','color',.75*[1 1 1],'linewidth',2); colormap(1-.25*gray); 
    set(gca,'xlim',[0 maxt/1000],'ylim',[.8 1.6],'ytick',[]); 
    xlabel('time (s)'); legend([arrayfun(@(n)sprintf('C%d',n),1:Nc,'uni',0),{'scan'}]);
    c=get(gca,'colororder'); c=[c;fliplr(c)]; colormap([1 1 1;.5+.5*c(1:size(X,2),:);.9 .9 .9]);
end
