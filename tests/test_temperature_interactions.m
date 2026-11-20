%% Temperature recovery must not override OV, UV or OC protection
init_BMS;

mdl = 'BMS_Temperature_Protection_Test';
load_system(mdl);

assert(abs(Ts - 0.1) < 1e-12, ...
    'This test expects Ts = 0.1 s.');

%% Check the thresholds used by these scenarios
actualThresholds = [ ...
    T_charge_low_trip_C, T_charge_low_release_C, ...
    T_charge_high_trip_C, T_charge_high_release_C, ...
    T_discharge_low_trip_C, T_discharge_low_release_C, ...
    T_discharge_high_trip_C, T_discharge_high_release_C, ...
    V_cell_OV_trip_V, V_cell_OV_release_V, ...
    V_cell_UV_trip_V, V_cell_UV_release_V, ...
    I_discharge_OC_trip_A, I_charge_OC_trip_A];

expectedThresholds = [ ...
    0, 5, 45, 40, -20, -15, 60, 55, ...
    4.15, 4.10, 3.05, 3.10, 2, 1];

assert(all(abs(actualThresholds - expectedThresholds) < 1e-12), ...
    'Unexpected protection thresholds.');

%% Four independent scenarios
scenarioNames = { ...
    'Temperature recovery with OV'; ...
    'Temperature recovery with UV'; ...
    'Temperature recovery with discharge OC'; ...
    'Temperature recovery with charge OC'};

measuredCurrents = [0; 0; 2.2; -1.2];

hasOV = logical([1; 0; 0; 0]);
hasUV = logical([0; 1; 0; 0]);
hasDischargeOC = logical([0; 0; 1; 0]);
hasChargeOC = logical([0; 0; 0; 1]);

chargeAfterRecovery = logical([0; 1; 0; 0]);
dischargeAfterRecovery = logical([1; 0; 0; 0]);

%% Temperature profile: hot initially, normal from 1 s
t = (0:20)' * Ts;
n = numel(t);
recoveryIndex = round(1 / Ts) + 1;

temperatureValues = 60 * ones(n, 1);
temperatureValues(recoveryIndex:end) = 25;

expectedTemperatureFault = true(n, 1);
expectedTemperatureFault(recoveryIndex:end) = false;

Temperature_profile = timeseries(temperatureValues, t);

temperatureBlock = [mdl '/Test_temperature_C'];

assert(strcmp(get_param(temperatureBlock, 'BlockType'), ...
    'FromWorkspace'), ...
    'Test_temperature_C must be a From Workspace block.');

recordedOV = false(4, 1);
recordedUV = false(4, 1);
recordedOC = false(4, 1);
recordedChargeTemp = false(4, 1);
recordedDischargeTemp = false(4, 1);
recordedChargeAllowed = false(4, 1);
recordedDischargeAllowed = false(4, 1);

for scenario = 1:4

    fprintf('\nScenario %d/4: %s\n', ...
        scenario, scenarioNames{scenario});

    %% Impose the remaining voltage or current fault
    cellVoltages = 3.96 * ones(96, 1);

    if hasOV(scenario)
        cellVoltages(17) = 4.16;
    end

    if hasUV(scenario)
        cellVoltages(18) = 3.04;
    end

    current = measuredCurrents(scenario);

    %% Explicit expected permissions
    expectedChargeAllowed = false(n, 1);
    expectedDischargeAllowed = false(n, 1);

    expectedChargeAllowed(recoveryIndex:end) = ...
        chargeAfterRecovery(scenario);

    expectedDischargeAllowed(recoveryIndex:end) = ...
        dischargeAfterRecovery(scenario);

    expectedOV = repmat(hasOV(scenario), n, 1);
    expectedUV = repmat(hasUV(scenario), n, 1);
    expectedDischargeOC = repmat(hasDischargeOC(scenario), n, 1);
    expectedChargeOC = repmat(hasChargeOC(scenario), n, 1);
    expectedOC = expectedDischargeOC | expectedChargeOC;

    allFalse = false(n, 1);

    %% Configure a fresh simulation
    simIn = Simulink.SimulationInput(mdl);

    simIn = setVariable(simIn, ...
        'Temperature_profile', Temperature_profile);

    simIn = setVariable(simIn, ...
        'Temperature_test_cell_voltages', cellVoltages);

    simIn = setBlockParameter(simIn, ...
        temperatureBlock, 'VariableName', 'Temperature_profile');

    simIn = setBlockParameter(simIn, ...
        temperatureBlock, 'SampleTime', num2str(Ts, 17));

    simIn = setBlockParameter(simIn, ...
        temperatureBlock, 'Interpolate', 'off');

    simIn = setBlockParameter(simIn, ...
        [mdl '/Test_measured_current_A'], ...
        'Value', num2str(current, 17));

    simIn = setBlockParameter(simIn, ...
        [mdl '/Test_requested_current_A'], ...
        'Value', num2str(current, 17));

    simIn = setBlockParameter(simIn, ...
        [mdl '/Test_cell_voltages_V'], ...
        'Value', 'Temperature_test_cell_voltages');

    simIn = setBlockParameter(simIn, ...
        [mdl '/Test_reset_OC'], 'Value', 'false');

    simIn = setBlockParameter(simIn, ...
        [mdl '/Test_reset_OC'], 'OutDataTypeStr', 'boolean');

    simIn = setModelParameter(simIn, ...
        'SolverType', 'Fixed-step', ...
        'Solver', 'FixedStepDiscrete', ...
        'FixedStep', num2str(Ts, 17), ...
        'StartTime', '0', ...
        'StopTime', '2', ...
        'ReturnWorkspaceOutputs', 'on');

    temperatureOut = sim(simIn);

    %% Check every sample, including startup and recovery
    checks = { ...
        'T_meas_log',                 temperatureValues; ...
        'I_meas_log',                 repmat(current,n,1); ...
        'I_requested_log',            repmat(current,n,1); ...
        'V_cells_meas_log',           repmat(cellVoltages.',n,1); ...
        'Reset_OC_requested_log',     allFalse; ...
        'Reset_OC_valid_log',         allFalse; ...
        'T_charge_fault_log',         expectedTemperatureFault; ...
        'T_discharge_fault_log',      expectedTemperatureFault; ...
        'Charge_allowed_log',         expectedChargeAllowed; ...
        'Discharge_allowed_log',      expectedDischargeAllowed; ...
        'OV_detected_log',            expectedOV; ...
        'OV_fault_log',               expectedOV; ...
        'UV_detected_log',            expectedUV; ...
        'UV_fault_log',               expectedUV; ...
        'OC_discharge_detected_log',  expectedDischargeOC; ...
        'OC_charge_detected_log',     expectedChargeOC; ...
        'OC_discharge_fault_log',     expectedDischargeOC; ...
        'OC_charge_fault_log',        expectedChargeOC; ...
        'OC_fault_log',               expectedOC};

    for k = 1:size(checks, 1)
        name = checks{k, 1};
        expected = checks{k, 2};

        signal = temperatureOut.get(name);

        assert(isa(signal, 'timeseries'), ...
            '%s must use Timeseries save format.', name);

        actualTime = signal.Time(:);
        actual = signal.Data;

        assert(isequal(size(actualTime), size(t)), ...
            'FAIL: incorrect time dimensions in %s.', name);

        assert(all(abs(actualTime - t) <= 1e-9), ...
            'FAIL: incorrect sample times in %s.', name);

        assert(isequal(size(actual), size(expected)), ...
            'FAIL: incorrect data dimensions in %s.', name);

        if islogical(expected)
            assert(islogical(actual), ...
                'FAIL: %s must contain boolean data.', name);

            assert(isequal(actual, expected), ...
                'FAIL: incorrect values in %s.', name);
        else
            assert(all(abs(actual - expected) <= 1e-10, 'all'), ...
                'FAIL: incorrect values in %s.', name);
        end
    end

    %% Record actual final states after temperature recovery
    signal = temperatureOut.get('OV_fault_log');
    recordedOV(scenario) = signal.Data(end);

    signal = temperatureOut.get('UV_fault_log');
    recordedUV(scenario) = signal.Data(end);

    signal = temperatureOut.get('OC_fault_log');
    recordedOC(scenario) = signal.Data(end);

    signal = temperatureOut.get('T_charge_fault_log');
    recordedChargeTemp(scenario) = signal.Data(end);

    signal = temperatureOut.get('T_discharge_fault_log');
    recordedDischargeTemp(scenario) = signal.Data(end);

    signal = temperatureOut.get('Charge_allowed_log');
    recordedChargeAllowed(scenario) = signal.Data(end);

    signal = temperatureOut.get('Discharge_allowed_log');
    recordedDischargeAllowed(scenario) = signal.Data(end);

    fprintf('PASS: %s.\n', scenarioNames{scenario});
end

%% Summary of recorded values at t = 2 s
results = table( ...
    scenarioNames, ...
    recordedChargeTemp, recordedDischargeTemp, ...
    recordedOV, recordedUV, recordedOC, ...
    recordedChargeAllowed, recordedDischargeAllowed, ...
    'VariableNames', { ...
    'Scenario', 'T_charge_fault', 'T_discharge_fault', ...
    'OV_fault', 'UV_fault', 'OC_fault', ...
    'Charge_allowed', 'Discharge_allowed'});

disp('Recorded states after temperature recovery:');
disp(results);

fprintf('\nPASS: all four temperature interaction scenarios.\n');