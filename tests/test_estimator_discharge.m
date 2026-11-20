% Test SOC estimation during 1 A discharge for 360 seconds.

% Configure the simulation.
simIn = Simulink.SimulationInput('BMS_Estimator_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_Estimator_Test/Test_current_A', 'Value', '1');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '360');

estOut = sim(simIn);

% Read the estimated and reference SOC values.
soc_est = estOut.SOC_est_log.Data;
soc_ref = estOut.SOC_cells_log.Data;

% Calculate independent expectations.
% Current = 1 A, capacity = 2 Ah, so SOC decreases by t/7200.
expected_t = (0:0.1:360)';
expected_soc = zeros(3601, 96);

for cell_number = 1:96
    expected_soc(:, cell_number) = 0.80 - expected_t / 7200;
end

% Cell 2 starts at 70% instead of 80%.
expected_soc(:, 2) = 0.70 - expected_t / 7200;

% Check estimated SOC dimensions and values.
assert(isequal(size(soc_est), size(expected_soc)), ...
    'FAIL: unexpected estimated SOC dimensions.');

soc_est_ok = all(abs(soc_est - expected_soc) <= 1e-10, 'all');

assert(soc_est_ok, 'FAIL: estimated SOC during discharge.');

% Collect timestamps for the plant and estimator.
recorded_times = [estOut.SOC_cells_log.Time, ...
                  estOut.SOC_est_log.Time];

expected_times = [expected_t, expected_t];

% Check timestamp dimensions and values.
assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected SOC timestamp dimensions.');

time_ok = all(abs(recorded_times - expected_times) <= 1e-9, 'all');

assert(time_ok, 'FAIL: plant or estimator recording times.');

% Compare corresponding cells at corresponding times.
assert(isequal(size(soc_ref), size(soc_est)), ...
    'FAIL: plant and estimator SOC dimensions differ.');

soc_error = soc_est - soc_ref;
agreement_ok = all(abs(soc_error) <= 1e-10, 'all');

assert(agreement_ok, ...
    'FAIL: estimator differs from plant during discharge.');

% Printed only if every check above passes.
disp('PASS: estimator discharge values, timing and plant agreement.');