% Scenario 1: discharge lowers the cell voltage until UV trips.
% Applied current then stops, and SOC remains constant.
test_uv_integration_discharge_stop;

% Scenario 2: undervoltage is present at startup.
% No discharge current may be applied.
test_uv_integration_startup;

disp('PASS: both UV integration scenarios.');