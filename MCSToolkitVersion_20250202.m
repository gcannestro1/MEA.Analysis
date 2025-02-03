%% Load Data in and verify details
%doc McsHDF5
clear all; close all; clc

% !!!!!!!! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% To Do list
% make plots of waveforms the same size
% Make Rasterplot include Network Bursts

%LogISI and MaxInterval are top two but which should we use?
% https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4969396/

DataFileName = '20241220_WT_WT.HD.NM.DIV43PTX_Control_mwd.h5';

data = McsHDF5.McsData(DataFileName);

%For .csv name later
[outputPath, outputFileBase, ~] = fileparts(DataFileName);
CSVFileName = fullfile(outputPath, [outputFileBase '.csv']);

HighPassOnData = data.Recording{1, 1}.AnalogStream{1, 1}.Info.HighPassFilterCutOffFrequency(1);
LowPassOnData = data.Recording{1, 1}.AnalogStream{1, 1}.Info.LowPassFilterCutOffFrequency(1);
SamplingRate = cast(1000000/(data.Recording{1, 1}.AnalogStream{1, 1}.Info.Tick(1)), 'double');

fprintf('SamplingRate %d Hz, HighPass %s Hz, LowPass %s Hz', SamplingRate, HighPassOnData{1,1}, LowPassOnData{1,1});

%% Double Check Parameters to be applied
clear SamplingRate LowPassOnData HighPassOnData outputFileBase outputPath;   %removes data pulled in from file to make room

%creating Array to keep Parameters Below!!!
Settings=[];

Settings.Recording.SamplingRate = 20000;
Settings.Recording.ElectrodeOrder = [21 31 12 22 32 42 13 23 33 43 24];
Settings.Recording.WellLabel = {'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'D1', 'D2', 'D3', 'D4', 'D5', 'D6'};
Settings.Recording.ScalingFactor = 1e-6;  % Scale back to microvolts

Settings.Filters.HighPassOrder = 2;
Settings.Filters.HighPassCutoff = 200;
Settings.Filters.LowPassOrder = 2;
Settings.Filters.LowPassCutoff = 3500;

Settings.Baseline.WindowMs = 100;                              %50 for toolkit, 100 for MCS
Settings.Baseline.NumberOfSegment = 3;
Settings.Baseline.ThresholdMulti = 5;
%Settings.Baseline.Purenoisewindow = 2;                     %10 sections of 50ms for 500

Settings.SpikeDetection.MinFiringRate = 0.1;
Settings.SpikeDetection.DeadTime = 0.003;                   % 3ms or 0.003s between peaks %paper says 1ms, why they implement 3

Settings.Waveform.BeforeEventMs = 1;                        %same as MCS
Settings.Waveform.AfterEventMs = 2;

Settings.BurstDetection.MinSpikes = 3;                      % min of 3 spikes to be a burst
Settings.BurstDetection.MaxStartInterval = 0.05;            % changed from  .17 to match MCS
Settings.BurstDetection.MaxIntraBurstInterval = 0.05;       % changed from  .2 to match MCS
Settings.BurstDetection.MaxInterBurstInterval = 0.1;        % changedfrom   .3 to match MCS
Settings.BurstDetection.MinDuration = 0.03;                 % changed from  .01 (they wrote this ->)used in the paper 0.03???

Settings.NetworkDetection.MinChannelParticipating = 3;
Settings.NetworkDetection.MinChannelSimultaneously = 3;

disp('Settings Set')
%% Load in necessary Data and other variables
Data = data.Recording{1, 1}.AnalogStream{1, 1}.ChannelData * Settings.Recording.ScalingFactor;
TotalSamples = length(Data(1,:));
DurationS = TotalSamples/Settings.Recording.SamplingRate;

% !!!!!!!!!! Remove me later !!!!!!!!!!!
Data = Data((1:12), :);

% Initialize Time Vector
TimeVector = 0:1/(Settings.Recording.SamplingRate):DurationS-1/(Settings.Recording.SamplingRate);

% Labels for Wells
WellNumber = (data.Recording{1, 1}.AnalogStream{1, 1}.Info.GroupID())+1;        %+1 because MCS starts at 0
ElectrodeNumber = data.Recording{1, 1}.AnalogStream{1, 1}.Info.Label;

clear data 
disp('Data Loaded')

%% Prep & Implement Filters
% Setting data up as columns being electrodes and rows being time points
SamplingRate = Settings.Recording.SamplingRate;

% Lowpass code here but not implemented
%[bLow, aLow] = butter(Settings.Filters.LowPassOrder, ((Settings.Filters.LowPassCutoff)/(Settings.Recording.SamplingRate/2)), 'low');      %Lowpass not implemented
[bHigh, aHigh] = butter(Settings.Filters.HighPassOrder, ((Settings.Filters.HighPassCutoff)/(SamplingRate/2)), 'high');

Filters = {
    designfilt('bandstopiir', 'FilterOrder', 2, 'HalfPowerFrequency1', 58, 'HalfPowerFrequency2', 62, 'SampleRate', SamplingRate);   % Notch Filter
    designfilt('bandstopiir', 'FilterOrder', 2, 'HalfPowerFrequency1', 175, 'HalfPowerFrequency2', 180, 'SampleRate', SamplingRate); % Light Noise Filter
    % Uncomment to enable extra noise filters
%     designfilt('bandstopiir', 'FilterOrder', 2, 'HalfPowerFrequency1', 780, 'HalfPowerFrequency2', 782, 'SampleRate', SamplingRate);
%     designfilt('bandstopiir', 'FilterOrder', 2, 'HalfPowerFrequency1', 1561, 'HalfPowerFrequency2', 1563, 'SampleRate', SamplingRate);
%     designfilt('bandstopiir', 'FilterOrder', 2, 'HalfPowerFrequency1', 2159, 'HalfPowerFrequency2', 2161, 'SampleRate', SamplingRate);
%     designfilt('bandstopiir', 'FilterOrder', 2, 'HalfPowerFrequency1', 3124, 'HalfPowerFrequency2', 3126, 'SampleRate', SamplingRate);
};

%Flipped to run filters as vectorized function
if size(Data, 1) < size(Data, 2)
    Data = Data';
end

%uncomment this if you need lowpass added.
%FilteredData = filtfilt(bLow, aLow, FilteredData);
FilteredData = filtfilt(bHigh, aHigh, Data);

for i = 1:length(Filters)
    FilteredData = filtfilt(Filters{i}, FilteredData);
end

clear aHigh bHigh aLow bLow Filters i
disp('Data Filtered')

%% Threshold 

SamplesPerBin = (Settings.Recording.SamplingRate / 1000)*Settings.Baseline.WindowMs;
NumElectrodes = size(FilteredData, 2);
NumberOfSegment = Settings.Baseline.NumberOfSegment;

BinnedData = nan(SamplesPerBin, NumberOfSegment, NumElectrodes);
for i = 1:NumElectrodes
    for ii = 1:NumberOfSegment
        StartIdx = (ii - 1) * SamplesPerBin + 1;
        EndIdx = ii * SamplesPerBin;
         if EndIdx <= TotalSamples
             BinnedData(:, ii, i) = FilteredData(StartIdx:EndIdx, i);
         end
    end
end

%Finding standard deviations of segments
SDBin = nan(NumberOfSegment, NumElectrodes);
for i = 1:NumElectrodes
    for ii = 1:NumberOfSegment
        if ~isempty(BinnedData(:, ii, i))
           SDBin(ii, i) = std(BinnedData(:, ii, i));
        end
    end
end
[~, MinSDBinIdx] = min(SDBin, [], 1);

%Baseline
SignalForBaseline = cell(NumElectrodes, 1);
NoiseSignal = cell(size(BinnedData, 1), 1);
for iii = 1:NumElectrodes
    NoiseSignal = [];
    if ~isempty(MinSDBinIdx(iii))
        NoiseSignal = BinnedData(:, MinSDBinIdx(iii), iii);
        SignalForBaseline{iii} = NoiseSignal;
    else
        SignalForBaseline{iii} = [];
    end
end

% Doing RMS of windows of each channel for threshold
ElectrodeThresholds = cell(NumElectrodes, 1);
ThresholdMulti = Settings.Baseline.ThresholdMulti;
parfor iv = 1:NumElectrodes
    if ~isempty(SignalForBaseline{iv})
        %ElectrodeThresholds{iv} = sqrt(mean(SignalForBaseline{iv}.^2)) * ThresholdMulti;
        ElectrodeThresholds{iv} = SignalForBaseline{iv}.^2;
        ElectrodeThresholds{iv} = mean(ElectrodeThresholds{iv});
        ElectrodeThresholds{iv} = sqrt(ElectrodeThresholds{iv})* ThresholdMulti;
    else
        ElectrodeThresholds{iv} = [];
    end
end

% Convert cell array of thresholds to a matrix
ElectrodeThresholds = cell2mat(ElectrodeThresholds)';  % Making it a double for easier use

clear ThresholdMulti SignalForBaseline  MinSDBinIdx NoiseSignal SDBin i ii iii StartIdx EndIdx NumberOfSegment
clear maxIdx SamplesPerBin BinnedData
disp('Threshold Applied')

%% Spike Detection 

InvertedData = -FilteredData;       % Invert only to get counts/time stamps for negative peaks
AllPeaks = cell(NumElectrodes, 2);
DeadTime = Settings.SpikeDetection.DeadTime;
%pulled from settings to not have to retrieve every iteration

for i = 1:NumElectrodes
    [pospeaks, postime] = findpeaks(FilteredData(:, i), TimeVector,'MinPeakHeight', ElectrodeThresholds(i));
    [negpeaks, negtime] = findpeaks(InvertedData(:, i), TimeVector, 'MinPeakHeight', ElectrodeThresholds(i));
    
    if isempty(pospeaks)
        AllPeaks{i,1} = [];
        AllPeaks{i,2} = [];
        continue
    end

    postime = postime';
    negtime = negtime';

    % Combine positive and negative peaks
    AllPeaks{i,1} = [pospeaks; -negpeaks];
    AllPeaks{i,2} = [postime; negtime];
end

% Sort the combined set into chronological order
for ii = 1:NumElectrodes
    [sortedTime, sortIdx] = sort(AllPeaks{ii, 2});
    AllPeaks{ii, 1} = AllPeaks{ii, 1}(sortIdx);
    AllPeaks{ii, 2} = sortedTime;
end

clear InvertedData negpeaks negtime postime pospeaks sortedTime sortIdx MinPeakDistance MinPeakHeight  i ii ElectrodeThresholds
disp('Spike Detection Complete');

%% Artifact Detection & Spike filtering

% !!!!!!!!!!!!!!!!!!
% Criteria from the MCSToolbox *Need to DOUBLE CHECK
% https://authors.library.caltech.edu/25142/1/01419673.pdf
% Ensure no secondary peaks within 3 ms; keep the largest peaks found within this window

for i = 1:NumElectrodes

    if ~isempty(AllPeaks{i})
        SpikeTimes = AllPeaks{i, 2};
        PeakValues = AllPeaks{i, 1};
        AbsPeakValues = abs(PeakValues);
        j = 1;
        while j <= length(SpikeTimes)
            currentWindow = SpikeTimes - SpikeTimes(j) <= DeadTime & SpikeTimes - SpikeTimes(j) >= 0;
            while sum(currentWindow) > 1
                [~, maxIdx] = max(AbsPeakValues(currentWindow));
                currentWindowIdx = find(currentWindow);
                currentWindowIdx(maxIdx) = [];
                PeakValues(currentWindowIdx) = [];
                AbsPeakValues(currentWindowIdx) = [];
                SpikeTimes(currentWindowIdx) = [];

                %recheck window
                currentWindow = SpikeTimes - SpikeTimes(j) <= DeadTime & SpikeTimes - SpikeTimes(j) >= 0;
            end
                j = j + 1;
            
        end

        AllPeaks{i, 1} = PeakValues;
        AllPeaks{i, 2} = SpikeTimes;

        if isempty(AllPeaks{i})
            AllPeaks{i, 1} = NaN;
            AllPeaks{i, 2} = NaN;
        end
    end
end

clear UniqueSpikeTimes timestamp idx ToRemove WhichPeak Peak1 Peak2 i ii iii j PeakValues AbsPeakValues DeadTime maxIdx currentWindow currentWindowIdx SpikeTimes NumElectrodes
disp('Artifact Detection Complete');
%% Remove Data Based on Firing Rates of Electrodes
FiringFreqAll = cellfun(@(x) length(x)/DurationS, AllPeaks(:,1));           % finding firing rate based on number of entries for peaks
IdxToRemove = FiringFreqAll < Settings.SpikeDetection.MinFiringRate;        % creating a logical array to sort out any elec that dont have proper firing rate

%Remove Sections that dont meet the firing rate reqs
AllPeaks = AllPeaks(~IdxToRemove, :);
FullyFilteredData = FilteredData(:, ~IdxToRemove);
ElectrodeNumber = ElectrodeNumber(~IdxToRemove);
WellNumber = WellNumber(~IdxToRemove);
SpikeRate = FiringFreqAll(~IdxToRemove);               % here we keep the firing freq for a table later

clear IdxToRemove FilteredData FiringFreqAll SpikeRate
disp('Electrodes Removed Based on Firing Rates');

%% Spike Waveforms
% Pull out spike waveforms
% 1 ms before, 2.2ms after
% based on  https://www.sciencedirect.com/science/article/pii/S0165027015004240#fig0005

% Get Indices for the spikes
SpikeIdx = {};
for i = 1:length(AllPeaks(:,1))
    [~, Idxpeak] = intersect(TimeVector, AllPeaks{i,2}, 'stable');
    SpikeIdx{i} = Idxpeak;
end
SpikeIdx = SpikeIdx';         % Now we have the index numbers for the tagged spike activity

% how many indices per ms
SamplesPerMs = Settings.Recording.SamplingRate/1000;    %Figuring out how many samples per ms to use for indexing

% setting up start and ends of each waveform window
WindowStart = {};
WindowEnd = {};
for i = 1:length(AllPeaks(:,1))
    WindowStart{i} = SpikeIdx{i, 1} - (SamplesPerMs * Settings.Waveform.BeforeEventMs);   % 1 ms before
    WindowEnd{i} = SpikeIdx{i, 1} + (SamplesPerMs * Settings.Waveform.AfterEventMs);     % 2.2 after

    for ii = 1:length(WindowStart{i})
        % If WindowStart precedes the start (meaning it is negative), set it to the first sample point
        if WindowStart{1,i}(ii) < 1
            WindowStart{1, i}(ii) = 1;
        end
        % If window goes past the final number of samples, change it to the last one
        if WindowEnd{1,i}(ii) > TotalSamples
            WindowEnd{1,i}(ii) = TotalSamples;
        end
    end
end

% Getting and Containing Spikeform data
SpikeWaveforms = cell(size(AllPeaks(:, 1)));
for i = 1:length(AllPeaks(:,1))
    ElectrodeWaveforms = cell(length(WindowStart{i}), 1);

    for j = 1:length(WindowStart{i})
        Waveform = FullyFilteredData(WindowStart{i}(j):WindowEnd{i}(j), i);

        ElectrodeWaveforms{j} = Waveform;
    end
    SpikeWaveforms{i} = ElectrodeWaveforms;
end

clear ElectrodeWaveforms SamplesPerMs WindowStart WindowEnd Waveform Idxpeak i ii j SpikeIdx
disp('Waveforms Selected');
 

%% PreAllocate 
%Preallocating here to keep things consistent later on
% for Spikes
SpikeByElectrode = cell(size(AllPeaks(:, 1)));
    for i = 1:length(SpikeByElectrode)
        SpikeByElectrode{i}.WellNumber = WellNumber(i);
        SpikeByElectrode{i}.ElectrodeNumber = ElectrodeNumber{i};
        SpikeByElectrode{i}.Voltages = AllPeaks{i, 1};
        SpikeByElectrode{i}.TimingS = AllPeaks{i, 2};
        SpikeByElectrode{i}.TotalSpikes = length(SpikeByElectrode{i}.TimingS);
        
        SpikeByElectrode{i}.AvgSpikeFreq = SpikeByElectrode{i}.TotalSpikes/DurationS;
        SpikeByElectrode{i}.SpikeISI = diff(SpikeByElectrode{i}.TimingS);
        SpikeByElectrode{i}.SpikeISIIdx = (1:length(SpikeByElectrode{i}.SpikeISI))';
    end

% for Burst 
BurstByElectrode = cell(size(AllPeaks(:, 1)));
    for i = 1:length(SpikeByElectrode)
        BurstByElectrode{i}.WellNumber = WellNumber(i);
        BurstByElectrode{i}.ElectrodeNumber = ElectrodeNumber{i};

        BurstByElectrode{i}.NumberOfBursts = [];
        BurstByElectrode{i}.TimingS = [];
        BurstByElectrode{i}.SpikesInBursts = [];
        BurstByElectrode{i}.TotalSpikesInBursts = [];
        BurstByElectrode{i}.BurstDurationS = [];
        BurstByElectrode{i}.FreqInBurst = [];
        BurstByElectrode{i}.BurstISI = SpikeByElectrode{i}.SpikeISI;
        BurstByElectrode{i}.BurstISIIdx = (1:length(BurstByElectrode{i}.BurstISI))';
        BurstByElectrode{i}.InterBurstIntervalS = [];

        BurstByElectrode{i}.AvgSpikesPerBurst = [];
        BurstByElectrode{i}.AvgSpikeFreq = [];
        BurstByElectrode{i}.AvgDurationS = [];
        BurstByElectrode{i}.AvgIBI = [];
        BurstByElectrode{i}.AvgISIInBursts = [];

        %BurstByElectrode{i}.Voltages = AllPeaks{i, 1};
        %BurstByElectrode{i}.TimingS = AllPeaks{i, 2};
    end

% for NetworkBurst
NetworkByElectrode = cell(size(AllPeaks(:, 1)));
for i = 1:length(SpikeByElectrode)
    NetworkByElectrode{i}.WellNumber = WellNumber(i);
    NetworkByElectrode{i}.ElectrodeNumber = ElectrodeNumber{i};

    NetworkByElectrode{i}.ElectrodesInvolved = [];
    NetworkByElectrode{i}.BurstIdxs = [];
    NetworkByElectrode{i}.TimingS = [];
    NetworkByElectrode{i}.NetworkSpikeCount = [];
    NetworkByElectrode{i}.NetworkBurstCount = [];
    NetworkByElectrode{i}.NetworkDurationS = [];
    NetworkByElectrode{i}.AvgNetworkSpikeCount = [];
    NetworkByElectrode{i}.AvgNetworkDurationS = [];
    NetworkByElectrode{i}.AvgNetworkSpikeFreq = [];
    NetworkByElectrode{i}.AvgNetworkIBI = [];
    NetworkByElectrode{i}.PercentSpikesInNetworkBurst = [];
    %NetworkByElectrode{i}.Voltages = AllPeaks{i, 1};
    %NetworkByElectrode{i}.TimingS = AllPeaks{i, 2};
end

clear i
%% Burst detection from Max Interval Method
% No need to put statements in case spikes are empty, because those
% electrodes get removed

%Keep SpikeISI separate for Burst Manipulations
MaxStartInterval = Settings.BurstDetection.MaxStartInterval;
MaxIntraBurstInterval = Settings.BurstDetection.MaxIntraBurstInterval;
MinBurstSpikes = Settings.BurstDetection.MinSpikes;

%Find ISI indices that meet Start ISI condition for each electrode
for i = 1:length(SpikeByElectrode)
    BurstStartISIIdx = find(BurstByElectrode{i}.BurstISI(:, 1) <= MaxStartInterval);
    ProcessingBurstIdxs = cell(1, length(BurstStartISIIdx));       %Back in rows

% Looking for indices of ISIs that meet Start req and are <= intraburst interval
    % Going from every start qualified burst
    for ii = 1:length(BurstStartISIIdx) 
        Burst1 = [];  
        for iii = BurstStartISIIdx(ii):length(BurstByElectrode{i}.BurstISI)  
            if BurstByElectrode{i}.BurstISI(iii) <= MaxIntraBurstInterval
                Burst1{iii} = BurstByElectrode{i}.BurstISIIdx(iii); %contains idxs of passed start & intra for THAT burst
            else
                break
            end
        end

        if isempty(Burst1)
        else
            Burst1 = vertcat(Burst1{:});    %concatenates Burst ISI idxs that meet criteria to for that electrode         
        end

        % Burst ISIs that meet start and intra criteria
        ProcessingBurstIdxs{ii} = Burst1;
    end

    % Removing duplicate indexes and merging overlapping ones
    MergeDupe = cellfun(@(x) x(end), ProcessingBurstIdxs);
    for iv = 1:length(MergeDupe)
        try
            if MergeDupe(iv) == MergeDupe(iv+1)
                ProcessingBurstIdxs{iv+1} = [];
            else
            end
        catch
        end
    end
    % Removing empty/merged cells
    ProcessingBurstIdxs = ProcessingBurstIdxs(~cellfun('isempty', ProcessingBurstIdxs));

% Removing bursts with fewer that preset number of spikes
    % Adding 1 because we are looking at ISI not spike numbers

    for viii = 1:length(ProcessingBurstIdxs)
        if length(ProcessingBurstIdxs{1, viii}) + 1 < MinBurstSpikes
            ProcessingBurstIdxs{1, viii} = [];
        end
    end

    % Removing empty/merged cells
    ProcessingBurstIdxs = ProcessingBurstIdxs(~cellfun('isempty', ProcessingBurstIdxs));

% Finding INTERburst interval
    % if <= threshold, merge into one burst
    for v = 1:length(ProcessingBurstIdxs)-1

        if isempty(ProcessingBurstIdxs{v})           %In case no bursts, moves along
            continue
        end

        for vi = v+1:length(ProcessingBurstIdxs)
            % merging bursts within the IBI threshold
            if isempty(ProcessingBurstIdxs{vi})
                continue
            end
            if SpikeByElectrode{i}.TimingS(ProcessingBurstIdxs{vi}(1)) - SpikeByElectrode{i}.TimingS(ProcessingBurstIdxs{v}(end)+1) < Settings.BurstDetection.MaxInterBurstInterval
                ProcessingBurstIdxs{v} = vertcat(ProcessingBurstIdxs{v}, ProcessingBurstIdxs{vi});
                ProcessingBurstIdxs{vi} = [];
            else
                continue
            end
        end
    end

    % removing empty cells
    ProcessingBurstIdxs = ProcessingBurstIdxs(~cellfun('isempty', ProcessingBurstIdxs));

    % checking duration of the burst, must meet minimum duration
    for vii = 1:length(ProcessingBurstIdxs)
        if SpikeByElectrode{i}.TimingS(ProcessingBurstIdxs{1, vii}(end)) - SpikeByElectrode{i}.TimingS(ProcessingBurstIdxs{1, vii}(1)) < Settings.BurstDetection.MinDuration
            ProcessingBurstIdxs{1, vii} = [];
        else
        end
    end

    % removing empty cells
    ProcessingBurstIdxs = ProcessingBurstIdxs(~cellfun('isempty', ProcessingBurstIdxs));
  
    %removing bursts with fewer that preset number of spikes
    %looking at ISIs so need to increase spike number by 1

    for viii = 1:length(ProcessingBurstIdxs)
        if length(ProcessingBurstIdxs{1, viii}) + 1 < MinBurstSpikes
            ProcessingBurstIdxs{1, viii} = [];
        end
    end

    %removes empty cells from ProcessingBurst
    ProcessingBurstIdxs = ProcessingBurstIdxs(~cellfun('isempty', ProcessingBurstIdxs));     

    % The indexes of burst ISIs that meet all criteria
    BurstByElectrode{i}.BurstISIIdx = ProcessingBurstIdxs';
end

disp('Burst Detection Complete')
clear MergeDupe i ii iii iv v vi  vii viii ProcessingBurstIdxs BurstStartISIIdx MaxIntraBurstInterval MinBurstSpikes Burst1

%% Getting timings back for bursts, not using idxs

% Swap ISI index to spike indices
for i = 1:length(BurstByElectrode)
    if isempty(BurstByElectrode{i}.BurstISIIdx)
        continue
    end

    BurstByElectrode{i}.TimingS = BurstByElectrode{i}.BurstISIIdx;  %used to set up to retrieve timings below
    BurstByElectrode{i}.BurstIdxs = BurstByElectrode{i}.BurstISIIdx;
          
% Add the next sequential number to the current cell to go from ISI to spikes
    for ii = 1:length(BurstByElectrode{i}.BurstISIIdx)
        BurstByElectrode{i}.BurstIdxs{ii} = [BurstByElectrode{i}.BurstIdxs{ii}(:); BurstByElectrode{i}.BurstIdxs{ii}(end)+1];
    
    end
    
    % Gets timings back from indices
    for iii = 1:length(BurstByElectrode{i}.BurstIdxs)
        BurstByElectrode{i}.TimingS{iii, 1} = SpikeByElectrode{i}.TimingS(BurstByElectrode{i}.BurstIdxs{iii});        
    end

    % Keep only burst ISI timings
    %Can i combine with previous loops?
    BurstByElectrode{i}.BurstISIs = cell(size(BurstByElectrode{i}.BurstIdxs));
    for iv = 1:length(BurstByElectrode{i}.BurstISIIdx)
        for v = 1:length(BurstByElectrode{i}.BurstISIIdx{iv})
            BurstByElectrode{i}.BurstISIs{iv}(v) = BurstByElectrode{i}.BurstISI(BurstByElectrode{i}.BurstISIIdx{iv}(v));
        end
    end
    BurstByElectrode{i} = rmfield(BurstByElectrode{i}, 'BurstISI');
end

clear Burst1 Burst i ii iii iv v
disp('Bursts Sorted')

%% Burst Characteristics By Electrode Below
% gets burst duration, number of bursts, number of spikes, ISI within
% bursts, Freq within bursts, and interburst interval
% All these characteristics are stored in a structure called
% BurstInfoByElectrode

for i = 1:length(BurstByElectrode)
    if isempty(BurstByElectrode{i}.BurstISIIdx)
        BurstByElectrode{i}.NumberOfBursts = 0;
        continue

    else
        BurstByElectrode{i}.NumberOfBursts = length(BurstByElectrode{i}.BurstISIIdx);
        for ii = 1:BurstByElectrode{i}.NumberOfBursts
            BurstByElectrode{i}.BurstDurationS(ii, 1) = BurstByElectrode{i}.TimingS{ii}(end) - BurstByElectrode{i}.TimingS{ii}(1);
            BurstByElectrode{i}.SpikesInBursts(ii, 1) = length(BurstByElectrode{i}.TimingS{ii});

            %Temp to save extra loop
            BurstByElectrode{i}.AvgISIInBursts = sum([BurstByElectrode{i}.AvgISIInBursts; BurstByElectrode{i}.BurstISIs{ii}(:)]);
        end

% Calculating Interburst Interval 
        IBI2 = [];
        for iii = 1:length(BurstByElectrode{i}.TimingS)
            for iv = 1:length(BurstByElectrode{i}.TimingS)-1
                InterBurstInterval = BurstByElectrode{i}.TimingS{iv + 1}(1) - BurstByElectrode{i}.TimingS{iv}(end);
                IBI2 = [IBI2, InterBurstInterval];
            end

            BurstByElectrode{i}.InterBurstIntervalS = IBI2';
            IBI2 = [];
        end

% Getting Burst Characteristics
        BurstByElectrode{i}.TotalSpikesInBursts = sum(BurstByElectrode{i}.SpikesInBursts(:));
        BurstByElectrode{i}.FreqInBurst = BurstByElectrode{i}.SpikesInBursts ./ BurstByElectrode{i}.BurstDurationS;

        BurstByElectrode{i}.AvgSpikesPerBurst = BurstByElectrode{i}.TotalSpikesInBursts/BurstByElectrode{i}.NumberOfBursts;
        BurstByElectrode{i}.AvgDurationS = sum(BurstByElectrode{i}.BurstDurationS(:))/BurstByElectrode{i}.NumberOfBursts;
        BurstByElectrode{i}.AvgSpikeFreq = sum(BurstByElectrode{i}.FreqInBurst)/BurstByElectrode{i}.NumberOfBursts;
        BurstByElectrode{i}.AvgIBI = sum(BurstByElectrode{i}.InterBurstIntervalS)/BurstByElectrode{i}.NumberOfBursts;
        BurstByElectrode{i}.AvgISIInBursts = BurstByElectrode{i}.AvgISIInBursts / BurstByElectrode{i}.NumberOfBursts;
    end
end
clear AvgISIInBursts SDISIBurst i ii iii iv IBI2 InterBurstInterval
disp("Burst Characteristics Done") 

 %% Network Burst by Well !!!!!!!!!!!!!!!!!!!!!!
% %redo from here

% Need to grab info from Burst by WELL then do math then store again by
% electrode

UniqueWells = unique(WellNumber);
NetworkBurstInfo = [];
for i = 1:length(UniqueWells)
    CurrentWell = UniqueWells(i);
    BurstingElectrodesInWell = [];

    % Look for bursting electrodes in a given well
    for ii = 1:length(BurstByElectrode)
        if BurstByElectrode{ii}.WellNumber == CurrentWell
            if BurstByElectrode{ii}.NumberOfBursts > 0
                BurstingElectrodesInWell = [BurstingElectrodesInWell; ii];
            end
        end
    end

    % Skip if not enough electrodes for a network burst
    if length(BurstingElectrodesInWell) < Settings.NetworkDetection.MinChannelParticipating
        continue
    end

    % Gathering Timestamp Data
    % Set up as BurstingElectrodesInWell(iii) to prevent shifts in skipped
    % electrodes
    TimeSortedBursts = [];
    for iii = 1:length(BurstingElectrodesInWell)
        for v = 1:length(BurstByElectrode{BurstingElectrodesInWell(iii)}.TimingS)
            StartTime = BurstByElectrode{BurstingElectrodesInWell(iii)}.TimingS{v}(1);
            EndTime = BurstByElectrode{BurstingElectrodesInWell(iii)}.TimingS{v}(end);
            TimeSortedBursts = [TimeSortedBursts; StartTime, EndTime, BurstingElectrodesInWell(iii), v];
        end
    end

    % Sort bursts by start time
    TimeSortedBursts = sortrows(TimeSortedBursts, 1);

    % Check for overlapping bursts in this well
    % Find Network Bursts
    NetworkBursts = [];
    vi = 1;
    while vi <= size(TimeSortedBursts, 1)
        ActiveBursts = [];
        CurrentStart = TimeSortedBursts(vi, 1);
        CurrentEnd = TimeSortedBursts(vi, 2);
        ActiveBursts = [ActiveBursts; TimeSortedBursts(vi, :)];

        vii = vi + 1;

        % Expand the burst window while conditions are met
        while vii <= size(TimeSortedBursts, 1)
            if TimeSortedBursts(vii, 1) <= CurrentEnd
                % Extend the burst window if overlapping
                CurrentEnd = max(CurrentEnd, TimeSortedBursts(vii, 2));
                ActiveBursts = [ActiveBursts; TimeSortedBursts(vii, :)];
                vii = vii + 1;
            else
                break;
            end
        end

        % Check when at least MinChannelSimultaneously channels are active
        UniqueElectrodes = unique(ActiveBursts(:, 3));
        SimultaneousCounts = zeros(size(ActiveBursts, 1), 1);

        for j = 1:size(ActiveBursts, 1)
            SimultaneousCounts(j) = sum(ActiveBursts(:, 1) <= ActiveBursts(j, 1) & ActiveBursts(:, 2) >= ActiveBursts(j, 1));
        end

        % Find the first time where at least MinChannelSimultaneously electrodes are bursting
        StartIndex = find(SimultaneousCounts >= Settings.NetworkDetection.MinChannelSimultaneously, 1);

        if ~isempty(StartIndex)
            CorrectedStart = ActiveBursts(StartIndex, 1);

            % Get the indices of the participating bursts
            ElectrodesInvolved = ActiveBursts(:, 3);
            BurstIdxs = ActiveBursts(:, 4);

            % Store network burst
            NetworkBursts = [NetworkBursts; {CorrectedStart, CurrentEnd, ElectrodesInvolved, BurstIdxs}];
        end

        % Move to the next potential network burst
        vi = vii;
    end

    % Store results
    NetworkBurstInfo{i}.WellNumber = CurrentWell;
    if isempty(NetworkBursts)
        NetworkBurstInfo{i}.NetworkBursts = 0;
        continue;
    end
    NetworkBurstInfo{i}.NetworkBursts = NetworkBursts;
    NetworkBurstInfo{i}.TimingS = cell2mat(NetworkBursts(:, [1,2]));
    NetworkBurstInfo{i}.NetworkBurstingElectrodes = unique(cell2mat(NetworkBursts(:,3)));
    NetworkBurstInfo{i}.NumberOfNetworkBursts = size(NetworkBursts, 1);
    NetworkBurstInfo{i}.ElectrodesInvolved = NetworkBursts(:, 3);
    NetworkBurstInfo{i}.ElecBurstIdxs = NetworkBursts(:, [3, 4]); % Storing indices

    for l = 1:length(NetworkBurstInfo{i}.ElectrodesInvolved)
        UniqueElecByNetwork{l, 1} = unique(NetworkBurstInfo{i}.ElectrodesInvolved{l, 1});
    end
    ElectNetworkCounts = groupcounts(categorical(vertcat(UniqueElecByNetwork{:})));
    for m = 1:length(NetworkBurstInfo{i}.NetworkBurstingElectrodes)
        ElectrodeRow = NetworkBurstInfo{i}.NetworkBurstingElectrodes(m);
        NetworkByElectrode{ElectrodeRow}.NetworkBurstCount = ElectNetworkCounts(m);
    end
end


clear NetworkBursts i ii iii v vi vii j k l m ElectrodeRow ElectNetworkCounts OverlappingBursts OverlapCount TimeSortedBursts StartTime EndTime Idxs
clear DoubleCheckedBursts BurstingElectrodesInWell ElectrodesInvolved
disp('Network by Well Done')

%% Config Network by Electrode
%Grouping info from indep electrode to then manipulate and send out
%to all electrodes involved

for i = 1:length(NetworkBurstInfo)  %independent wells
    NetworkDurationS = [];
    TempCount = zeros(size(SpikeByElectrode, 1), 1);

% End - Start Times for Duration S
    for ii = 1:length(NetworkBurstInfo{i}.NetworkBursts) %Each Burst
        NetworkDurationS = NetworkBurstInfo{i}.NetworkBursts{ii, 2} - NetworkBurstInfo{i}.NetworkBursts{ii, 1};

% Counting total spikes in burst by electrode
        for iii = 1:length(NetworkBurstInfo{i}.NetworkBursts{ii, 3}) %Each electrode in burst
            ElectrodeRow = NetworkBurstInfo{i}.NetworkBursts{ii, 3}(iii, 1);
            BurstNumber = NetworkBurstInfo{i}.NetworkBursts{ii, 4}(iii, 1);

            TempCount(ElectrodeRow, 1) = BurstByElectrode{ElectrodeRow, 1}.SpikesInBursts(BurstNumber, 1) + TempCount(ElectrodeRow, 1);
        end
    end

% Getting and basic counts done
    for iv = 1:length(NetworkBurstInfo{i}.NetworkBursts) %Each Network Burst

        for v = 1:length(UniqueElecByNetwork{iv}) %Each unique Electrode in Burst to prevent duplicate times
        ElectrodeRow = UniqueElecByNetwork{iv}(v);
        BurstNumber = NetworkBurstInfo{i}.NetworkBursts{iv, 4}(v, 1);

        NetworkByElectrode{ElectrodeRow}.TimingS = [NetworkByElectrode{ElectrodeRow}.TimingS; NetworkBurstInfo{i}.TimingS(iv, :)];
        NetworkByElectrode{ElectrodeRow}.ElectrodesInvolved = [NetworkByElectrode{ElectrodeRow}.ElectrodesInvolved; NetworkBurstInfo{i}.ElectrodesInvolved(ii)];
        NetworkByElectrode{ElectrodeRow}.BurstIdxs = [NetworkByElectrode{ElectrodeRow}.BurstIdxs; NetworkBurstInfo{i}.ElecBurstIdxs(v, 2)];
        NetworkByElectrode{ElectrodeRow}.NetworkSpikeCount = TempCount(ElectrodeRow, 1);
        NetworkByElectrode{ElectrodeRow}.NetworkDurationS = [NetworkByElectrode{ElectrodeRow}.NetworkDurationS; NetworkDurationS];
        end  
    end

end

clear i ii iii iv v ElectrodeRow BurstNumber TempCount NetworkDurationS UniqueElecByNetwork 
disp('Network Sorted by Electrode')
%% Network Characteristics
for i = 1:length(NetworkByElectrode)

    if NetworkByElectrode{i}.NetworkBurstCount ~= 0
        NetworkByElectrode{i}.AvgNetworkSpikeFreq = sum(NetworkByElectrode{i}.NetworkSpikeCount)/sum(NetworkByElectrode{i}.NetworkDurationS(:));
        NetworkByElectrode{i}.AvgNetworkSpikeCount = sum(NetworkByElectrode{i}.NetworkSpikeCount)/NetworkByElectrode{i}.NetworkBurstCount;
        NetworkByElectrode{i}.AvgNetworkDurationS = sum(NetworkByElectrode{i}.NetworkDurationS)/NetworkByElectrode{i}.NetworkBurstCount;

        %Getting IBI here
        TempTime = [];
        InterNetworkInterval = [];
        for iii = 1:NetworkByElectrode{i}.NetworkBurstCount-1
            v = iii + 1;
            TempTime = NetworkByElectrode{i}.TimingS(v, 1) - NetworkByElectrode{i}.TimingS(iii, 2);
            InterNetworkInterval = [InterNetworkInterval; TempTime];
        end

        NetworkByElectrode{i}.AvgNetworkIBI = sum(InterNetworkInterval)/NetworkByElectrode{i}.NetworkBurstCount;
        NetworkByElectrode{i}.PercentSpikesInNetworkBurst = NetworkByElectrode{i}.AvgNetworkSpikeCount/length(AllPeaks(i));
    
    else
        NetworkByElectrode{i}.NetworkBurstCount = 0;
        NetworkByElectrode{i}.AvgNetworkSpikeFreq = [];
        NetworkByElectrode{i}.AvgNetworkSpikeCount = [];
        NetworkByElectrode{i}.AvgNetworkDurationS = [];
        NetworkByElectrode{i}.AvgNetworkIBI = [];
        NetworkByElectrode{i}.PercentSpikesInNetworkBurst = [];
    end

    if NetworkByElectrode{i}.NetworkBurstCount == 1
        NetworkByElectrode{i}.AvgNetworkIBI = [];
    end
end


clear Tempcount i ii iii ElectrodeRow 
disp('Network Burst Characteristics Done')


%% Save things here
% going to fill with NaNs for table afterwards
%Saving here allows for visualization from file
save('20241220_WT_WT.HD.NM.DIV43PTX_Control_mwd.mat', 'NetworkBurstInfo', 'Settings', 'AllPeaks', 'BurstIdxs', 'BurstByElectrode', 'SpikeByElectrode', 'NetworkByElectrode', 'Data', 'ElectrodeNumber', 'WellNumber', 'FullyFilteredData',  '-v7.3')

%% empty Cell to NaN
for i = 1:length(SpikeByElectrode)
    if BurstByElectrode{i}.NumberOfBursts == 0;
        BurstByElectrode{i}.TimingS = NaN;
        BurstByElectrode{i}.TotalSpikesInBursts = NaN;
        BurstByElectrode{i}.FreqInBurst = NaN;
        BurstByElectrode{i}.AvgSpikesPerBurst = NaN;
        BurstByElectrode{i}.AvgDurationS = NaN;
        BurstByElectrode{i}.AvgSpikeFreq = NaN;
        BurstByElectrode{i}.AvgIBI = NaN;
        BurstByElectrode{i}.AvgISIInBursts = NaN;
        BurstByElectrode{i}.BurstDurationS = NaN;
        BurstByElectrode{i}.SpikesInBursts = NaN;
        BurstByElectrode{i}.AvgISIInBursts = NaN;
        BurstByElectrode{i}.InterBurstIntervalS = NaN;
    end
    if  NetworkByElectrode{i}.NetworkBurstCount == 0;
        NetworkByElectrode{i}.AvgNetworkSpikeFreq = NaN;
        NetworkByElectrode{i}.AvgNetworkSpikeCount = NaN;
        NetworkByElectrode{i}.AvgNetworkDurationS = NaN;
        NetworkByElectrode{i}.AvgNetworkIBI = NaN;
        NetworkByElectrode{i}.PercentSpikesInNetworkBurst = NaN;
    end

end

%% Plot Tables
AllSpikeTable = table();
for i = 1:length(SpikeByElectrode)
    ElectrodeNumCell = {SpikeByElectrode{i}.ElectrodeNumber};
    TempTable = table(SpikeByElectrode{i}.WellNumber, ElectrodeNumCell, SpikeByElectrode{i}.TotalSpikes, SpikeByElectrode{i}.AvgSpikeFreq, 'VariableNames', {'Well Number', 'Electrode Number', 'Total Spikes', 'Average Spiking Frequency'});
    AllSpikeTable = [AllSpikeTable; TempTable];
end

AllBurstTable = table();
if ~isempty(BurstByElectrode)
    for i = 1:length(BurstByElectrode)
        ElectrodeNumCell = {BurstByElectrode{i}.ElectrodeNumber};
        TempTable2 = table(BurstByElectrode{i}.WellNumber, ElectrodeNumCell, BurstByElectrode{i}.NumberOfBursts, BurstByElectrode{i}.TotalSpikesInBursts, BurstByElectrode{i}.AvgDurationS, BurstByElectrode{i}.AvgSpikesPerBurst, BurstByElectrode{i}.AvgSpikeFreq, BurstByElectrode{i}.AvgIBI,  'VariableNames', {'Well Number', 'Electrode Number', 'Number of Bursts', 'Total Spikes in Bursts', 'Average Duration (s)', 'Average Spikes per Burst', 'Average Spiking Frequency', 'Average Interburst Interval (s)'});
        AllBurstTable = [AllBurstTable; TempTable2];
    end
end

AllNetworkTable = table();
if ~isempty(NetworkByElectrode)
    for i = 1:length(NetworkByElectrode)
        ElectrodeNumCell = {NetworkByElectrode{i}.ElectrodeNumber};
        TempTable3 = table(NetworkByElectrode{i}.WellNumber, ElectrodeNumCell, NetworkByElectrode{i}.NetworkBurstCount, NetworkByElectrode{i}.AvgNetworkSpikeCount, NetworkByElectrode{i}.AvgNetworkSpikeFreq, NetworkByElectrode{i}.AvgNetworkIBI, NetworkByElectrode{i}.PercentSpikesInNetworkBurst, 'VariableNames', {'Well Number', 'Electrode Number', 'Number of Network Bursts', 'Avg Network Spike Count', 'Avg Network Spike Rate', 'Average IBI Network (S)', 'PercentSpikesInNetworkBurst'});
        AllNetworkTable = [AllNetworkTable; TempTable3];
    end
end

AllSpikeTable.("Electrode Number") = string(AllSpikeTable.("Electrode Number"));
AllBurstTable.("Electrode Number") = string(AllBurstTable.("Electrode Number"));
AllNetworkTable.("Electrode Number") = string(AllNetworkTable.("Electrode Number"));


AllCombinedTable = outerjoin(AllSpikeTable, AllBurstTable, 'Keys', {'Well Number', 'Electrode Number'}, 'MergeKeys', true );
if ~isempty(AllNetworkTable)
    AllCombinedTable = outerjoin(AllCombinedTable, AllNetworkTable, 'Keys', {'Well Number', 'Electrode Number'}, 'MergeKeys', true );
else
end

%Saving Table Below
writetable(AllCombinedTable, CSVFileName);

clear TempTable TempTable2 TempTable3 


%%

%% CV between wells or condition, i dont remember
% Calculating Coefficient of Variance

% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% NEED TO DO THIS LATER ON BETWEEN WELLS
% Timing or voltage?
% try this in s instead of ms
% meanISI = cell(length(ISIAllSpikeS), 1);
% StdISI = cell(length(ISIAllSpikeS), 1);
% CV = cell(length(ISIAllSpikeS), 1);
% 
% for i = 1:length(ISIAllSpikeS)
%     meanISI{i} = mean(ISIAllSpikeS{i,1});
%     StdISI{i} = std(ISIAllSpikeS{i,1});
%     CV{i} = (StdISI{i})/ (meanISI{i}) *100;
% end


% %% Table with data info
% % Need to do this by well and maybe by condition.
% %double check what parameters we need for this
% 
% % num of channels participating, num of burst, num of spikes, duration, ibi, Freq, anything else?
% 
% NetworkTable = cell(numel(UniqueWells), 6); 
% 
% %num of active electrodes?, num of burst, num of spikes, duration, ibi, Freq, anything else?
% BurstTable = cell(numel(UniqueWells), 6);
% 
% %num spike, isi, freq, num of active elec?, 
% SpikeTable = cell(numel(UniqueWells), 4);