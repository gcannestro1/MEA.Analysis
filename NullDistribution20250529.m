%% STTC Null–Distribution Simulation
% Generate a null distribution of the Spike‐Time Tiling Coefficient
% by randomizing two spike‐trains of fixed sizes over a recording.

% Based on code from Negri, Menon, & Young-Pearse (2020)
% Available on Github here https://github.com/SubstantiaNegri/meaAnalysis/tree/master
% https://pmc.ncbi.nlm.nih.gov/articles/PMC6984810/#s3

% User Parameters
RecordingLength = numel(TimeVector); % in “ticks”
DeltaT    = 0.01/2;                        % ± window around each spike, in seconds
Iterations    = 1000;                    % how many randomizations to run
OutputNull    = 'STTC_null.csv';
OutputReal = 'RealSTTC.csv';

%% Choosing Indiv. wells and only looking at electrodes within them
for i = 1%:length(UniqueWells)
    CurrentWell = UniqueWells(i);
    ElectrodesInCurrentWell = find(WellNumber == CurrentWell);
    if length(ElectrodesInCurrentWell) < 2
        continue
    end

    for ii = 1:length(ElectrodesInCurrentWell)
        Electrode1 = ElectrodesInCurrentWell(ii);
        for iii = 1:length(ElectrodesInCurrentWell)
            Electrode2 = ElectrodesInCurrentWell(iii);
            if Electrode1 == Electrode2 || Electrode2 < Electrode1
                continue
            end

            %Electrode Spikes
            ElectrodeA_NumSpikes = length(AllPeaks{ii});           % # of spikes on electrode A
            ElectrodeB_NumSpikes = length(AllPeaks{iii});           % # of spikes in electrode B

            % Pre‐allocate Result Table
            ElectrodeA = repmat(ElectrodeA_NumSpikes, Iterations, 1);
            ElectrodeB = repmat(ElectrodeB_NumSpikes, Iterations, 1);
            %DeltaTs   = repmat(DeltaT, Iterations, 1);
            STTCvals = zeros(Iterations, 1);


            %% Run Simulations
            for iv = 1:Iterations
                % random spike indexes (ticks) without replacement
                A_spikes = randperm(RecordingLength, ElectrodeA_NumSpikes)';
                B_spikes = randperm(RecordingLength, ElectrodeB_NumSpikes)';

                %Convert to timings
                A_spikes = sort(A_spikes)/SamplingRate;
                B_spikes = sort(B_spikes)/SamplingRate;
                
                % compute STTC (uses calculate_sttc from STTC_20250522.m)
                [sttc_value, ~, ~, ~, ~] = calculate_sttc(A_spikes, B_spikes, DeltaT, RecordingLength);
                STTCvals(iv) = sttc_value;
            end


            %% Is STTC real based on null param
            % SD*2.58 is 99.5% of population
            SDNull = std(STTCvals) * 2.58;
            SDNullMean = mean(STTCvals);
            PosSDLim = SDNullMean + SDNull;
            NegSDLim = SDNullMean - SDNull;
            % Make a logic index if they are real or not to remove the
            % false ones
            
            T = table(CurrentWell, Electrode1, Electrode2, SDNull, PosSDLim, NegSDLim, 'VariableNames',{'Well Number','Electrode 1','Electrode 2', 'SDNull', 'PositiveLimit', 'NegativeLimit'});

            if exist(OutputNull,'file')
                writetable(T, OutputNull, 'WriteMode','Append', 'Delimiter',',', 'WriteVariableNames',false);
            else
                writetable(T, OutputNull, 'Delimiter',',');
            end

            disp(['Well ', num2str(CurrentWell), ' Electrode', num2str(Electrode1)])
        end
    end
end

%% Combine real/null sttc numbers
T1 = readtable('STTC_notconfirmed.csv');
T2 = readtable('STTC_null.csv');

MergedTable = outerjoin(T1, T2, 'Keys', {'WellNumber', 'Electrode1', 'Electrode2'}, 'MergeKeys', true);

% %% Plotting to visualize distribution and STTC value
% % % 2.58 SD accounts for 99.5% of the population
% SDNull = std(STTCvals) * 2.58;
% SDNullMean = mean(STTCvals);
% PosSDLim = SDNullMean + SDNull;
% NegSDLim = SDNullMean - SDNull;
% figure
% hold on
% histogram(STTCvals)
% xline(PosSDLim)
% xline(NegSDLim)
% %plot(0.67, 0, 'r*')



% %% Filter and save real STTC values
FilteredTable = MergedTable(MergedTable.STTC > MergedTable.PositiveLimit | MergedTable.STTC < MergedTable.NegativeLimit, :);
% writetable(FilteredTable, 'ValidSTTCs.csv');


%% Functions for STTC from STTC file
% Functions used in the STTC calculation
function [sttc_value, P_A, P_B, T_A, T_B] = calculate_sttc(A, B, DeltaT, RecordingLength)
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
T_A = calculate_T(A, DeltaT, RecordingLength);
T_B = calculate_T(B, DeltaT, RecordingLength);

% STTC calculation
denom1 = 1 - (P_A * T_B);
denom2 = 1 - (P_B * T_A);

if denom1 == 0 || denom2 == 0
    sttc_value = NaN;
else
    sttc_value = 0.5 * (((P_A - T_B) / denom1) + ((P_B - T_A) / denom2));
end
end

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

function T = calculate_T(spike_times, DeltaT, RecordingLength)
if isempty(spike_times)
    T = 0;
    return;
end

% Create intervals around each spike
intervals = zeros(length(spike_times), 2);
intervals(:,1) = max(spike_times - DeltaT, 1);
intervals(:,2) = min(spike_times + DeltaT, RecordingLength);

% Sort intervals
intervals = sortrows(intervals);

% Merge overlapping intervals
merged_intervals = intervals(1,:);
for i = 2:size(intervals,1)
    if intervals(i,1) <= merged_intervals(end,2)
        % Overlapping intervals, merge them
        merged_intervals(end,2) = max(merged_intervals(end,2), intervals(i,2));
    else
        % Non-overlapping interval, add it to the list
        merged_intervals = [merged_intervals; intervals(i,:)];
    end
end

% Calculate total covered samples
covered_samples = sum(merged_intervals(:,2) - merged_intervals(:,1) + 1);
T = covered_samples / RecordingLength;
end
