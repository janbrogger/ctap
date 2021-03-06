% Adds a burst of simulated EMG contamination to the EEG data
%   function eeg = ctaptest_add_EMG(eeg,ampl,t_start,dur,loc,rad,F)
%
% Args:
%   eeg: EEG struct
%   ampl <double>: EMG signal amplitude
%   t_start <double>: start time of the artifact (in seconds)
%   dur <double>: duration of the burst (in seconds)
%   loc <mat>: epicenter of the burst ([X Y Z])
%   rad <double>: radius of the EMG source
%   F <mat>: frequency band of the EMG burst ([lower_edge upper_edge transition_band])
%
% Returns:
%   eeg: EEG struct with EMG burst added. Artifact logged in 
%        eeg.CTAP.artifact.EMG   
function eeg = ctaptest_add_emg(eeg,ampl,t_start,dur,loc,rad,F)

% Find sample-index corresponding to start time
[~,start_idx]=min(abs(eeg.times-t_start*1e3));

burst_dur = floor(eeg.srate*dur);
emg = randn(size(eeg.data,1),burst_dur);

% Design the filter
wp  = [F(1)+F(3) F(2)-F(3)]./(.5*eeg.srate);
ws  = [F(1)-F(3) F(2)+F(3)]./(.5*eeg.srate);
rp = 1;
rs = 40;

[n,Wp] = cheb1ord(wp,ws,rp,rs);
[b,a] = cheby1(n,rp,Wp); %#ok<ASGLU>

fprintf(1,'Adding %0.2fs %0.2f-%0.2fHz (A=%0.2f) EMG burst at t=%0.2fs\n',...
            dur,F(1),F(2),ampl,t_start);

% Apply filter (maybe try eegfilt here)
%for k=1:size(emg,1)
%    emg(k,:) = filtfilt(b,a,emg(k,:)).*ampl;
%end

%ssx = eegfilt(emg,100,F(1),0,0,[],[],'fir1');
%ssx = eegfilt(ssx,100,0,F(2),0,[],[],'fir1');

ssx = eegfilt(emg,100,F(1),0,0,[],0,'fir1');
ssx = eegfilt(ssx,100,0,F(2),0,[],0,'fir1');
emg = ssx.*ampl;


chc = [[eeg.chanlocs.X]' [eeg.chanlocs.Y]' [eeg.chanlocs.Z]'];
chd = eucl(chc,loc);

% This is the "propagation template" 
% linear might not be good though
x = linspace(0,5,1000);
c = zeros(size(x));
c(x<rad)=linspace(1,0,sum(x<rad));

emg = emg.*repmat(interp1(x,c,chd),1,size(emg,2));

% inject emg burst back into eeg-struct
eeg.data(:,start_idx:start_idx+burst_dur-1)= ...
           eeg.data(:,start_idx:start_idx+burst_dur-1) + single(emg);

eeg = eeg_checkset(eeg);

% Logging parameters
emg_params.time_window_smp = [start_idx start_idx+burst_dur-1];
emg_params.amplitude = ampl;
emg_params.duration = burst_dur;
emg_params.location = loc;
emg_params.radius = rad;
emg_params.freqband = F;

% need to update the CTAP.artifacts structure
if isfield(eeg.CTAP.artifact,'EMG')
    eeg.CTAP.artifact.EMG(end+1) = emg_params;
else
    eeg.CTAP.artifact.EMG = emg_params;
end
