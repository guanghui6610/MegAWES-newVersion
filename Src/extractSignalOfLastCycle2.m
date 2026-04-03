function signalData = extractSignalOfLastCycle2( signal, sample_count_last_cycle,  simInit )
% Extract 1D data from the last converged power cycle.
%
% Args:
%     signal (double timeseries): Full 1D timeseries simulation output.
%     sample_count_last_cycle (double timeseries): Simulation timeseries 'cycle_signal_counter'.
%     simInit (struct): Structure containing simulation initialisation parameters.
%
% Returns:
%     signalData (double): Extracted power cycle 1D timeseries.
%
% Date:
%     2019-12-01
%
% Authors:
%     Sebastian Rapp, Dylan Eijkelhof (d.eijkelhof@tudelft.nl)

%------------- BEGIN CODE --------------
if ~isstruct(simInit) || ~isfield(simInit, 'Ts_power_conv_check')
	error('extractSignalOfLastCycle2:InvalidSimInit', ...
		'simInit must contain Ts_power_conv_check.');
end

if ~isfield(sample_count_last_cycle, 'Data') || isempty(sample_count_last_cycle.Data)
	warning('extractSignalOfLastCycle2:MissingCycleCounter', ...
		'sample_count_last_cycle.Data is missing or empty. Falling back to the full signal window.');
	signalData = signal;
	return
end

if ~isfield(signal, 'Time') || ~isfield(signal, 'Data') || isempty(signal.Time) || isempty(signal.Data)
	error('extractSignalOfLastCycle2:InvalidSignal', ...
		'signal must contain non-empty Time and Data fields.');
end

time_window_last_cylce = sample_count_last_cycle.Data(end) * simInit.Ts_power_conv_check;
if ~isfinite(time_window_last_cylce) || time_window_last_cylce <= 0
	warning('extractSignalOfLastCycle2:InvalidCycleWindow', ...
		'Computed cycle window is invalid. Falling back to the full signal window.');
	signalData = signal;
	return
end

idx_time_window_start = find(signal.Time >= signal.Time(end)-time_window_last_cylce,1);
if isempty(idx_time_window_start)
	warning('extractSignalOfLastCycle2:WindowNotFound', ...
		'Could not locate the start index for the last cycle window. Falling back to the full signal window.');
	signalData = signal;
	return
end

signalData.Data = signal.Data(idx_time_window_start:end);
signalData.Time = signal.Time(idx_time_window_start:end);

%------------- END CODE --------------
end