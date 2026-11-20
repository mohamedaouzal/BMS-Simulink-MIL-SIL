# BMS simulation and verification report
Educational 96S1P battery management system

Delivery snapshot 18 November 2026

## Outcome and scope
The project combines a discrete battery plant, per-cell SOC estimation, voltage and current protection, temperature protection, and an interactive dashboard. The user reported successful completion of all 12 model regression groups and all four SIL groups containing nine comparison scenarios. The supplied SIL scripts compare every controller output and independently check expected behaviour.

The results concern an educational battery model, not a qualified EV battery or ECU. Documentation was checked against saved files; simulations were not rerun during packaging.

## System structure
The pack comprises eight 12-cell series modules, giving 96 cells in series and one parallel path. The controller receives measured current, 96 cell voltages, requested current, an OC-reset request and a uniform measured temperature. Its permission outputs gate the requested current before a one-sample response delay applies it to the plant.

Positive current denotes discharge. Negative current denotes charge. The dashboard shows the minimum of the 96 estimated cell SOC values, multiplied by 100, rather than their average.

| Parameter | Saved value | Meaning |
|---|---|---|
| Ts | 0.1 s | Controller and discrete simulation step |
| Q_cell_Ah and Q_est_cell_Ah | 2 Ah | Plant and assumed estimator capacity |
| Initial SOC | 0.80, except cell 2 at 0.70 | Same initial plant and estimator vector |
| OCV range | 3.0 to 4.2 V | Linear resting-voltage approximation |
| R0_cell_Ohm | 0.05 ohm | Fixed resistance per cell |
| Pack arrangement | 96S1P | Eight series modules of twelve cells |

## Plant and estimator equations
The following discrete equations describe the model, with SOC expressed as a fraction. The plant uses applied current; the estimator uses measured current. The output at sample k is the stored SOC before the update to sample k+1.

```text
SOC[k+1] = clip(SOC[k] - I[k]*Ts/(3600*Q), 0, 1)
OCV = 3.0 + 1.2*SOC
V_cell = OCV - 0.05*I_applied
V_pack = sum(V_cell for all 96 cells)
```



<!-- page -->
## Protection behaviour
Stateflow charts hold fault state between samples. Startup conditional transitions evaluate the trip condition immediately when each chart first executes. OV, UV and temperature faults recover through hysteresis. OC faults require a valid reset.

| Protection | Trip condition | Recovery condition |
|---|---|---|
| Overvoltage | Maximum cell voltage >= 4.15 V | Maximum cell voltage <= 4.10 V |
| Undervoltage | Minimum cell voltage <= 3.05 V | Minimum cell voltage >= 3.10 V |
| Discharge OC | Measured current >= 2.0 A | Valid OC reset |
| Charge OC | Measured current <= -1.0 A | Valid OC reset |
| Charge temperature | T <= 0 or T >= 45 degC | 5 <= T <= 40 degC |
| Discharge temperature | T <= -20 or T >= 60 degC | -15 <= T <= 55 degC |

All listed comparisons include equality. The release intervals lie inside the trip limits, preventing rapid switching when an input moves near a boundary.

## OC reset and current permissions
A reset request is accepted only when all four conditions below are true. The measured-current range is a reset qualification band; it is not a tolerance band for requested current.

```text
Reset_OC_valid = Reset_OC_requested
                 AND (I_requested_A == 0)
                 AND (I_meas_A >= -0.8)
                 AND (I_meas_A <= 1.5)

OC_fault = OC_discharge_fault OR OC_charge_fault
Charge_allowed = NOT (OV_fault OR OC_fault OR T_charge_fault)
Discharge_allowed = NOT (UV_fault OR OC_fault OR T_discharge_fault)
```

Returning measured current to zero does not clear a latched OC fault. Requiring a zero current request separates reset from an immediate restart demand. After reset, the request can be raised again. OV blocks charging; UV blocks discharge; any OC fault blocks both directions. Temperature faults block their respective direction. Clearing one fault does not override another active fault.

## Closed loop timing
In the integration models, the permitted current command passes through a Unit Delay with Ts = 0.1 s and initial value zero. An excessive request can therefore appear as applied current on the next sample, trigger detection on that sample, and be removed on the following sample. This is the modelled command and current delay, not a measured hardware disconnection time.

Controller-only SIL protection tests supply current directly. They verify controller outputs and SOC from that supplied current; they do not model a physical current interruption. Closed-loop current stopping and restarting were exercised by the separate MIL integration tests.

<!-- page -->
## Controller interface
The referenced model is `BMS_Controller`. All five inputs are sampled at Ts. Current and temperature inputs are scalar; cell voltages form a vector of 96 values. Fault, detection, reset and permission outputs are Boolean.

| Input port | Name | Type and meaning |
|---|---|---|
| 1 | I_meas_A | double scalar; measured current in A |
| 2 | V_cells_V | double vector of 96 cell voltages in V |
| 3 | Reset_OC_requested | boolean scalar; requested OC reset |
| 4 | I_requested_A | double scalar; desired current in A |
| 5 | T_meas_C | double scalar; uniform temperature in degC |

| Output port | Name | Meaning |
|---|---|---|
| 1 | SOC_est | 96 estimated SOC fractions, limited to 0-1 |
| 2 | OV_detected | Instantaneous OV threshold comparison |
| 3 | OV_fault | OV state including hysteresis |
| 4 | Charge_allowed | Permission to command charging |
| 5 | UV_detected | Instantaneous UV threshold comparison |
| 6 | UV_fault | UV state including hysteresis |
| 7 | Discharge_allowed | Permission to command discharge |
| 8 | OC_discharge_detected | Instantaneous discharge OC comparison |
| 9 | OC_charge_detected | Instantaneous charge OC comparison |
| 10 | Reset_OC_valid | Reset qualification result |
| 11 | OC_discharge_fault | Latched discharge OC state |
| 12 | OC_charge_fault | Latched charge OC state |
| 13 | OC_fault | Combined overcurrent fault |
| 14 | T_charge_fault | Charge temperature state with hysteresis |
| 15 | T_discharge_fault | Discharge temperature state with hysteresis |

<!-- page -->
## Model regression evidence
`run_bms_regression_tests.m` invokes the following 12 groups. The final aggregate PASS was supplied by the user. MIL tests verify the mathematical model and its intended protection and integration behaviour before generated-code equivalence is considered.

| Group | Entry point | Main coverage |
|---|---|---|
| 1 | test_cell_voltage_at_180s | Cell voltage calculation |
| 2 | run_module_tests | Module rest, charge and discharge |
| 3 | run_pack_tests | Pack rest, charge and discharge |
| 4 | run_estimator_tests | SOC evolution, errors and saturation |
| 5 | run_ov_tests | OV detection and thresholds |
| 6 | run_ov_fault_tests | OV startup, memory and release |
| 7 | run_ov_integration_tests | Charging block in closed loop |
| 8 | run_uv_tests | UV startup, memory and release |
| 9 | run_uv_integration_tests | Discharge block in closed loop |
| 10 | test_voltage_current_permissions | Direction permissions with OV and UV |
| 11 | run_oc_tests | Trip, reset, integration and interactions |
| 12 | run_temperature_tests | Boundaries, hysteresis and interactions |

The runner's first eleven printed progress headings still use /11. Its twelve calls and final /12 total are present. This is a display-only inconsistency in the supplied script. No new MIL run or saved MIL console transcript was produced during packaging.

## Generated code configuration
The saved controller uses C and the Embedded Coder target `ert.tlc`. The inspected generated header records model version 1.41, Simulink Coder 25.2 R2025b, and Intel x86-64 Windows64 hardware. The reported selected compiler was Microsoft Visual C++ 2019 (C), version 16.0. The model-reference target built successfully before SIL execution.

The C entry points and state structures are generated implementation details. The models and parameter script remain the source of behaviour. Rebuild after model or parameter changes, and keep shared generated support files with the controller sources.


<!-- page -->
## SIL comparison evidence
`run_sil_tests.m` invokes four scripts containing nine scenarios. Each scenario runs in Normal mode and model-reference SIL mode. Thus the suite performs eighteen simulations. The supplied aggregate result reports all four groups and all nine comparisons passed.

| Group | Scenarios | Evidence under results |
|---|---:|---|
| Normal discharge | 1 | sil_normal_scenario.mat |
| OV and UV hysteresis | 2 | sil_voltage_scenarios.mat |
| Discharge and charge OC | 2 | sil_oc_scenarios.mat |
| Cold and hot temperature protection | 4 | sil_temperature_scenarios.mat |

All 15 controller outputs are compared at each recorded sample. Boolean results must agree exactly. Numeric comparisons use an absolute tolerance of 1e-10; timestamps use 1e-9 s. Dimensions and data types are checked. Expected states and SOC are independently asserted, preventing two equally incorrect runs from passing solely because they agree. The protection scripts also verify all five input recordings.

The normal-discharge table supplied by the user reports zero maximum error on every output. The other groups passed their stated tolerances; no measured zero-error claim is made for every remaining scenario.

### Reading the saved evidence
Each protection MAT file stores scenarioResults with NormalOutput, SILOutput, Comparison, Profiles and Expected fields. The normal-discharge file stores normalOutput, silOutput and comparisonResults directly. Use the following example from the project root:

```matlab
e = load(fullfile('results','sil_voltage_scenarios.mat'));
disp(e.scenarioResults(1).Comparison);
```

A final group PASS is reached only after all assertions complete. The scripts also verify expected sample times and input values. The comparison table reports the largest absolute Normal/SIL difference over all samples and, for SOC, all 96 cells. Saved outputs allow a reviewer to inspect fault timing and state recovery, not just the final state.

<!-- page -->
## SIL scenario details
The normal scenario uses 0.5 A measured and requested current, all cells at 3.96 V, 25 degC and no reset for 10 s. SOC decreases according to coulomb counting; no protection fault is expected. Both current directions remain permitted.

### Voltage sequences
Only cell 17 changes. Other cells remain at 3.96 V; current is zero and temperature is 25 degC. The six-second profiles include threshold equality at release and retrip.

| Time in s | OV voltage in V | UV voltage in V | Fault state |
|---|---:|---:|---|
| 0 | 4.12 | 3.08 | Off |
| 1 | 4.16 | 3.04 | On |
| 2 | 4.12 | 3.08 | Remains on |
| 3 | 4.10 | 3.10 | Clears |
| 4 | 4.12 | 3.08 | Remains off |
| 5 and 6 | 4.15 | 3.05 | Trips again |

### Overcurrent reset sequences
Each ten-second scenario starts with normal current, trips at 1 s, and remains latched after measured current returns to zero at 2 s. Single-sample reset requests at 3, 4 and 7 s are rejected respectively because the requested current is nonzero, measured current is +1.501 A, or measured current is -0.801 A. Resets at 5 and 8 s succeed at +1.5 A and -0.8 A with zero requested current. Retrips occur at 6 and 10 s. The discharge trip input is +2.2 A; the charge trip input is -1.2 A.

### Temperature sequences
The following values are applied at whole seconds from 0 through 6. Current is zero and all cells are at 3.96 V. Each targeted temperature fault follows Off, On, On, Off, Off, On, Off.

| Scenario | Temperature sequence in degC |
|---|---|
| Charge cold | 25, 0, 2, 5, 2, 0, 25 |
| Charge hot | 25, 45, 42, 40, 42, 45, 25 |
| Discharge cold | 25, -20, -17, -15, -17, -20, 25 |
| Discharge hot | 25, 60, 57, 55, 57, 60, 25 |

During the discharge-temperature cases, the charge-temperature fault remains active through the discharge release band until the final return to 25 degC. This verifies that the two direction permissions recover independently.

<!-- page -->
## Reproduction and handover
Use MATLAB R2025b with MATLAB, Simulink and Stateflow; install and configure Simulink Coder, Embedded Coder and a supported C compiler for SIL. Extract the entire delivery into a writable folder, select the project root as MATLAB's Current Folder, and use the following commands. Detailed dashboard instructions are in README.md.

```matlab
setup_BMS;
init_BMS;
run_bms_regression_tests;
run_sil_tests;
open_system('BMS_Dashboard');
```

Profile-driven harnesses should normally be executed through their scripts, which supply the From Workspace variables. Fresh Normal and SIL runs use identical inputs. The scripts save evidence only after their scenario assertions pass; rerunning a group replaces its corresponding MAT file.

The archive contains the saved models, parameters, test scripts, four SIL result files, generated-code snapshot, this report, an editable report source, README and a test matrix. The SHA-256 manifest identifies packaged file content. Backups, autosave files and simulation caches are excluded. No original project files were changed during packaging.

## Interpretation and limits
The verified requirements concern the supplied educational model and the listed scenarios. A uniform input temperature replaces thermal dynamics. The cell voltage law is linear with fixed resistance and capacity. There is no cell balancing, SOH estimator, contactor or precharge plant, vehicle communication implementation, or commercial-cell parameter validation.

SIL runs generated code on the development computer. No processor-in-the-loop or hardware-in-the-loop test, ECU deployment, execution-time deadline measurement, structural code-coverage assessment, or functional-safety certification is included. MIL interaction tests and closed-loop integration tests are broader than the selected nine SIL scenarios; those additional MIL cases were not all repeated in SIL.

Generated build metadata and binaries can contain original-machine paths. Rebuild on a different computer or after relocating the project. The C header's field 'Validation result: Not run' is generator metadata and is separate from the custom SIL assertion results in this delivery.

## Sources and evidence locations
Project sources: parameters/init_BMS.m; setup_BMS.m; models/BMS_Controller.slx; models/BMS_Dashboard.slx; tests/run_bms_regression_tests.m; tests/run_sil_tests.m; the individual scripts listed in docs/TEST_MATRIX.csv; and generated/code/slprj/ert/BMS_Controller/BMS_Controller.c. The four results/*.mat files preserve SIL outputs and comparison data. The PASS summaries were reported by the user in the project conversation.

MathWorks workflow references:

- Configure and Run SIL Simulation: https://www.mathworks.com/help/ecoder/ug/configuring-a-sil-or-pil-simulation.html
- Generate and compile model code: https://www.mathworks.com/help/simulink/slref/slbuild.html
- Dashboard panels: https://www.mathworks.com/help/simulink/ug/getting-started-with-panels.html


