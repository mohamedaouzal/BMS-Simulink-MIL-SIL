% Scenario: battery voltage triggers OV protection and stops charging.
init_BMS;

assert(abs(Ts - 0.1) <= 1e-12, ...
    'FAIL: this test requires Ts = 0.1 seconds.');

assert(V_cell_OV_trip_V == 4.15 && ...
       V_cell_OV_release_V == 4.10, ...
    'FAIL: unexpected OV thresholds.');

% Comparison tolerances.
cell_voltage_tolerance = 1e-10;
pack_voltage_tolerance = 96 * cell_voltage_tolerance;
soc_tolerance = 1e-10;
current_tolerance = 1e-10;
time_tolerance = 1e-9;

% Configure the integration model.
simIn = Simulink.SimulationInput('BMS_OV_Integration_Test');

simIn = setBlockParameter(simIn, ...
    'BMS_OV_Integration_Test/Test_current_A', ...
    'Value', '-0.5');

simIn = setBlockParameter(simIn, ...
    'BMS_OV_Integration_Test/Test_current_A', ...
    'SampleTime', 'Ts');

simIn = setBlockParameter(simIn, ...
    'BMS_OV_Integration_Test/Blocked_current_A', ...
    'Value', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_OV_Integration_Test/Current_sensor_bias_A', ...
    'Bias', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_OV_Integration_Test/Voltage_test_bias_V', ...
    'Bias', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_OV_Integration_Test/Charger_response_delay', ...
    'InitialCondition', '0');

simIn = setBlockParameter(simIn, ...
    'BMS_OV_Integration_Test/Charger_response_delay', ...
    'SampleTime', 'Ts');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '2100', ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '0.1');

intOut = sim(simIn);

% Expected recording times: 21001 samples.
expected_t = (0:0.1:2100)';
n_samples = numel(expected_t);

% Check dimensions and timestamps for every recording.
log_names = {'SOC_cells_log', 'SOC_est_log', ...
    'V_cells_log', 'V_cells_meas_log', 'V_pack_log', ...
    'OV_detected_log', 'OV_fault_log', 'Charge_allowed_log', ...
    'Charge_current_command_log', 'I_applied_log', 'I_meas_log'};

log_widths = [96 96 96 96 1 1 1 1 1 1 1];

for k = 1:numel(log_names)
    recorded = intOut.get(log_names{k});

    assert(isequal(size(recorded.Data), ...
        [n_samples log_widths(k)]), ...
        ['FAIL: unexpected dimensions for ' log_names{k}]);

    assert(isequal(size(recorded.Time), size(expected_t)), ...
        ['FAIL: unexpected timestamp dimensions for ' log_names{k}]);

    assert(all(abs(recorded.Time - expected_t) ...
        <= time_tolerance, 'all'), ...
        ['FAIL: incorrect timestamps for ' log_names{k}]);
end

% Read the recorded signals.
soc = intOut.SOC_cells_log.Data;
soc_est = intOut.SOC_est_log.Data;

v_cells = intOut.V_cells_log.Data;
v_meas = intOut.V_cells_meas_log.Data;
v_pack = intOut.V_pack_log.Data;

detected = intOut.OV_detected_log.Data;
fault = intOut.OV_fault_log.Data;
allowed = intOut.Charge_allowed_log.Data;

command = intOut.Charge_current_command_log.Data;
i_applied = intOut.I_applied_log.Data;
i_meas = intOut.I_meas_log.Data;

assert(islogical(detected) && ...
       islogical(fault) && islogical(allowed), ...
    'FAIL: protection outputs must be boolean.');

% Find the first fault activation.
trip_row = find(fault, 1, 'first');

assert(~isempty(trip_row), ...
    'FAIL: overvoltage protection never activated.');

trip_time = expected_t(trip_row);

% Analytical crossing:
% 1980 seconds of charging plus the initial 0.1-second delay.
% Numerical rounding may postpone detection by one sample.
assert(trip_time >= 1980.1 - time_tolerance && ...
       trip_time <= 1980.2 + time_tolerance, ...
    'FAIL: OV trip occurred outside the expected time window.');

% Applied current must stop one sample after the fault activates.
stop_row = trip_row + 1;
stop_time = expected_t(stop_row);

% Expected fault and permission: one trip, then remain blocked.
expected_fault = false(n_samples, 1);
expected_fault(trip_row:end) = true;

expected_allowed = true(n_samples, 1);
expected_allowed(trip_row:end) = false;

assert(isequal(fault, expected_fault), ...
    'FAIL: OV fault must remain active after the trip.');

assert(isequal(allowed, expected_allowed), ...
    'FAIL: incorrect charging permission.');

% Command stops immediately when the fault activates.
expected_command = -0.5 * ones(n_samples, 1);
expected_command(trip_row:end) = 0;

% Applied current starts at zero.
% Charging starts at 0.1 s and stops one sample after the trip.
expected_current = zeros(n_samples, 1);
expected_current(2:trip_row) = -0.5;

assert(all(abs(command - expected_command) ...
    <= current_tolerance, 'all'), ...
    'FAIL: incorrect charging-current command.');

assert(all(abs(i_applied - expected_current) ...
    <= current_tolerance, 'all'), ...
    'FAIL: incorrect applied current or charger response delay.');

assert(all(abs(i_meas - expected_current) ...
    <= current_tolerance, 'all'), ...
    'FAIL: BMS measured current does not match applied current.');

% Independent SOC calculation for 2 Ah cells.
% Most cells start at 80%; Cell 2 starts at 70%.
initial_soc = 0.80 * ones(1, 96);
initial_soc(2) = 0.70;

% Charging begins at 0.1 s and ends at stop_time.
charging_duration = min( ...
    max(expected_t - 0.1, 0), stop_time - 0.1);

% SOC increase = 0.5 * charging_duration / (3600 * 2).
expected_soc = ones(n_samples, 1) * initial_soc ...
    + (charging_duration / 14400) * ones(1, 96);

assert(all(abs(soc - expected_soc) <= soc_tolerance, 'all'), ...
    'FAIL: incorrect plant SOC during charging or after stopping.');

assert(all(abs(soc_est - expected_soc) <= soc_tolerance, 'all'), ...
    'FAIL: incorrect estimated SOC.');

% Independent voltage calculation:
% V = 3 + 1.2*SOC - 0.05*I.
expected_v = 3.0 + 1.2 * expected_soc ...
    - 0.05 * expected_current * ones(1, 96);

expected_pack_v = sum(expected_v, 2);

assert(all(abs(v_cells - expected_v) ...
    <= cell_voltage_tolerance, 'all'), ...
    'FAIL: incorrect cell voltages.');

assert(all(abs(v_meas - expected_v) ...
    <= cell_voltage_tolerance, 'all'), ...
    'FAIL: incorrect supplied voltage measurements.');

% Pack tolerance accounts for the sum of 96 cell-voltage errors.
assert(all(abs(v_pack - expected_pack_v) ...
    <= pack_voltage_tolerance, 'all'), ...
    'FAIL: incorrect pack voltage.');

% Separately verify the pack's summation of its cell voltages.
assert(all(abs(v_pack - sum(v_cells, 2)) <= 1e-10, 'all'), ...
    'FAIL: pack voltage does not match the sum of cell voltages.');

% Confirm that voltage actually crossed the trip threshold.
highest_v = max(v_cells, [], 2);

assert(all(highest_v(1:trip_row-1) < 4.15), ...
    'FAIL: a voltage threshold crossing was missed.');

assert(highest_v(trip_row) >= 4.15, ...
    'FAIL: fault activated before voltage reached the threshold.');

% After current stops, voltage remains inside the hysteresis band.
assert(all(highest_v(stop_row:end) > 4.10 & ...
           highest_v(stop_row:end) < 4.15), ...
    'FAIL: unexpected voltage after charging stopped.');

% Raw detection clears after stopping, while the fault stays active.
expected_detected = false(n_samples, 1);
expected_detected(trip_row) = true;

assert(isequal(detected, expected_detected), ...
    'FAIL: incorrect instantaneous overvoltage detection.');

% Display startup, trip, current interruption and final results.
rows = [1; 2; trip_row-1; trip_row; stop_row; n_samples];

disp(table(expected_t(rows), highest_v(rows), ...
    command(rows), i_applied(rows), fault(rows), soc(rows, 1), ...
    'VariableNames', {'Time_s', 'Highest_cell_V', ...
    'Command_A', 'Applied_A', 'OV_fault', 'Cell1_SOC'}));

fprintf('OV trip time: %.1f s\n', trip_time);
fprintf('Charging current stopped at: %.1f s\n', stop_time);

disp('PASS: integrated OV protection stops charging and holds SOC.');