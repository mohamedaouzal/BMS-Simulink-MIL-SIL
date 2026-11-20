% Scenario 1: battery voltage rises during charging.
% Expected: OV protection stops current and SOC stops increasing.
test_ov_integration_charge_stop;

% Scenario 2: supplied overvoltage exists at startup.
% Expected: no charging current, including the first sample.
test_ov_integration_startup;

disp('PASS: both OV integration scenarios.');