%% STTC


!!!!!!!!!!!!!! FIX VISUALIZATION THAT IS COMMENTED OUT!!!!!!!!!!!!!!!!!!!!!


% Spike‐Time Tiling Coefficient
%   Here we find the spike time tiling coefficient *source*
%   DeltaT - window around the spikes of the examined source (electrode)
%   P - proportion of spikes (diff source) within DeltaT of the examined
%       source
%   T - proportion of time in Delta T / total duration of recording
%   Requires the MCSToolkit to be run prior

% STTC Null–Distribution Simulation
%   Generate a null distribution of the Spike‐Time Tiling Coefficient
%   by randomizing two spike‐trains of fixed sizes over a recording.
% 
%   Using +/- 2 SD of null distribution so only STTC values that pass the 
%   p= 0.05 or 95% (two-tailed) are retained in the final form

% Based on code from Negri, Menon, & Young-Pearse (2020)
%   Available on Github here https://github.com/SubstantiaNegri/meaAnalysis/tree/master
%   https://pmc.ncbi.nlm.nih.gov/articles/PMC6984810/#s3

%% User Parameters
RecordingLength = numel(TimeVector);
DeltaT    = 0.01/2;                      % ± window around each spike, in seconds .005s in each direction
StartTime = 0;            % Start time in seconds
EndTime = DurationS;      % End time in seconds

Iterations = 1000;                    % how many randomizations to run

% Defining file name for output to elim overwriting
[~, base, ~] = fileparts(DataFileName);
OutputSTTC = [base, 'RealSTTC.csv'];

%% STTC (real data)

% Going well-by-well isolating electrodes within that well
UniqueWells = unique(WellNumber);
AllSTTC = [];

for i = 1%:length(UniqueWells)
    CurrentWell = UniqueWells(i);
    ElectrodesInCurrentWell = find(WellNumber == CurrentWell);
    if length(ElectrodesInCurrentWell) < 2
        continue
    end
    % Define the electrode range
    ElectrodeRange = ElectrodesInCurrentWell;
    NumElectrodes = length(ElectrodeRange);

%% Loop over the electrodes in ElectrodeRange
    for ii = 1:NumElectrodes
        Electrode1 = ElectrodeRange(ii);
        for iii = 1:NumElectrodes
            Electrode2 = ElectrodeRange(iii);

            %% Real STTC
            % Calculate STTC between Electrode1 and ElectrodeRange
            [RealSTTC, ~, ~, ~, ~] = calculate_sttc(AllPeaks{Electrode1, 2}, AllPeaks{Electrode2, 2}, DeltaT, DurationS);

            %% Null STTC permutation
            %Electrode Spikes
            ElectrodeA_NumSpikes = length(AllPeaks{ii});           % # of spikes on electrode A
            ElectrodeB_NumSpikes = length(AllPeaks{iii});           % # of spikes in electrode B
            STTCNull = zeros(Iterations, 1);

            % Run Simulations
            for iv = 1:Iterations
                % random spike indexes (ticks) without replacement ->
                % converted to timings
                A_spikes = sort(randperm(RecordingLength, ElectrodeA_NumSpikes)'/ SamplingRate);
                B_spikes = sort(randperm(RecordingLength, ElectrodeB_NumSpikes)'/ SamplingRate);

                % compute STTC
                STTCNull(iv) = calculate_sttc(A_spikes, B_spikes, DeltaT, DurationS);
            end

            % Limits
            NullSD = std(STTCNull) * 2;
            NullMean = mean(STTCNull);
            PosLim = NullMean + NullSD;
            NegLim = NullMean - NullSD;

            % Flag valid STTC
            IsSignificant = RealSTTC > PosLim || RealSTTC < NegLim;

            % Store Row
            AllSTTC = [AllSTTC; {CurrentWell, Electrode1, Electrode2, RealSTTC, NullMean, NullSD, PosLim, NegLim, IsSignificant}];

        end
    end
end

%% Make Table
VarNames = {'WellNumber','Electrode1','Electrode2','STTC', 'NullMean', 'Null2SD', 'UpperLimit', 'LowerLimit', 'Significant'};
T = cell2table(AllSTTC, 'VariableNames', VarNames);

% Filter based on significance
FilteredTable = T(T.Significant == true, :);
writetable(FilteredTable, OutputSTTC);

clear NegLim PosLim NullMean NullSD IsSignificant ElectrodeA_NumSpikes ElectrodeB_NumSpikes STTCNull A_spikes B_spikes AllSTTC RealSTTC

%% Plot the STTC values using a bar graph
    % figure;
    % bar(ElectrodeRange, sttc_values);
    % xlabel('Electrode Number');
    % ylabel('STTC Value');
    % title(sprintf('STTC between Electrodes 1-8 and Electrode %d (Time %d-%d sec)', Electrode2, StartTime, EndTime));
    % grid on;
    % set(gca, 'XTick', ElectrodeRange);
    % xlim([min(ElectrodeRange)-1, max(ElectrodeRange)+1]);
    % 
    % figure;
    % imagesc(sttc_values);
    % ColorLimits = [0, 1]
    % imagesc(sttc_values, ColorLimits);
    % colorbar;
    % xlabel('Channel');
    % ylabel('Channel');
    % title('STTC between Channels in Well', UniqueWells(i));

%% Plotting to visualize distribution and STTC value

% figure
% hold on
% xlim = [-1, 1]
% histogram(STTCvals)
% xline(PosLim)
% xline(NegLim)
% plot(0.67, 0, 'r*')


%% Functions used in the STTC calculation
function [sttc_value, P_A, P_B, T_A, T_B] = calculate_sttc(A, B, DeltaT, DurationS)
    % Handle empty spike trains
    if isempty(A) || isempty(B)
        sttc_value = NaN;
        P_A = 0;
        P_B = 0;
        T_A = 0;
        T_B = 0;
        return;
    end

    % Ensure spike times are sorted
    A = sort(A(:));
    B = sort(B(:));

    % Calculate P_A and P_B using optimized functions
    P_A = calculate_P(A, B, DeltaT);
    P_B = calculate_P(B, A, DeltaT);

    % Calculate T_A and T_B
    T_A = calculate_T(A, DeltaT, DurationS);
    T_B = calculate_T(B, DeltaT, DurationS);

    % STTC calculation
    denom1 = 1 - (P_A * T_B);
    denom2 = 1 - (P_B * T_A);

    if denom1 == 0 || denom2 == 0
        sttc_value = NaN;
    else
        sttc_value = 0.5 * (((P_A - T_B) / denom1) + ((P_B - T_A) / denom2));
    end
end

% P is proportion of spikes within DeltaT of the other spike train.
function P = calculate_P(A, B, DeltaT)
    % Initialize count of spikes in A that have a spike in B within DeltaT
    count = 0;
    idx_B = 1;
    len_B = length(B);

    for i = 1:length(A)
        % Move idx_B to the first B spike within DeltaT of A(i)
        while idx_B <= len_B && B(idx_B) < A(i) - DeltaT
            idx_B = idx_B + 1;
        end

        % Check if B spike is within DeltaT of A(i)
        if idx_B <= len_B && abs(B(idx_B) - A(i)) <= DeltaT
            count = count + 1;
        end
    end

    P = count / length(A);
end

% T is the proportion of time in DeltaT compared to the total recording 
function T = calculate_T(spike_times, DeltaT, DurationS)
    if isempty(spike_times)
        T = 0;
        return;
    end

    % Create intervals around each spike
    intervals = zeros(length(spike_times), 2);
    intervals(:, 1) = max(spike_times - DeltaT, 1);
    intervals(:, 2) = min(spike_times + DeltaT, DurationS);

    % Sort intervals
    intervals = sortrows(intervals);

    % Merge overlapping intervals
    MergedIntervals = intervals(1, :);
    for i = 2:size(intervals, 1)

        % Overlapping intervals, merge them
        if intervals(i, 1) <= MergedIntervals(end, 2)       
            MergedIntervals(end, 2) = max(MergedIntervals(end, 2), intervals(i, 2));
        
        % Non-overlapping interval, add it to the list
        else
            MergedIntervals = [MergedIntervals; intervals(i,:)];
        end
    end

    % Calculate total covered samples
    CoveredTime = sum(MergedIntervals(:, 2) - MergedIntervals(:, 1));
    T = CoveredTime / DurationS;
end

