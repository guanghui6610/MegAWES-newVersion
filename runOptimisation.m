% runOptimisation Optimisation execution script based on given yaml inputs (Lib)
%
% Returns:
%     list_old_individuals.mat (file): CMAES optimisation history
%
% Author:
%      Dylan Eijkelhof (d.eijkelhof@tudelft.nl)
%
% Date:
%     2024-10-31

%% Set folder dependencies

directoriesToAdd = {'Lib','Src','Optimisation'};
initialiseWorkspaceAndFolders(directoriesToAdd,{'numProcs','useParallel'})
%%
global runID
global listvars paramUbounds model Int_listvars
global fileName_simInput fileName_kite
global useParallel
runID = 0;

if ~exist('numProcs','var')
    numProcs=4;
end

if ~exist('useParallel','var')
    useParallel = true;
end

if useParallel
    jobStoragePath = fullfile(pwd, 'tmpStorage');
    [useParallel, poolStatus] = startParallelPoolWithRecovery(numProcs, jobStoragePath);
    disp(poolStatus);
else
    disp('Parallel pool disabled. Running optimisation simulations in serial mode.');
end

if exist('list_old_individuals.mat','file')
    movefile('list_old_individuals.mat',sprintf('%s_list_old_individuals.mat',datetime('today')))
end
delete('outcmaes*.dat')
delete('variablescmaes.mat')

%% Importing input parameters
model = 'simL0_multiPath';
fileName_simInput = 'fig8up_simInput.yaml';
fileName_optBounds = 'fig8up_opt_params_limits.yaml';
fileName_kite = 'MegAWESkite.yaml';

[listvars, x_init, paramUbounds, paramLbounds, Int_listvars] = ...
    defineOptParamsBounds(fileName_simInput, fileName_optBounds);

%% Set initial optimization parameters

paramsFull = x_init./paramUbounds; % normalisation
paramLbounds = paramLbounds./paramUbounds; % normalisation
paramSigma = (paramUbounds./paramUbounds - paramLbounds) * 0.3;

opts = cmaes('defaults');
opts.EvalParallel = 'yes'; % objective function FUN accepts NxM matrix, with M>1?
opts.EvalInitialX = 'yes'; % evaluation of initial solution
opts.PopSize = 100;%50; % (4 + floor(3*log(N)))  % population size, lambda
opts.Resume = 'no'; % resume former run from SaveFile
opts.DiagonalOnly = 0; % OPTS.DiagonalOnly > 1 defines the number of initial iterations, where the covariance matrix remains diagonal
opts.LBounds = paramLbounds;
opts.UBounds = paramUbounds./paramUbounds; % normalisation
opts.CMA.active = 1; % active CMA 1: neg. updates with pos. def. check, 2: neg. updates
opts.StopOnStagnation = 0;
opts.StopOnWarnings = 0;
opts.StopOnEqualFunctionValues = 0; 
opts.TolHistFun = 1e-20;

XMIN = cmaes('runOneGeneration2', paramsFull, paramSigma, opts);
% delete(gcp());

function [useParallel, statusMessage] = startParallelPoolWithRecovery(numProcs, jobStoragePath)
useParallel = true;
statusMessage = 'Parallel pool already available.';

pool = gcp('nocreate');
if ~isempty(pool)
    return
end

if exist(jobStoragePath, 'dir') ~= 7
    mkdir(jobStoragePath);
end

if ~probeProcessPool(numProcs)
    useParallel = false;
    statusMessage = ['Process-based parallel pool is unavailable in this MATLAB environment. ', ...
        'Falling back to serial mode to avoid hard crashes.'];
    return
end

try
    parpool('Processes', numProcs);
    statusMessage = 'Parallel pool started successfully.';
catch ME
    warning('runOptimisation:ParallelInitFailed', ...
        'Parallel initialisation failed (%s). Falling back to serial mode.', ME.message);
    useParallel = false;
    statusMessage = 'Parallel initialisation failed. Running optimisation simulations in serial mode.';
end

end

function isAvailable = probeProcessPool(numProcs)
isAvailable = false;

probeWorkers = min(max(1, numProcs), 2);
probeCmd = [ ...
    'matlab -batch "try; p = gcp(''''nocreate''''); ', ...
    'if isempty(p); parpool(''''Processes'''',' num2str(probeWorkers) '); end; ', ...
    'delete(gcp(''''nocreate'''')); catch; exit(1); end; exit(0);"'];

[status, ~] = system(probeCmd);
if status == 0
    isAvailable = true;
end

end
