% Test the effect of an incorrect starting SOC estimate.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '1');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '360');

% Only Cell 2 differs from the plant's initial SOC.
simIn = setBlockParameter(simIn, ...
    'BMS_Controller/SOC_memory', ...
    'InitialCondition', '0.80 * ones(96, 1)');

estOut = sim(simIn);

soc_ref = estOut.SOC_cells_log.Data;
soc_est = estOut.SOC_est_log.Data;

% Expected error: zero everywhere except Cell 2.
expected_error = zeros(3601, 96);
expected_error(:, 2) = 0.10;

% Check dimensions.
assert(isequal(size(soc_ref), size(expected_error)), ...
    'FAIL: unexpected reference SOC dimensions.');

assert(isequal(size(soc_est), size(expected_error)), ...
    'FAIL: unexpected estimated SOC dimensions.');

% Verify the times before comparing corresponding values.
expected_t = (0:0.1:360)';
expected_times = [expected_t, expected_t];

recorded_times = [estOut.SOC_cells_log.Time, ...
                  estOut.SOC_est_log.Time];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp dimensions.');

time_ok = all(abs(recorded_times - expected_times) <= 1e-9, 'all');
assert(time_ok, 'FAIL: incorrect SOC recording times.');

% Check the signed error at every time and for every cell.
soc_error = soc_est - soc_ref;

error_ok = all(abs(soc_error - expected_error) <= 1e-10, 'all');
assert(error_ok, 'FAIL: unexpected initial-error behavior.');

disp('PASS: initial SOC error persists as expected.');