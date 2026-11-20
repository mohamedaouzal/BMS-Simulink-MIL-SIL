% Scenario: only Cell 17's supplied voltage exceeds the threshold.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', 'Bias', '0');

% Cells 1-16: zero offset; Cell 17: +0.20 V; Cells 18-96: zero.
simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Voltage_test_bias_V', ...
    'Bias', '[zeros(1,16), 0.20, zeros(1,79)]');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

estOut = sim(simIn);

% Read original voltages, supplied measurements and detection.
v_actual = estOut.V_cells_log.Data;
v_meas = estOut.V_cells_meas_log.Data;
ov = estOut.OV_detected_log.Data;

% Independently specified expected values.
expected_actual = 3.96 * ones(11, 96);
expected_actual(:, 2) = 3.84;

expected_meas = expected_actual;
expected_meas(:, 17) = 4.16;

expected_t = (0:0.1:1)';

% Check dimensions.
assert(isequal(size(v_actual), [11 96]), ...
    'FAIL: unexpected actual-voltage dimensions.');

assert(isequal(size(v_meas), [11 96]), ...
    'FAIL: unexpected measured-voltage dimensions.');

assert(isequal(size(ov), [11 1]), ...
    'FAIL: unexpected detection dimensions.');

% Verify the plant remains unchanged and only Cell 17 is altered.
assert(all(abs(v_actual - expected_actual) <= 1e-10, 'all'), ...
    'FAIL: unexpected plant voltages.');

assert(all(abs(v_meas - expected_meas) <= 1e-10, 'all'), ...
    'FAIL: incorrect single-cell voltage injection.');

% Verify all three recordings use the expected timestamps.
recorded_times = [estOut.V_cells_log.Time, ...
                  estOut.V_cells_meas_log.Time, ...
                  estOut.OV_detected_log.Time];

expected_times = [expected_t, expected_t, expected_t];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp dimensions.');

assert(all(abs(recorded_times - expected_times) <= 1e-9, 'all'), ...
    'FAIL: incorrect recording times.');

% Detection must be boolean and true at every sample, including t = 0.
assert(islogical(ov), ...
    'FAIL: detection output must be boolean.');

assert(all(ov == true, 'all'), ...
    'FAIL: single-cell overvoltage was not detected immediately.');

disp('PASS: single-cell overvoltage detected.');