% Configure rest: 0 A for 1 second.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '0');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

estOut = sim(simIn);

% Read all recorded SOC estimates.
soc_est = estOut.SOC_est_log.Data;

% Independent expectations for this test.
expected_soc = 0.80 * ones(11, 96);
expected_soc(:, 2) = 0.70;

% Check dimensions before comparing values.
assert(isequal(size(soc_est), size(expected_soc)), ...
    'FAIL: unexpected estimated SOC dimensions.');

% Absolute SOC tolerance for numerical rounding.
soc_est_ok = all(abs(soc_est - expected_soc) <= 1e-10, 'all');

assert(soc_est_ok, 'FAIL: estimated SOC during rest.');

% Read the plant's reference SOC.
soc_ref = estOut.SOC_cells_log.Data;

% Check both records against the expected sample times.
expected_t = (0:0.1:1)';

recorded_times = [estOut.SOC_cells_log.Time, ...
                  estOut.SOC_est_log.Time];

expected_times = [expected_t, expected_t];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected SOC timestamp dimensions.');

time_ok = all(abs(recorded_times - expected_times) <= 1e-9, 'all');

assert(time_ok, 'FAIL: plant or estimator recording times.');

% Compare corresponding cells at corresponding times.
assert(isequal(size(soc_ref), size(soc_est)), ...
    'FAIL: plant and estimator SOC dimensions differ.');

soc_error = soc_est - soc_ref;
agreement_ok = all(abs(soc_error) <= 1e-10, 'all');

assert(agreement_ok, 'FAIL: estimator differs from plant during rest.');

disp('PASS: estimator rest values, timing and plant agreement.');