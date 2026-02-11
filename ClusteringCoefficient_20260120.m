% !!!!!!!!!!!!!!!!!!
% To Do list
% make in well-by-well for loop
% add in color for active electrodes
% finish saving file
% write paragraph for explanation of code
% add to github


% Getting Network Clustering Coefficient here
% References to:
% (Negri et al., 2020) https://www.eneuro.org/content/7/1/ENEURO.0080-19.2019/tab-figures-data
% (Watts & Strogatz, 1998) https://www.nature.com/articles/30918

%% Setting up layout for figures
%Electrode config for sttc
% Electrodes are setup like this for MCS 24-well
% ** 21 31 **
% 12 22 32 42
% 13 23 33 43
% ** 24 34 **

ChannelLayout.ElectrodeNumber = [21; 31; 12; 22; 32; 42; 13; 23; 33; 43; 24; 34];
ChannelLayout.x = [2; 3; 1; 2; 3; 4; 1; 2; 3; 4; 2; 3];
ChannelLayout.y = [4; 4; 3; 3; 3; 3; 2; 2; 2; 2; 1; 1];
SPlot = string(ChannelLayout.ElectrodeNumber);

% Remove self-referencing nodes from STTC table
ToRemove = [];
for i = 1:height(FilteredTable)
    if FilteredTable.Electrode1(i) == FilteredTable.Electrode2(i)
        ToRemove = [ToRemove, i];
    end
end

FilteredTable(ToRemove, :) = []; %cleaned from self-ref

%% Run Clustering Co by well
UniqueClusterWells = unique(FilteredTable.WellNumber);

% Pre-determining x and y
x = ChannelLayout.x;
y = ChannelLayout.y;

for i = 1:length(UniqueClusterWells)
    CurrentWell = UniqueClusterWells(i);
    STTCInCurrentWell = find(FilteredTable.WellNumber == CurrentWell);

    %Finding all active electrodes to map at end
    ActiveElecForWell = AllCombinedTable.("Well Number") == CurrentWell;
    ActiveElecForWell = AllCombinedTable.("Electrode Number")(ActiveElecForWell);

    % Create graph with edges below from STTCs
        % get which elect are 1 and 2
    s = FilteredTable.Electrode1(STTCInCurrentWell);
    t = FilteredTable.Electrode2(STTCInCurrentWell);
        %get elect identity
    s = ElectrodeNumber(s);
    t = ElectrodeNumber(t);

    w = FilteredTable.STTC(STTCInCurrentWell);             % Is a weight to create edge maybe change later?
    G = graph(s, t, w, SPlot);

    % using channel layout from above and electrode numbers to plot in well
    % orientation
    [~, locs] = ismember(G.Nodes.Name, SPlot);
    XCoords = x(locs);
    YCoords = y(locs);

    % Removing duplicate edges (from 1-2 and 2-1 to only retaining 1-2)
    ToRemove = [];
    for m = 1:height(G.Edges)-1
        E1m = G.Edges.EndNodes(m,:);
        E2m = G.Edges.EndNodes(m+1, :);

        if E1m{1} == E2m{1} & E1m{2} == E2m{2}
            ToRemove = [m, ToRemove];
        else
            continue  
        end
    end
    G = rmedge(G,ToRemove);

    %Finding local clustering coefficients (by elec)
    ClusteringCo = zeros(height(G.Nodes), 1);
    for j = 1:height(G.Nodes)
        NeighborNodes = neighbors(G, j);
        NeighborCount = height(NeighborNodes);
        Links = 0;

        % removes nodes with <2 neighbors to avoid dividing by 0 in eq below
        if NeighborCount < 2
            ClusteringCo(j) = 0;
            continue
        end

        for k = 1:NeighborCount
            for l = k+1:NeighborCount
                if l <= k
                    continue
                end
                if findedge(G, NeighborNodes(k), NeighborNodes(l)) > 0
                    Links = Links + 1;
                end
            end
        end

        Numerator = 2*Links;
        Denom = NeighborCount*(NeighborCount - 1);
        ClusteringCo(j) = Numerator/Denom;
    end

    % Global Clustering Co here
    AvgClusteringCo = mean(ClusteringCo);

    % Plotting here
    F = figure;
    h = plot(G, 'XData', XCoords, 'YData', YCoords, 'NodeLabel', G.Nodes.Name, 'NodeFontSize', 14, 'LineWidth', 1, 'EdgeColor', 'k', 'NodeColor', '#808080');
    highlight(h, ActiveElecForWell, 'NodeColor', 'r')
    title(['Clustering Coefficient C = ' num2str(AvgClusteringCo)])
    set(gca, 'XTick', [], 'YTick', [])
    axis off

    % Saving figure here as .png because axis doesn't need adjustment

    FigFile = fullfile(sprintf('%s%sClusterCo%s', base, string(UniqueClusterWells(i))));
    FigFile = append(FigFile, '.png');
    exportgraphics(gcf, FigFile, 'Resolution', 600)
    close(F)

end
% disp('Clustering Coefficient Complete')
% clear RemoveSelf ToRemove F h Numerator Denom ClusteringCo AvgClusteringCo i j k l
% clear NeighborCount NeighborNodes Links XCoords x YCoords y ActiveElecForWell STTCInCurrentWell
% clear CurrentWell s t w G UniqueClusterWells ToRemove SPlot
