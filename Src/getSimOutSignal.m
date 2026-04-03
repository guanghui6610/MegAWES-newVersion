function signal = getSimOutSignal(simOut, signalName)
% Resolve a named signal from simOut across direct fields and logged datasets.

    if isstring(signalName)
        signalName = char(signalName);
    end

    if ~ischar(signalName)
        error('getSimOutSignal:InvalidSignalName', 'signalName must be a char or string.');
    end

    [rawSignal, isFound] = getDirectSignal(simOut, signalName);

    if ~isFound
        [rawSignal, isFound] = getFromContainer(simOut, 'logsout', signalName);
    end

    if ~isFound
        [rawSignal, isFound] = getFromContainer(simOut, 'yout', signalName);
    end

    if ~isFound
        availableNames = collectAvailableNames(simOut);
        error('getSimOutSignal:SignalNotFound', ...
            'Signal "%s" was not found in simOut. Available names: %s', ...
            signalName, strjoin(availableNames, ', '));
    end

    signal = normaliseSignal(rawSignal, signalName);
end

function [rawSignal, isFound] = getDirectSignal(simOut, signalName)
    rawSignal = [];
    isFound = false;

    if hasMember(simOut, signalName)
        rawSignal = simOut.(signalName);
        isFound = ~isempty(rawSignal);
        if isFound
            return
        end
    end

    try
        rawSignal = simOut.get(signalName);
        isFound = ~isempty(rawSignal);
    catch
        %
    end
end

function [rawSignal, isFound] = getFromContainer(simOut, containerName, signalName)
    rawSignal = [];
    isFound = false;

    if ~hasMember(simOut, containerName)
        return
    end

    container = simOut.(containerName);
    if isempty(container)
        return
    end

    if isa(container, 'Simulink.SimulationData.Dataset')
        [rawSignal, isFound] = getFromDataset(container, signalName);
        return
    end

    if isstruct(container) && isfield(container, signalName)
        rawSignal = container.(signalName);
        isFound = true;
    end
end

function [rawSignal, isFound] = getFromDataset(datasetObj, signalName)
    rawSignal = [];
    isFound = false;

    idx = [];
    try
        idx = datasetObj.getIndexByName(signalName);
    catch
        %
    end

    if ~isempty(idx) && idx > 0
        element = datasetObj.getElement(idx);
        rawSignal = element.Values;
        isFound = true;
        return
    end

    nElements = datasetObj.numElements;
    for k = 1:nElements
        element = datasetObj.getElement(k);
        if strcmp(element.Name, signalName)
            rawSignal = element.Values;
            isFound = true;
            return
        end
    end
end

function signal = normaliseSignal(rawSignal, signalName)
    if isa(rawSignal, 'Simulink.SimulationData.Signal')
        rawSignal = rawSignal.Values;
    end

    if isa(rawSignal, 'timeseries')
        signal = rawSignal;
        return
    end

    if isstruct(rawSignal) && isfield(rawSignal, 'Time') && isfield(rawSignal, 'Data')
        signal = rawSignal;
        return
    end

    error('getSimOutSignal:UnsupportedType', ...
        'Signal "%s" has unsupported type: %s', signalName, class(rawSignal));
end

function tf = hasMember(obj, name)
    if isstruct(obj)
        tf = isfield(obj, name);
    else
        tf = isprop(obj, name);
    end
end

function availableNames = collectAvailableNames(simOut)
    if isstruct(simOut)
        availableNames = fieldnames(simOut)';
    else
        try
            availableNames = simOut.who;
        catch
            availableNames = {};
        end
    end

    availableNames = [availableNames, collectContainerNames(simOut, 'logsout')];
    availableNames = [availableNames, collectContainerNames(simOut, 'yout')];

    if isempty(availableNames)
        availableNames = {'none'};
    else
        availableNames = unique(availableNames, 'stable');
    end
end

function names = collectContainerNames(simOut, containerName)
    names = {};

    if ~hasMember(simOut, containerName)
        return
    end

    container = simOut.(containerName);
    if ~isa(container, 'Simulink.SimulationData.Dataset')
        return
    end

    nElements = container.numElements;
    names = cell(1, nElements);
    for k = 1:nElements
        names{k} = container.getElement(k).Name;
    end

    names = names(~cellfun(@isempty, names));
end