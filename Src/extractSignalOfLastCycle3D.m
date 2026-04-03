function signalData = extractSignalOfLastCycle3D( signal, sample_count_last_cycle,  simInit )
% Extract 3D data from the last converged power cycle.
%
% Args:
%     signal (double timeseries): Full 3D timeseries simulation output.
%     sample_count_last_cycle (double timeseries): Simulation timeseries 'cycle_signal_counter'.
%     simInit (struct): Structure containing simulation initialization parameters.
%
% Returns:
%     signalData (double): Extracted power cycle 3D timeseries.
%
% Date:
%     2020-05-01
%
% Authors:
%     Sebastian Rapp, Dylan Eijkelhof (d.eijkelhof@tudelft.nl)

if ~isstruct(simInit) || ~isfield(simInit, 'Ts_power_conv_check')
	error('extractSignalOfLastCycle3D:InvalidSimInit', ...
		'simInit must contain Ts_power_conv_check.');
end

if ~isfield(sample_count_last_cycle, 'Data') || isempty(sample_count_last_cycle.Data)
	warning('extractSignalOfLastCycle3D:MissingCycleCounter', ...
		'sample_count_last_cycle.Data is missing or empty. Falling back to the full signal window.');
	signalData = signal;
	return
end

if ~isfield(signal, 'Time') || ~isfield(signal, 'Data') || isempty(signal.Time) || isempty(signal.Data)
	error('extractSignalOfLastCycle3D:InvalidSignal', ...
		'signal must contain non-empty Time and Data fields.');
end

time_window_last_cylce = sample_count_last_cycle.Data(end) * simInit.Ts_power_conv_check;
if ~isfinite(time_window_last_cylce) || time_window_last_cylce <= 0
	warning('extractSignalOfLastCycle3D:InvalidCycleWindow', ...
		'Computed cycle window is invalid. Falling back to the full signal window.');
	signalData = signal;
	return
end

idx_time_window_start = find(signal.Time >= signal.Time(end)-time_window_last_cylce,1);
if isempty(idx_time_window_start)
	warning('extractSignalOfLastCycle3D:WindowNotFound', ...
		'Could not locate the start index for the last cycle window. Falling back to the full signal window.');
	signalData = signal;
	return
end

rawData = signal.Data(idx_time_window_start:end,:,:);
if size(rawData,2) < 3
	error('extractSignalOfLastCycle3D:InvalidShape', ...
		'Expected at least 3 signal components in the second dimension.');
end

signalData.Data(:,1) = rawData(:,1,1);
signalData.Data(:,2) = rawData(:,2,1);
signalData.Data(:,3) = rawData(:,3,1);
signalData.Time = signal.Time(idx_time_window_start:end);

end