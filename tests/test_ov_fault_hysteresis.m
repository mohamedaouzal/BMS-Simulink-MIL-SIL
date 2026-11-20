% Scenario: overvoltage trip, memory, release and retrip.
init_BMS;

% Confirm the parameter values required by this scenario.
assert(abs(Ts - 0.1) <= 1e-12, ...
    'FAIL: this test requires Ts = 0.1 seconds.');

assert(V_cell_OV_trip_V == 4.15, ...
    'FAIL: this test requires a 4.15 V trip threshold.');

assert(V_cell_OV_release_V == 4.10, ...
    'FAIL: this test requires a 4.10 V release threshold.');

% Prepare the supplied voltages.
t_voltage = (0:6)';

v_cells_test = 3.96 * ones(7, 96);
v_cells_test(:, 17) = [4.12;
                      4.16;
                      4.12;
                      4.10;
                      4.12;
                      4.15;
                      4.15];

OV_voltage_profile = [t_voltage, v_cells_test];

% Configure the simulation.
simIn = Simulink.SimulationInput('BMS_OV_Protection_Test');

simIn = setVariable(simIn, ...
    'OV_voltage_profile', OV_voltage_profile);

simIn = setBlockParameter(simIn, ...
    'BMS_OV_Protection_Test/Test_current_A', 'Value', '0');

simIn = setModelParameter(simIn, ...
    'StartTime', '0', 'StopTime', '6');

ovOut = sim(simIn);

% Read the recorded inputs and outputs.
v_meas = ovOut.V_cells_meas_log.Data;
detected = ovOut.OV_detected_log.Data;
fault = ovOut.OV_fault_log.Data;

% Independently specify the expected values at all 61 samples.
expected_t = (0:0.1:6)';

expected_v = 3.96 * ones(61, 96);
expected_v(:, 17) = [4.12 * ones(10, 1);
                     4.16 * ones(10, 1);
                     4.12 * ones(10, 1);
                     4.10 * ones(10, 1);
                     4.12 * ones(10, 1);
                     4.15 * ones(11, 1)];

expected_detected = [false(10, 1);
                    true(10, 1);
                    false(30, 1);
                    true(11, 1)];

expected_fault = [false(10, 1);
                 true(20, 1);
                 false(20, 1);
                 true(11, 1)];

% Check dimensions before comparing values.
assert(isequal(size(v_meas), [61 96]), ...
    'FAIL: unexpected measured-voltage dimensions.');

assert(isequal(size(detected), [61 1]), ...
    'FAIL: unexpected detection dimensions.');

assert(isequal(size(fault), [61 1]), ...
    'FAIL: unexpected fault dimensions.');

% Verify every supplied cell voltage.
assert(all(abs(v_meas - expected_v) <= 1e-10, 'all'), ...
    'FAIL: incorrect supplied voltage sequence.');

% Confirm exact threshold values for the boundary checks.
assert(v_meas(31, 17) == 4.10, ...
    'FAIL: Cell 17 must equal 4.10 V at t = 3 seconds.');

assert(v_meas(51, 17) == 4.15, ...
    'FAIL: Cell 17 must equal 4.15 V at t = 5 seconds.');

% Verify Boolean types and behavior at every sample.
assert(islogical(detected) && islogical(fault), ...
    'FAIL: detection and fault outputs must be boolean.');

assert(isequal(detected, expected_detected), ...
    'FAIL: incorrect instantaneous overvoltage detection.');

assert(isequal(fault, expected_fault), ...
    'FAIL: incorrect overvoltage hysteresis behavior.');

% Verify timestamps for all three recordings.
recorded_times = [ovOut.V_cells_meas_log.Time, ...
                  ovOut.OV_detected_log.Time, ...
                  ovOut.OV_fault_log.Time];

expected_times = [expected_t, expected_t, expected_t];

assert(isequal(size(recorded_times), size(expected_times)), ...
    'FAIL: unexpected timestamp dimensions.');

assert(all(abs(recorded_times - expected_times) <= 1e-9, 'all'), ...
    'FAIL: incorrect recording times.');

% Show the results at each whole second.
rows = (1:10:61)';

disp(table(ovOut.OV_fault_log.Time(rows), ...
    v_meas(rows, 17), detected(rows), fault(rows), ...
    'VariableNames', ...
    {'Time_s', 'Cell17_V', 'OV_detected', 'OV_fault'}));

disp('PASS: OV fault trip, hysteresis, release and retrip.');

% Check charging permission during the hysteresis scenario.
charge_allowed = ovOut.Charge_allowed_log.Data;
charge_times = ovOut.Charge_allowed_log.Time;

% Independent expected permission at all 61 samples.
expected_charge_allowed = [true(10, 1);
                          false(20, 1);
                          true(20, 1);
                          false(11, 1)];

% Verify dimensions and Boolean type.
assert(isequal(size(charge_allowed), [61 1]), ...
    'FAIL: unexpected charging-permission dimensions.');

assert(islogical(charge_allowed), ...
    'FAIL: Charge_allowed must be boolean.');

% Check permission at every sample, including startup.
assert(isequal(charge_allowed, expected_charge_allowed), ...
    'FAIL: incorrect charging permission.');

% Verify recording times.
assert(isequal(size(charge_times), size(expected_t)), ...
    'FAIL: unexpected charging-permission timestamps.');

assert(all(abs(charge_times - expected_t) <= 1e-9, 'all'), ...
    'FAIL: incorrect charging-permission recording times.');

% Display results at each whole second.
rows = (1:10:61)';

disp(table(charge_times(rows), v_meas(rows, 17), ...
    fault(rows), charge_allowed(rows), ...
    'VariableNames', ...
    {'Time_s', 'Cell17_V', 'OV_fault', 'Charge_allowed'}));

disp('PASS: charging permission follows OV fault hysteresis.');

% Check the permitted charging-current command.
charge_command = ovOut.Charge_current_command_log.Data;
command_times = ovOut.Charge_current_command_log.Time;

% Independent expected command at all 61 samples.
expected_command = [-ones(10, 1);
                     zeros(20, 1);
                    -ones(20, 1);
                     zeros(11, 1)];

% Verify dimensions and every command value.
assert(isequal(size(charge_command), [61 1]), ...
    'FAIL: unexpected charging-command dimensions.');

assert(all(abs(charge_command - expected_command) <= 1e-10, 'all'), ...
    'FAIL: incorrect charging-current command.');

% Verify recording times.
assert(isequal(size(command_times), size(expected_t)), ...
    'FAIL: unexpected charging-command timestamps.');

assert(all(abs(command_times - expected_t) <= 1e-9, 'all'), ...
    'FAIL: incorrect charging-command recording times.');

% Display results at each whole second.
rows = (1:10:61)';

disp(table(command_times(rows), v_meas(rows, 17), ...
    fault(rows), charge_allowed(rows), charge_command(rows), ...
    'VariableNames', ...
    {'Time_s', 'Cell17_V', 'OV_fault', ...
     'Charge_allowed', 'Charge_command_A'}));

disp('PASS: charging command is blocked during OV fault and resumes after release.');