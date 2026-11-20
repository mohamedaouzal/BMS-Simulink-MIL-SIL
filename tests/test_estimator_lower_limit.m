% Scenario: charge from 0% and reach the lower SOC limit.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '1');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Current_sensor_bias_A', 'Bias', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_Controller/SOC_memory', ...
    'InitialCondition', '0.01 * ones(96, 1)');

simIn = setBlockParameter(simIn, ...
    'BMS_Controller/Current_to_SOC_change', ...
    'Gain', 'Ts / (3600 * 2)');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '90');

estOut = sim(simIn);

% Read the recorded estimates and timestamps.
soc_est = estOut.SOC_est_log.Data;
recorded_t = estOut.SOC_est_log.Time;

% Independent expectation from elapsed charging time.
expected_t = (0:0.1:90)';
expected_one_cell = 0.01 - expected_t / 7200;

% The expected SOC must stop increasing at 0.01%.
expected_one_cell(expected_one_cell < 0) = 0;

% All 96 estimates start with the same initial SOC.
expected_soc = zeros(901, 96);
for cell_number = 1:96
    expected_soc(:, cell_number) = expected_one_cell;
end

% Check the recorded dimensions.
assert(isequal(size(soc_est), size(expected_soc)), ...
    'FAIL: unexpected SOC dimensions.');

assert(isequal(size(recorded_t), size(expected_t)), ...
    'FAIL: unexpected timestamp dimensions.');

% Compare timestamps and SOC values.
time_ok = all(abs(recorded_t - expected_t) <= 1e-9);
soc_ok = all(abs(soc_est - expected_soc) <= 1e-10, 'all');

assert(time_ok, 'FAIL: lower-limit recording times.');
assert(soc_ok, 'FAIL: SOC trajectory near the lower limit.');

% No recorded estimate may fall below 0%.
assert(all(soc_est >= 0, 'all'), ...
    'FAIL: estimated SOC falls below 0%.');

disp('PASS: estimator lower SOC limit.');