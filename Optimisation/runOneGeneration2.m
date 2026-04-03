function yOUT = runOneGeneration2(xIN)
    % Execute one generation of optimization simulations.
    %
    % Args:
    %     xIN (double): Input matrix defining the parameters for the optimization individuals. 
    %         Each column corresponds to an individual.
    %
    % Returns:
    %     yOUT (double): Output array containing the final cost values for each individual in the population.
    %
    % Notes:
    %     - The function checks for previously simulated individuals to avoid redundant computations.
    %     - Simulink models are loaded and configured for each individual.
    %     - Simulation results are stored and reused if an identical individual is re-evaluated.
    %     - The cost function evaluates performance and constraint penalties for each individual.
    %     - Uses parallel simulations (`parsim`) to improve computation speed.
    %     - Global variables:
    %         - `runID`: Tracks the simulation run ID.
    %         - `listvars`: List of optimization variable names.
    %         - `paramUbounds`: Upper bounds for optimization parameters.
    %         - `model`: Name of the Simulink model.
    %         - `Int_listvars`: List of discrete (integer) optimization variables.
    %         - `fileName_simInput`: File name for simulation input configuration.
    %         - `fileName_kite`: File name for kite-specific parameters.
    %
    % Workflow:
    %     1. Checks if preveous individuals exist by loading `list_old_individuals.mat`.
    %     2. Configures simulation inputs using `runParamSim` and `initAllStructs`.
    %     3. Runs simulations using `parsim`.
    %     4. Computes cost values for each individual using `getCost_new`.
    %     5. Updates and saves the history file `list_old_individuals.mat`.
    %
    % Date:
    %     2024-10-31
    %
    % Authors:
    %     Dylan Eijkelhof (d.eijkelhof@tudelft.nl)
    
    global runID
    global listvars paramUbounds model Int_listvars
    global fileName_simInput fileName_kite
    global useParallel
    
    if numel(runID) == 0
        runID = 0;
    end
    
    nInd = size(xIN, 2); % number of individuals
    nRetvals = 9; % number of outputs of the cost function CHECK!!
    
    optsIN = xIN;
    penaltyVector = [1e8; 1e8; 1e8; 1e8; 1e8; 0; 0; 0; 5e8];
    
    try
        load('list_old_individuals.mat','list_old_individuals', 'listvars_copy', ...
            'Int_listvars_copy', 'paramUbounds_copy'); % [runID; parameters; retval]
        if ~isequal(listvars_copy,listvars) || ~isequal(paramUbounds_copy,paramUbounds) || ~isequal(Int_listvars_copy,Int_listvars)
            % Check if imported dataset matches the current running
            % optimisation, otherwise concatenation won't work
            error('runOneGeneration2: data in list_old_individuals.mat does not match current optimisation dataset')
        end
    catch
        list_old_individuals = ones(size(optsIN,1)+nRetvals,0);
    end
    
    szList_old_individuals = size(list_old_individuals, 2);
    list_old_individuals = [list_old_individuals, NaN(size(optsIN,1)+nRetvals, nInd)]; %%%%%%%%% Concatenation involves an empty array with an incorrect number of rows.
    
    fprintf(1, 'Adding %d jobs\n', nInd);
    lastResume = 0;
    foundMatch = false(1, nInd);
    curResults = repmat(struct('retval', []), 1, nInd);
    yOUTlog = repmat(penaltyVector, 1, nInd);
    
    
    for i = 1:nInd
        curResults(i).retval = [];
        % try to figure out if that individual did already run
        for jj = 1:szList_old_individuals
            j = lastResume + jj;
            if j > szList_old_individuals
                j = j - szList_old_individuals;
            end
            if sum(optsIN(:, i) ~= list_old_individuals(1:(end-nRetvals), j)) == 0
                if ~isinf(list_old_individuals(end, j))
                    % if it was analyzed
                    results(i).retval = list_old_individuals((end-nRetvals+1):end, j);
                    curResults(i) = results(i);
                    foundMatch(i) = true;
                    yOUTlog(:, i) = curResults(i).retval;
                    lastResume = j;
                end
                break;
            end
        end
    end
    
    
    %% load simulink model
    model_copy        = model;
    listvars_copy     = listvars;     % suggested by matlab
    paramUbounds_copy = paramUbounds; % suggested by matlab
    Int_listvars_copy = Int_listvars; % suggested by matlab
    fileName_simInput_copy = fileName_simInput;
    fileName_kite_copy = fileName_kite;
    
    %% define sim input for optimization
    MegAWESkite = yaml.ReadYaml(fileName_kite_copy,false,true);
    simIn = Simulink.SimulationInput.empty(0, nInd);
    simInitByIdx = cell(1, nInd);
    tetherForceMaxByIdx = NaN(1, nInd);
    validToRun = false(1, nInd);
    simOutByIdx = cell(1, nInd);
    successfulMask = false(1, nInd);
    
    for i = 1:size(optsIN,2)
        if foundMatch(i)
            continue
        end

        try
            [simInit, ENVMT, controllerGains_traction, ... 
                controllerGains_retraction, tetherParams, pathparam, ...
                actuatorLimit, winchParameter] = ...
                runParamSim(fileName_simInput_copy, MegAWESkite, listvars_copy, ...
                optsIN(:,i), paramUbounds_copy, Int_listvars_copy);

            simInit.doPlot = false;

            % to be optimized wind speed
            simInP = initAllStructs(model_copy, simInit, ENVMT, controllerGains_traction, ... 
            controllerGains_retraction, tetherParams, pathparam, ...
            actuatorLimit, winchParameter, MegAWESkite);
            simIn(i) = simInP;
            simInitByIdx{i} = simInit;
            tetherForceMaxByIdx(i) = tetherParams.forceMax;
            validToRun(i) = true;
        catch ME
            warning('runOneGeneration2:PrepareIndividualFailed', ...
                'Skipping individual %d due to invalid setup (%s). Applying penalty.', i, ME.message);
        end
    end
    
    %% run simulations
    if sum(foundMatch) ~= nInd
        validIdx = find(validToRun);
        if ~isempty(validIdx)
            if useParallel
                try
                    simOutValid = parsim(simIn(validIdx), ...
                        'StopOnError', 'off', ...
                        'UseFastRestart', false, ...
                        'ShowProgress', 'off');

                    for k = 1:numel(validIdx)
                        i = validIdx(k);
                        simErrMsg = '';
                        try
                            simErrMsg = simOutValid(k).ErrorMessage;
                        catch
                            %
                        end

                        if isempty(simErrMsg)
                            successfulMask(i) = true;
                            simOutByIdx{i} = simOutValid(k);
                        else
                            warning('runOneGeneration2:SimulationFailed', ...
                                'Simulation failed for individual %d (%s). Applying penalty.', i, simErrMsg);
                        end
                    end
                catch ME
                    warning('runOneGeneration2:ParsimFailed', ...
                        'Parallel simulation batch failed (%s). Retrying this generation in serial mode.', ME.message);
                    useParallel = false;
                end
            end

            if ~useParallel
                for k = 1:numel(validIdx)
                    i = validIdx(k);
                    try
                        simOutByIdx{i} = sim(simIn(i), 'UseFastRestart', false);
                        successfulMask(i) = true;
                    catch ME
                        warning('runOneGeneration2:SimulationFailed', ...
                            'Simulation failed for individual %d (%s). Applying penalty.', i, ME.message);
                    end
                end
            end

            successfulIdx = find(successfulMask);
            for k = 1:numel(successfulIdx)
                i = successfulIdx(k);
                ySingle = getCost_new(optsIN(:, i), simOutByIdx{i}, ...
                    simInitByIdx{i}, tetherForceMaxByIdx(i), MegAWESkite.MainWing.alphaMax);
                yOUTlog(:, i) = ySingle(:, 1);
            end
        end

        list_old_individuals(:, szList_old_individuals+(1:nInd)) = [optsIN; yOUTlog];
    else
        list_old_individuals(:,(end-nInd+1):end) = []; % delete NaN
    end
    
    yOUT = yOUTlog(end,:);
    
    Simulink.sdi.clear
    
    save('list_old_individuals.mat', 'list_old_individuals', 'listvars_copy', ...
        'paramUbounds_copy', 'Int_listvars_copy');
    if useParallel
        try
            parfevalOnAll(gcp,@bdclose,0,'all');
        catch
            %
        end
    end
    runID = runID + nInd;
    fprintf(1, ' done\n');
end