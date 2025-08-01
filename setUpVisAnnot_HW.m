function annoStr = setUpVisAnnot_HW(bg, op)
% Setting up visualization
% Helper script that sets up a couple of annotation objects that can be used for
% stimulus visualization / presentation.
%

HW_testing = false;

if nargin<1||isempty(bg), bg = [0 0 0]; end
txt = 1 - bg;

%% get monitorSize and set up related var
monitorSize = get(0, 'Monitor');
numMon = size(monitorSize, 1);

if numMon == 2
    figPosition = [monitorSize(2,1) monitorSize(2,2) monitorSize(2,3) monitorSize(2,4)];
else
    W = monitorSize(1, 3);
    H = monitorSize(1, 4);
    W2 = W/2;
    H2 = H/2;
    XPos = W2;
    YPos = 50;
    figPosition = [XPos YPos W2 H2];
end
winPos = figPosition;

%% Preparing 'Ready' Annotation Position
rdAnoD = [0.7 0.3];
rdAnoPos = getPos(rdAnoD, winPos);

% Preparing 'Cue' Annotation Position
cuAnoD = [0.25 0.15];
cuAnoPos = getPos(cuAnoD, winPos);
% cuAnoPos = [0.35 0.10 0.25 0.25];

% Preparing 'Stim' Annotation Position
stimAnoD = [0.50 0.50]; % if stim too small/large, need to adjust
stimAnoPos = getPos(stimAnoD, winPos);

%% Actually create the stim presentation figure
% this causes the stim window to appear
VBFig = figure('NumberTitle', 'off', 'Color', bg, 'Position', winPos, 'MenuBar', 'none', 'ToolBar','none');
drawnow; 
if ~HW_testing
    if ~isequal(get(VBFig,'position'),winPos), set(VBFig,'Position',winPos, 'MenuBar', 'none', 'ToolBar', 'none'); end % fix needed only on some dual monitor setups
end

% Common annotation settings
cSettings = {'Color',txt,...
    'LineStyle','none',...
    'HorizontalAlignment','center',...
    'VerticalAlignment','middle',...
    'FontSize',40,...
    'FontWeight','bold',...
    'FontName','Arial',...
    'FitBoxToText','on',...
    'EdgeColor','none',...
    'BackgroundColor',bg,...
    'visible','off'};

% Ready annotation
annoStr.Ready = annotation(VBFig,'textbox', rdAnoPos,...
    'String',{'READY'},...
    cSettings{:});

% Cue annotation
annoStr.Plus = annotation(VBFig,'textbox', cuAnoPos,...
    'String',{'+'},...
    cSettings{:});
set(annoStr.Plus, 'FontSize', 200);

% Stim annotation
annoStr.Stim = annotation(VBFig,'textbox', stimAnoPos,...
    'String',{'stim'},...
    cSettings{:});

annoStr.Pic = axes(VBFig, 'pos',[1/2-winPos(4)/(4*winPos(3)) 0.25 winPos(4)/(2*winPos(3)) 0.5]);
axes(annoStr.Pic)
imshow([])
drawnow

% Green square GO cue
% Get screen size for rectangle positioning
% % % % % % % % % % % % % % % % % % % % % % % % screenSize = get(0, 'ScreenSize'); % [left bottom width height]
% % % % % % % % % % % % % % % % % % % % % % % % rectWidth = screenSize(3) * expParams.rectWidthProp;
% % % % % % % % % % % % % % % % % % % % % % % % rectHeight = screenSize(4) * expParams.rectHeightProp;
% % % % % % % % % % % % % % % % % % % % % % % % rectX = (screenSize(3) - rectWidth) / 2;  % center horizontally
% % % % % % % % % % % % % % % % % % % % % % % % rectY = (screenSize(4) - rectHeight) / 2; % center vertically

% Create rectangle (initially invisible)
% % % % % % % annoStr.GoRect = rectangle('Position', [0.5, 0.7, 0.6, 0.3], ...
% % % % % % %                           'FaceColor', [0 1 0], ...
% % % % % % %                           'EdgeColor', 'none', ...
% % % % % % %                           'Visible', 'off');

% Calculate position and size based on proportion variables
rectX = (1 - op.rectWidthProp) / 2;     % center horizontally
rectY = (1 - op.rectHeightProp) / 2;    % center vertically

% Create rectangle using the calculated proportions
annoStr.GoRect = annotation(VBFig, 'rectangle', [rectX, rectY, op.rectWidthProp, op.rectHeightProp], ...
                           'FaceColor', op.rectColor, ...
                           'EdgeColor', 'none', ...
                           'Visible', 'off');


end

% Function to determine annotation position
function anoPos = getPos(anoD, winPos)
    
    
    anoW = round(anoD(1)/winPos(3), 2);
    anoH = round(anoD(2)/winPos(4), 2);
    anoX = 0.5 - anoW/2;
    anoY = 0.5 - anoH/2;
    anoPos = [anoX anoY anoW anoH];

end

%% Commands to use within the main script / trial
% Use the following to set up the visual annotations and
% manipulate stim presentation

% sets up 'annoStr' variable which is used to manipulate the
% created visual annotations
%        annoStr = setUpVisAnnot();

% How to turn specific annotation 'on' / 'off'
%       set(annoStr.Ready, 'Visible','on');  % Turn on 'Ready?'
%       set(annoStr.Ready, 'Visible','off'); % Turn off 'Ready?'

%       set(annoStr.Plus, 'Visible','on');   % Turn on fixation 'Cross'
%       set(annoStr.Plus, 'Visible','off');  % Turn off fixation 'Cross'

%       annoStr.Stim.String = 'stim1';      % change the stimulus to desired word (in this case 'stim1')

%       set(annoStr.Stim,'Visible','on');  % Turn on stimulus
%       set(annoStr.Stim,'Visible','off');  % Turn off stimulus

%       set([annoStr.Stim annoStr.visTrig],'Visible','on');  % Turn on stimulus + trigger box
%       set([annoStr.Stim annoStr.visTrig],'Visible','off'); % Turn off stimulus + trigger box

