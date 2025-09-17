function selectedScripts = SelectOptionalScripts(optionalScriptList)
% SelectOptionalScripts  Minimal checkbox GUI (flat or hierarchical)
% Input:
%   - optionalScriptList:
%       A) cellstr: {'STTC.m','Clustering.m', ...}
%       B) struct array with fields:
%            .label   (string/char)
%            .script  (string/char)
%            .children (struct array, optional, same shape)
% Output:
%   - selectedScripts : cellstr of chosen script names (visual order)

    % ---------- Normalize to struct tree ----------
    if iscell(optionalScriptList)
        S = repmat(struct('label',"", 'script',"", 'children',struct.empty(0,1)), numel(optionalScriptList), 1);
        for k = 1:numel(optionalScriptList)
            txt = string(optionalScriptList{k});
            S(k).label = txt;
            S(k).script = txt;
        end
        rootItems = S;
    elseif isstruct(optionalScriptList)
        rootItems = optionalScriptList(:);
    else
        error('optionalScriptList must be a cellstr or struct array.');
    end

    % ---------- Flatten to nodes ----------
    nodes = struct('label',{},'script',{},'level',{},'parent',{},'children',{},'idx',{});
    function addNodes(items, level, parentIdx)
        for ii = 1:numel(items)
            nd.label    = string(items(ii).label);
            nd.script   = string(items(ii).script);
            nd.level    = level;
            nd.parent   = parentIdx;
            nd.children = [];
            nd.idx      = numel(nodes)+1;
            nodes(end+1) = nd; %#ok<AGROW>
            myIdx = numel(nodes);
            if isfield(items(ii),'children') && ~isempty(items(ii).children)
                startChild = numel(nodes)+1;
                addNodes(items(ii).children(:), level+1, myIdx);
                nodes(myIdx).children = startChild:numel(nodes);
            end
        end
    end
    addNodes(rootItems, 0, 0);

    if isempty(nodes)
        selectedScripts = {};
        return
    end

    % ---------- GUI layout ----------
    rowH       = 24;
    marginTop  = 56;
    marginBot  = 56;
    indentStep = 20;
    figW       = 420;
    figH       = max(180, marginTop + marginBot + rowH*numel(nodes));

    selections = false(1, numel(nodes));
    cbs        = gobjects(numel(nodes),1);
    doneFlag   = false; %#ok<NASGU> % set in callbacks
    % keep selections & nodes in outer scope so callbacks can see them

    fig = figure( ...
        'Name','Select Optional Scripts', ...
        'NumberTitle','off', ...
        'MenuBar','none', ...
        'Resize','off', ...
        'Position',[500 300 figW figH], ...
        'CloseRequestFcn', @onClose);

    uicontrol('Style','text', ...
        'String','Select optional analyses to run:', ...
        'HorizontalAlignment','left', ...
        'Position',[16 figH-34 figW-32 18]);

    % Checkboxes
    for i = 1:numel(nodes)
        y = figH - marginTop - (i-1)*rowH;
        if nodes(i).level > 0
            label = sprintf('↳ %s', nodes(i).label);
        else
            label = char(nodes(i).label);
        end
        cbs(i) = uicontrol('Style','checkbox', ...
            'String', label, ...
            'Position',[16 + nodes(i).level*indentStep, y, figW-48, 20], ...
            'HorizontalAlignment','left', ...
            'Enable', onOff(nodes(i).parent==0), ...
            'Callback', @(src,~) onToggle(i, logical(get(src,'Value'))));
    end

    % Buttons
    uicontrol('Style','pushbutton', ...
        'String','Top-Level: All', ...
        'Position',[16 16 120 28], ...
        'Callback', @selectAllTop);
    uicontrol('Style','pushbutton', ...
        'String','Clear', ...
        'Position',[144 16 80 28], ...
        'Callback', @clearAll);
    uicontrol('Style','pushbutton', ...
        'String','Confirm', ...
        'Position',[232 16 80 28], ...
        'Callback', @confirmSelection);
    uicontrol('Style','pushbutton', ...
        'String','Cancel', ...
        'Position',[320 16 80 28], ...
        'Callback', @cancelSelection);

    % ---------- Wait WITHOUT uiwait (avoids ViewModel warnings) ----------
    % We simply wait for the figure to be deleted.
    waitfor(fig);  % returns when fig is deleted by any of the callbacks

    % On confirm, a nested callback stored the choices into base selection array
    % Build the output (preserve visual order)
    picked = {};
    for i = 1:numel(nodes)
        if selections(i) && strlength(nodes(i).script) > 0
            picked{end+1} = char(nodes(i).script); %#ok<AGROW>
        end
    end
    selectedScripts = picked;

    % ---------- nested helpers ----------
    function onToggle(idx, val)
        selections(idx) = val;
        if ~val
            % turn OFF: disable and uncheck descendants
            for ch = nodes(idx).children
                selections(ch) = false;
                set(cbs(ch),'Value',0,'Enable','off');
                cascadeDisable(ch);
            end
        else
            % turn ON: ensure ancestors are ON, enable children
            p = nodes(idx).parent;
            while p > 0
                if ~selections(p)
                    selections(p) = true;
                    set(cbs(p),'Value',1,'Enable','on');
                end
                p = nodes(p).parent;
            end
            for ch = nodes(idx).children
                set(cbs(ch),'Enable','on');
            end
        end
    end

    function cascadeDisable(idx)
        for ch = nodes(idx).children
            selections(ch) = false;
            set(cbs(ch),'Value',0,'Enable','off');
            cascadeDisable(ch);
        end
    end

    function selectAllTop(~,~)
        for i = 1:numel(nodes)
            if nodes(i).parent==0
                selections(i) = true;
                set(cbs(i),'Value',1,'Enable','on');
                % enable immediate children (don't auto-select them)
                for ch = nodes(i).children
                    set(cbs(ch),'Enable','on');
                end
            end
        end
    end

    function clearAll(~,~)
        for i = 1:numel(nodes)
            selections(i) = false;
            set(cbs(i),'Value',0, 'Enable', onOff(nodes(i).parent==0));
        end
    end

    function confirmSelection(~,~)
        % simply close; selections are already up to date
        if ishghandle(fig), delete(fig); end
    end

    function cancelSelection(~,~)
        % clear selections and close
        selections(:) = false;
        if ishghandle(fig), delete(fig); end
    end

    function onClose(~,~)
        % Treat window close as cancel
        selections(:) = false;
        delete(fig);
    end

    function s = onOff(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end
end
