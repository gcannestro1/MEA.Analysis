
% GUI for selecting optional analysis scripts, with optional hierarchy.
% This file houses multiple functions
    % SelectedScripts - creates Gui for tree-like appearance for selecting
        % analysis to be run
    % MaybeCall - runs a script/function if it was checked off in SelectedScripts
    % various helper functions


% SelectedScripts Input types
% 1) Flat list (backward-compatible): {'STTC.m','Clustering.m', ...}
% 2) Hierarchical list (struct array):
%    optionalScriptList(i) has fields:
%       .label    (string)  - Display name in the list
%       .script   (string)  - Script/function filename to return if selected
%       .children (struct array, same shape) - optional children

% Outputs:
%   selectedScripts - cell array of selected script names (strings)
%
% Children are shown indented and disabled until the parent is selected.


function selectedScripts = SelectOptionalScripts(optionalScriptList)
    % Normalize input into a tree of structs with fields: label, script, children
    if iscell(optionalScriptList) && (isempty(optionalScriptList) || ischar(optionalScriptList{1}) || isstring(optionalScriptList{1}))
        
        % Flat cellstr → struct array
        S = repmat(struct('label',"", 'script',"", 'children',struct.empty(0,1)), numel(optionalScriptList), 1);
        for k = 1:numel(optionalScriptList)
            txt = string(optionalScriptList{k});
            S(k).label = txt;
            S(k).script = txt;
            S(k).children = struct.empty(0,1);
        end
        rootItems = S;

    elseif isstruct(optionalScriptList)
        % Assume already hierarchical structs
        rootItems = optionalScriptList(:);
    else
        error('optionalScriptList must be a cellstr or a struct array.');
    end

    % Flatten tree into a linear list with level, parent, and child links
    nodes = struct('label',{},'script',{},'level',{},'parent',{},'children',{},'idx',{});
    parentStack = [];
    function addNodes(items, level, parentIdx)
        for ii = 1:numel(items)
            nd.label   = string(items(ii).label);
            nd.script  = string(items(ii).script);
            nd.level   = level;
            nd.parent  = parentIdx;
            nd.children = [];   % will fill after push
            nd.idx     = numel(nodes)+1;
            nodes(end+1) = nd; %#ok<AGROW>

            myIdx = numel(nodes);
            if ~isempty(items(ii).children)
                startChild = numel(nodes)+1;
                addNodes(items(ii).children(:), level+1, myIdx);
                childIdx = startChild:numel(nodes);
                nodes(myIdx).children = childIdx;
            end
        end
    end
    addNodes(rootItems, 0, 0);

    if isempty(nodes)
        selectedScripts = {};
        return;
    end

    % GUI sizing
    rowH    = 26;
    topPad  = 60;
    botPad  = 60;
    figW    = 380;
    figH    = max(180, topPad + botPad + rowH*numel(nodes));
    indentStep = 20;

    % State
    selections = false(1, numel(nodes));
    cb = gobjects(numel(nodes),1);

    % Build figure
    fig = figure('Name','Select Optional Scripts', ...
                 'NumberTitle','off', ...
                 'MenuBar','none', ...
                 'Resize','off', ...
                 'Position',[500 300 figW figH]);

    uicontrol('Style','text',...
              'String','Select optional analyses to run:',...
              'HorizontalAlignment','left',...
              'Position',[20 figH-40 figW-40 20]);

    % Create checkboxes
    for i = 1:numel(nodes)
        y = figH - topPad - (i-1)*rowH;
        % Add a visual arrow for children
        prefix = repmat(' ', 1, nodes(i).level*0); % visual spacing is via Position X
        if nodes(i).level > 0
            displayText = sprintf('↳ %s', nodes(i).label);
        else
            displayText = char(nodes(i).label);
        end

        cb(i) = uicontrol('Style','checkbox', ...
            'String', displayText, ...
            'Position',[20 + nodes(i).level*indentStep, y, figW-60, 20], ...
            'HorizontalAlignment','left', ...
            'Enable', ternary(nodes(i).parent==0,'on','off'), ...
            'Callback', @(src,~) onToggle(src, i));
    end

    % Action buttons
    uicontrol('Style','pushbutton',...
              'String','Select All (Top Level)',...
              'Position',[20 20 150 28],...
              'Callback', @selectAllTop);
    uicontrol('Style','pushbutton',...
              'String','Clear All',...
              'Position',[180 20 90 28],...
              'Callback', @clearAll);
    uicontrol('Style','pushbutton',...
              'String','Confirm Selection',...
              'Position',[280 20 90 28],...
              'Callback', @confirmSelection);

    uiwait(fig);

    % Output (preserve on-screen order)
    selectedScripts = cellstr(nodes2scripts());

    %% Helpers
    function v = ternary(cond, a, b), if cond, v=a; else, v=b; end; end

    function onToggle(src, idx)
        val = logical(get(src,'Value'));
        selections(idx) = val;

        if ~val
            % Turning a node OFF: disable & clear all descendants
            disableDescendants(idx, true);
        else
            % Turning a node ON: ensure all ancestors are ON and enable children
            ensureAncestors(idx);
            enableChildren(idx);
        end
    end

    function ensureAncestors(idx)
        p = nodes(idx).parent;
        while p > 0
            if ~selections(p)
                selections(p) = true;
                set(cb(p),'Value',1,'Enable','on');
            end
            p = nodes(p).parent;
        end
    end

    function enableChildren(idx)
        for ch = nodes(idx).children
            set(cb(ch), 'Enable', 'on');
            % do NOT auto-select child; user decides
        end
    end

    function disableDescendants(idx, clearVals)
        % Disable & optionally uncheck entire subtree
        for ch = nodes(idx).children
            if clearVals
                selections(ch) = false;
                set(cb(ch),'Value',0);
            end
            set(cb(ch),'Enable','off');
            disableDescendants(ch, clearVals);
        end
    end

    function selectAllTop(~,~)
        for i = 1:numel(nodes)
            if nodes(i).parent==0
                selections(i) = true;
                set(cb(i),'Value',1,'Enable','on');
                enableChildren(i);
            end
        end
    end

    function clearAll(~,~)
        for i = 1:numel(nodes)
            selections(i) = false;
            set(cb(i),'Value',0);
            if nodes(i).parent == 0
                set(cb(i),'Enable','on');
            else
                set(cb(i),'Enable','off');
            end
        end
    end

    function confirmSelection(~,~)
        uiresume(fig);
        if isvalid(fig), delete(fig); end
    end

    function out = nodes2scripts()
        % Return scripts for all selected nodes, in visual order
        picked = find(selections);
        out = strings(1, numel(picked));
        c = 0;
        for i = 1:numel(nodes)
            if selections(i) && strlength(nodes(i).script) > 0
                c = c+1;
                out(c) = nodes(i).script;
            end
        end
        out = out(1:c);
    end
end

% %% MaybeCall
% % Call function/script `name` if it was selected
%     % can be {'FuncA','FuncB.m', ...}. `name` can be 'FuncA' or 'FuncA.m'.
%     % Convention: functions accept/return `ctx`; scripts will just run in-place.
% 
% function ctx = MaybeCall(SelectedAnalysis, name, ctx, varargin)
%     % normalize names (case-insensitive, ignore .m)
%     norm = @(s) lower(erase(string(s), ".m"));
%     picked = norm(SelectedAnalysis);
%     target = norm(name);
% 
%     if ~ismember(target, picked)
%         return; % not selected → do nothing
%     end
% 
%     % try as function first
%     fname = char(target);
%     if exist(fname, 'file') == 2
%         try
%             % Preferred: optional analyses are functions:  function ctx = X(ctx, varargin)
%             ctx = feval(fname, ctx, varargin{:});
%             return
%         catch
%             % Fall back: try to run as a script (uses current workspace)
%             try
%                 run([fname '.m']);
%             catch ME
%                 warning('Failed to run "%s": %s', fname, ME.message);
%             end
%         end
%     else
%         warning('Analysis "%s" not found on the path.', fname);
%     end
% end
