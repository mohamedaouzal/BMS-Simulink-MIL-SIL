% Scenario: Cell 17 is above the trip threshold from startup.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

% Battery at rest; no current sensor error.
simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', 'Bias', '0');

% Add 0.20 V only to Cell 17's supplied measurement.
simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Voltage_test_bias_V', ...
    'Bias', '[zeros(1,16), 0.20, zeros(1,79)]');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

estOut = sim(simIn);

% Read actual voltages, supplied measurements and fault output.
v_actual = estOut.V_cells_log.Data;
v_meas = estOut.V_cells_meas_log.Data;
fault = estOut.OV_fault_log.Data;

% Independent expected values.
expected_t = (0:0.1:1)';

expected_actual = 3.96 * ones(11, 96);
expected_actual(:, 2) = 3.84;

expected_meas = expected_actual;
expected_meas(:, 17) = 4.16;

% Check dimensions before comparing values.
assert(isequal(size(v_actual), [11 96]), ...
    'FAIL: unexpected actual-voltage dimensions.');

assert(isequal(size(v_meas), [11 96]), ...
    'FAIL: unexpected measured-voltage dimensions.');

assert(isequal(size(fault), [11 1]), ...
    'FAIL: unexpected fault dimensions.');

% Verify that the plant is unchanged and the injection is correct.
assert(all(abs(v_actual - expected_actual) <= 1e-10, 'all'), ...
    'FAIL: unexpected plant voltages.');

assert(all(abs(v_meas - expected_meas) <= 1e-10, 'all'), ...
    'FAIL: incorrect startup voltage injection.');

% Fault must be boolean and active from the first sample.
assert(islogical(fault), ...
    'FAIL: OV_fault must be boolean.');

assert(all(fault == true, 'all'), ...
    'FAIL: OV fault must be active from startup.');

% Verify all recording times.
recorded_times = [estOut.V_cells_log.Time, ...
                  estOut.V_cells_meas_log.Time, ...
                  estOut.OV_fault_log.Time];

expected_times = [expected_t, expected_t, expected_t];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp dimensions.');

assert(all(abs(recorded_times - expected_times) <= 1e-9, 'all'), ...
    'FAIL: incorrect recording times.');

disp('PASS: OV fault is active from startup for an overvoltage.');
