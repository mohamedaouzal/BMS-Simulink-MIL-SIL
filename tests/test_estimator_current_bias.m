% Scenario: 1 A discharge with a +0.1 A current-measurement bias.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '1');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', 'Bias', '0.1');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '360');

estOut = sim(simIn);

% Read reference and estimated SOC.
soc_ref = estOut.SOC_cells_log.Data;
soc_est = estOut.SOC_est_log.Data;

% Calculate independent expectations.
expected_t = (0:0.1:360)';
expected_ref = zeros(3601, 96);
expected_error = zeros(3601, 96);

for cell_number = 1:96
    expected_ref(:, cell_number) = 0.80 - expected_t / 7200;
    expected_error(:, cell_number) = -0.1 * expected_t / 7200;
end

% Cell 2 has a different initial SOC, but the same error drift.
expected_ref(:, 2) = 0.70 - expected_t / 7200;

% Check SOC table dimensions.
assert(isequal(size(soc_ref), size(expected_ref)), ...
    'FAIL: unexpected reference SOC dimensions.');

assert(isequal(size(soc_est), size(expected_ref)), ...
    'FAIL: unexpected estimated SOC dimensions.');

% Check both recording timelines.
recorded_times = [estOut.SOC_cells_log.Time, ...
                  estOut.SOC_est_log.Time];

expected_times = [expected_t, expected_t];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp dimensions.');

time_ok = all(abs(recorded_times - expected_times) <= 1e-9, 'all');
assert(time_ok, 'FAIL: incorrect SOC recording times.');

% Verify that the plant follows the actual 1 A current.
reference_ok = all(abs(soc_ref - expected_ref) <= 1e-10, 'all');

assert(reference_ok, ...
    'FAIL: plant SOC does not match the actual-current scenario.');

% Verify the drift caused by the measurement bias.
soc_error = soc_est - soc_ref;

error_ok = all(abs(soc_error - expected_error) <= 1e-10, 'all');

assert(error_ok, ...
    'FAIL: SOC error does not match the expected current-bias drift.');

disp('PASS: current bias produces the expected SOC drift.');