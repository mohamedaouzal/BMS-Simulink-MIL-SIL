%% BMS regression tests
% Run existing tests from the cell model through OC protection.
% Any failed assertion stops execution immediately.

setup_BMS;
init_BMS;

fprintf('\n===== 1/11: Cell voltage =====\n');
test_cell_voltage_at_180s;

fprintf('\n===== 2/11: Module model =====\n');
run_module_tests;

fprintf('\n===== 3/11: Pack model =====\n');
run_pack_tests;

fprintf('\n===== 4/11: SOC estimator =====\n');
run_estimator_tests;

fprintf('\n===== 5/11: OV detection =====\n');
run_ov_tests;

fprintf('\n===== 6/11: OV fault and hysteresis =====\n');
run_ov_fault_tests;

fprintf('\n===== 7/11: OV integration =====\n');
run_ov_integration_tests;

fprintf('\n===== 8/11: UV fault and hysteresis =====\n');
run_uv_tests;

fprintf('\n===== 9/11: UV integration =====\n');
run_uv_integration_tests;

fprintf('\n===== 10/11: Voltage current permissions =====\n');
test_voltage_current_permissions;

fprintf('\n===== 11/11: Overcurrent protection =====\n');
run_oc_tests;

fprintf('\n===== 12/12: Temperature protection =====\n');
run_temperature_tests;

fprintf('\n=================================================\n');
fprintf('\nPASS: all 12 BMS regression test groups completed.\n');
fprintf('=================================================\n');