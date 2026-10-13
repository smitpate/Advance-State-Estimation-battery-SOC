# Every block and why it is used

Model: `EV_Battery_Discharge_Regen`, built using MATLAB R2023b.

Solver: FixedStepDiscrete; step 0.05 s; duration 1800 s. Observer and saved-data sample period: 1 s.

The real Battery block represents a complete 350 V / 114.3 Ah EV pack. It is not a single physical cell. Its built-in SOC measurement is comparison truth only. Discharge-source current flows HV+ to HV-; the regeneration source is wired oppositely.

## 1. powergui

**Library:** `sps_lib/powergui`

Solves the connected SPS electrical network. Discrete 50 ms is suitable for this battery current-profile test, not PWM switching.

| Parameter | Setting |
|---|---|
| `SimulationMode` | `Discrete` |
| `SampleTime` | `.05` |

## 2. Lithium ion EV battery

**Library:** `sps_lib/Sources/Battery`

Actual SPS Battery block with internal charge state and nonlinear charge/discharge voltage. This single block represents an EV pack, not a single 350 V cell.

| Parameter | Setting |
|---|---|
| `BatType` | `Lithium-Ion` |
| `NomV` | `350` |
| `NomQ` | `114.2857142857` |
| `SOC` | `80` |
| `Batt_Tr` | `30` |
| `ShowTempParam` | `off` |
| `ShowAgeParam` | `off` |
| `PresetModel` | `on` |
| `current` | `[60 120 180]` |

## 3. Battery current sensor

**Library:** `sps_lib/Sensors and Measurements/Current Measurement`

Measures total battery current. Positive means discharge; negative means charging.

No custom numerical setting; library defaults and inherited signal rate are used.

## 4. Battery voltage sensor

**Library:** `sps_lib/Sensors and Measurements/Voltage Measurement`

Connected across the battery terminals to measure pack voltage without drawing current.

No custom numerical setting; library defaults and inherited signal rate are used.

## 5. Discharge current source

**Library:** `sps_lib/Sources/Controlled Current Source`

Physical current-source load: draws 120 A from HV+ to HV- while traction pulse is high.

| Parameter | Setting |
|---|---|
| `Orientation` | `down` |
| `Initialize` | `on` |
| `Source_Type` | `DC` |
| `Amplitude` | `0` |
| `Measurements` | `None` |

## 6. Regenerative current source

**Library:** `sps_lib/Sources/Controlled Current Source`

Separate physical current source connected in the opposite direction: injects 60 A into the battery positive terminal during braking.

| Parameter | Setting |
|---|---|
| `Orientation` | `up` |
| `Initialize` | `on` |
| `Source_Type` | `DC` |
| `Amplitude` | `0` |
| `Measurements` | `None` |

## 7. Battery negative reference

**Library:** `sps_lib/Utilities/Ground`

Defines the negative electrical reference node.

No custom numerical setting; library defaults and inherited signal rate are used.

## 8. Traction command 120 A

**Library:** `simulink/Sources/Pulse Generator`

Traction is ON from 60 to 360 s in each 600 s cycle.

| Parameter | Setting |
|---|---|
| `Amplitude` | `120` |
| `Period` | `600` |
| `PulseWidth` | `50` |
| `PhaseDelay` | `60` |

## 9. Braking command 60 A

**Library:** `simulink/Sources/Pulse Generator`

Regeneration is ON from 420 to 540 s in each 600 s cycle, separate from traction.

| Parameter | Setting |
|---|---|
| `Amplitude` | `60` |
| `Period` | `600` |
| `PulseWidth` | `20` |
| `PhaseDelay` | `420` |

## 10. Battery SOC output

**Library:** `simulink/Signal Routing/Bus Selector`

Selects built-in SOC (%) from the Battery measurement bus. It is comparison truth and is never an estimator input.

| Parameter | Setting |
|---|---|
| `OutputSignals` | `SOC (%)` |

## 11. Send Ipack

**Library:** `simulink/Signal Routing/Goto`

Routes Ipack by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Ipack` |
| `TagVisibility` | `global` |

## 12. Send Vpack

**Library:** `simulink/Signal Routing/Goto`

Routes Vpack by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Vpack` |
| `TagVisibility` | `global` |

## 13. Send SOCtrue

**Library:** `simulink/Signal Routing/Goto`

Routes SOCtrue by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCtrue` |
| `TagVisibility` | `global` |

## 14. Send Idischarge

**Library:** `simulink/Signal Routing/Goto`

Routes Idischarge by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Idischarge` |
| `TagVisibility` | `global` |

## 15. Send Iregen

**Library:** `simulink/Signal Routing/Goto`

Routes Iregen by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Iregen` |
| `TagVisibility` | `global` |

## 16. Current input

**Library:** `simulink/Signal Routing/From`

Receives signal Ipack from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Ipack` |

## 17. Voltage input

**Library:** `simulink/Signal Routing/From`

Receives signal Vpack from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Vpack` |

## 18. Sample current

**Library:** `simulink/Discrete/Zero-Order Hold`

Samples measured current once per second for the observer.

| Parameter | Setting |
|---|---|
| `SampleTime` | `1` |

## 19. Sample voltage

**Library:** `simulink/Discrete/Zero-Order Hold`

Samples terminal voltage at the same 1-second observer rate.

| Parameter | Setting |
|---|---|
| `SampleTime` | `1` |

## 20. Current sensor error

**Library:** `simulink/Sources/Random Number`

Adds a known +1.2 A offset and 0.25 A standard deviation noise to test current-sensor error.

| Parameter | Setting |
|---|---|
| `Mean` | `1.2` |
| `Variance` | `.25^2` |
| `Seed` | `23` |
| `SampleTime` | `1` |

## 21. Voltage sensor error

**Library:** `simulink/Sources/Random Number`

Adds 0.15 V standard deviation pack-voltage noise, with a repeatable independent seed.

| Parameter | Setting |
|---|---|
| `Mean` | `0` |
| `Variance` | `.15^2` |
| `Seed` | `47` |
| `SampleTime` | `1` |

## 22. Measured current

**Library:** `simulink/Math Operations/Sum`

Combines true measured current with the current-sensor error.

| Parameter | Setting |
|---|---|
| `Inputs` | `++` |

## 23. Measured voltage

**Library:** `simulink/Math Operations/Sum`

Combines true terminal voltage with voltage-sensor noise.

| Parameter | Setting |
|---|---|
| `Inputs` | `++` |

## 24. Battery observer parameters

**Library:** `simulink/Sources/Constant`

Stores E0,K,A,B,R,Qinternal,Qrated,kc,tau extracted from this Battery mask. Contains no true SOC.

| Parameter | Setting |
|---|---|
| `Value` | `observer_parameters` |

## 25. SOC estimation

**Library:** `simulink/User-Defined Functions/MATLAB Function`

Online CC, EKF and augmented EKF. States are SOC and filtered current; the augmented filter adds current bias. All priors start at 60 percent.

No custom numerical setting; library defaults and inherited signal rate are used.

## 26. Estimator outputs

**Library:** `simulink/Signal Routing/Demux`

Separates the four observer outputs: CC percent, EKF percent, bias-EKF percent, estimated bias A.

| Parameter | Setting |
|---|---|
| `Outputs` | `4` |

## 27. Send SOCcc

**Library:** `simulink/Signal Routing/Goto`

Routes SOCcc by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCcc` |
| `TagVisibility` | `global` |

## 28. Send SOCekf

**Library:** `simulink/Signal Routing/Goto`

Routes SOCekf by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCekf` |
| `TagVisibility` | `global` |

## 29. Send SOCaug

**Library:** `simulink/Signal Routing/Goto`

Routes SOCaug by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCaug` |
| `TagVisibility` | `global` |

## 30. Send Ibias

**Library:** `simulink/Signal Routing/Goto`

Routes Ibias by name to Scopes/observer without long crossing wires.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Ibias` |
| `TagVisibility` | `global` |

## 31. Battery V I SOC

**Library:** `simulink/Sinks/Scope`

Primary Scope: voltage, signed battery current and built-in SOC on separate axes.

| Parameter | Setting |
|---|---|
| `NumInputPorts` | `3` |

## 32. Voltage to Scope

**Library:** `simulink/Signal Routing/From`

Receives signal Vpack from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Vpack` |

## 33. Current to Scope

**Library:** `simulink/Signal Routing/From`

Receives signal Ipack from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Ipack` |

## 34. SOC to Scope

**Library:** `simulink/Signal Routing/From`

Receives signal SOCtrue from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCtrue` |

## 35. SOC comparison

**Library:** `simulink/Sinks/Scope`

Shows true SOC, Coulomb counting, EKF and bias-EKF together in percent.

| Parameter | Setting |
|---|---|
| `NumInputPorts` | `4` |

## 36. Truth comparison

**Library:** `simulink/Signal Routing/From`

Receives signal SOCtrue from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCtrue` |

## 37. CC comparison

**Library:** `simulink/Signal Routing/From`

Receives signal SOCcc from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCcc` |

## 38. EKF comparison

**Library:** `simulink/Signal Routing/From`

Receives signal SOCekf from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCekf` |

## 39. Augmented comparison

**Library:** `simulink/Signal Routing/From`

Receives signal SOCaug from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCaug` |

## 40. Discharge and regeneration

**Library:** `simulink/Sinks/Scope`

Shows two nonnegative branch source commands and measured signed net battery current. Ideal-source branch currents equal their commands.

| Parameter | Setting |
|---|---|
| `NumInputPorts` | `3` |

## 41. Discharge to Scope

**Library:** `simulink/Signal Routing/From`

Receives signal Idischarge from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Idischarge` |

## 42. Regen to Scope

**Library:** `simulink/Signal Routing/From`

Receives signal Iregen from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Iregen` |

## 43. Net current to Scope

**Library:** `simulink/Signal Routing/From`

Receives signal Ipack from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Ipack` |

## 44. Sensor bias estimate

**Library:** `simulink/Sinks/Scope`

Displays the augmented EKF current-offset estimate. The injected offset is 1.2 A.

| Parameter | Setting |
|---|---|
| `NumInputPorts` | `1` |

## 45. Bias to Scope

**Library:** `simulink/Signal Routing/From`

Receives signal Ibias from its matching Goto.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Ibias` |

## 46. Saved test data

**Library:** `simulink/Ports & Subsystems/Subsystem`

Records the same Scope signals at 1 s for automated checks and the results table.

No custom numerical setting; library defaults and inherited signal rate are used.

## 47. Saved test data/SOCtrue

**Library:** `simulink/Signal Routing/From`

Fetches SOCtrue for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCtrue` |

## 48. Saved test data/SOCcc

**Library:** `simulink/Signal Routing/From`

Fetches SOCcc for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCcc` |

## 49. Saved test data/SOCekf

**Library:** `simulink/Signal Routing/From`

Fetches SOCekf for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCekf` |

## 50. Saved test data/SOCaug

**Library:** `simulink/Signal Routing/From`

Fetches SOCaug for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `SOCaug` |

## 51. Saved test data/Ipack

**Library:** `simulink/Signal Routing/From`

Fetches Ipack for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Ipack` |

## 52. Saved test data/Vpack

**Library:** `simulink/Signal Routing/From`

Fetches Vpack for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Vpack` |

## 53. Saved test data/Idischarge

**Library:** `simulink/Signal Routing/From`

Fetches Idischarge for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Idischarge` |

## 54. Saved test data/Iregen

**Library:** `simulink/Signal Routing/From`

Fetches Iregen for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Iregen` |

## 55. Saved test data/Ibias

**Library:** `simulink/Signal Routing/From`

Fetches Ibias for repeatable validation only.

| Parameter | Setting |
|---|---|
| `GotoTag` | `Ibias` |

## 56. Saved test data/Combine

**Library:** `simulink/Signal Routing/Mux`

Combines nine scalar channels in the documented order.

| Parameter | Setting |
|---|---|
| `Inputs` | `9` |

## 57. Saved test data/Log

**Library:** `simulink/Sinks/To Workspace`

Saves all nine channels as a timeseries named recorded, at 1 s; Scopes remain the primary output.

| Parameter | Setting |
|---|---|
| `VariableName` | `recorded` |
| `SaveFormat` | `Timeseries` |
| `SampleTime` | `1` |

## Battery auto-derived discharge parameters

These are the generic SPS nominal-parameter preset values, not manufacturer test data. Temperature and aging options are disabled; their inactive default fields do not affect this run.

- `NomV = 350`
- `NomQ = 114.2857142857`
- `SOC = 80`
- `Batt_Tr = 30`
- `MaxQ = 114.2857`
- `MinV = 262.5`
- `FullV = 407.3955`
- `Dis_rate = 49.6894`
- `R = 0.030625`
- `Normal_OP = 103.354`
- `expZone = [378.135      5.614907]`

## Scope settings

All Scopes: 0 to 1800 s, grid and legend enabled, complete run retained (point limit disabled). Battery Scope: 3 rows, V [320,420], A [-80,140], SOC [35,85]. SOC comparison: one axis, [30,85] percent. Branch currents: one axis, [-80,140] A. Bias Scope: [-2,5] A.

## Observer settings

`battery_observers.m` is embedded in the MATLAB Function block. Both EKFs use the native Battery nonlinear voltage model, including separate charging/discharging polarization expressions. The CC and both EKF prior SOC values are 0.60; initial filtered current is 0 A and initial bias is 0 A.

EKF covariance P0=diag([0.15^2,25]); process Q=diag([1e-8,0.1]). Bias EKF P0=diag([0.15^2,25,1]); process Q=diag([1e-8,0.1,1e-5]). Measurement variance R=0.2^2 V^2 (slightly larger than the injected 0.15^2 to allow model discretization error). Joseph covariance updates are used. Jacobian differences: SOC +/-1e-5; filtered current +/-1e-3 A. SOC is bounded 0 to 1; bias is bounded +/-5 A. The derivative evaluation stays within SOC 0.05 to 0.99. These limits stabilize this mid-SOC test; they do not validate empty/full operation.

The observer constants `[E0 K A B R Qinternal Qrated kc tau]` are:

`[379.525650451 0.0229436828398 29.3915870716 0.534292035398 0.030625 118.171428571 114.285714286 0.1 10]`

Raw dialog values, including inactive/default fields, for every listed block are saved in `Exact_block_parameters.json`. Internal implementation blocks inside linked MathWorks library components are not separately edited.
