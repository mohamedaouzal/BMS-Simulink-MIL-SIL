% Scenario 1: normal voltages; no UV fault; discharge permitted.
test_uv_normal;

% Scenario 2: undervoltage present at startup; discharge forbidden.
test_uv_startup;

% Scenario 3: trip, fault memory, release and retrip.
test_uv_fault_hysteresis;

disp('PASS: all three UV protection scenarios.');