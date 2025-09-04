function annoStr = setUpVisAnnot_HW(bg, op)
% Setting up visualization
% Helper script that sets up a couple of annotation objects that can be used for
% stimulus visualization / presentation.
%

HW_testing = false;

field_default('op','visible',1); % start visible by default
field_default('op', 'rectWidthProp', 0.8);      % rectangle width as proportion of screen width
field_default('op', 'rectHeightProp', 0.6);     % rectangle height as proportion of screen height  
field_default('op', 'rectColor', [0 1 0]);      % RGB color of rectangle [R G B] (0-1 scale)



if nargin<1||isempty(bg), bg = [0 0 0]; end
txt = 1 - bg;

%% get monitorSize and set up related var
monitorSize = get(0, 'Monitor');
annoStr.numMonitors = size(monitorSize, 1);

if annoStr.numMonitors == 2
    % For dual monitor, still use second monitor but only right half
    annoStr.fig_width = monitorSize(2,3) / 2; % Start at middle of second monitor
    annoStr.fig_height = monitorSize(2,4);
    XPos = monitorSize(2,1) + annoStr.fig_width;  
    YPos = monitorSize(2,2);
    annoStr.figPosition = [XPos YPos annoStr.fig_width annoStr.fig_height];  % Right half width, full height
    annoStr.monitorSize = monitorSize(2,:);
else
    % For single monitor, use right half
    annoStr.fig_width = monitorSize(1, 3) / 2; % Start at middle of screen
    annoStr.fig_height = monitorSize(1, 4);
    XPos = annoStr.fig_width;  
    YPos = 0;    % Start at bottom
    annoStr.figPosition = [XPos YPos annoStr.fig_width annoStr.fig_height];  % Right half width, full height
    annoStr.monitorSize = monitorSize(1,:);
end

winPos = annoStr.figPosition;

%% Preparing 'Ready' Annotation Position
rdAnoD = [0.7 0.3];
rdAnoPos = getPos(rdAnoD, winPos);

% Preparing 'Cue' Annotation Position
cuAnoD = [0.25 0.15];
cuAnoPos = getPos(cuAnoD, winPos);
% cuAnoPos = [0.35 0.10 0.25 0.25];

% Preparing 'Stim' Annotation Position
stimAnoD = [0.60 0.40]; % Made wider to accommodate more text
stimAnoPos = getPos(stimAnoD, winPos);

%% Actually create the stim presentation figure
% this causes the stim window to appear
annoStr.hfig = figure('Visible',op.visible, 'NumberTitle', 'off', 'Color', bg, 'Position', winPos, 'MenuBar', 'none', 'ToolBar','none');
drawnow; 
if ~HW_testing
    if ~isequal(get(annoStr.hfig,'position'),winPos), set(annoStr.hfig,'Position',winPos, 'MenuBar', 'none', 'ToolBar', 'none'); end % fix needed only on some dual monitor setups
end

% Common annotation settings
cSettings = {'Color',txt,...
    'LineStyle','none',...
    'HorizontalAlignment','center',...
    'VerticalAlignment','middle',...
    'FontSize',40,...
    'FontWeight','bold',...
    'FontName','Arial',...
    'FitBoxToText','off',... % Changed to 'off' to allow proper positioning
    'EdgeColor','none',...
    'BackgroundColor',bg,...
    'visible','off'};

% Ready annotation
annoStr.Ready = annotation(annoStr.hfig,'textbox', rdAnoPos,...
    'String',{'READY'},...
    cSettings{:});

% Cue annotation
annoStr.Plus = annotation(annoStr.hfig,'textbox', cuAnoPos,...
    'String',{'+'},...
    cSettings{:});
set(annoStr.Plus, 'FontSize', 200);

% GO arrow
annoStr.goArrow = annotation(annoStr.hfig,'arrow',...
    'X',[0.7 0.1], 'Y',[0.5 0.5],...
    'HeadStyle', 'plain',...
    'HeadSize', 100,...
    'LineWidth',50,...
    'Color',[0 1 0],... 
    'Visible','off'...
    );

% Stim orthography annotation
annoStr.Stim = annotation(annoStr.hfig,'textbox', stimAnoPos,...
    'String',{'stim'},...
    cSettings{:});

% --- Override to span full figure width and left-justify ---
set(annoStr.Stim, ...
    'Position', [0.02 0.05 0.96 0.9], ...   % [left bottom width height] in normalized units
    'HorizontalAlignment','left', ...
    'VerticalAlignment','middle', ...
    'Interpreter','none', ...               % avoid TeX interpretation surprises
    'FitBoxToText','off');                  % keep the box size fixed so text wraps to box


annoStr.Pic = axes(annoStr.hfig, 'pos',[1/2-winPos(4)/(4*winPos(3)) 0.25 winPos(4)/(2*winPos(3)) 0.5]);
axes(annoStr.Pic)
imshow([])
drawnow

% Calculate position and size based on proportion variables
rectX = (1 - op.rectWidthProp) / 2;     % center horizontally
rectY = (1 - op.rectHeightProp) / 2;    % center vertically

% Create rectangle using the calculated proportions
annoStr.goRect = annotation(annoStr.hfig, 'rectangle', [rectX, rectY, op.rectWidthProp, op.rectHeightProp], ...
                           'FaceColor', op.rectColor, ...
                           'EdgeColor', 'none', ...
                           'Visible', 'off');


% Add a helper function for setting wrapped text
annoStr.setWrappedText = @(textStr) setWrappedText(annoStr.Stim, textStr);

% Add a helper function to set text with automatic wrapping for stimulus
annoStr.setStimText = @(textStr) setWrappedText(annoStr.Stim, textStr);

end

% Function to determine annotation position
function anoPos = getPos(anoD, winPos)    
    % For stimulus text, use full width positioning
    if anoD(1) >= 1.0  % This is the stimulus text box
        anoX = 0;      % Start at very left edge
        anoY = 0.05;   % Small top margin
        anoW = 1.0;    % Use full width
        anoH = 0.9;    % Use most of height
    else
        % For other annotations, use original logic
        anoW = anoD(1) * 100 / winPos(3);
        anoH = anoD(2) * 100 / winPos(4);
        anoW = anoW / 100;
        anoH = anoH / 100;
        anoX = 0.5 - anoW/2; % Center horizontally
        anoY = 0.5 - anoH/2; % Center vertically
    end
    
    anoPos = [anoX anoY anoW anoH];
end