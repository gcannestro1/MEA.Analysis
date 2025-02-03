% Rasterplot
clear all; close all; clc 
load('20241220_HD_WT.HD.NM.DIV43_Control_mwd.mat')
%%
OrderOfElectrode = str2num(cell2mat(ElectrodeNumber));
UniqueWells = unique(WellNumber);
[~, ElectrodeOrderTemp] = ismember(OrderOfElectrode, Settings.Recording.ElectrodeOrder);
ElectrodeOrder = ElectrodeOrderTemp + 1;

for WellIdx = 1:length(UniqueWells)
    CurrentWell = UniqueWells(WellIdx);
    ElectrodesInCurrentWell = find(WellNumber == CurrentWell);
    WellName = Settings.Recording.WellLabel(CurrentWell);
    NetworkBurstInfoIdx = find(arrayfun(@(x) NetworkBurstInfo{x}.WellNumber == CurrentWell, 1:length(NetworkBurstInfo)));

    % Plot spikes and BurstTimes for each electrode in the current well
    figure      % Create figure for each unique well
    hold on
    for WellIdx = 1:length(ElectrodesInCurrentWell)
        ElectrodeIndex = ElectrodesInCurrentWell(WellIdx);
        ElectrodeSpikes = SpikeByElectrode{ElectrodeIndex, 1}.TimingS;
        YPosition = ElectrodeOrder(ElectrodeIndex);

        % Plot electrode spikes
        plot(ElectrodeSpikes, YPosition * ones(size(ElectrodeSpikes)), '|k', 'MarkerSize', 10);

        % Plot BurstTimes for the corresponding row
        CurrentBurstTimes = BurstByElectrode{ElectrodeIndex}.TimingS;
        if ~isempty(CurrentBurstTimes)
            for BurstIdx = 1:length(CurrentBurstTimes)
                line([CurrentBurstTimes{BurstIdx}(1), CurrentBurstTimes{BurstIdx}(end)], [YPosition+0.25, YPosition+0.25], 'Color', 'r', 'LineWidth', 5);
                %the 0.5 above is to offset it slightly to be visible ABOVE
                %the activity
                hold on;
            end
        end
    end
    if ~isempty(NetworkBurstInfoIdx)
        for idx = 1:length(NetworkBurstInfoIdx)
            nbInfo = NetworkBurstInfo{NetworkBurstInfoIdx(idx)};
            for nb = 1:length(nbInfo.NetworkBursts)
                startTime = nbInfo.TimingS(nb, 1);
                endTime = nbInfo.TimingS(nb, 2);
                involvedElectrodes = nbInfo.ElectrodesInvolved{nb};
                for elec = involvedElectrodes'
                    yPositionNB = ElectrodeOrder(elec);
                    line([startTime, endTime], [yPositionNB + 0.5, yPositionNB + 0.5], 'Color', 'b', 'LineWidth', 5);
                end
            end
        end
    end

% Customize subplot
xlabel('Time (s)');
ylabel('Electrode Number');
ylim([0 13]);
title(['Raster Plot - Well ' (WellName)]);
end

clear YPosition i ElectrodeSpikes WellIdx ElectrodeIndex CurrentWell CurrentBurstTimes ElectrodesInCurrentWell BurstIdx WellName idx elec nb nbInfo
