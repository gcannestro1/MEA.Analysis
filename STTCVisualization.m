%% Plot the STTC values that pass for valid & self-ref
% STTCVisualization makes heatmaps of STTC per well (colorbar limited to 0..1)

function STTCVisualization(FilteredTable, ChannelLayout, ElectrodeNumber, base)
% Expects FilteredTable with vars: WellNumber, Electrode1, Electrode2, STTC
    UniqueWellsSTTC = unique(FilteredTable.WellNumber);

    for j = 1%:numel(UniqueWellsSTTC)
        % rows for this well
        Rows = FilteredTable.WellNumber == UniqueWellsSTTC(j);
        X = FilteredTable.Electrode1(Rows);
        Y = FilteredTable.Electrode2(Rows);
        STTC = FilteredTable.STTC(Rows);

        % Need to figure out actual row/column based on 12 elec to assign
        XElecNum = str2double(ElectrodeNumber(X));
        YElecNum = str2double(ElectrodeNumber(Y));

        %Find actual electrode order to keep images consistent
  
        for l = 1:length(XElecNum)
            XElecOrder(l) = find(ChannelLayout.ElectrodeNumber == XElecNum(l));
            YElecOrder(l) = find(ChannelLayout.ElectrodeNumber == YElecNum(l));
        end

        % Make the matrix set to zeros to retain space for
        % non-participating electrodes
        n = numel(ChannelLayout.ElectrodeNumber);
        Matrix = NaN(n);

        % Make YElecOrder, XElecOrder, and STTC be lined up in a matrix
        for k = 1:length(STTC)
            Matrix(YElecOrder(k), XElecOrder(k)) = STTC(k);
        end

        % Plotting happens here
        f = figure('Name', sprintf('STTC Well %s', string(UniqueWellsSTTC(j))));
        % lock color limits to 0..1
        h = imagesc(Matrix, [0 1]);
        %removes color from NaNs
        set(h, 'Alphadata', ~isnan(Matrix))

        axis equal tight
        colormap(nebula);                       % use any colormap you like
        cb = colorbar; ylabel(cb, 'STTC');
        set(gca, 'XTick', 1:12, 'YTick', 1:12, 'TickLength', [0 0]);
        set(gca, 'XAxisLocation', 'top')
        
        % !!!!! Need to offset grid !!
        grid 
        Ax.XGrid
        
        xlabel('Electrode', 'FontSize', 12); 
        ylabel('Electrode', 'FontSize', 12);
        title(sprintf('STTC between electrodes – well %s', string(UniqueWellsSTTC(j))), 'FontSize', 12);

        %Exporting here
        PngFile = fullfile( sprintf('%s_STTC_Well%s.png', base, string(UniqueWellsSTTC(j))));
        exportgraphics(gcf, PngFile, 'Resolution', 600)
        close(f)
    end
clear X Y XElecNum YElecNum XElecOrder YElecOrder Matrix cb h j k Rows STTC UniqueWellsSTTC f PngFile n 
end

