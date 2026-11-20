%% Run all implemented temperature protection tests
% Execution stops immediately if a test fails.

fprintf('\n=== Constant-temperature tests ===\n');
test_temperature_constant_scenarios;

fprintf('\n=== Temperature hysteresis tests ===\n');
test_temperature_hysteresis;

fprintf('\n=== Temperature integration tests ===\n');
test_temperature_integration;

fprintf('\n=== Temperature interaction tests ===\n');
test_temperature_interactions;

fprintf('\nPASS: all four temperature test groups completed successfully.\n');