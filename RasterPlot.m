%% RasterPlot 

% get how many wells
UniqueWellRaster = unique(WellNumber);
for i = 1:length(UniqueWellRaster)
    % participating elec in that well
    ElecInWell = find(WellNumber == UniqueWellRaster(i));

    % Initializing figure here
    f = figure('Name', sprintf('Raster Well %s', string(UniqueWellRaster(i))));
    hold on

    for j = 1:length(ElecInWell)
        ElecNumInWell = str2double(ElectrodeNumber{ElecInWell(j)});
        ElecOrderForThisWell = find(ChannelLayout.ElectrodeNumber == ElecNumInWell);    % Will also be the Y position in plotting

        % Get spike info & plot
        ElectrodeSpikes = SpikeByElectrode{ElecInWell(j), 1}.TimingS;
        plot(ElectrodeSpikes, ElecOrderForThisWell * ones(size(ElectrodeSpikes)), '|k', 'MarkerSize', 10)
        hold on

        % Bursts
        % Does it exist? If no bursts, no network either so
        % continue
        if BurstByElectrode{ElecInWell(j)}.NumberOfBursts == 0
            continue
        end

        % Get timings, plot above spikes
        CurrentBurstTimes = BurstByElectrode{ElecInWell(j)}.TimingS;
        for k = 1:length(CurrentBurstTimes)
            line([CurrentBurstTimes{k}(1), CurrentBurstTimes{k}(end)], [ElecOrderForThisWell+0.25, ElecOrderForThisWell+0.25], 'Color', 'r', 'LineWidth', 5);

            %the 0.5 above is to offset it slightly to be visible ABOVE spikes
            hold on;
        end

        % Network burst
        if NetworkByElectrode{ElecInWell(j)}.NetworkBurstCount == 0
            continue
        end

        NBInfo = NetworkByElectrode{ElecInWell(j)};
        for l = 1:NBInfo.NetworkBurstCount
            Start = NBInfo.TimingS(l, 1);
            End = NBInfo.TimingS(l, 2);

            InvolvedElectrodes = NBInfo.ElectrodesInvolved{l};
            for m = 1:length(InvolvedElectrodes)
                %Need to get electrode order here again
                InvolvedNumber(m) = str2double(ElectrodeNumber{InvolvedElectrodes(m)});
                NBYPosition = find(ChannelLayout.ElectrodeNumber == InvolvedNumber(m));
                line([Start, End], [NBYPosition + 0.5, NBYPosition + 0.5], 'Color', 'b', 'LineWidth', 5);
            end
        end

    end
    % Customize plot
    xlabel('Time (s)', 'FontSize', 12);
    ylabel('Electrode Number', 'FontSize', 12);
    ylim([0 13]);
    TitleTxt = append('Raster plot - Well ', string(UniqueWellRaster(i)));
    title(TitleTxt, 'FontSize', 12);

    %export figure here
    %PngFile = fullfile(sprintf('%s_RasterWell%s.png', base, string(UniqueWellRaster(i))));
    %exportgraphics(gcf, PngFile, 'Resolution', 600, Units="pixels", Width=600,Height=500,Padding=10)

    FigFile = fullfile(sprintf('%s_RasterWell%s.fig', base, string(UniqueWellRaster(i))));
    savefig(FigFile)

    close(f)
end

clear CurrentBurstTimes BurstIdx Start End f k m l InvolvedNumber NBYPosition InvolvedElectrodes NBInfo UniqueWellRaster


