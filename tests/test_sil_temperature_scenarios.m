%% SIL temperature protection: four hysteresis scenarios
setup_BMS;
init_BMS;

mdl = 'BMS_SIL_Protection_Test';
load_system(mdl);

assert(abs(Ts - 0.1) <= 1e-12, ...
    'This test requires Ts = 0.1 s.');

actualThresholds = [
    T_charge_low_trip_C, T_charge_low_release_C, ...
    T_charge_high_trip_C, T_charge_high_release_C, ...
    T_discharge_low_trip_C, T_discharge_low_release_C, ...
    T_discharge_high_trip_C, T_discharge_high_release_C
];

assert(isequal(actualThresholds, [0 5 45 40 -20 -15 60 55]), ...
    'Unexpected temperature-protection thresholds.');

controllerBlocks = find_system(mdl, ...
    'SearchDepth', 1, ...
    'BlockType', 'ModelReference', ...
    'ModelName', 'BMS_Controller');

assert(numel(controllerBlocks) == 1, ...
    'Expected exactly one BMS_Controller Model block.');

controllerBlock = controllerBlocks{1};

%% Recordings and source blocks
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
    'Charge cold hysteresis'
    'Charge hot hysteresis'
    'Discharge cold hysteresis'
    'Discharge hot hysteresis'
};

temperatureSequences = [
    25    0    2    5    2    0   25
    25   45   42   40   42   45   25
    25  -20  -17  -15  -17  -20   25
    25   60   57   55   57   60   25
];

% Independent expected fault states at whole seconds.
chargeFaultPhases = logical([
    0 1 1 0 0 1 0
    0 1 1 0 0 1 0
    0 1 1 1 1 1 0
    0 1 1 1 1 1 0
]);

dischargeFaultPhases = logical([
    0 0 0 0 0 0 0
    0 0 0 0 0 0 0
    0 1 1 0 0 1 0
    0 1 1 0 0 1 0
]);

expectedTime = (0:Ts:6).';
nSamples = numel(expectedTime);
phaseRows = [repelem((1:6).', 10); 7];

expectedCurrent = zeros(nSamples,1);
expectedReset = false(nSamples,1);
expectedVoltages = 3.96 * ones(nSamples,96);
expectedSOC = repmat(SOC0_est_pack(:).', nSamples,1);

timeTolerance = 1e-9;
numericTolerance = 1e-10;

resultsFolder = fullfile(fileparts(which('setup_BMS')), 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

scenarioResults = struct([]);

%% Run all four scenarios
for scenarioIndex = 1:4
    fprintf('\nScenario %d/4: %s\n', ...
        scenarioIndex, scenarioNames{scenarioIndex});

    temperaturePhases = temperatureSequences(scenarioIndex,:).';
    chargePhases = chargeFaultPhases(scenarioIndex,:).';
    dischargePhases = dischargeFaultPhases(scenarioIndex,:).';

    expectedTemperature = temperaturePhases(phaseRows);
    expectedChargeFault = chargePhases(phaseRows);
    expectedDischargeFault = dischargePhases(phaseRows);

    profiles = {
        timeseries(expectedCurrent, expectedTime)
        timeseries(expectedCurrent, expectedTime)
        timeseries(expectedReset, expectedTime)
        timeseries(expectedVoltages, expectedTime)
        timeseries(expectedTemperature, expectedTime)
    };

    expectedOutputs = cell(15,1);
    expectedOutputs{1} = expectedSOC;

    for k = 2:15
        expectedOutputs{k} = false(nSamples,1);
    end

    expectedOutputs{4} = ~expectedChargeFault;
    expectedOutputs{7} = ~expectedDischargeFault;
    expectedOutputs{14} = expectedChargeFault;
    expectedOutputs{15} = expectedDischargeFault;

    expectedInputs = {
        expectedCurrent
        expectedCurrent
        expectedReset
        expectedVoltages
        expectedTemperature
    };

    %% Configure identical inputs
    baseInput = Simulink.SimulationInput(mdl);

    baseInput = baseInput.setModelParameter( ...
        'SimulationMode', 'normal', ...
        'StartTime', '0', ...
        'StopTime', '6', ...
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

    %% Check expected behaviour and equivalence
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

    temperature = silOutput.T_meas_log.Data;
    chargeFault = silOutput.T_charge_fault_log.Data;
    dischargeFault = silOutput.T_discharge_fault_log.Data;
    chargeAllowed = silOutput.Charge_allowed_log.Data;
    dischargeAllowed = silOutput.Discharge_allowed_log.Data;

    disp(table(expectedTime(rows), temperature(rows), ...
        chargeFault(rows), dischargeFault(rows), ...
        chargeAllowed(rows), dischargeAllowed(rows), ...
        'VariableNames', {'Time_s', 'Temperature_C', ...
        'T_charge_fault', 'T_discharge_fault', ...
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
save(fullfile(resultsFolder, 'sil_temperature_scenarios.mat'), ...
    'scenarioResults', 'allNames', 'expectedTime', ...
    'timeTolerance', 'numericTolerance');

fprintf('\nPASS: all four SIL temperature-protection scenarios.\n');

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