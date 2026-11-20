% Run the model and read its recorded voltage.
simOut = sim('BMS_MIL', 'ReturnWorkspaceOutputs', 'on');
t = simOut.V_cell_log.Time;
v = simOut.V_cell_log.Data;

% Expected times in seconds and voltages in volts.
expected_t = [179.9; 180; 180.1];
expected_v = [3.880016666666667; 3.93; 3.93];

% Compare the three recorded samples with our expectations.
time_ok = all(abs(t(1800:1802) - expected_t) <= 1e-9);
voltage_ok = all(abs(v(1800:1802) - expected_v) <= 1e-10);

assert(time_ok, 'FAIL: unexpected sample times.');
assert(voltage_ok, 'FAIL: voltage around 180 s is incorrect.');

% Read the recorded SOC times and values.
soc_t = simOut.SOC_plant_log.Time;
soc = simOut.SOC_plant_log.Data;

% Expected SOC before, at and after the current stops.
expected_soc = [0.775013888888889; 0.775; 0.775];

soc_time_ok = all(abs(soc_t(1800:1802) - expected_t) <= 1e-9);
soc_ok = all(abs(soc(1800:1802) - expected_soc) <= 1e-10);

assert(soc_time_ok, 'FAIL: unexpected SOC sample times.');
assert(soc_ok, 'FAIL: SOC around 180 s is incorrect.');

% Check that both recordings reach 360 seconds.
end_times = [t(end); soc_t(end)];
end_ok = all(abs(end_times - 360) <= 1e-9);

% Check every recorded sample during rest.
rest_soc_ok = all(abs(soc(1801:end) - 0.775) <= 1e-10);
rest_voltage_ok = all(abs(v(1801:end) - 3.93) <= 1e-10);

assert(end_ok, 'FAIL: recordings must end at 360 s.');
assert(rest_soc_ok, 'FAIL: SOC is incorrect during rest.');
assert(rest_voltage_ok, 'FAIL: voltage is incorrect during rest.');

% Calculate expected SOC at each recorded time from 0 to 180 s.
expected_discharge_soc = 0.80 - soc_t(1:1801) / (3600 * 2);

% Compare the recorded SOC with the independent calculation.
discharge_soc_ok = all(abs(soc(1:1801) - expected_discharge_soc) <= 1e-10);

assert(discharge_soc_ok, 'FAIL: SOC during discharge is incorrect.');

% Expected voltage while the discharge current is 1 A.
expected_discharge_voltage = 3.0 + 1.2 * expected_discharge_soc(1:1800) - 0.05;

discharge_voltage_ok = all(abs(v(1:1800) - expected_discharge_voltage) <= 1e-10);

assert(discharge_voltage_ok, 'FAIL: voltage during discharge is incorrect.');


% Read fresh results from this simulation.
soc2 = simOut.SOC_cell2_log.Data;
v2 = simOut.V_cell2_log.Data;
vpack = simOut.V_pack_log.Data;

% Compare initial and final values.
soc2_ok = all(abs([soc2(1); soc2(end)] - [0.70; 0.675]) <= 1e-10);
v2_ok = all(abs([v2(1); v2(end)] - [3.79; 3.81]) <= 1e-10);
vpack_ok = all(abs([vpack(1); vpack(end)] - [7.70; 7.74]) <= 1e-10);

assert(soc2_ok, 'FAIL: Cell 2 initial or final SOC.');
assert(v2_ok, 'FAIL: Cell 2 initial or final voltage.');
assert(vpack_ok, 'FAIL: initial or final pack voltage.');

disp('PASS: Cell 1 scenario and two-cell initial/final checks.');