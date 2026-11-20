% Initial parameters for our first one-cell model
% Educational assumptions, not validated battery data

Ts = 0.1;           
Q_cell_Ah = 2;      

SOC0_plant = 0.80;  
SOC0_est = 0.80; 

% Educational resting-voltage assumptions
OCV_empty_V = 3.0;
OCV_full_V = 4.2;

R0_cell_Ohm = 0.05; % Educational internal resistance, in ohms

SOC0_cell2 = 0.70;  % Cell 2 starts at 70% SOC

% Initial SOC for the 12 cells in one module
SOC0_module = SOC0_plant * ones(12, 1);
SOC0_module(2) = SOC0_cell2;

% Initial SOC: rows = cells, columns = modules.
SOC0_pack = SOC0_plant * ones(12, 8);

% Cell 2 of Module 1 starts at the lower SOC.
SOC0_pack(2, 1) = SOC0_cell2;

% BMS starting estimates: one value per cell.
SOC0_est_pack = SOC0_est * ones(96, 1);

% Assumed known initial SOC for Cell 2.
SOC0_est_pack(2) = 0.70;

% Capacity assumed by the BMS estimator, in Ah per cell.
Q_est_cell_Ah = 2;


% Educational cell overvoltage thresholds.
V_cell_OV_trip_V = 4.15;       % Activate the fault.
V_cell_OV_release_V = 4.10;    % Clear the fault.

% Undervoltage thresholds for our simulation model.
V_cell_UV_trip_V = 3.05;
V_cell_UV_release_V = 3.10;

% Overcurrent thresholds for the educational simulation.
% The charge thresholds are stored as positive magnitudes.

I_discharge_OC_trip_A = 2.0;
I_discharge_OC_release_A = 1.5;

I_charge_OC_trip_A = 1.0;
I_charge_OC_release_A = 0.8;


assert(I_discharge_OC_release_A > 0 && ...
       I_discharge_OC_release_A < I_discharge_OC_trip_A, ...
    'Invalid discharge overcurrent thresholds.');

assert(I_charge_OC_release_A > 0 && ...
       I_charge_OC_release_A < I_charge_OC_trip_A, ...
    'Invalid charge overcurrent thresholds.');

%% Temperature protection
% Educational assumptions for the generic battery model.

T_charge_low_trip_C       = 0;
T_charge_low_release_C    = 5;

T_charge_high_trip_C      = 45;
T_charge_high_release_C   = 40;

T_discharge_low_trip_C    = -20;
T_discharge_low_release_C = -15;

T_discharge_high_trip_C    = 60;
T_discharge_high_release_C = 55;