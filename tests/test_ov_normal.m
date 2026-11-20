% Scenario: normal cell voltages while the pack rests.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', 'Bias', '0');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

estOut = sim(simIn);

% Read voltages and the overvoltage decision.
v_cells = estOut.V_cells_log.Data;
ov = estOut.OV_detected_log.Data;

% Expected normal voltages at all 11 sample times.
expected_v = 3.96 * ones(11, 96);
expected_v(:, 2) = 3.84;
expected_t = (0:0.1:1)';

% Check dimensions before comparing.
assert(isequal(size(v_cells), [11 96]), ...
    'FAIL: unexpected cell-voltage dimensions.');

assert(isequal(size(ov), [11 1]), ...
    'FAIL: unexpected overvoltage-output dimensions.');

% Confirm that this really is the intended normal-voltage scenario.
assert(all(abs(v_cells - expected_v) <= 1e-10, 'all'), ...
    'FAIL: unexpected normal cell voltages.');

% Check recording times for both signals.
recorded_times = [estOut.V_cells_log.Time, ...
                  estOut.OV_detected_log.Time];
expected_times = [expected_t, expected_t];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp dimensions.');

assert(all(abs(recorded_times - expected_times) <= 1e-9, 'all'), ...
    'FAIL: incorrect recording times.');

% Boolean decisions must match exactly: no numerical tolerance.
assert(islogical(ov), ...
    'FAIL: overvoltage output must be boolean.');

assert(all(ov == false, 'all'), ...
    'FAIL: overvoltage detected during normal voltage.');

disp('PASS: normal voltages do not trigger overvoltage.');