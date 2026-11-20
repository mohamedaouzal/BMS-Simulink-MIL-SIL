% Scenario: Cell 17's measured voltage is below the UV threshold
% from startup. The pack is resting, and actual voltages stay normal.
% Expected: UV detection and fault active; discharge forbidden.

init_BMS;

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

% Only Cell 17 receives a voltage offset.
simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Voltage_test_bias_V', ...
    'Bias', '[zeros(1,16), -0.92, zeros(1,79)]');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

estOut = sim(simIn);

% Independently specified expected values.
expected_t = (0:0.1:1)';

expected_actual = 3.96 * ones(11, 96);
expected_actual(:, 2) = 3.84;

expected_meas = expected_actual;
expected_meas(:, 17) = 3.04;

% Read recorded signals.
v_actual = estOut.V_cells_log.Data;
v_meas = estOut.V_cells_meas_log.Data;

detected = estOut.UV_detected_log.Data;
fault = estOut.UV_fault_log.Data;
allowed = estOut.Discharge_allowed_log.Data;

% Check voltage dimensions.
assert(isequal(size(v_actual), [11 96]), ...
    'FAIL: unexpected actual-voltage dimensions.');

assert(isequal(size(v_meas), [11 96]), ...
    'FAIL: unexpected measured-voltage dimensions.');

% Verify actual voltages and the single-cell measurement injection.
assert(all(abs(v_actual - expected_actual) <= 1e-10, 'all'), ...
    'FAIL: unexpected plant voltages.');

assert(all(abs(v_meas - expected_meas) <= 1e-10, 'all'), ...
    'FAIL: incorrect single-cell voltage injection.');

% Check boolean output dimensions and types.
assert(isequal(size(detected), [11 1]), ...
    'FAIL: unexpected UV detection dimensions.');

assert(isequal(size(fault), [11 1]), ...
    'FAIL: unexpected UV fault dimensions.');

assert(isequal(size(allowed), [11 1]), ...
    'FAIL: unexpected discharge-permission dimensions.');

assert(islogical(detected) && islogical(fault) && islogical(allowed), ...
    'FAIL: UV outputs and discharge permission must be boolean.');

% Verify every sample, including t = 0.
assert(all(detected == true, 'all'), ...
    'FAIL: startup undervoltage was not detected.');

assert(all(fault == true, 'all'), ...
    'FAIL: UV fault must be active from startup.');

assert(all(allowed == false, 'all'), ...
    'FAIL: discharge must be forbidden during UV fault.');

% Verify recording times.
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

disp('PASS: startup undervoltage activates UV fault and forbids discharge.');