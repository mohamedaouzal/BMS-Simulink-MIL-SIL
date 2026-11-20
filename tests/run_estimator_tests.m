% Ideal operation: accurate initialization, current and capacity.
test_estimator_rest;
test_estimator_discharge;
test_estimator_charge;

% Deliberately incorrect estimator information.
test_estimator_initial_error;
test_estimator_current_bias;
test_estimator_capacity_error;

% Estimated SOC boundaries.
test_estimator_upper_limit;
test_estimator_lower_limit;

disp('PASS: all eight estimator scenarios.');