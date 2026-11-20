% Scenario 1: normal voltages from startup.
% Expected: fault remains false.
test_ov_fault_normal;

% Scenario 2: one cell exceeds the threshold from startup.
% Expected: fault is true immediately, including at t = 0.
test_ov_fault_startup;

% Scenario 3: voltage crosses the trip and release thresholds.
% Expected: correct trip, memory, release and retrip.
test_ov_fault_hysteresis;

disp('PASS: all three OV fault scenarios.');