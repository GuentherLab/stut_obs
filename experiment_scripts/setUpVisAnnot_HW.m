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
    % For dual monitor, still use second monitor but only right half
    W = monitorSize(2,3);
    H = monitorSize(2,4);
    XPos = monitorSize(2,1) + W/2;  % Start at middle of second monitor
    YPos = monitorSize(2,2);
    figPosition = [XPos YPos W/2 H];  % Right half width, full height
else
    % For single monitor, use right half
    W = monitorSize(1, 3);
    H = monitorSize(1, 4);
    XPos = W/2;  % Start at middle of screen
    YPos = 0;    % Start at bottom
    figPosition = [XPos YPos W/2 H];  % Right half width, full height
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
stimAnoD = [0.30 0.50]; % if stim too small/large, need to adjust
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

% GO arrow
annoStr.goArrow = annotation(VBFig,'arrow',...
    'X',[0.7 0.1], 'Y',[0.5 0.5],...
    'HeadStyle', 'plain',...
    'HeadSize', 100,...
    'LineWidth',50,...
    'Color',[0 1 0],... 
    'Visible','off'...
    );

% Stim orthography annotation
annoStr.Stim = annotation(VBFig,'textbox', stimAnoPos,...
    'String',{'stim'},...
    cSettings{:});

annoStr.Pic = axes(VBFig, 'pos',[1/2-winPos(4)/(4*winPos(3)) 0.25 winPos(4)/(2*winPos(3)) 0.5]);
axes(annoStr.Pic)
imshow([])
drawnow

% Calculate position and size based on proportion variables
rectX = (1 - op.rectWidthProp) / 2;     % center horizontally
rectY = (1 - op.rectHeightProp) / 2;    % center vertically

% Create rectangle using the calculated proportions
annoStr.GoRect = annotation(VBFig, 'rectangle', [rectX, rectY, op.rectWidthProp, op.rectHeightProp], ...
                           'FaceColor', op.rectColor, ...
                           'EdgeColor', 'none', ...
                           'Visible', 'off');


% Add a helper function for setting wrapped text
annoStr.setWrappedText = @(textStr) setWrappedText(annoStr.Stim, textStr);

end

% Function to determine annotation position
function anoPos = getPos(anoD, winPos)


    anoW = round(anoD(1)/winPos(3), 2);
    anoH = round(anoD(2)/winPos(4), 2);
    anoX = 0.2 - anoW/2; %%% shift left.... to center instead, use 0.5 - anoW/2
    anoY = 0.5 - anoH/2;
    anoPos = [anoX anoY anoW anoH];

end


% Helper function to set text with automatic wrapping
function setWrappedText(textObj, textStr)
    % Simple text wrapping function
    maxCharsPerLine = 60; % Adjust based on font size and box width
    
    if length(textStr) <= maxCharsPerLine
        set(textObj, 'String', textStr);
        return;
    end
    
    % Split long text into lines
    words = strsplit(textStr, ' ');
    lines = {};
    currentLine = '';
    
    for i = 1:length(words)
        testLine = [currentLine, words{i}, ' '];
        if length(testLine) > maxCharsPerLine && ~isempty(currentLine)
            lines{end+1} = strtrim(currentLine);
            currentLine = [words{i}, ' '];
        else
            currentLine = testLine;
        end
    end
    
    if ~isempty(currentLine)
        lines{end+1} = strtrim(currentLine);
    end
    
    % Set the wrapped text
    set(textObj, 'String', lines);
end








