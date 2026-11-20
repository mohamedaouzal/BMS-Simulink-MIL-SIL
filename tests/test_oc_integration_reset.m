%% Integrated OC protection: reset, restart and retrip
init_BMS;

mdl = 'BMS_OC_Integration_Reset_Test';
load_system(mdl);

assert(abs(Ts - 0.1) < 1e-12, ...
    'This test expects Ts = 0.1 s.');

thresholds = [ ...
    I_discharge_OC_trip_A, I_discharge_OC_release_A, ...
    I_charge_OC_trip_A, I_charge_OC_release_A];

assert(all(abs(thresholds - [2, 1.5, 1, 0.8]) < 1e-12), ...
    'Unexpected OC thresholds.');

scenarioNames = { ...
    'Discharge reset and restart'; ...
    'Charge reset and restart'};

normalCurrents = [0.5; -0.5];
tripCurrents = [2.2; -1.2];

t = (0:70)' * Ts;
n = numel(t);

% Convert an exact event time into its sample index.
at = @(seconds) round(seconds / Ts) + 1;

soc0 = SOC0_pack(:).';
socEst0 = SOC0_est_pack(:).';

assert(numel(soc0) == 96 && numel(socEst0) == 96, ...
    'Expected 96 initial SOC values.');

for scenario = 1:2

    fprintf('\nScenario %d/2: %s\n', ...
        scenario, scenarioNames{scenario});

    normalI = normalCurrents(scenario);
    tripI = tripCurrents(scenario);

    %% Requested-current profile
    requested = zeros(n, 1);

    requested(at(0):at(1)-1) = normalI;
    requested(at(1):at(2)-1) = tripI;
    requested(at(2):at(3)-1) = normalI;
    % From 3 s to just before 5 s: request remains zero.
    requested(at(5):at(6)-1) = normalI;
    requested(at(6):end) = tripI;

    % One-sample reset pulses:
    % 2 s: invalid because requested current is nonzero.
    % 4 s: valid because requested and measured currents are zero.
    resetRequested = false(n, 1);
    resetRequested([at(2), at(4)]) = true;

    OC_requested_current_profile = timeseries(requested, t);
    OC_reset_profile = timeseries(resetRequested, t);

    %% Independent expected command
    expectedCommand = zeros(n, 1);

    expectedCommand(at(0):at(1)-1) = normalI;
    expectedCommand(at(1)) = tripI;

    expectedCommand(at(5):at(6)-1) = normalI;
    expectedCommand(at(6)) = tripI;

    % One-sample actuator delay, initially zero.
    expectedApplied = [0; expectedCommand(1:end-1)];

    %% Independent expected protection states
    expectedFault = false(n, 1);
    expectedFault(at(1.1):at(4)-1) = true;
    expectedFault(at(6.1):end) = true;

    expectedDetected = false(n, 1);
    expectedDetected([at(1.1), at(6.1)]) = true;

    expectedResetValid = false(n, 1);
    expectedResetValid(at(4)) = true;

    expectedAllowed = ~expectedFault;
    allFalse = false(n, 1);

    if scenario == 1
        dischargeFault = expectedFault;
        chargeFault = allFalse;
        dischargeDetected = expectedDetected;
        chargeDetected = allFalse;
    else
        dischargeFault = allFalse;
        chargeFault = expectedFault;
        dischargeDetected = allFalse;
        chargeDetected = expectedDetected;
    end

    %% Expected SOC from the preceding applied-current samples
    cumulativeAs = [0; cumsum(expectedApplied(1:end-1))] * Ts;

    expectedSOC = repmat(soc0, n, 1) ...
        - cumulativeAs / (3600 * Q_cell_Ah);

    expectedSOCEst = repmat(socEst0, n, 1) ...
        - cumulativeAs / (3600 * Q_est_cell_Ah);

    expectedSOC = min(max(expectedSOC, 0), 1);
    expectedSOCEst = min(max(expectedSOCEst, 0), 1);

    %% Configure simulation
    simIn = Simulink.SimulationInput(mdl);

    simIn = setVariable(simIn, ...
        'OC_requested_current_profile', ...
        OC_requested_current_profile);

    simIn = setVariable(simIn, ...
        'OC_reset_profile', OC_reset_profile);

    sourceNames = {'Test_current_A'; 'Test_reset_OC'};
    profileNames = { ...
        'OC_requested_current_profile'; ...
        'OC_reset_profile'};

    for b = 1:numel(sourceNames)
        blockPath = [mdl '/' sourceNames{b}];

        assert(strcmp(get_param(blockPath, 'BlockType'), ...
            'FromWorkspace'), ...
            '%s must be a From Workspace block.', blockPath);

        simIn = setBlockParameter(simIn, ...
            blockPath, 'VariableName', profileNames{b});

        simIn = setBlockParameter(simIn, ...
            blockPath, 'SampleTime', num2str(Ts, 17));

        simIn = setBlockParameter(simIn, ...
            blockPath, 'Interpolate', 'off');
    end

    simIn = setBlockParameter(simIn, ...
        [mdl '/Current_sensor_bias_A'], 'Bias', '0');

    simIn = setBlockParameter(simIn, ...
        [mdl '/Voltage_test_bias_V'], 'Bias', '0');

    simIn = setBlockParameter(simIn, ...
        [mdl '/Current_response_delay'], 'InitialCondition', '0');

    simIn = setBlockParameter(simIn, ...
        [mdl '/Current_response_delay'], ...
        'SampleTime', num2str(Ts, 17));

    simIn = setModelParameter(simIn, ...
        'SolverType', 'Fixed-step', ...
        'Solver', 'FixedStepDiscrete', ...
        'FixedStep', num2str(Ts, 17), ...
        'StartTime', '0', ...
        'StopTime', '7', ...
        'ReturnWorkspaceOutputs', 'on');

    %% Run simulation
    ocOut = sim(simIn);

    %% Check command, applied current and measured current
    command = checkResetLog(ocOut, 'Current_command_log', ...
        t, expectedCommand, 1e-10);

    applied = checkResetLog(ocOut, 'I_applied_log', ...
        t, expectedApplied, 1e-10);

    checkResetLog(ocOut, 'I_meas_log', ...
        t, expectedApplied, 1e-10);

    %% Check fault memory, reset and permissions
    logNames = { ...
        'Current_allowed_log'; ...
        'Charge_allowed_log'; ...
        'Discharge_allowed_log'; ...
        'OC_discharge_detected_log'; ...
        'OC_charge_detected_log'; ...
        'OC_discharge_fault_log'; ...
        'OC_charge_fault_log'; ...
        'OC_fault_log'; ...
        'Reset_OC_valid_log'; ...
        'OV_detected_log'; ...
        'OV_fault_log'; ...
        'UV_detected_log'; ...
        'UV_fault_log'};

    expectedData = { ...
        expectedAllowed; ...
        expectedAllowed; ...
        expectedAllowed; ...
        dischargeDetected; ...
        chargeDetected; ...
        dischargeFault; ...
        chargeFault; ...
        expectedFault; ...
        expectedResetValid; ...
        allFalse; ...
        allFalse; ...
        allFalse; ...
        allFalse};

    for k = 1:numel(logNames)
        checkResetLog(ocOut, logNames{k}, ...
            t, expectedData{k}, 0);
    end

    %% Check SOC throughout the simulation
    soc = checkResetLog(ocOut, 'SOC_cells_log', ...
        t, expectedSOC, 1e-10);

    checkResetLog(ocOut, 'SOC_est_log', ...
        t, expectedSOCEst, 1e-10);

    % SOC must remain constant during both stopped intervals.
    firstHold = soc(at(1.2):at(5.1), :);
    secondHold = soc(at(6.2):end, :);

    assert(all(abs(firstHold - firstHold(1,:)) <= 1e-10, 'all'), ...
        'FAIL: SOC changes during the first stopped interval.');

    assert(all(abs(secondHold - secondHold(1,:)) <= 1e-10, 'all'), ...
        'FAIL: SOC changes after the second current interruption.');

    %% Display recorded results at the important event times
    faultLog = ocOut.get('OC_fault_log');
    validLog = ocOut.get('Reset_OC_valid_log');

    eventTimes = [ ...
        0; 0.1; 1; 1.1; 1.2; 2; 3; 4; ...
        5; 5.1; 6; 6.1; 6.2; 7];

    idx = at(eventTimes);

    results = table( ...
        t(idx), ...
        requested(idx), ...
        resetRequested(idx), ...
        validLog.Data(idx), ...
        command(idx), ...
        applied(idx), ...
        faultLog.Data(idx), ...
        soc(idx,1), ...
        'VariableNames', { ...
        'Time_s', 'Requested_A', 'Reset_requested', ...
        'Reset_valid', 'Command_A', 'Applied_A', ...
        'OC_fault', 'Cell1_SOC'});

    disp(results);

    fprintf('PASS: %s.\n', scenarioNames{scenario});
end

fprintf('\nPASS: both integrated OC reset, restart and retrip scenarios.\n');

%% Local verification function
function actual = checkResetLog(simOut, name, expectedTime, expected, tolerance)

    signal = simOut.get(name);

    assert(isa(signal, 'timeseries'), ...
        '%s must use Timeseries save format.', name);

    actualTime = signal.Time(:);
    actual = signal.Data;

    assert(isequal(size(actualTime), size(expectedTime)), ...
        'FAIL: incorrect time dimensions in %s.', name);

    assert(all(abs(actualTime - expectedTime) <= 1e-9), ...
        'FAIL: incorrect sample times in %s.', name);

    assert(isequal(size(actual), size(expected)), ...
        'FAIL: incorrect data dimensions in %s.', name);

    if islogical(expected)
        assert(islogical(actual), ...
            'FAIL: %s must contain boolean data.', name);

        assert(isequal(actual, expected), ...
            'FAIL: incorrect values in %s.', name);
    else
        assert(all(abs(actual - expected) <= tolerance, 'all'), ...
            'FAIL: incorrect values in %s.', name);
    end
end