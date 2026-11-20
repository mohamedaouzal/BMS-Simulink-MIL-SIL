% Scenario: normal cell voltages must not trigger undervoltage.
% Current: 0 A. No current or voltage sensor bias.
% Expected: UV_detected = false, UV_fault = false,
%           Discharge_allowed = true, including at t = 0.

init_BMS;

% Confirm the intended test configuration.
assert(abs(Ts - 0.1) <= 1e-12, ...
    'FAIL: this test expects Ts = 0.1 s.');

assert(abs(V_cell_UV_trip_V - 3.05) <= 1e-12, ...
    'FAIL: unexpected UV trip threshold.');

assert(abs(V_cell_UV_release_V - 3.10) <= 1e-12, ...
    'FAIL: unexpected UV release threshold.');

% Configure the simulation.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', ...
    'Value', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', ...
    'Bias', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Voltage_test_bias_V', ...
    'Bias', '0');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

estOut = sim(simIn);

% Expected sample times and cell voltages.
expected_t = (0:0.1:1)';

expected_v = 3.96 * ones(11, 96);
expected_v(:, 2) = 3.84;

% Read the recorded signals.
v_actual = estOut.V_cells_log.Data;
v_meas = estOut.V_cells_meas_log.Data;

detected = estOut.UV_detected_log.Data;
fault = estOut.UV_fault_log.Data;
allowed = estOut.Discharge_allowed_log.Data;

% Check voltage dimensions before comparing values.
assert(isequal(size(v_actual), [11 96]), ...
    'FAIL: unexpected actual-voltage dimensions.');

assert(isequal(size(v_meas), [11 96]), ...
    'FAIL: unexpected measured-voltage dimensions.');

% Verify that the intended normal voltages were supplied.
assert(all(abs(v_actual - expected_v) <= 1e-10, 'all'), ...
    'FAIL: unexpected plant voltages.');

assert(all(abs(v_meas - expected_v) <= 1e-10, 'all'), ...
    'FAIL: unexpected measured voltages.');

% Check dimensions and types of the three boolean outputs.
assert(isequal(size(detected), [11 1]), ...
    'FAIL: unexpected UV detection dimensions.');

assert(isequal(size(fault), [11 1]), ...
    'FAIL: unexpected UV fault dimensions.');

assert(isequal(size(allowed), [11 1]), ...
    'FAIL: unexpected discharge-permission dimensions.');

assert(islogical(detected) && islogical(fault) && islogical(allowed), ...
    'FAIL: UV outputs and discharge permission must be boolean.');

% Check every sample, including startup.
assert(all(detected == false, 'all'), ...
    'FAIL: undervoltage detected under normal voltages.');

assert(all(fault == false, 'all'), ...
    'FAIL: UV fault active under normal voltages.');

assert(all(allowed == true, 'all'), ...
    'FAIL: discharge forbidden under normal voltages.');

% Verify each recording's timestamps independently.
logs_to_check = { ...
    estOut.V_cells_log, ...
    estOut.V_cells_meas_log, ...
    estOut.UV_detected_log, ...
    estOut.UV_fault_log, ...
    estOut.Discharge_allowed_log};

for k = 1:numel(logs_to_check)
    recorded_t = logs_to_check{k}.Time;

    assert(isequal(size(recorded_t), size(expected_t)), ...
        'FAIL: unexpected timestamp dimensions.');

    assert(all(abs(recorded_t - expected_t) <= 1e-9, 'all'), ...
        'FAIL: incorrect recording times.');
end

disp('PASS: normal voltages do not trigger UV and discharge is allowed.');