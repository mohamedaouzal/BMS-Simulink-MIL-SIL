% Scenario: actual battery discharge triggers UV protection.
% Requested current: +0.5 A.
% Cell 2 should trigger UV first.
% Applied current must stop one sample after the fault.
% SOC must then remain constant.

init_BMS;

assert(abs(Ts - 0.1) <= 1e-12, ...
    'FAIL: this test expects Ts = 0.1 s.');

assert(abs(V_cell_UV_trip_V - 3.05) <= 1e-12, ...
    'FAIL: unexpected UV trip threshold.');

assert(abs(V_cell_UV_release_V - 3.10) <= 1e-12, ...
    'FAIL: unexpected UV release threshold.');

% Configure the simulation.
model = 'BMS_UV_Integration_Test';
simIn = Simulink.SimulationInput(model);

simIn = setBlockParameter(simIn, ...
    [model '/Test_current_A'], 'Value', '0.5');

simIn = setBlockParameter(simIn, ...
    [model '/Blocked_current_A'], 'Value', '0');

simIn = setBlockParameter(simIn, ...
    [model '/Current_sensor_bias_A'], 'Bias', '0');

simIn = setBlockParameter(simIn, ...
    [model '/Voltage_test_bias_V'], 'Bias', '0');

simIn = setBlockParameter(simIn, ...
    [model '/Discharge_response_delay'], ...
    'InitialCondition', '0');

simIn = setBlockParameter(simIn, ...
    [model '/Discharge_response_delay'], ...
    'SampleTime', 'Ts');

simIn = setModelParameter(simIn, ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '0.1', ...
    'StartTime', '0', ...
    'StopTime', '9500');

uvOut = sim(simIn);

% Expected times and numerical tolerances.
expected_t = (0:0.1:9500)';
n = numel(expected_t);

value_tol = 1e-10;
pack_tol = 96 * value_tol;
time_tol = 1e-9;

% Check dimensions and timestamps of all required recordings.
log_names = { ...
    'SOC_cells_log', ...
    'SOC_est_log', ...
    'V_cells_log', ...
    'V_cells_meas_log', ...
    'V_pack_log', ...
    'UV_detected_log', ...
    'UV_fault_log', ...
    'Discharge_allowed_log', ...
    'Discharge_current_command_log', ...
    'I_applied_log', ...
    'I_meas_log'};

widths = [96 96 96 96 1 1 1 1 1 1 1];

for k = 1:numel(log_names)
    signal = uvOut.get(log_names{k});

    assert(isequal(size(signal.Data), [n widths(k)]), ...
        ['FAIL: unexpected dimensions for ' log_names{k} '.']);

    assert(isequal(size(signal.Time), size(expected_t)), ...
        ['FAIL: unexpected timestamp dimensions for ' log_names{k} '.']);

    assert(all(abs(signal.Time - expected_t) <= time_tol, 'all'), ...
        ['FAIL: incorrect recording times for ' log_names{k} '.']);
end

% Read recorded signals.
soc = uvOut.SOC_cells_log.Data;
soc_est = uvOut.SOC_est_log.Data;

v_cells = uvOut.V_cells_log.Data;
v_meas = uvOut.V_cells_meas_log.Data;
v_pack = uvOut.V_pack_log.Data;

detected = uvOut.UV_detected_log.Data;
fault = uvOut.UV_fault_log.Data;
allowed = uvOut.Discharge_allowed_log.Data;

command = uvOut.Discharge_current_command_log.Data;
applied = uvOut.I_applied_log.Data;
i_meas = uvOut.I_meas_log.Data;

assert(islogical(detected) && islogical(fault) && islogical(allowed), ...
    'FAIL: protection outputs must be boolean.');

% Locate the first UV fault.
trip_row = find(fault, 1, 'first');

assert(~isempty(trip_row), ...
    'FAIL: UV fault never activated.');

trip_time = expected_t(trip_row);

% Analytical trip time:
% 3 + 1.2 * SOC2 - 0.05 * 0.5 = 3.05
% SOC2 at trip = 0.0625.
% Discharge duration = (0.70 - 0.0625) * 7200 / 0.5
%                    = 9180 seconds.
% Add the initial 0.1-second response delay.
% Allow one extra sample for accumulated floating-point rounding.
assert(trip_time >= 9180.1 - time_tol && ...
       trip_time <= 9180.2 + time_tol, ...
    'FAIL: unexpected UV trip time.');

% Current must stop one sample after the fault.
stop_row = trip_row + 1;
stop_time = expected_t(stop_row);

% Expected fault, permission, command and applied current.
expected_fault = false(n, 1);
expected_fault(trip_row:end) = true;

expected_allowed = ~expected_fault;

expected_command = 0.5 * ones(n, 1);
expected_command(trip_row:end) = 0;

expected_current = zeros(n, 1);
expected_current(2:trip_row) = 0.5;

assert(isequal(fault, expected_fault), ...
    'FAIL: UV fault must remain active after tripping.');

assert(isequal(allowed, expected_allowed), ...
    'FAIL: incorrect discharge permission.');

assert(all(abs(command - expected_command) <= value_tol, 'all'), ...
    'FAIL: incorrect discharge-current command.');

assert(all(abs(applied - expected_current) <= value_tol, 'all'), ...
    'FAIL: incorrect applied current or response delay.');

assert(all(abs(i_meas - expected_current) <= value_tol, 'all'), ...
    'FAIL: BMS must measure the actual applied current.');

% Independently calculate SOC from discharge duration.
% At t = 0.1 s current starts, but SOC still has its initial value.
discharge_duration = min( ...
    max(expected_t - 0.1, 0), stop_time - 0.1);

soc_drop = discharge_duration / 14400;

initial_soc = 0.80 * ones(1, 96);
initial_soc(2) = 0.70;

% Check each cell without creating another large 96-column matrix.
expected_pack_v = zeros(n, 1);

for cell_number = 1:96
    expected_soc = initial_soc(cell_number) - soc_drop;
    expected_v = 3.0 + 1.2 * expected_soc ...
        - 0.05 * expected_current;

    assert(all(abs(soc(:, cell_number) - expected_soc) <= value_tol), ...
        sprintf('FAIL: incorrect plant SOC for Cell %d.', cell_number));

    assert(all(abs(soc_est(:, cell_number) - expected_soc) <= value_tol), ...
        sprintf('FAIL: incorrect estimated SOC for Cell %d.', cell_number));

    assert(all(abs(v_cells(:, cell_number) - expected_v) <= value_tol), ...
        sprintf('FAIL: incorrect actual voltage for Cell %d.', cell_number));

    assert(all(abs(v_meas(:, cell_number) - expected_v) <= value_tol), ...
        sprintf('FAIL: incorrect measured voltage for Cell %d.', cell_number));

    assert(all(abs(soc(stop_row:end, cell_number) ...
        - soc(stop_row, cell_number)) <= value_tol), ...
        sprintf('FAIL: SOC keeps changing after stopping, Cell %d.', cell_number));

    expected_pack_v = expected_pack_v + expected_v;
end

assert(all(abs(v_pack - expected_pack_v) <= pack_tol), ...
    'FAIL: incorrect pack voltage.');

assert(all(abs(v_pack - sum(v_cells, 2)) <= value_tol), ...
    'FAIL: pack voltage differs from the recorded cell-voltage sum.');

% Verify that Cell 2 triggers the protection.
lowest_v = min(v_meas, [], 2);

assert(all(lowest_v(1:trip_row-1) > V_cell_UV_trip_V), ...
    'FAIL: fault should activate at the first UV sample.');

assert(v_meas(trip_row, 2) <= V_cell_UV_trip_V, ...
    'FAIL: Cell 2 has not reached the UV threshold.');

other_cells = [1, 3:96];

assert(all(v_meas(trip_row, other_cells) > V_cell_UV_trip_V), ...
    'FAIL: a cell other than Cell 2 is also undervoltage.');

% After current stops, voltage recovers above trip but below release.
assert(all(lowest_v(stop_row:end) > V_cell_UV_trip_V), ...
    'FAIL: unexpected voltage recovery after stopping.');

assert(all(lowest_v(stop_row:end) < V_cell_UV_release_V), ...
    'FAIL: voltage reached the UV release threshold unexpectedly.');

% Instantaneous detection is active only at the trip sample.
expected_detected = false(n, 1);
expected_detected(trip_row) = true;

assert(isequal(detected, expected_detected), ...
    'FAIL: incorrect instantaneous UV detection.');

% Display key recorded samples.
rows = [1; 2; trip_row-1; trip_row; stop_row; n];

disp(table(expected_t(rows), lowest_v(rows), ...
    command(rows), applied(rows), fault(rows), soc(rows, 2), ...
    'VariableNames', {'Time_s', 'Lowest_cell_V', ...
    'Command_A', 'Applied_A', 'UV_fault', 'Cell2_SOC'}));

fprintf('UV trip time: %.1f s\n', trip_time);
fprintf('Discharge current stopped at: %.1f s\n', stop_time);

disp('PASS: integrated UV protection stops discharge and holds SOC.');