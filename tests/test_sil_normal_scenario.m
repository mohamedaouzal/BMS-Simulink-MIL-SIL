%% Normal-discharge comparison: model versus generated C code
setup_BMS;
init_BMS;

mdl = 'BMS_SIL_Test';
load_system(mdl);

% Locate the controller without depending on its block name.
controllerBlocks = find_system(mdl, ...
    'SearchDepth', 1, ...
    'BlockType', 'ModelReference', ...
    'ModelName', 'BMS_Controller');

assert(numel(controllerBlocks) == 1, ...
    'Expected exactly one BMS_Controller Model block.');

controllerBlock = controllerBlocks{1};

%% Identical inputs and simulation settings for both runs
baseInput = Simulink.SimulationInput(mdl);

baseInput = baseInput.setModelParameter( ...
    'SimulationMode', 'normal', ...
    'StartTime', '0', ...
    'StopTime', '10', ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', 'Ts', ...
    'ReturnWorkspaceOutputs', 'on');

baseInput = baseInput.setBlockParameter( ...
    [mdl '/Test_measured_current_A'], 'Value', '0.5');

baseInput = baseInput.setBlockParameter( ...
    [mdl '/Test_requested_current_A'], 'Value', '0.5');

baseInput = baseInput.setBlockParameter( ...
    [mdl '/Test_reset_OC'], 'Value', 'false');

baseInput = baseInput.setBlockParameter( ...
    [mdl '/Test_cell_voltages_V'], ...
    'Value', '3.96*ones(96,1)');

baseInput = baseInput.setBlockParameter( ...
    [mdl '/Test_temperature_C'], 'Value', '25');

%% Run the model
normalInput = baseInput.setBlockParameter( ...
    controllerBlock, 'SimulationMode', 'Normal');

fprintf('\nRunning Normal simulation...\n');
normalOutput = sim(normalInput);

%% Run the generated C code
silInput = baseInput.setBlockParameter( ...
    controllerBlock, ...
    'SimulationMode', 'Software-in-the-loop (SIL)');

silInput = silInput.setBlockParameter( ...
    controllerBlock, 'CodeInterface', 'Model reference');

fprintf('\nRunning SIL simulation...\n');
silOutput = sim(silInput);

%% Compare all 15 controller outputs
signalNames = {
    'SOC_est_log'
    'OV_detected_log'
    'OV_fault_log'
    'Charge_allowed_log'
    'UV_detected_log'
    'UV_fault_log'
    'Discharge_allowed_log'
    'OC_discharge_detected_log'
    'OC_charge_detected_log'
    'Reset_OC_valid_log'
    'OC_discharge_fault_log'
    'OC_charge_fault_log'
    'OC_fault_log'
    'T_charge_fault_log'
    'T_discharge_fault_log'
};

expectedTime = (0:Ts:10).';
timeTolerance = 1e-9;
socTolerance = 1e-10;
maxAbsoluteError = zeros(numel(signalNames), 1);

for k = 1:numel(signalNames)
    name = signalNames{k};

    normalSignal = normalOutput.get(name);
    silSignal = silOutput.get(name);

    assert(isa(normalSignal, 'timeseries') && ...
           isa(silSignal, 'timeseries'), ...
        '%s must be logged in Timeseries format.', name);

    normalTime = normalSignal.Time(:);
    silTime = silSignal.Time(:);

    assert(numel(normalTime) == numel(expectedTime) && ...
           numel(silTime) == numel(expectedTime), ...
        'FAIL: incorrect sample count in %s.', name);

    assert(all(abs(normalTime - expectedTime) <= timeTolerance) && ...
           all(abs(silTime - expectedTime) <= timeTolerance), ...
        'FAIL: incorrect sample times in %s.', name);

    normalData = normalSignal.Data;
    silData = silSignal.Data;

    assert(isequal(size(normalData), size(silData)), ...
        'FAIL: different data dimensions in %s.', name);

    assert(strcmp(class(normalData), class(silData)), ...
        'FAIL: different data types in %s.', name);

    difference = abs(double(normalData(:)) - double(silData(:)));
    maxAbsoluteError(k) = max(difference);

    if strcmp(name, 'SOC_est_log')
        assert(all(isfinite(normalData(:))) && ...
               all(isfinite(silData(:))), ...
            'FAIL: nonfinite SOC values.');

        assert(maxAbsoluteError(k) <= socTolerance, ...
            'FAIL: SOC differs between Normal and SIL.');

        % Independently check the expected SOC trajectory.
        expectedSOC = SOC0_est_pack(:).' ...
            - expectedTime * (0.5 / (3600 * Q_est_cell_Ah));
        expectedSOC = min(max(expectedSOC, 0), 1);

        assert(isequal(size(normalData), size(expectedSOC)), ...
            'FAIL: expected SOC data arranged as time-by-cell.');

        assert(all(abs(double(normalData(:)) - ...
                       expectedSOC(:)) <= socTolerance) && ...
               all(abs(double(silData(:)) - ...
                       expectedSOC(:)) <= socTolerance), ...
            'FAIL: incorrect SOC trajectory.');
    else
        assert(islogical(normalData) && islogical(silData), ...
            'FAIL: %s must be boolean.', name);

        assert(isequal(normalData, silData), ...
            'FAIL: Normal/SIL mismatch in %s.', name);

        expectedValue = any(strcmp(name, ...
            {'Charge_allowed_log', 'Discharge_allowed_log'}));

        assert(all(normalData(:) == expectedValue), ...
            'FAIL: unexpected protection state in %s.', name);
    end

    fprintf('PASS: %s\n', name);
end

comparisonResults = table(string(signalNames), maxAbsoluteError, ...
    'VariableNames', {'Signal', 'MaxAbsoluteError'});

disp(comparisonResults);

%% Save evidence for the final delivery
resultsFolder = fullfile(fileparts(which('setup_BMS')), 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

save(fullfile(resultsFolder, 'sil_normal_scenario.mat'), ...
    'normalOutput', 'silOutput', 'comparisonResults', ...
    'timeTolerance', 'socTolerance');

fprintf('\nPASS: Normal and SIL agree for normal discharge.\n');