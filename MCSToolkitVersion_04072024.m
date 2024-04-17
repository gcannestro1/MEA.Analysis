%% Load Data in and verify details
%doc McsHDF5
clear all

% !!!!!!!! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% To Do list
% make plots of waveforms the same size
% finish up network and tables

%LogISI and MaxInterval are top two but which should we use?
% https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4969396/
%data = McsHDF5.McsData('20231107_HD_DIV20_mwd.h5');
data = McsHDF5.McsData('20240308_HD-iMSN_DIV21_Control_mwd.h5');


HighPassOnData = data.Recording{1, 1}.AnalogStream{1, 1}.Info.HighPassFilterCutOffFrequency(1);
LowPassOnData = data.Recording{1, 1}.AnalogStream{1, 1}.Info.LowPassFilterCutOffFrequency(1);
SamplingRate = cast(1000000/(data.Recording{1, 1}.AnalogStream{1, 1}.Info.Tick(1)), 'double');

fprintf('SamplingRate %d Hz, HighPass %s Hz, LowPass %s Hz', SamplingRate, HighPassOnData{1,1}, LowPassOnData{1,1});

%% Double Check Parameters to be applied
clear SamplingRate LowPassOnData HighPassOnData;   %removes data pulled in from file to make room

%creating Array to keep Parameters Below!!!
Settings=[];

Settings.Recording.SamplingRate = 20000;
Settings.Recording.ElectrodeOrder = [34 24 43 33 23 13 42 32 22 12 31 12];
Settings.Recording.WellLabel = {'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'D1', 'D2', 'D3', 'D4', 'D5', 'D6'};
Settings.Recording.ScalingFactor = 1e-6;  % Scale back to microvolts

Settings.Filters.HighPassCutoff = 300;
Settings.Filters.HighPassOrder = 4;
Settings.Filters.LowPassCutoff = 3500;
Settings.Filters.LowPassOrder = 2;

Settings.Baseline.Window = 50;
Settings.Baseline.Purenoisewindow = 10;                     %10 sections of 50ms for 500
Settings.Baseline.ThresholdMulti = 5;

Settings.SpikeDetection.MinPeakDistance = 0;                %Divided by 1000 below. idk why
Settings.SpikeDetection.MinPeakProminence = 0;
Settings.SpikeDetection.MinFiringRate = 0.1;
Settings.SpikeDetection.DeadTime = 0.001;                   % 3ms or 0.003s between peaks %paper says 1ms, why they implement 3

Settings.Waveform.BeforeEventMs = 1;                        %same as MCS
Settings.Waveform.AfterEventMs = 2;

Settings.BurstDetection.MinSpikes = 3;                      % min of 3 spikes to be a burst
Settings.BurstDetection.MaxStartInterval = 0.05;            % changed from  .17 to match MCS
Settings.BurstDetection.MaxIntraBurstInterval = 0.05;       % changed from  .2 to match MCS
Settings.BurstDetection.MaxInterBurstInterval = 0.1;        % changedfrom   .3 to match MCS
Settings.BurstDetection.MinDuration = 0.03;                 % changed from  .01 (they wrote this ->)used in the paper 0.03???
%Settings.BurstDetection.MaxNumSpike = 10;                   %used in the paper 4, !!!!!!!!!!! doesn't exist in MCS

Settings.NetworkDetection.MinChannelParticipating = 3;
Settings.NetworkDetection.MinChannelSimultaneously = 3;

%MCS settings are 50ms to start, 50ms to end, 100ms min between burst, 50ms
%min duration, 4 min spike count.
%Network MCS, min 6 channels participating, min 3 channels simultaneously


% Settings.burstdetectionlogisi.void=0.7;
% Settings.burstdetectionlogisi.nspikes=3;

% Settings.NetworkDetection.TimeWindowForSynch = 0.1; % time in seconds
% Settings.NetworkDetection.minimumsynchronizedburstcount = 2; % in counts
% Settings.NetworkDetection.minimumchannelparticipation = 0.5; % in percentage

disp('Settings Set')
%% Load in necessary Data and other variables
Data = data.Recording{1, 1}.AnalogStream{1, 1}.ChannelData * Settings.Recording.ScalingFactor;
TotalSamples = length(Data(1,:));
DurationS = TotalSamples/Settings.Recording.SamplingRate;

% Initialize Time Vector
TimeVector = 0:1/(Settings.Recording.SamplingRate):DurationS-1/(Settings.Recording.SamplingRate);

% Labels for Wells
WellNumber = (data.Recording{1, 1}.AnalogStream{1, 1}.Info.GroupID())+1;        %+1 because MCS starts at 0
ElectrodeNumber = data.Recording{1, 1}.AnalogStream{1, 1}.Info.Label;
%Labels = [WellNumber ElectrodeNumber];

clear data 
%% Prep & Implement Filters
% Lowpass code here but not implemented
 %order is divided by 2 because filtfilt applies twice, doubling the order

%[bLow, aLow] = butter(Settings.Filters.LowPassOrder/2, ((Settings.Filters.LowPassCutoff)/(Settings.Recording.SamplingRate/2)), 'low');      %Lowpass not implemented
[bHigh, aHigh] = butter(Settings.Filters.HighPassOrder/2, ((Settings.Filters.HighPassCutoff)/(Settings.Recording.SamplingRate/2)), 'high');

% Filtering here
parfor i = 1:size(Data,1)
    FilteredData(i, :) = filtfilt(bHigh, aHigh, Data(i, :));        %highpass
    %FilteredData(i,:) = filtfilt(bLow, aLow, FilteredData(i, :));  %lowpass
end

clear aHigh bHigh aLow bLow
disp('Data Filtered')

%% Comparing Unfiltered and Filtered

% figure
% for i = 1:12
%     subplot(4,3,i)
%     hold on
%     plot(TimeVector, Data(i,:), 'k');
%     plot(TimeVector, FilteredData(i,:), 'r'); 
%     legend('Raw', 'Filtered'), xlabel('Time (s)'), ylabel('Voltage (\muV)')
%     hold off;
% end

%% Baseline Noise
% Setting up for Baseline
% Creating 50ms Bins to set up for Baseline Noise
SamplesPerBin = (Settings.Recording.SamplingRate/1000) * Settings.Baseline.Window;
FlippedData = FilteredData';
Dummy = nan(SamplesPerBin, numel(FlippedData)./SamplesPerBin);  %This has number of bins for duration * number of electrodes
Dummy(1:numel(FilteredData)) = FlippedData;

FlipTimeVector = TimeVector';
DummyTime = nan(SamplesPerBin, numel(FlipTimeVector)./SamplesPerBin);
DummyTime(1:numel(FlipTimeVector)) = FlipTimeVector;

%Split bins into appropriate channels
Split = {};
Temp = [];
BinStartIndex = 1;
BinEndIndex = length(FilteredData)/SamplesPerBin;
for i = 1:length(FilteredData(:,1))
    Temp = Dummy(1:SamplesPerBin, BinStartIndex:BinEndIndex);
    BinStartIndex = BinStartIndex + length(FilteredData)/SamplesPerBin;
    BinEndIndex = BinEndIndex + length(FilteredData)/SamplesPerBin;
    Split{i} = Temp;
end
Split = Split'; % now sep by each channel

% histo to test for norm distribution
SDBin = cell(1, length(FilteredData(:,1)));
for j = 1:length(FilteredData(:,1))
    sigma = [];
    for i = 1:(length(FilteredData)/SamplesPerBin)
        [~, sigma(i)] = normfit(Split{j, 1}(:, i));
    end
    sigma = sigma';
    SDBin{j} = sigma;
end
SDBin = SDBin';

clear Temp BinStartIndex BinEndIndex Dummy FlippedData FlipTimeVector sigma i j

% Threshold of SD based on Avg Thresh in each channel
MeanChannelThresh = [];
parfor i = 1:length(SDBin)
    Means = mean(SDBin{i, 1});
    MeanChannelThresh = [MeanChannelThresh Means];
end
MeanChannelThresh = MeanChannelThresh';

clear Means i

%% Finding Windows for Baseline to be set
BaselineNoise = {};
parfor i = 1:length(FilteredData(:,1))
    Threshold = MeanChannelThresh(i, 1);                                    % Sets Threshold to Avg of Stf from bins                                
    BelowThresh = (SDBin{i,1} < Threshold);
    ThresholdChange = [BelowThresh(1); diff(BelowThresh)];
    ThresholdChange(ThresholdChange==-1) = 0;                               % Uses above two lines to see where values cross threshold
    spanLocs = cumsum(ThresholdChange);                                     % sets values to 0 where data is not below thresh
    spanLocs(~BelowThresh) = 0;                                             % finds where data is below thresh
    BelowThreshIdx = find(BelowThresh==1);
    NotConsecutiveIdx = [true; diff(BelowThreshIdx) ~= 1];                  % identifies non-consequtive indices below thresh
    SumIdx = cumsum(NotConsecutiveIdx);
    SpanLength = histcounts(SumIdx, 1:max(SumIdx));                         % Lengths of segments that meet criteria
    GoodSpan = find(SpanLength >= (Settings.Baseline.Purenoisewindow));     % Looking for segments of 20 in length (50ms -> 1s)
    AllInSpans = find(ismember(spanLocs, GoodSpan));
    BaselineNoise{i} = AllInSpans;
end
BaselineNoise = BaselineNoise';

% Fills empty cells if present
emptyCells = cellfun(@isempty, BaselineNoise);
vec = linspace(1,length(FilteredData)/SamplesPerBin, length(FilteredData)/SamplesPerBin);
BaselineNoise(emptyCells) = {vec'};

clear emptyCells vec SDBin Threshold BelowThresh ThresholdChange spanLocs BelowThreshIdx NotConsecutiveIdx SumIdx SpanLength GoodSpan AllInSpans MeanChannelThresh SamplesPerBin
disp('Baseline Threshold Determined')

%% Determining Baseline Noise
SignalForBaseline = {};
TimeForBaseline = {};
parfor i = 1:(length(BaselineNoise))
    NoiseSignal = Split{i, 1}(:, BaselineNoise{i,1});
    NoiseSignal = reshape(NoiseSignal, [], 1);
    SignalForBaseline{i} = NoiseSignal;

    NoiseTime = DummyTime(:, BaselineNoise{i,1});
    NoiseTime = reshape(NoiseTime, [], 1);
    TimeForBaseline{i} = NoiseTime;
end

SignalForBaseline = SignalForBaseline';    % has the signal values for the bins selected for baseline noise
TimeForBaseline = TimeForBaseline';        % has the timings for the sections used for baseline noise

%Doing RMS of windows of each channel for threshold
ElectrodeThresholds = {};
parfor ii = 1:length(SignalForBaseline)
    ElectrodeThresholds{ii}= sqrt(mean(SignalForBaseline{ii,1}.^2))*Settings.Baseline.ThresholdMulti;                                 % S of RMS
end

ElectrodeThresholds = cell2mat(ElectrodeThresholds)';                           % making it a double for multiplication

clear Split BaselineNoise NoiseTime NoiseSignal DummyTime
disp('Baseline Noise Set')

%% Spike Detection

InvertedData = -FilteredData;       %invert only to get counts/time stamps for negative peaks
AllPeaks = cell(length(SignalForBaseline),2);
for i = 1:length(SignalForBaseline)
    [pospeaks, postime] = findpeaks(FilteredData(i,:), TimeVector, 'MinPeakHeight', ElectrodeThresholds(i,1), 'MinPeakDistance', (Settings.SpikeDetection.MinPeakDistance/1000), "MinPeakProminence", (Settings.SpikeDetection.MinPeakProminence));
    [negpeak, negtime] = findpeaks(InvertedData(i,:), TimeVector, 'MinPeakHeight', ElectrodeThresholds(i,1), 'MinPeakDistance', (Settings.SpikeDetection.MinPeakDistance/1000), "MinPeakProminence", (Settings.SpikeDetection.MinPeakProminence));

    %positive and negative peaks combined
    AllPeaks{i,1} = [pospeaks -negpeak];
    AllPeaks{i,2} = [postime negtime];
end


% Sort the combined set into chronological order
for ii = 1:length(AllPeaks)
    [sortedTime, sortIdx] = sort(AllPeaks{ii, 2});
    AllPeaks{ii, 1} = AllPeaks{ii, 1}(sortIdx);
    AllPeaks{ii, 2} = sortedTime;
end

clear InvertedData negpeak negtime postime pospeaks ElectrodeThresholds SignalForBaseline sortedTime sortIdx
%clear sortedTime sortIdx
disp('Spike Detection');

%% Artifact Detection & Spike filtering
% Removing spikes with the EXACT same timing. Must be artifact.

% Find unique spike times for each electrode
UniqueSpikeTimes = cell(length(AllPeaks), 1);
for i = 1:length(AllPeaks)
    UniqueSpikeTimes{i} = unique(AllPeaks{i, 2});
end

for ii = 1:length(AllPeaks)
    for iii = 1:length(UniqueSpikeTimes{ii})
        timestamp = UniqueSpikeTimes{ii}(iii);
        idx = find(AllPeaks{ii, 2} == timestamp);
%actually removes them here
        if length(idx) > 1
            AllPeaks{ii, 1}(idx) = [];
            AllPeaks{ii, 2}(idx) = [];
        end
    end
end

clear UniqueSpikeTimes timestamp idx i ii iii

% !!!!!!!!!!!!!!!!!!
% Criteria from the MCSToolbox *Need to DOUBLE CHECK
% https://authors.library.caltech.edu/25142/1/01419673.pdf
% First Criteria is that the peak found needs to be the highest in
% ampltiude and within a 1 ms window there can't be any secondary
% peaks in the same polarity

% the second criteria is that 50% of the ampltiude of the peak
% needs to be in the same window?
% the third criteria is that spikes with the exact same time stamps
% on 2 or more channels are not considered to be spikes

% Does not allow for peaks within 3ms
    %where does this number come from? MCS analysis?
% Keeps the larger of the two
for i = 1:length(AllPeaks)
    if isempty(AllPeaks{i})
    else
        ToRemove = find(diff(AllPeaks{i,2}) < Settings.SpikeDetection.DeadTime )+1;
        if isempty(ToRemove)
        else
            Peak1 = AllPeaks{i,1}(ToRemove);
            Peak2 = AllPeaks{i,1}(ToRemove-1);
            WhichPeak = Peak1 > Peak2;   % 0 means that Peak 2 is higher, 1 means Peak1 is higher
            for ii = 1:length(WhichPeak)
                if WhichPeak(ii)==1
                    ToRemove(ii) = ToRemove(ii)-1;
                end
            end
            AllPeaks{i,1}(ToRemove) = [];
            AllPeaks{i,2}(ToRemove) = [];
        end
    end
end

clear ToRemove WhichPeak Peak1 Peak2 i ii
disp('Artifact Detection');

%% Remove Data Based on Firing Rates of Electrodes
FiringFreqAll = cellfun(@(x) length(x)/DurationS, AllPeaks(:,1));           % finding firing rate based on number of entries for peaks
IdxToRemove = FiringFreqAll < Settings.SpikeDetection.MinFiringRate;           % creating a logical array to sort out any elec that dont have proper firing rate

%Remove Sections that dont meet the firing rate reqs
AllPeaks = AllPeaks(~IdxToRemove, :);
FullyFilteredData = FilteredData(~IdxToRemove, :);
ElectrodeNumber = ElectrodeNumber(~IdxToRemove);
WellNumber = WellNumber(~IdxToRemove);
SpikeRate = FiringFreqAll(~IdxToRemove);               % here we keep the firing freq for a table later

clear IdxToRemove FilteredData FiringFreqAll
disp('Electrodes Removed Based on Firing Rates');

%% Spike Waveforms
% Pull out spike waveforms
% 1 ms before, 2.2ms after
% based on  https://www.sciencedirect.com/science/article/pii/S0165027015004240#fig0005

% Get Indices for the spikes
SpikeIdx = {};
for i = 1:length(FullyFilteredData(:,1))
    [~, Idxpeak] = intersect(TimeVector, AllPeaks{i,2}, 'stable');
    SpikeIdx{i} = Idxpeak;
end
SpikeIdx = SpikeIdx';         % Now we have the index numbers for the tagged spike activity

% how many indices per ms
SamplesPerMs = Settings.Recording.SamplingRate/1000;    %Figuring out how many samples per ms to use for indexing

% setting up start and ends of each waveform window
WindowStart = {};
WindowEnd = {};
for i = 1:length(FullyFilteredData(:,1))
    WindowStart{i} = SpikeIdx{i,1} - (SamplesPerMs * Settings.Waveform.BeforeEventMs);   % 1 ms before
    WindowEnd{i} = SpikeIdx{i,1} + (SamplesPerMs * Settings.Waveform.AfterEventMs);     % 2.2 after

    %If WindowStart precedes the start (meaning it is negative), set it to the first sample point
    if WindowStart{i} < 1
        WindowStart = 1;
    end
    % If window goes past the final number of samples, change it to the last one
    if WindowEnd{i} > TotalSamples
        WindowEnd = TotalSamples;
    end
end

% Getting and Containing Spikeform data
SpikeWaveforms = cell(size(FullyFilteredData, 1), 1);
for i = 1:length(FullyFilteredData(:, 1))
    ElectrodeWaveforms = cell(length(WindowStart{i}), 1);

    for j = 1:length(WindowStart{i})
        Waveform = FullyFilteredData(i, WindowStart{i}(j):WindowEnd{i}(j));

        ElectrodeWaveforms{j} = Waveform;
    end
    SpikeWaveforms{i} = ElectrodeWaveforms;
end

clear ElectrodeWaveforms SamplesPerMs WindowStart WindowEnd Waveform
disp('Waveforms Selected');

%% Plotting Waveforms by well with all passing electrodes
% Assuming WellNumber and ElectrodeNumber are vectors of the same length
UniqueWells = unique(WellNumber);
for i = 1:length(UniqueWells)
    CurrentWell = UniqueWells(i);
    ElectrodesInCurrentWell = find(WellNumber == CurrentWell);       %finds electrodes that belong to well being processed

    figure;
    for ElectrodeIndex = 1:length(ElectrodesInCurrentWell)
        currentElectrode = ElectrodesInCurrentWell(ElectrodeIndex);

        subplot(length(ElectrodesInCurrentWell), 1, ElectrodeIndex);
        for j = 1:length(SpikeWaveforms{currentElectrode})
            waveform = SpikeWaveforms{currentElectrode}{j};
            WaveVector = linspace(-1, 2.2, length(waveform));
            plot(WaveVector, waveform, 'LineWidth', 1);
            hold on;
        end

        xlabel('Time Relative to Event (ms)');
        ylabel('Voltage (mV)');
        title([' Electrode ' ElectrodeNumber(currentElectrode)], 'Interpreter', 'none');
        grid on;
        xlim([-1, 2.2]);
        % ylim([-20, 20]);
    end
    % main title for the entire figure
    sgtitle(['Superimposed Waveforms - Well ' num2str(CurrentWell)]);
end

clear WaveVector waveform

%% Rasterplots Original, just Spike

% %!!!!!!!!!!!!!!!!!!  Need to set up a way to use a slider in here !!!!!!! %
% 
% OrderOfElectrode = str2num(cell2mat(ElectrodeNumber));
% [~, ElectrodeOrderTemp] = ismember(OrderOfElectrode, Settings.Recording.ElectrodeOrder);
% ElectrodeOrder = ElectrodeOrderTemp + 1;
% 
% for i = 1:length(UniqueWells)
%     CurrentWell = UniqueWells(i);
%     ElectrodesInCurrentWell = find(WellNumber == CurrentWell);
% 
%     % Plot spikes for each electrode in the current well
%     figure      % Create figure for each unique well
%     for ii = 1:length(ElectrodesInCurrentWell)
%         ElectrodeIndex = ElectrodesInCurrentWell(ii);
%         electrodeSpikes = AllPeaks{ElectrodeIndex, 2};
%         % right here i need to get the Y position to be multiplied by the
%         % order in the ElectrodeOrder+1 to get it in the proper position
%         plot(electrodeSpikes, ElectrodeOrder(ElectrodeIndex)*ones(size(electrodeSpikes)), '|k', 'MarkerSize', 10);
%         hold on;
%     end
% 
%     % Customize subplot
%     xlabel('Time (s)');
%     ylabel('Electrode Number');
%     ylim([0 (size(Settings.Recording.ElectrodeOrder(1,:), 2)+1)]);
%     title(['Raster Plot - Well ' num2str(CurrentWell)]);
% end

%% Burst detection from Max Interval Method
% !! copied from toolbox !!!!!!
%Calculating the Bursts according to the Max interval method from
%Neuroexplorer 2014 where they predefine 5 parameters that constitute a
%burst max ISI of the first two spikes in a burst cant be higher than 170
%ms and any ISI afterwards within the burst cannot be higher than 300 ms
%and the burst will end if it is higher than 300 ms.
% the minimum duration of bursts is 10 ms and the duration between bursts
% is a min of 200 ms or they get merged and the min amount of spikes in a
% burst is 10 spikes

% Getting ISIs for all spikes
ISIAllSpikeS = cell(size(AllPeaks,1),1);            %All ISI of all spikes, all channels
for i = 1:length(AllPeaks)
    ISIAllSpikeS{i}  = diff(AllPeaks{i,2});
    ISIAllSpikeS{i,2} = 1:length(ISIAllSpikeS{i});  %adding index of ISIs to be used later with SpikeIdx to get timings
end

%same thing just separating to keep any manipulations separate
ISIBurst = ISIAllSpikeS;

Burst = cell(1, length(AllPeaks));
for ii = 1:length(AllPeaks)
    %find indices that meet criteria for start of burst
    StartISIIdx = find(ISIBurst{ii}(1,:) < Settings.BurstDetection.MaxStartInterval);
    ProcessingBurst = cell(1, length(StartISIIdx));

    for iii = 1:length(StartISIIdx)
        Burst1 = [];  
        %finding indexes of bursts ISIs that follow the start indices and are less than the intra burst interval
        for iv = StartISIIdx(iii):length(ISIBurst{ii})
            if ISIBurst{ii, 1}(1, iv) < Settings.BurstDetection.MaxIntraBurstInterval
                burst = ISIBurst{ii, 2}(1, iv);
                Burst1{iv} = burst;                 %contains idxs of passed start & intra for THAT burst
            else
                break
            end
        end

        if isempty(Burst1)
        else
            Burst1 = vertcat(Burst1{:});    %concatenates Burst ISI idxs that meet criteria to for that electrode
        end

        % Burst ISIs that meet start and intra criteria
        ProcessingBurst{iii} = Burst1;
    end

    %removing duplicate indexes and merging overlapping ones
    MergeDupe = cellfun(@(x) x(end), ProcessingBurst);
    for vi = 1:length(MergeDupe)
        try
            if MergeDupe(vi) == MergeDupe(vi+1)
                ProcessingBurst{vi+1} = [];
            else
            end
        catch
        end
    end
    ProcessingBurst = ProcessingBurst(~cellfun('isempty', ProcessingBurst));

    % Finding INTERburst interval
    % if less than threshold, merge into one burst
    for vii = 1:length(ProcessingBurst)-1
        if isempty(ProcessingBurst{vii})
            continue
        end
        for viii = vii+1:length(ProcessingBurst)
            % merging bursts within the IBI threshold
            if isempty(ProcessingBurst{viii})
                continue
            end
            if AllPeaks{ii,2}(ProcessingBurst{viii}(1)) - AllPeaks{ii,2}(ProcessingBurst{vii}(end)+1) < Settings.BurstDetection.MaxInterBurstInterval
                ProcessingBurst{vii} = vertcat(ProcessingBurst{vii}, ProcessingBurst{viii});
                ProcessingBurst{viii} = [];
            else
                continue
            end
        end
    end

    ProcessingBurst = ProcessingBurst(~cellfun('isempty', ProcessingBurst));

    % checking duration of the burst, must meet minimum duration
    for ix = 1:length(ProcessingBurst)
        if AllPeaks{ii,2}(ProcessingBurst{1,ix}(end)) - AllPeaks{ii,2}(ProcessingBurst{1, ix}(1)) < Settings.BurstDetection.MinDuration
            ProcessingBurst{1, ix} = [];
        else
        end
    end

    % removing empty cells
    ProcessingBurst = ProcessingBurst(~cellfun('isempty', ProcessingBurst));
  
    %removing bursts with fewer that preset number of spikes
    %looking at ISIs so need to increase spike number by 1

    for v = 1:length(ProcessingBurst)
        if length(ProcessingBurst{1, v}) + 1 < Settings.BurstDetection.MinSpikes
            ProcessingBurst{1, v} = [];
        end
    end

    %removes empty cells from ProcessingBurst
    ProcessingBurst = ProcessingBurst(~cellfun('isempty', ProcessingBurst));     

    % The indexes of burst ISIs that meet all criteria
    BurstISIIdxs{ii} = ProcessingBurst;
end

 clear ProcessingBurst Burst1 burst StartISIIdx MergeDupe

%% Getting timings back
BurstISIIdxs = BurstISIIdxs';
BurstTimes = BurstISIIdxs;         %used to set up to retrieve timings below
BurstIdxs = BurstISIIdxs;

BurstInfo = cell(length(AllPeaks), 1);
% Swap ISI index to actual spike indexes
for i = 1:length(BurstISIIdxs)
    for ii = 1:length(BurstISIIdxs{i})
        % Add the next sequential number to the current cell to go from ISI
        % to spikes
        BurstIdxs{i}{ii} = [BurstIdxs{i}{ii}(:); BurstIdxs{i}{ii}(end)+1];
    end
end

%Gets timings back
for x = 1:length(AllPeaks)
    for xi = 1:length(BurstIdxs{x, 1})
        if isempty(BurstIdxs(x, 1))
            BurstTimes(x,1) = [];
        else
            BurstTimes{x, 1}{1, xi} = AllPeaks{x, 2}(BurstIdxs{x, 1}{1, xi});        %have to use 2 for time because 1 is voltage
            BurstInfo{x}.BurstTimestamps{xi} = BurstTimes{x}{xi};
        end
    end
end

clear Burst1
disp('Bursts found through Max Interval Method')

%% Burst Characteristics Below
% gets burst duration, number of bursts, number of spikes, ISI within
% bursts, Freq within bursts, and interburst interval
% All these characteristics are stored in a structure called BurstInfo

for i = 1:length(AllPeaks)
    BurstInfo{i}.NumberofBursts = 1:length(BurstTimes{i});
    
    for ii = 1:length(BurstTimes{i, 1})
        BurstInfo{i}.BurstDuration(ii) = BurstTimes{i, 1}{1, ii}(end) - BurstTimes{i, 1}{1, ii}(1, 1);
        BurstInfo{i}.SpikesInBursts(ii) = length(BurstTimes{i, 1}{1, ii});
    end

    if isempty(BurstInfo{i}.NumberofBursts)
        BurstInfo{i}.FreqInBurst = [];
        AvgISIInBursts{i} = [];
        SDISIBurst{i} = [];            %do we need this?? SD of ISIs of bursts

    else
        BurstInfo{i}.FreqInBurst = BurstInfo{i}.SpikesInBursts ./ BurstInfo{i}.BurstDuration;
        AvgISIInBursts{i} = cellfun(@(BurstTimes) mean(diff(BurstTimes)), BurstTimes{i});
        BurstInfo{i}.AvgISIInBursts = AvgISIInBursts{i}';
        
        SDISIBurst{i} = cellfun(@(BurstTimes) std(diff(BurstTimes)), BurstTimes{i});
        BurstInfo{i}.SDISIBurst = SDISIBurst{i}';
    end
end
clear AvgISIInBursts SDISIBurst 

% Calculating Interburst Interval 
IBI2 = [];
for i = 1:length(BurstTimes)
    if isempty(BurstTimes{i})
        continue
    else 
        for ii = 1:length(BurstTimes{i})-1
            InterBurstInterval = BurstTimes{i}{ii + 1}(1) - BurstTimes{i}{ii}(end);
            IBI2 = [IBI2, InterBurstInterval];
        end
    end
    BurstInfo{i}.InterBurstInterval = IBI2';
    IBI2 = [];
end
clear InterBurstInterval IBI2 IBI
disp("Burst Characteristics Done")
%% Bursting Info by Well

BurstInfoByWell = cell(length(UniqueWells), 1);
BurstingElectrodes = [];
for i = 1:length(UniqueWells)
    CurrentWell = UniqueWells(i);
    ElectrodesInCurrentWell = find(WellNumber == CurrentWell);

    for ii = 1:length(ElectrodesInCurrentWell)
        if BurstInfo{ElectrodesInCurrentWell(ii)}.NumberofBursts ~= 0;
            Temp = ElectrodesInCurrentWell(ii);
            BurstingElectrodes = [BurstingElectrodes, Temp];

            BurstInfoByWell{i}.ElectrodeRow = BurstingElectrodes;
        end
    end

    if isfield(BurstInfoByWell{i}, 'ElectrodeRow')
        BurstInfoByWell{i}.ElectrodeNum = ElectrodeNumber(BurstingElectrodes);
        BurstInfoByWell{i}.WellLabel = CurrentWell;

        TotalBurst = 0;
        TotalSpikes = 0;
        FreqAdded = 0;
        InterBurstIntervals = 0;
        TotalDur = 0;
        Timestamps = {};
        %getting counts and things below if they have bursting electrodes
        for iii = 1:length(BurstInfoByWell{i}.ElectrodeRow)
            ElectrodeSelected = BurstInfoByWell{i}.ElectrodeRow(iii);

            Temp = length(BurstInfo{ElectrodeSelected}.NumberofBursts);
            Temp2 = sum(BurstInfo{ElectrodeSelected}.SpikesInBursts);
            Temp3 = sum(BurstInfo{ElectrodeSelected}.FreqInBurst);
            Temp4 = sum(BurstInfo{ElectrodeSelected}.InterBurstInterval);
            Temp5 = sum(BurstInfo{ElectrodeSelected}.BurstDuration);
            Temp6 = BurstInfo{ElectrodeSelected}.BurstTimestamps;
            Temp7 = BurstIdxs{ElectrodeSelected};


            TotalBurst = TotalBurst + Temp;
            TotalSpikes = TotalSpikes + Temp2;
            FreqAdded = FreqAdded + Temp3;
            InterBurstIntervals = InterBurstIntervals + Temp4;
            TotalDur = TotalDur + Temp5;
            BurstInfoByWell{i}.Timestamps{iii, 1} = Temp6;
            BurstInfoByWell{i}.BurstIdxs{iii, 1} = Temp7;
        end

        BurstInfoByWell{i}.NumberOfBursts = TotalBurst;
        BurstInfoByWell{i}.NumberOfSpikes = TotalSpikes;

        BurstInfoByWell{i}.AvgDuration = TotalDur/BurstInfoByWell{i}.NumberOfBursts;
        BurstInfoByWell{i}.AvgSpikesPerBurst = TotalSpikes/BurstInfoByWell{i}.NumberOfBursts;
        BurstInfoByWell{i}.AvgSpikingFreq = FreqAdded/BurstInfoByWell{i}.NumberOfBursts;
        BurstInfoByWell{i}.AvgIBI = InterBurstIntervals/BurstInfoByWell{i}.NumberOfBursts;

    end
    clear Temp Temp2 Temp3 Temp4 Temp5 Temp6 Temp7 TotalBurst ElectrodeSelected InterBurstIntervals FreqAdded TotalSpikes TotalDur CurrentWell
end

%removes empty cells
NotEmpty = ~cellfun(@isempty, BurstInfoByWell);
BurstInfoByWell = BurstInfoByWell(NotEmpty);

clear BurstingElectrodes ElectrodeRow ElectrodesInCurrentWell NotEmpty
disp("Burst Info Grouped by Well")
%% Network Stuff Below
%!!!!!!!!!!! %adapted from in vitro cortical network is homeostatiscally
%regulated: a model for sleep regulation ( like in the mukai et
%al.,2003 and ito et al., (2010) paper !!!!!!!!!!
% looking to find network bursts


NetworkInfo = cell(length(BurstInfoByWell), 1);
BurstSpikeIdxs = cell(length(BurstInfoByWell), 1);
OverlappingBursts = cell(length(BurstInfoByWell), 1);

for i = 1:length(BurstInfoByWell)     %go into well
    % skips any wells that have less than the minimum number of channels
    % participating in bursts
    if length(BurstInfoByWell{i}.ElectrodeNum) < Settings.NetworkDetection.MinChannelParticipating;
        continue
    end

    %using indexes from spikes to line them up in time
    NumBursts = length(BurstInfoByWell{i}.BurstIdxs);
    BurstSpikeIdxs{i} = cell(NumBursts, 1);
    OverlappingBursts{i} = cell(NumBursts, 1);

    for ii = 1:NumBursts
        BurstLength = length(BurstInfoByWell{i}.BurstIdxs{ii});
        BurstSpikeIdxs{i}{ii} = cell(BurstLength, 1);
        OverlappingBursts{i}{ii} = cell(BurstLength, 1);

        for iii = 1:BurstLength
            SpikeIndices = BurstInfoByWell{i}.BurstIdxs{ii}{iii};
            ElectrodeRow = BurstInfoByWell{i}.ElectrodeRow(ii);
            for iv = 1:length(SpikeIndices)
                BurstSpikeIdxs{i}{ii}{iii}{iv} = SpikeIdx{ElectrodeRow}(SpikeIndices(iv));
            end

        end
    end

    %Looking for overlaps in time
    for ii = 1:length(BurstSpikeIdxs{i})                        %electrode
        disp(num2str(ii))
        for iii = 1:length(BurstSpikeIdxs{i}{1})               %bursts
            disp(num2str(iii))
            for iv = 1:length(BurstSpikeIdxs{i}{ii}{iii})       %spikes within burst
                spikeIndex = BurstSpikeIdxs{i}{ii}{iii}{iv};
                % Check for overlaps with other bursts in other rows
                for v = 1:length(BurstSpikeIdxs{i})             %electrode
                    if v <= ii
                        continue
                    end
                    for vi = 1:length(BurstSpikeIdxs{i}{v})                    % bursts in other rows
                        for vii = 1:length(BurstSpikeIdxs{i}{v}{vi})           % spike indices in the burst
                            otherSpikeIndex = BurstSpikeIdxs{i}{v}{vi}{vii};   % spike index for the burst in other row

                            [commonValues, idx1, idx2] = intersect(spikeIndex, otherSpikeIndex);

                            if ~isempty(commonValues)
                                OverlappingBursts{i}{end+1} = {ii, iii, iv, v, vi, vii, commonValues, idx1, idx2}; % If there is an overlap, store the indices of the overlapping bursts
                            end
                        end
                    end
                end
            end
        end
    end
end

clear NumBursts
% 
% allTimepoints = [];
% % Loop through each electrode to find unique timepoints
% for i = 1:numel(BurstSpikeIdxs)
%     % Concatenate spike indices for the current electrode
%     spikeIndices = BurstSpikeIdxs{i};
%     electrodeTimepoints = cat(1, spikeIndices{:});
% 
%     % Add unique timepoints for the current electrode to the array
% end
% 
% 
% 
% totalBurstPerWell = cell(length(BurstSpikeIdxs), 1);
% AllTimepoints = {};
% for wellIdx = 1:2    %well
%     if isempty(BurstSpikeIdxs{wellIdx})
%         continue
%     end
%     for electrodeIdx = 1:length(BurstSpikeIdxs{wellIdx}) %electrode
%         for BurstIdx = 1:length(BurstSpikeIdxs{wellIdx}{electrodeIdx}) %bursts
%             for spikeIdx = 1:length(BurstSpikeIdxs{wellIdx}{electrodeIdx}{BurstIdx})
%                Temp = BurstSpikeIdxs{wellIdx}{electrodeIdx}{BurstIdx}(spikeIdx);
%                AllTimepoints = [AllTimepoints; Temp];
%             end
%         end
%     end
%     AllTimepoints = cell2mat(AllTimepoints);
%     UniqueTimepoints = unique(AllTimepoints);
% 
%     LogicalIndex = false(length(UniqueTimepoints), length(BurstSpikeIdxs{wellIdx}));
%     for electrodeIdx = 1:length(BurstSpikeIdxs{wellIdx}) %electrode
%         for BurstIdx = 1:length(BurstSpikeIdxs{wellIdx}{electrodeIdx}) %bursts
%             LogicalIndex(ismember(UniqueTimepoints, BurstSpikeIdxs{wellIdx}{electrodeIdx}{BurstIdx}), electrodeIdx) = true;
%         end
%     end
% 
%     totalBurstPerWell{wellIdx} = sum(LogicalIndex, 2);
% end
% 
% 
% for 
% 


% Assuming AllPeaks{electrodeIndex, 2} provides spike times in increasing order

for i = 1:numel(BurstInfoByWell)
    BurstSpikeIdxs = cell(length(BurstInfoByWell{i}));
    for ii = 1:numel(BurstInfoByWell{i}.ElectrodeRow)
        electrode = BurstInfoByWell{i}.ElectrodeRow(ii);
        BurstSpikeIdxs{ii} = cell(length(BurstInfoByWell{i}.BurstIdxs{ii}), 1);
        for iii = 1:numel(BurstInfo{electrode}.BurstTimestamps)
            burstTimes = BurstInfo{electrode}.BurstTimestamps{iii};
            BurstRanges{i}{electrode}(iii, :) = [burstTimes(1), burstTimes(end)];

            if iii <= length(BurstInfoByWell{i}.BurstIdxs{ii, 1})
                Indexes = SpikeIdx{BurstInfoByWell{i}.ElectrodeRow(ii)}(BurstInfoByWell{i}.BurstIdxs{ii}{iii});
                StartStopIndxs{i}{ii}(iii, :) = [Indexes(1), Indexes(end)];
            end
        end
    end
end



networkBursts = cell(length(BurstInfoByWell),1); 
for i = 1:length(BurstInfoByWell)                           % For each well
    networkBursts{i} = {};                                  % Initialize a cell array to store network burst info
    for ii = 1:length(StartStopIndxs{i})                    % For each electrode in the well
        for iii = 1:size(StartStopIndxs{i}{ii}, 1)          % For each burst on the electrode
            overlappingBursts = 1;                                                           % Start counting with the current burst
            for jj = 1:length(StartStopIndxs{i})                        % Compare with other electrodes
                if ii == jj
                    continue;                                            % Skip self-comparison
                end
                for jjj = 1:size(StartStopIndxs{i}{jj}, 1)                          % For each burst on the other electrode
                    % Check for overlap
                    if ~(StartStopIndxs{i}{ii}(iii, 2) < StartStopIndxs{i}{jj}(jjj, 1) || StartStopIndxs{i}{ii}(iii, 1) > StartStopIndxs{i}{jj}(jjj, 2))
                        overlappingBursts = overlappingBursts + 1;
                        break;  % Only need one overlap per electrode
                    end
                end
            end
            % Check if the count exceeds the threshold
            if overlappingBursts >= Settings.NetworkDetection.MinChannelParticipating
                % Store network burst information, e.g., time range, electrodes involved
                networkBursts{i}{end+1} = {ii, StartStopIndxs{i}{ii}(iii, :)};
            end
        end
    end
    % Store or process the network bursts for well 'i' as needed
end




%% Plot with the Burst and Spikes put up!

OrderOfElectrode = str2num(cell2mat(ElectrodeNumber));
[~, ElectrodeOrderTemp] = ismember(OrderOfElectrode, Settings.Recording.ElectrodeOrder);
ElectrodeOrder = ElectrodeOrderTemp + 1;

for electrodeIdx = 1:length(UniqueWells)
    CurrentWell = UniqueWells(electrodeIdx);
    ElectrodesInCurrentWell = find(WellNumber == CurrentWell);

    % Plot spikes and BurstTimes for each electrode in the current well
    figure      % Create figure for each unique well
    for electrodeIdx = 1:length(ElectrodesInCurrentWell)
        ElectrodeIndex = ElectrodesInCurrentWell(electrodeIdx);
        electrodeSpikes = AllPeaks{ElectrodeIndex, 2};
        YPosition = ElectrodeOrder(ElectrodeIndex);

        % Plot electrode spikes
        plot(electrodeSpikes, YPosition * ones(size(electrodeSpikes)), '|k', 'MarkerSize', 10);
        hold on;

        % Plot BurstTimes for the corresponding row
        currentBurstTimes = BurstTimes{ElectrodeIndex};
        if ~isempty(currentBurstTimes)
            for BurstIdx = 1:length(currentBurstTimes)
                line([currentBurstTimes{BurstIdx}(1), currentBurstTimes{BurstIdx}(end)], [YPosition+0.5, YPosition+0.5], 'Color', 'r', 'LineWidth', 10);
                %the 0.5 above is to offset it slightly to be visible ABOVE
                %the activity
                hold on;
            end
        end
    end

% Customize subplot
xlabel('Time (s)');
ylabel('Electrode Number');
ylim([0 (size(Settings.Recording.ElectrodeOrder(1, :), 2) + 1)]);
title(['Raster Plot - Well ' num2str(CurrentWell)]);
end


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