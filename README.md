# BMS simulation and SIL verification

This project implements a generic educational 96S1P battery model, a BMS controller, an interactive dashboard, and automated model and generated-code tests. The pack contains eight 12-cell series modules; cell capacity is 2 Ah. Positive current means discharge and negative current means charge.

Recorded validation: all 12 model regression groups and all four SIL groups (nine Normal/SIL comparison scenarios) passed in the project environment. Four saved SIL result files are included. This repository copy was prepared on 20 November 2026; tests were not rerun during repository preparation.

## Start here

Clone this repository or download and extract its ZIP into a writable folder. Set MATLAB's Current Folder to the repository root containing `setup_BMS.m`. Use one copy of the project on the MATLAB path at a time.

```matlab
setup_BMS;
init_BMS;
```

`setup_BMS` locates its own folder, adds the models, parameters and tests folders to the path, and configures `generated/cache` and `generated/code`. `init_BMS` defines the sample time, capacities, initial SOC values, voltage model parameters, and protection thresholds.

## Software environment

The reported successful environment was MATLAB R2025b (25.2.0.2998904), Windows 11, and Microsoft Visual C++ 2019 (C), version 16.0. Model simulation uses MATLAB, Simulink and Stateflow. The supplied SIL workflow additionally uses Simulink Coder, Embedded Coder and a configured supported C compiler. The scripts use MATLAB assertions and SimulationInput; they do not require Simulink Test or MATLAB Test to execute this workflow.

The controller uses C, the `ert.tlc` target, fixed-step execution, and `Ts = 0.1 s`. The original successful generated-code build identified Intel x86-64 Windows64 hardware and model version 1.41. This is a host SIL configuration, not an embedded ECU deployment.

Check the selected compiler when setting up another computer:

```matlab
mex.getCompilerConfigurations('C', 'Selected')
```

If no C compiler is selected, configure an installed supported compiler with `mex -setup C`.

## Run the automated tests

Start from the project root after running setup and initialization:

```matlab
run_bms_regression_tests
run_sil_tests
```

The first command runs 12 model regression groups. The second runs four SIL groups comprising nine scenarios. Each SIL scenario executes twice, once with the referenced controller in Normal mode and once in Software-in-the-loop mode. The top model stays in Normal mode.

Expected final messages:

```text
PASS: all 12 BMS regression test groups completed.
PASS: all four BMS SIL test groups completed.
PASS: all nine Normal/SIL comparison scenarios.
```

A failed assertion stops the relevant script before its final PASS message. A successful code build alone is not a successful equivalence test.

The first eleven progress headings in `run_bms_regression_tests.m` still use `/11`. The script actually calls the temperature group as group 12 and prints the correct final total of 12. This display inconsistency is retained from the saved source; it does not omit a test group.

### SIL scripts and saved evidence

| Script | Scenarios | Result file under results |
|---|---:|---|
| test_sil_normal_scenario.m | 1 | sil_normal_scenario.mat |
| test_sil_voltage_scenarios.m | 2 | sil_voltage_scenarios.mat |
| test_sil_oc_scenarios.m | 2 | sil_oc_scenarios.mat |
| test_sil_temperature_scenarios.m | 4 | sil_temperature_scenarios.mat |

`run_sil_tests.m` runs these scripts in order. Re-running them overwrites the corresponding result files. Preserve a copy if a historical run must be retained.

The normal-discharge MAT file contains `normalOutput`, `silOutput`, `comparisonResults` and tolerances. The protection MAT files contain `scenarioResults`, which holds each scenario's Normal and SIL outputs, comparison table, profiles and expected data, plus recording names, timestamps and tolerances.

```matlab
evidence = load(fullfile('results','sil_voltage_scenarios.mat'));
disp(evidence.scenarioResults(1).Comparison);
```

All 15 controller outputs are compared at every recorded sample. Boolean values match exactly; the numerical tolerance is 1e-10 and the timestamp tolerance is 1e-9 s. The protection scripts also verify five recorded inputs against their intended profiles. Expected protection states and SOC trajectories are checked independently of Normal/SIL agreement.

### Running individual harnesses

Use the matching test script to run a profile-driven harness. The scripts provide From Workspace variables through SimulationInput. Opening a harness and clicking Run directly can fail if its profile variables have not been defined. `BMS_SIL_Test` uses constants for the normal scenario; `BMS_SIL_Protection_Test` uses five From Workspace sources for the remaining eight SIL scenarios.

## Open the dashboard

Stop any active simulation, then run:

```matlab
setup_BMS;
init_BMS;
open_system('BMS_Dashboard');
set_param('BMS_Dashboard/Test_current_A','Value','0');
set_param('BMS_Dashboard/Test_temperature_C','Value','25');
set_param('BMS_Dashboard/Test_reset_OC','Value','false');
set_param('BMS_Dashboard','StopTime','300');
```

The explicit input settings give a repeatable starting point even if the saved dashboard last used different slider values. Use the Panels tab to show the existing panel and open it in a separate window. Enable Simulation Pacing at one simulated second per real second for a manual demonstration, then start a fresh simulation.

The panel contains current and temperature sliders, an OC-reset toggle, numerical measurements, a rectangular SOC filling gauge, two permission lamps and five fault lamps. The SOC gauge displays the **minimum estimated cell SOC**, in percent, rather than an average pack SOC. At initialization the minimum is 70%; the other cells start at 80%. With zero current, expected initial voltages are approximately 3.84 V minimum, 3.96 V maximum and 380.04 V pack voltage.

### Short demonstration

1. At 0 A and 25 degC, both permission lamps should be green and all fault lamps gray.
2. Request +0.5 A. Applied current follows after one sample, and SOC decreases.
3. Request +2.2 A. The OC lamp turns red, both permissions turn off, and applied current falls to zero after the modelled delay.
4. Return the request to exactly 0 A. The OC fault remains latched. When measured current is within -0.8 to +1.5 A inclusive, switch OC reset On briefly, then Off. The fault clears.
5. Request +0.5 A again. Applied current resumes.
6. Set temperature to 60 degC. Both temperature faults activate and current is blocked. At 55 degC discharge can recover, while charging remains blocked. At 25 degC both temperature faults clear.

Stopped dashboard values may reflect the previous run. Evaluate behaviour during a fresh simulation. These manual demonstrations supplement the automated tests; they are not new mandatory test groups.

## Project contents

| Location | Purpose |
|---|---|
| setup_BMS.m | Project paths and generated-file locations |
| parameters/init_BMS.m | Shared numerical parameters |
| models | Controller, battery library, dashboard and test models |
| tests | MIL regression tests and SIL comparison scripts |
| results | Four saved SIL evidence files |
| generated | Created locally by setup/build; excluded from Git |
| docs | Technical report, test matrix and handover notes |
| .gitignore and .gitattributes | Build-file exclusions and binary model/data handling |

The repository includes saved `.slx` models, `.m` source scripts, documentation and the four SIL evidence files. Build outputs, simulation caches, autosaves and backups are excluded. The models and scripts were copied without edits. The technical report describes the original 18 November delivery snapshot, which also contained generated build files; this source repository regenerates those files locally.

## Rebuild the controller

The saved controller is configured for Embedded Coder. To explicitly rebuild its model-reference target:

```matlab
setup_BMS;
init_BMS;
load_system('BMS_Controller');
slbuild('BMS_Controller','ModelReferenceCoderTarget');
```

After building, generated sources are under `generated/code/slprj/ert/BMS_Controller`, with dependencies in `generated/code/slprj/ert/_sharedutils`. These build files are created locally and excluded from Git. Rebuild on each computer; generated sources depend on MATLAB-supplied support headers and are not a standalone ECU integration kit.

Do not edit generated C to change protection behaviour. Change the model or parameters, rebuild, and rerun the affected tests and equivalence comparisons. The generated header's `Validation result: Not run` is a separate generator metadata field; it is not the result of the supplied custom SIL assertions.

## Scope and limitations

The battery is generic and educational. Its 2 Ah capacity, 0.05 ohm resistance, linear 3.0-4.2 V OCV relationship, and current and temperature limits are project assumptions, not a selected commercial EV cell specification. Temperature is an externally supplied uniform signal, not a thermal plant state. SOC uses coulomb counting with known initial values and no voltage correction. Bias, capacity-error and initial-error MIL tests illustrate sensitivity rather than prove convergence.

SIL verifies selected generated-code behaviour on the host computer. It does not establish complete code coverage, real-time execution deadlines, target-processor equivalence, hardware protection performance or certification. Cell balancing, SOH, contactor/precharge physics, CAN communication and sensor-diagnostic strategies are outside this delivery.

See the [technical report](docs/BMS_Technical_Report.pdf) for architecture, interfaces and evidence scope, and the [test matrix](docs/TEST_MATRIX.csv) for the group-level test inventory.
