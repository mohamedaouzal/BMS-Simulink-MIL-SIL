%% Run all implemented overcurrent protection tests
% Execution stops immediately if a test fails.

fprintf('\n=== OC constant-current tests ===\n');
test_oc_constant_scenarios;

fprintf('\n=== OC memory and reset tests ===\n');
test_oc_reset_scenarios;

fprintf('\n=== OC integration trip tests ===\n');
test_oc_integration_trip;

fprintf('\n=== OC integration reset and restart tests ===\n');
test_oc_integration_reset;

fprintf('\n=== OC and voltage-protection interaction tests ===\n');
test_oc_voltage_interactions;

fprintf('\nPASS: all five OC test groups completed successfully.\n');