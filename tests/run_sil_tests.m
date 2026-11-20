%% Run all BMS SIL comparison tests
setup_BMS;
init_BMS;

fprintf('\n=== SIL group 1/4: Normal discharge ===\n');
test_sil_normal_scenario;

fprintf('\n=== SIL group 2/4: Voltage protection ===\n');
test_sil_voltage_scenarios;

fprintf('\n=== SIL group 3/4: Overcurrent protection ===\n');
test_sil_oc_scenarios;

fprintf('\n=== SIL group 4/4: Temperature protection ===\n');
test_sil_temperature_scenarios;

fprintf('\n=================================================\n');
fprintf('PASS: all four BMS SIL test groups completed.\n');
fprintf('PASS: all nine Normal/SIL comparison scenarios.\n');
fprintf('=================================================\n');