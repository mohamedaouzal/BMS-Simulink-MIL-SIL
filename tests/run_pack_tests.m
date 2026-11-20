% Run all three normal-operation pack tests.
test_pack_rest;
test_pack_discharge;
test_pack_charge;

% Reached only if every test finishes without an error.
disp('PASS: all three pack scenarios.');