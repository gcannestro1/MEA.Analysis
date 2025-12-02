% Getting Network Clustering Coefficient here
% References to:
% (Negri et al., 2020) https://www.eneuro.org/content/7/1/ENEURO.0080-19.2019/tab-figures-data
% (Watts & Strogatz, 1998) https://www.nature.com/articles/30918 


%Electrode config for sttc
% Electrodes are setup like
% ** 21 31 **
% 12 22 32 42
% 13 23 33 43
% ** 24 34 **

!!!!!!!!!!!!!! See below issues !!!!!!!!!!!
%Setting up layout for figures
ChannelLayout.ElectrodeNumber = [21; 31; 12; 22; 32; 42; 13; 23; 33; 43; 24; 34];
ChannelLayout.X = [2; 3; 1; 2; 3; 4; 1; 2; 3; 4; 2; 3];
ChannelLayout.Y = [4; 4; 3; 3; 3; 3; 2; 2; 2; 2; 1; 1];
SPlot = string(ChannelLayout.ElectrodeNumber);

%  figure; hold on
%  dot = plot(ChannelLayout.X, ChannelLayout.Y, 'ko', MarkerFaceColor='none')
%  text(ChannelLayout.X, ChannelLayout.Y+0.25, SPlot)
% 
% for Well = 1:length(unique(FilteredTable.WellNumber))
%     WellRange = find(FilteredTable.WellNumber == FilteredTable.WellNumber(Well));
%     figure; hold on
%     plot(ChannelLayout.X, ChannelLayout.Y, 'ko', MarkerFaceColor ='none');
%     %text(ChannelLayout.X, ChannelLayout.Y+0.25, SPlot);
% 
% 
%     for i = 1:height(WellRange)
%         e1 = FilteredTable.Electrode1(i);
%         e2 = FilteredTable.Electrode2(i);
% 
%         % Find coordinates
%         idx1 = find(ChannelLayout.ElectrodeNumber == str2double(ElectrodeNumber{e1}));
%         idx2 = find(ChannelLayout.ElectrodeNumber == str2double(ElectrodeNumber{e2}));
% 
%         %Set-up color for heatmap
%         cmap = colormap('turbo');
%         zmap = linspace(0, 1, length(cmap));
% 
%         if ~isempty(idx1) && ~isempty(idx2)
%             x = [ChannelLayout.X(idx1), ChannelLayout.X(idx2)];
%             y = [ChannelLayout.Y(idx1), ChannelLayout.Y(idx2)];
% 
%             color = interp1(zmap, cmap, abs(FilteredTable.STTC(i)));
%             plot(x, y, '-', 'LineWidth', 2, 'Color', color);
%             colorbar
%         end
%     end
%     %Filling in all active elec, regardless of sttc
%     ActiveElecinWell = find(WellNumber == FilteredTable.WellNumber(Well));
%     for ActivePlot = 1:length(ActiveElecinWell)
%         ActiveElecLocation = find(ChannelLayout.ElectrodeNumber == str2double(ElectrodeNumber{ActivePlot}));
%         FilledDot = plot(ChannelLayout.X(ActiveElecLocation), ChannelLayout.Y(ActiveElecLocation), 'ko', MarkerFaceColor='k');
%     end
% 
% end
% xlim([0,5])
% ylim([0,5])
% set(gca, 'XTick', [], 'YTick', [])
% axis off
% uistack(FilledDot, 'top')
%     text(ChannelLayout.X, ChannelLayout.Y+0.25, SPlot);
% title(['Clustering Coefficient C = ' num2str(AvgClusteringCo)])



%% As a graph for connectivity
!!!!!!!!!! Remove self referencing, nan from avg, & ????? !!!!!!!!!!!!!!!!!!
!!!!! remove colorcoding for the indiv lines only the global matters!!!!!!
s = FilteredTable.Electrode1;
t = FilteredTable.Electrode2;
w = FilteredTable.STTC;

G = graph(s, t, w, SPlot);

ElectrodeIDs = num2str(ChannelLayout.ElectrodeNumber)';
X = ChannelLayout.X;
Y = ChannelLayout.Y;

[~, locs] = ismember(G.Nodes.Name, SPlot);
XCoords = X(locs);
YCoords = Y(locs);

cmap = colormap('turbo');
zmap = linspace(-1, 1, length(cmap));
ColorIdx = round(255*G.Edges.Weight+1);
EdgeColors = cmap(ColorIdx, :);

% Getting Network Clustering Coefficient here
% References to:
% (Negri et al., 2020) https://www.eneuro.org/content/7/1/ENEURO.0080-19.2019/tab-figures-data
% (Watts & Strogatz, 1998) https://www.nature.com/articles/30918 

ClusteringCo = zeros(height(G.Nodes), 1);
for i = 1:height(G.Nodes);
    NeighborNodes = neighbors(G, i);
    NeighborCount = height(NeighborNodes);
    Links = 0;

    % removes nodes with <2 neighbors to avoid dividing by 0 in eq below
    if NeighborCount < 2;
        ClusteringCo(i) = NaN;
        continue
    end

    for k = 1:NeighborCount
        for l = k+1:NeighborCount
            if l <= k
                continue
            end
            if findedge(G, NeighborNodes(k), NeighborNodes(l)) > 0;
                Links = Links + 1;
            end
        end
    end

    Numerator = 2*Links;
    Denom = NeighborCount*(NeighborCount - 1);
    ClusteringCo(i) = Numerator/Denom;
end
%!!!!!!! remove nan before doing avg here!!!!!!!!!!
% 
AvgClusteringCo = mean(ClusteringCo);



figure
plot(G, 'XData', XCoords, 'YData', YCoords, 'NodeLabel', G.Nodes.Name, 'NodeFontSize', 14,  'EdgeColor', EdgeColors, 'LineWidth', 2)
title(['Clustering Coefficient C = ' num2str(AvgClusteringCo)])
colormap('Turbo')
colorbar
set(gca, 'XTick', [], 'YTick', [])
axis off
