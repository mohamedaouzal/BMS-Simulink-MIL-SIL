% Scenario: current = 0 A, start = 0 s, stop = 1 s, Ts = 0.1 s.
simIn = Simulink.SimulationInput('Module_12S_Test');

simIn = setBlockParameter(simIn, ...
    'Module_12S_Test/Test_current_A', 'Value', '0');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

moduleOut = sim(simIn);
% Read the recorded SOC table.
soc = moduleOut.SOC_cells_log.Data;

% Build the expected SOC table.
expected_soc = 0.80 * ones(11, 12);
expected_soc(:, 2) = 0.70;

% Check the number of rows and columns before comparing values.
assert(isequal(size(soc), size(expected_soc)), ...
    'FAIL: unexpected SOC table dimensions.');

% Compare every recorded SOC with its expected value.
soc_error = abs(soc - expected_soc);
soc_ok = all(soc_error <= 1e-10, 'all');

assert(soc_ok, 'FAIL: module SOC values during rest.');

% Read the voltage recordings.
v_cells = moduleOut.V_cells_log.Data;
v_module = moduleOut.V_module_log.Data;

% Expected voltages throughout the zero-current scenario.
expected_v_cells = 3.96 * ones(11, 12);
expected_v_cells(:, 2) = 3.84;
expected_v_module = 47.40 * ones(11, 1);

% Check the recording dimensions.
assert(isequal(size(v_cells), size(expected_v_cells)), ...
    'FAIL: unexpected cell-voltage table dimensions.');

assert(isequal(size(v_module), size(expected_v_module)), ...
    'FAIL: unexpected module-voltage table dimensions.');

% Check every voltage value.
cell_voltage_ok = all(abs(v_cells - expected_v_cells) <= 1e-10, 'all');
module_voltage_ok = all(abs(v_module - expected_v_module) <= 1e-10, 'all');

assert(cell_voltage_ok, 'FAIL: cell voltages during rest.');
assert(module_voltage_ok, 'FAIL: total module voltage during rest.');

% Expected times, arranged as one column.
expected_t = (0:0.1:1)';

% Collect the three recordings' time columns.
recorded_times = [moduleOut.SOC_cells_log.Time, ...
                  moduleOut.V_cells_log.Time, ...
                  moduleOut.V_module_log.Time];

% Each recording should have the same expected times.
expected_times = [expected_t, expected_t, expected_t];

% Check dimensions before comparing timestamps.
assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp table dimensions.');

time_ok = all(abs(recorded_times - expected_times) <= 1e-9, 'all');

assert(time_ok, 'FAIL: incorrect module recording times.');

disp('PASS: module rest values and sample times.');