% Scenario: Cell 17's supplied voltage equals the 4.15 V threshold.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', 'Bias', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Voltage_test_bias_V', ...
    'Bias', '[zeros(1,16), 0.19, zeros(1,79)]');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

estOut = sim(simIn);

% Read original voltages, supplied measurements and detection.
v_actual = estOut.V_cells_log.Data;
v_meas = estOut.V_cells_meas_log.Data;
ov = estOut.OV_detected_log.Data;

% Expected values for the intended scenario.
expected_actual = 3.96 * ones(11, 96);
expected_actual(:, 2) = 3.84;

expected_meas = expected_actual;
expected_meas(:, 17) = 4.15;

expected_t = (0:0.1:1)';

% Check dimensions.
assert(isequal(size(v_actual), [11 96]), ...
    'FAIL: unexpected actual-voltage dimensions.');

assert(isequal(size(v_meas), [11 96]), ...
    'FAIL: unexpected measured-voltage dimensions.');

assert(isequal(size(ov), [11 1]), ...
    'FAIL: unexpected detection dimensions.');

% Verify the original and supplied voltages.
assert(all(abs(v_actual - expected_actual) <= 1e-10, 'all'), ...
    'FAIL: unexpected plant voltages.');

assert(all(abs(v_meas - expected_meas) <= 1e-10, 'all'), ...
    'FAIL: incorrect voltage injection.');

% Exact equality is necessary to test the equality boundary.
assert(all(v_meas(:, 17) == 4.15), ...
    'FAIL: test input is not exactly at the threshold.');

% Check recording times.
recorded_times = [estOut.V_cells_log.Time, ...
                  estOut.V_cells_meas_log.Time, ...
                  estOut.OV_detected_log.Time];

expected_times = [expected_t, expected_t, expected_t];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp dimensions.');

assert(all(abs(recorded_times - expected_times) <= 1e-9, 'all'), ...
    'FAIL: incorrect recording times.');

% Detection must be boolean and true from the first sample.
assert(islogical(ov), ...
    'FAIL: detection output must be boolean.');

assert(all(ov == true, 'all'), ...
    'FAIL: overvoltage not detected at the threshold.');

disp('PASS: overvoltage detected exactly at the threshold.');