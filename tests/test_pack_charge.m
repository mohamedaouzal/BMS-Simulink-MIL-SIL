% Configure charge: -1 A for 360 seconds.
simIn = Simulink.SimulationInput('Pack_96S_Test');

simIn = setBlockParameter(simIn, ...
    'Pack_96S_Test/Test_current_A', 'Value', '-1');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '360');

packOut = sim(simIn);

% Read recorded SOC values.
soc = packOut.SOC_cells_log.Data;

% Calculate expected SOC at every sample time.
expected_t = (0:0.1:360)';
expected_soc = zeros(3601, 96);

for cell_number = 1:96
    expected_soc(:, cell_number) = 0.80 + expected_t / 7200;
end

% Cell 2 starts at 70%.
expected_soc(:, 2) = 0.70 + expected_t / 7200;

% Check dimensions and every SOC value.
assert(isequal(size(soc), size(expected_soc)), ...
    'FAIL: unexpected charge SOC dimensions.');

soc_ok = all(abs(soc - expected_soc) <= 1e-10, 'all');

assert(soc_ok, 'FAIL: pack SOC during charge.');

% Read recorded voltages.
v_cells = packOut.V_cells_log.Data;
v_pack = packOut.V_pack_log.Data;

% Expected voltages during -1 A charge.
expected_v_cells = 3.0 + 1.2 * expected_soc + 0.05;
expected_v_pack = 384.84 + 0.016 * expected_t;

% Check dimensions.
assert(isequal(size(v_cells), size(expected_v_cells)), ...
    'FAIL: unexpected charge cell-voltage dimensions.');

assert(isequal(size(v_pack), size(expected_v_pack)), ...
    'FAIL: unexpected charge pack-voltage dimensions.');

% Compare every recorded voltage.
cell_voltage_ok = all( ...
    abs(v_cells - expected_v_cells) <= 1e-10, 'all');

pack_voltage_ok = all( ...
    abs(v_pack - expected_v_pack) <= 1e-10, 'all');

assert(cell_voltage_ok, 'FAIL: cell voltages during charge.');
assert(pack_voltage_ok, 'FAIL: pack voltage during charge.');

% Collect the recording times for all three signals.
recorded_times = [packOut.SOC_cells_log.Time, ...
                  packOut.V_cells_log.Time, ...
                  packOut.V_pack_log.Time];

% Each signal should use the same expected times.
expected_times = [expected_t, expected_t, expected_t];

% Check dimensions before comparing.
assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected charge timestamp dimensions.');

% Compare every timestamp, with tolerance in seconds.
time_ok = all(abs(recorded_times - expected_times) <= 1e-9, 'all');

assert(time_ok, 'FAIL: pack charge recording times.');

disp('PASS: pack charge SOC, voltages and sample times.');