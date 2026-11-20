%% SIL overcurrent: trip, memory, reset and retrip
setup_BMS;
init_BMS;

mdl = 'BMS_SIL_Protection_Test';
load_system(mdl);

assert(abs(Ts - 0.1) <= 1e-12, ...
    'This test requires Ts = 0.1 s.');

assert(I_discharge_OC_trip_A == 2 && ...
       I_charge_OC_trip_A == 1 && ...
       I_discharge_OC_release_A == 1.5 && ...
       I_charge_OC_release_A == 0.8, ...
    'Unexpected overcurrent thresholds.');

controllerBlocks = find_system(mdl, ...
    'SearchDepth', 1, ...
    'BlockType', 'ModelReference', ...
    'ModelName', 'BMS_Controller');

assert(numel(controllerBlocks) == 1, ...
    'Expected exactly one BMS_Controller Model block.');

controllerBlock = controllerBlocks{1};

%% Output and input recordings
outputNames = {
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

inputNames = {
    'I_meas_log'
    'I_requested_log'
    'Reset_OC_requested_log'
    'V_cells_meas_log'
    'T_meas_log'
};

sourceBlocks = {
    'Test_measured_current_A'
    'Test_requested_current_A'
    'Test_reset_OC'
    'Test_cell_voltages_V'
    'Test_temperature_C'
};

profileNames = {
    'SIL_measured_current_profile'
    'SIL_requested_current_profile'
    'SIL_reset_profile'
    'SIL_voltage_profile'
    'SIL_temperature_profile'
};

scenarioNames = {
    'Discharge OC memory, reset and retrip'
    'Charge OC memory, reset and retrip'
};

%% Values at whole seconds, t = 0 through 10
measuredSequences = [
     0.5  2.2  0  0  1.501  1.5  2.2  -0.801  -0.8   0.5   2.2
    -0.5 -1.2  0  0  1.501  1.5 -1.2  -0.801  -0.8  -0.5  -1.2
];

requestedSequences = [
     0.5  2.2  0   0.5  0  0   2.2  0  0   0.5   2.2
    -0.5 -1.2  0  -0.5  0  0  -1.2  0  0  -0.5  -1.2
];

% Independent expected states for each whole-second phase.
detectedPhases = logical([0 1 0 0 0 0 1 0 0 0 1]).';
faultPhases    = logical([0 1 1 1 1 0 1 1 0 0 1]).';

expectedTime = (0:Ts:10).';
nSamples = numel(expectedTime);
phaseRows = [repelem((1:10).', 10); 11];

expectedDetected = detectedPhases(phaseRows);
expectedFault = faultPhases(phaseRows);

% Reset requests are single-sample pulses.
resetRequested = false(nSamples,1);
resetRequested(round([3 4 5 7 8]/Ts) + 1) = true;

% Only requests at t = 5 and t = 8 meet every reset condition.
expectedResetValid = false(nSamples,1);
expectedResetValid(round([5 8]/Ts) + 1) = true;

expectedVoltages = 3.96 * ones(nSamples,96);
expectedTemperature = 25 * ones(nSamples,1);

timeTolerance = 1e-9;
numericTolerance = 1e-10;

resultsFolder = fullfile(fileparts(which('setup_BMS')), 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

scenarioResults = struct([]);

%% Run both scenarios
for scenarioIndex = 1:2
    fprintf('\nScenario %d/2: %s\n', ...
        scenarioIndex, scenarioNames{scenarioIndex});

    measuredPhases = measuredSequences(scenarioIndex,:).';
    requestedPhases = requestedSequences(scenarioIndex,:).';

    expectedMeasured = measuredPhases(phaseRows);
    expectedRequested = requestedPhases(phaseRows);

    profiles = {
        timeseries(expectedMeasured, expectedTime)
        timeseries(expectedRequested, expectedTime)
        timeseries(resetRequested, expectedTime)
        timeseries(expectedVoltages, expectedTime)
        timeseries(expectedTemperature, expectedTime)
    };

    % The estimator integrates the supplied measured current.
    accumulatedAh = [0; cumsum(expectedMeasured(1:end-1))] ...
        * Ts / 3600;

    expectedSOC = SOC0_est_pack(:).' ...
        - accumulatedAh / Q_est_cell_Ah;
    expectedSOC = min(max(expectedSOC, 0), 1);

    expectedOutputs = cell(15,1);
    expectedOutputs{1} = expectedSOC;

    for k = 2:15
        expectedOutputs{k} = false(nSamples,1);
    end

    expectedOutputs{4} = ~expectedFault;
    expectedOutputs{7} = ~expectedFault;
    expectedOutputs{10} = expectedResetValid;
    expectedOutputs{13} = expectedFault;

    if scenarioIndex == 1
        expectedOutputs{8} = expectedDetected;
        expectedOutputs{11} = expectedFault;
    else
        expectedOutputs{9} = expectedDetected;
        expectedOutputs{12} = expectedFault;
    end

    expectedInputs = {
        expectedMeasured
        expectedRequested
        resetRequested
        expectedVoltages
        expectedTemperature
    };

    %% Identical simulation inputs
    baseInput = Simulink.SimulationInput(mdl);

    baseInput = baseInput.setModelParameter( ...
        'SimulationMode', 'normal', ...
        'StartTime', '0', ...
        'StopTime', '10', ...
        'SolverType', 'Fixed-step', ...
        'Solver', 'FixedStepDiscrete', ...
        'FixedStep', 'Ts', ...
        'ReturnWorkspaceOutputs', 'on');

    for k = 1:numel(sourceBlocks)
        blockPath = [mdl '/' sourceBlocks{k}];

        assert(strcmp(get_param(blockPath, 'BlockType'), ...
                      'FromWorkspace'), ...
            '%s must be a From Workspace block.', sourceBlocks{k});

        baseInput = baseInput.setVariable( ...
            profileNames{k}, profiles{k});

        baseInput = baseInput.setBlockParameter( ...
            blockPath, 'VariableName', profileNames{k});

        baseInput = baseInput.setBlockParameter( ...
            blockPath, 'SampleTime', 'Ts');

        baseInput = baseInput.setBlockParameter( ...
            blockPath, 'Interpolate', 'off');
    end

    normalInput = baseInput.setBlockParameter( ...
        controllerBlock, 'SimulationMode', 'Normal');

    fprintf('Running Normal simulation...\n');
    normalOutput = sim(normalInput);

    silInput = baseInput.setBlockParameter( ...
        controllerBlock, ...
        'SimulationMode', 'Software-in-the-loop (SIL)');

    silInput = silInput.setBlockParameter( ...
        controllerBlock, 'CodeInterface', 'Model reference');

    fprintf('Running SIL simulation...\n');
    silOutput = sim(silInput);

    %% Verify expected behaviour and Normal/SIL agreement
    allNames = [outputNames; inputNames];
    allExpected = [expectedOutputs; expectedInputs];
    maxAbsoluteError = zeros(numel(allNames),1);

    for k = 1:numel(allNames)
        name = allNames{k};
        normalSignal = normalOutput.get(name);
        silSignal = silOutput.get(name);

        checkRecording(normalSignal, allExpected{k}, ...
            expectedTime, name, 'Normal', ...
            timeTolerance, numericTolerance);

        checkRecording(silSignal, allExpected{k}, ...
            expectedTime, name, 'SIL', ...
            timeTolerance, numericTolerance);

        assert(strcmp(class(normalSignal.Data), ...
                      class(silSignal.Data)), ...
            'FAIL: Normal/SIL data types differ for %s.', name);

        difference = abs(double(normalSignal.Data(:)) - ...
                         double(silSignal.Data(:)));

        maxAbsoluteError(k) = max(difference);

        if islogical(allExpected{k})
            assert(isequal(normalSignal.Data, silSignal.Data), ...
                'FAIL: Normal/SIL mismatch for %s.', name);
        else
            assert(maxAbsoluteError(k) <= numericTolerance, ...
                'FAIL: Normal/SIL mismatch for %s.', name);
        end
    end

    comparisonResults = table( ...
        string(outputNames), maxAbsoluteError(1:15), ...
        'VariableNames', {'Signal', 'MaxAbsoluteError'});

    disp(comparisonResults);

    %% Show SIL results at whole seconds
    rows = (1:10:nSamples).';

    measured = silOutput.I_meas_log.Data;
    requested = silOutput.I_requested_log.Data;
    reset = silOutput.Reset_OC_requested_log.Data;
    resetValid = silOutput.Reset_OC_valid_log.Data;
    fault = silOutput.OC_fault_log.Data;
    chargeAllowed = silOutput.Charge_allowed_log.Data;
    dischargeAllowed = silOutput.Discharge_allowed_log.Data;

    disp(table(expectedTime(rows), ...
        measured(rows), requested(rows), ...
        reset(rows), resetValid(rows), fault(rows), ...
        chargeAllowed(rows), dischargeAllowed(rows), ...
        'VariableNames', {'Time_s', 'Measured_A', 'Requested_A', ...
        'Reset_requested', 'Reset_valid', 'OC_fault', ...
        'Charge_allowed', 'Discharge_allowed'}));

    scenarioResults(scenarioIndex).Name = ...
        scenarioNames{scenarioIndex};
    scenarioResults(scenarioIndex).NormalOutput = normalOutput;
    scenarioResults(scenarioIndex).SILOutput = silOutput;
    scenarioResults(scenarioIndex).Comparison = comparisonResults;
    scenarioResults(scenarioIndex).Profiles = profiles;
    scenarioResults(scenarioIndex).Expected = allExpected;

    fprintf('PASS: %s in Normal and SIL.\n', ...
        scenarioNames{scenarioIndex});
end

%% Save evidence
save(fullfile(resultsFolder, 'sil_oc_scenarios.mat'), ...
    'scenarioResults', 'allNames', 'expectedTime', ...
    'timeTolerance', 'numericTolerance');

fprintf('\nPASS: both SIL overcurrent-protection scenarios.\n');

%% Local helper
function checkRecording(signal, expected, expectedTime, ...
    name, mode, timeTolerance, numericTolerance)

    assert(isa(signal, 'timeseries'), ...
        '%s: %s must use Timeseries logging.', mode, name);

    actualTime = signal.Time(:);

    assert(isequal(size(actualTime), size(expectedTime)), ...
        'FAIL [%s]: incorrect sample count for %s.', mode, name);

    assert(all(abs(actualTime - expectedTime) <= timeTolerance), ...
        'FAIL [%s]: incorrect timestamps for %s.', mode, name);

    actual = signal.Data;

    assert(isequal(size(actual), size(expected)), ...
        'FAIL [%s]: incorrect dimensions for %s.', mode, name);

    if islogical(expected)
        assert(islogical(actual), ...
            'FAIL [%s]: %s must be boolean.', mode, name);

        assert(isequal(actual, expected), ...
            'FAIL [%s]: incorrect values for %s.', mode, name);
    else
        assert(all(isfinite(actual(:))), ...
            'FAIL [%s]: nonfinite values in %s.', mode, name);

        assert(all(abs(double(actual(:)) - ...
                       double(expected(:))) <= numericTolerance), ...
            'FAIL [%s]: incorrect values for %s.', mode, name);
    end
end