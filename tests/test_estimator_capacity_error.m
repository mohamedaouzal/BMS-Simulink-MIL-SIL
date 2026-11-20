% Scenario: actual capacity 2 Ah, estimator assumes 1.8 Ah.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '1');

% No current-measurement error in this test.
simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', 'Bias', '0');

% Override only the estimator's capacity assumption.
simIn = setBlockParameter(simIn, ...
    'BMS_Controller/Current_to_SOC_change', ...
    'Gain', 'Ts / (3600 * 1.8)');

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

% Error = actual SOC decrease minus estimated SOC decrease.
error_trajectory = expected_t / (3600 * 2) ...
                 - expected_t / (3600 * 1.8);

for cell_number = 1:96
    expected_ref(:, cell_number) = 0.80 - expected_t / 7200;
    expected_error(:, cell_number) = error_trajectory;
end

expected_ref(:, 2) = 0.70 - expected_t / 7200;

% Check SOC dimensions.
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

% Verify the plant still follows the 2 Ah expectation.
reference_ok = all(abs(soc_ref - expected_ref) <= 1e-10, 'all');

assert(reference_ok, ...
    'FAIL: plant SOC does not match the 2 Ah expectation.');

% Verify the error caused by assuming 1.8 Ah.
soc_error = soc_est - soc_ref;

error_ok = all(abs(soc_error - expected_error) <= 1e-10, 'all');

assert(error_ok, ...
    'FAIL: unexpected capacity-error behavior.');

disp('PASS: incorrect capacity produces the expected SOC error.');