% MaybeCall
% Call function/script `name` if it was selected
    % can be {'FuncA','FuncB.m', ...}. `name` can be 'FuncA' or 'FuncA.m'.
    % Convention: functions accept/return `ctx`; scripts will just run in-place.

function varargout = MaybeCall(SelectedAnalysis, name, varargin)
    % normalize names (case-insensitive, ignore .m)
    norm = @(s) erase(string(s), ".m");
    picked = norm(SelectedAnalysis);
    target = norm(name);

    if ~ismember(target, picked)
        return; % not selected → do nothing
    end

    % try as function first
    fname = char(target);
    % if exist(fname, 'file') == 2
    %     try
    %         % Preferred: optional analyses are functions:  function ctx = X(ctx, varargin)
    %         ctx = feval(fname, ctx, varargin{:});
    %         return
    %     catch
    %         % Fall back: try to run as a script (uses current workspace)
    %         try
    %             run([fname '.m']);
    %         catch ME
    %             warning('Failed to run "%s": %s', fname, ME.message);
    %         end
    %     end
    % else
    %     warning('Analysis "%s" not found on the path.', fname);
    % end
        % Call as function with forwarded args
    if nargout
        varargout{1} = feval(fname, varargin{:});
    else
        feval(fname, varargin{:});
    end
end