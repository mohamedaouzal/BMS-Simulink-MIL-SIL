% Scenario: normal voltages at rest for 1 second.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', 'Bias', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Voltage_test_bias_V', 'Bias', '0');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

estOut = sim(simIn);

% Read the voltages supplied to the controller and its fault output.
v_meas = estOut.V_cells_meas_log.Data;
fault = estOut.OV_fault_log.Data;

% Independently specified expectations.
expected_t = (0:0.1:1)';
expected_v = 3.96 * ones(11, 96);
expected_v(:, 2) = 3.84;

% Confirm that the intended voltage scenario was applied.
assert(isequal(size(v_meas), [11 96]), ...
    'FAIL: unexpected measured-voltage dimensions.');

assert(all(abs(v_meas - expected_v) <= 1e-10, 'all'), ...
    'FAIL: unexpected supplied voltages.');

% Check the fault at every sample, including startup.
assert(isequal(size(fault), [11 1]), ...
    'FAIL: unexpected fault dimensions.');

assert(islogical(fault), ...
    'FAIL: OV_fault must be boolean.');

assert(all(fault == false, 'all'), ...
    'FAIL: fault active under normal voltages.');

% Verify both recordings cover the expected sample times.
recorded_times = [estOut.V_cells_meas_log.Time, ...
                  estOut.OV_fault_log.Time];
expected_times = [expected_t, expected_t];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp dimensions.');

assert(all(abs(recorded_times - expected_times) <= 1e-9, 'all'), ...
    'FAIL: incorrect recording times.');

disp('PASS: OV fault stays inactive under normal voltages.');