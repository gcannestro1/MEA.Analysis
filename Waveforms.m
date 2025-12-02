% Waveform Visualization
% Plotting Waveforms by well with all passing electrodes
% WellNumber and ElectrodeNumber are vectors of the same length

UniqueWellsWaveform = unique(WellNumber);

for i = 1:length(UniqueWells)
    CurrentWell = UniqueWellsWaveform(i);
    ElectrodesInCurrentWell = find(WellNumber == CurrentWell);       %finds electrodes that belong to well being processed

    f = figure('Name', sprintf('Waveforms %s', string(UniqueWellsWaveform(i))));
    for ElectrodeIndex = 1:length(ElectrodesInCurrentWell)
        CurrentElectrode = ElectrodesInCurrentWell(ElectrodeIndex);
        subplot(length(ElectrodesInCurrentWell), 1, ElectrodeIndex);
        for j = 1:length(SpikeWaveforms{CurrentElectrode})
            waveform = SpikeWaveforms{CurrentElectrode}{j};
            WaveVector = linspace(-1, 2.2, length(waveform));
            plot(WaveVector, waveform, 'LineWidth', 1 );
            hold on;
        end

        xlabel('Time Relative to Event (ms)', 'Color', 'k', 'FontSize', 12);
        ylabel('Voltage (\muV)', 'Color', 'k', 'FontSize', 12);
        TitleTxt = append('Electrode ', ElectrodeNumber(CurrentElectrode));
        title(TitleTxt, 'Color', 'k', 'FontSize', 12, 'HorizontalAlignment', 'Center');
        grid on;
        xlim([-1, 2]);
        ylim([-50, 50]);
    end

    % % Customized plot
    OverallTitle = append('Waveforms Well ', string(UniqueWellsWaveform(i)));
    sgtitle(OverallTitle, 'color', 'k', 'FontSize', 12);

    % Export here
        % Saving as .fig here to edit axis after inspection
        % Not all needed, not all have same amplitude
    FigFile = fullfile(sprintf('%s_WaveformWell%s', base, string(UniqueWellsWaveform(i))));
    savefig(FigFile)
    %exportgraphics(gcf, FigFile, 'Resolution', 600)
    close(f)

end

clear WaveVector waveform i j CurrentElectrode CurrentWell TitleTxt OverallTitle UniqueWellsWaveform FigFile ElectrodeIndex f ElectrodesInCurrentWell
