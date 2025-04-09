%Spectral analysis of data processing

nfft = 2^nextpow2(length(Data(:, 1))*4);
Fs = 20000;
f = (-nfft/2 : nfft/2-1)/nfft;                 %normalized freq
F = Fs*f;                                      %Analog frequency (Hz)
f_filt = 2*F/Fs;            %norm freq 

%spectral mag
fftRawData = fft(Data(:), nfft);
%fftFiltData = fft(FilteredData(:), nfft);
        
%centered frequencies
afRaw =  fftshift(abs(fftRawData));
%afFilt =  fftshift(abs(fftFiltData));


figure 
subplot(211), plot(F, afRaw ), title('Spectral Magnitude of Raw vs. Analog Frequency'), xlabel('Analog Frequency (Hz)') 
%subplot(212), plot(F, afFilt ), title('Spectral Magnitude of Filtered vs. Analog Frequency'), xlabel('Analog Frequency (Hz)'), %hold, plot(F, 3000*magfiltButter1, 'r' ) 
%%
[bHigh, aHigh] = butter(Settings.Filters.HighPassOrder/2, ((Settings.Filters.HighPassCutoff)/(Settings.Recording.SamplingRate/2)), 'high');
magfiltButter1 = abs(fftshift(freqz(bHigh, aHigh, nfft, 'whole')));

figure
plot(f_filt, afFilt), hold, plot(f_filt, 300*magfiltButter1, 'r'), title('Spectral Magnitude of Signal with Filter (Butter) overlay'), xlabel('Normalized freq'), legend('Signal', 'Filter')
