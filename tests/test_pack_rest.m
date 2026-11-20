% Configure this test: zero current for one second.
simIn = Simulink.SimulationInput('Pack_96S_Test');

simIn = setBlockParameter(simIn, ...
    'Pack_96S_Test/Test_current_A', 'Value', '0');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '1');

packOut = sim(simIn);

% Read the recorded SOC values.
soc = packOut.SOC_cells_log.Data;

% Expected SOC: 11 sample times, 96 cells.
expected_soc = 0.80 * ones(11, 96);
expected_soc(:, 2) = 0.70;

% Check dimensions before comparing values.
assert(isequal(size(soc), size(expected_soc)), ...
    'FAIL: unexpected pack SOC table dimensions.');

% Allow only tiny numerical rounding differences.
soc_ok = all(abs(soc - expected_soc) <= 1e-10, 'all');

assert(soc_ok, 'FAIL: pack SOC values during rest.');

% Read recorded voltages.
v_cells = packOut.V_cells_log.Data;
v_pack = packOut.V_pack_log.Data;

% Expected voltages during rest.
expected_v_cells = 3.96 * ones(11, 96);
expected_v_cells(:, 2) = 3.84;
expected_v_pack = 380.04 * ones(11, 1);

% Check table dimensions.
assert(isequal(size(v_cells), size(expected_v_cells)), ...
    'FAIL: unexpected cell-voltage dimensions.');

assert(isequal(size(v_pack), size(expected_v_pack)), ...
    'FAIL: unexpected pack-voltage dimensions.');

% Compare every recorded value.
cell_voltage_ok = all( ...
    abs(v_cells - expected_v_cells) <= 1e-10, 'all');

pack_voltage_ok = all( ...
    abs(v_pack - expected_v_pack) <= 1e-10, 'all');

assert(cell_voltage_ok, 'FAIL: cell voltages during rest.');
assert(pack_voltage_ok, 'FAIL: total pack voltage during rest.');

% Expected recording times: 0 to 1 second, every 0.1 second.
expected_t = (0:0.1:1)';

% One time column for each recorded signal.
recorded_times = [packOut.SOC_cells_log.Time, ...
                  packOut.V_cells_log.Time, ...
                  packOut.V_pack_log.Time];

expected_times = [expected_t, expected_t, expected_t];

% Check dimensions before comparing.
assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp table dimensions.');

% Allow tiny numerical rounding differences in seconds.
time_ok = all(abs(recorded_times - expected_times) <= 1e-9, 'all');

assert(time_ok, 'FAIL: pack recording times.');

disp('PASS: pack rest SOC, voltages and sample times.');