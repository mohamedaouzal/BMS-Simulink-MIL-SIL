% Run the three module scenarios.
test_module_rest;
test_module_discharge;
test_module_charge;

% Reached only if all preceding tests complete successfully.
disp('PASS: all three module scenarios.');