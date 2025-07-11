
% Parameters
OutputSTTC = 'STTC_notconfirmed.csv';

DeltaT = 0.01;       % 100 ms = 0.1 seconds
SamplesInWindow = DeltaT * SamplingRate;  % 100 ms corresponds to 2000 samples

% Define the time window for analysis 
StartTime = 0;            % Start time in seconds
EndTime = DurationS;      % End time in seconds

% Calculate the corresponding sample indices
StartSample = round(StartTime * SamplingRate) + 1;
EndSample = round(EndTime * SamplingRate);

% Use the number of samples in the selected window
RecordingLength = EndSample - StartSample + 1;  % In samples


% Going well-by-well isolating electrodes within that well
UniqueWells = unique(WellNumber);
for i = 1%:length(UniqueWells)
    CurrentWell = UniqueWells(i);
    ElectrodesInCurrentWell = find(WellNumber == CurrentWell);
    if length(ElectrodesInCurrentWell) < 2
        continue
    end
    % Define the electrode range and the electrode to compare with
    ElectrodeRange = ElectrodesInCurrentWell;
    %Electrode2 = ElectrodesInCurrentWell(1);  % Electrode to compare with

    % Initialize arrays to store STTC values and intermediate parameters
    NumElectrodes = length(ElectrodeRange);
    sttc_values = zeros(NumElectrodes);
    P_A_values = zeros(NumElectrodes);
    P_B_values = zeros(NumElectrodes);
    T_A_values = zeros(NumElectrodes);
    T_B_values = zeros(NumElectrodes);

    %% Loop over the electrodes in ElectrodeRange
    for ii = 1:NumElectrodes
        Electrode1 = ElectrodeRange(ii);
        for iii = 1:NumElectrodes
            Electrode2 = ElectrodeRange(iii);

            % Skip comparison if Electrode1 is the same as Electrode2
             % if Electrode1 == Electrode2 
             %     continue;
             % end

            % % Get full data for Electrode1
            % data1_full = channelData(Electrode1, :);
            % % Extract the data segment for Electrode1
            % data1 = data1_full(StartSample:EndSample);
            %
            % % High-pass filter for Electrode1
            % dataFilterHigh1 = filtfilt(b, a, data1);
            %
            % % Spike detector for Electrode1
            % MPH1 = std(abs(dataFilterHigh1)) * 6.5;  % Adjust threshold as needed
            % [PKS1, LOC1] = findpeaks(abs(dataFilterHigh1), 'MinPeakHeight', MPH1, 'MinPeakDistance', MPD);
            %
            % Calculate STTC between Electrode1 and ElectrodeRange
            [sttc_value, P_A, P_B, T_A, T_B] = calculate_sttc(AllPeaks{Electrode1, 2}, AllPeaks{Electrode2, 2}, DeltaT, RecordingLength);

            % Store the results
            sttc_values(iii, ii) = sttc_value;
            P_A_values(iii, ii) = P_A;
            P_B_values(iii, ii) = P_B;
            T_A_values(iii, ii) = T_A;
            T_B_values(iii, ii) = T_B;


            %% Save results in table csv
            T = table(CurrentWell, Electrode1, Electrode2, sttc_value, 'VariableNames', {'Well Number','Electrode 1','Electrode 2','STTC'});

            if exist(OutputSTTC,'file')
                writetable(T, OutputSTTC, 'WriteMode','Append', 'Delimiter',',', ...
                    'WriteVariableNames',false);
            else
                writetable(T, OutputSTTC, 'Delimiter',',');
            end

            % Display the result for this electrode
            %fprintf('Electrode %d vs Electrode %d: STTC = %f\n', Electrode1, Electrode2, sttc_value);
        end
    end

    %% Plot the STTC values using a bar graph
    % figure;
    % bar(ElectrodeRange, sttc_values);
    % xlabel('Electrode Number');
    % ylabel('STTC Value');
    % title(sprintf('STTC between Electrodes 1-8 and Electrode %d (Time %d-%d sec)', Electrode2, StartTime, EndTime));
    % grid on;
    % set(gca, 'XTick', ElectrodeRange);
    % xlim([min(ElectrodeRange)-1, max(ElectrodeRange)+1]);

    figure;
    imagesc(sttc_values);
    colorbar;
    xlabel('Channel');
    ylabel('Channel');
    title('STTC between Channels in Well', UniqueWells(i));

end
%% Functions used in the STTC calculation
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


