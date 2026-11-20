% Run the 1 A discharge scenario for 360 seconds.
simIn = Simulink.SimulationInput('Module_12S_Test');

simIn = setBlockParameter(simIn, ...
    'Module_12S_Test/Test_current_A', 'Value', '1');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '360');

moduleOut = sim(simIn);

soc_t = moduleOut.SOC_cells_log.Time;
soc = moduleOut.SOC_cells_log.Data;

% Expected recording times: 3601 samples.
expected_t = (0:0.1:360)';

% Prepare a table, then fill each cell's expected SOC trajectory.
expected_soc = zeros(3601, 12);

for cell_number = 1:12
    expected_soc(:, cell_number) = 0.80 - expected_t / (3600 * 2);
end

% Cell 2 starts at 0.70 instead of 0.80.
expected_soc(:, 2) = 0.70 - expected_t / (3600 * 2);

% Check dimensions before comparing.
assert(isequal(size(soc_t), size(expected_t)), ...
    'FAIL: unexpected SOC timestamp dimensions.');

assert(isequal(size(soc), size(expected_soc)), ...
    'FAIL: unexpected SOC table dimensions.');

% Check timing and SOC throughout discharge.
time_ok = all(abs(soc_t - expected_t) <= 1e-9, 'all');
soc_ok = all(abs(soc - expected_soc) <= 1e-10, 'all');

assert(time_ok, 'FAIL: discharge SOC sample times.');
assert(soc_ok, 'FAIL: SOC during module discharge.');

% Read recorded voltage values.
v_cells = moduleOut.V_cells_log.Data;
v_module = moduleOut.V_module_log.Data;

% Calculate expected voltages independently of the recordings.
expected_v_cells = 3.0 + 1.2 * expected_soc - 0.05;
expected_v_module = 46.80 - 0.002 * expected_t;

% Check voltage table dimensions.
assert(isequal(size(v_cells), size(expected_v_cells)), ...
    'FAIL: unexpected cell-voltage dimensions.');

assert(isequal(size(v_module), size(expected_v_module)), ...
    'FAIL: unexpected module-voltage dimensions.');

% Check every voltage value.
cell_voltage_ok = all(abs(v_cells - expected_v_cells) <= 1e-10, 'all');
module_voltage_ok = all(abs(v_module - expected_v_module) <= 1e-10, 'all');

assert(cell_voltage_ok, 'FAIL: cell voltages during discharge.');
assert(module_voltage_ok, 'FAIL: total voltage during discharge.');

% Check both voltage recordings' timestamps.
voltage_times = [moduleOut.V_cells_log.Time, ...
                 moduleOut.V_module_log.Time];
expected_voltage_times = [expected_t, expected_t];

assert(isequal(size(voltage_times), size(expected_voltage_times)), ...
    'FAIL: unexpected voltage timestamp dimensions.');

voltage_time_ok = all(abs(voltage_times - expected_voltage_times) <= 1e-9, 'all');

assert(voltage_time_ok, 'FAIL: voltage recording times.');

disp('PASS: module discharge SOC, voltages and sample times.');