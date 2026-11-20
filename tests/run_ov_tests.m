% Normal operation: no false alarm.
test_ov_normal;

% One high cell must trigger detection.
test_ov_single_cell;

% Check behavior immediately below and exactly at the threshold.
test_ov_below_threshold;
test_ov_at_threshold;

disp('PASS: all four overvoltage detection scenarios.');