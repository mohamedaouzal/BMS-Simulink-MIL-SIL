%% SIL voltage protection: OV and UV hysteresis
setup_BMS;
init_BMS;

mdl = 'BMS_SIL_Protection_Test';
load_system(mdl);

assert(abs(Ts - 0.1) <= 1e-12, ...
    'This test requires Ts = 0.1 s.');

assert(V_cell_OV_trip_V == 4.15 && ...
       V_cell_OV_release_V == 4.10 && ...
       V_cell_UV_trip_V == 3.05 && ...
       V_cell_UV_release_V == 3.10, ...
    'Unexpected voltage-protection thresholds.');

controllerBlocks = find_system(mdl, ...
    'SearchDepth', 1, ...
    'BlockType', 'ModelReference', ...
    'ModelName', 'BMS_Controller');

assert(numel(controllerBlocks) == 1, ...
    'Expected exactly one BMS_Controller Model block.');

controllerBlock = controllerBlocks{1};

%% Output names, in controller port order
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

scenarioNames = {'OV hysteresis', 'UV hysteresis'};

voltageSequences = [
    4.12 4.16 4.12 4.10 4.12 4.15 4.15
    3.08 3.04 3.08 3.10 3.08 3.05 3.05
];

%% Independent expected results at all 61 samples
expectedTime = (0:Ts:6).';
nSamples = numel(expectedTime);

% Each whole-second value holds for ten samples.
phaseRows = [repelem((1:6).', 10); 7];

expectedDetected = [
    false(10,1)
    true(10,1)
    false(30,1)
    true(11,1)
];

expectedFault = [
    false(10,1)
    true(20,1)
    false(20,1)
    true(11,1)
];

expectedSOC = repmat(SOC0_est_pack(:).', nSamples, 1);

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

    profileTime = (0:6).';
    profileVoltages = 3.96 * ones(7,96);
    profileVoltages(:,17) = ...
        voltageSequences(scenarioIndex,:).';

    profiles = {
        timeseries(zeros(7,1), profileTime)
        timeseries(zeros(7,1), profileTime)
        timeseries(false(7,1), profileTime)
        timeseries(profileVoltages, profileTime)
        timeseries(25*ones(7,1), profileTime)
    };

    expectedVoltages = profileVoltages(phaseRows,:);

    % Start with all Boolean outputs false.
    expectedOutputs = cell(15,1);
    expectedOutputs{1} = expectedSOC;

    for k = 2:15
        expectedOutputs{k} = false(nSamples,1);
    end

    expectedOutputs{4} = true(nSamples,1);
    expectedOutputs{7} = true(nSamples,1);

    if scenarioIndex == 1
        expectedOutputs{2} = expectedDetected;
        expectedOutputs{3} = expectedFault;
        expectedOutputs{4} = ~expectedFault;
    else
        expectedOutputs{5} = expectedDetected;
        expectedOutputs{6} = expectedFault;
        expectedOutputs{7} = ~expectedFault;
    end

    expectedInputs = {
        zeros(nSamples,1)
        zeros(nSamples,1)
        false(nSamples,1)
        expectedVoltages
        25*ones(nSamples,1)
    };

    %% Configure identical inputs for Normal and SIL
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

    %% Check every output and verify the supplied inputs
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

    %% Display the SIL results at each whole second
    rows = (1:10:nSamples).';
    measuredVoltages = silOutput.V_cells_meas_log.Data;
    chargeAllowed = silOutput.Charge_allowed_log.Data;
    dischargeAllowed = silOutput.Discharge_allowed_log.Data;

    if scenarioIndex == 1
        detected = silOutput.OV_detected_log.Data;
        fault = silOutput.OV_fault_log.Data;
    else
        detected = silOutput.UV_detected_log.Data;
        fault = silOutput.UV_fault_log.Data;
    end

    disp(table(expectedTime(rows), measuredVoltages(rows,17), ...
        detected(rows), fault(rows), ...
        chargeAllowed(rows), dischargeAllowed(rows), ...
        'VariableNames', {'Time_s', 'Cell17_V', ...
        'Detected', 'Fault', 'Charge_allowed', 'Discharge_allowed'}));

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

%% Save comparison evidence
save(fullfile(resultsFolder, 'sil_voltage_scenarios.mat'), ...
    'scenarioResults', 'allNames', 'expectedTime', ...
    'timeTolerance', 'numericTolerance');

fprintf('\nPASS: both SIL voltage-protection scenarios.\n');

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