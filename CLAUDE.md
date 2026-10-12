# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Beckhoff TwinCAT 3 demo project (TcVersion 3.1.4026.x, 64-bit target) built around generating print signals from NC axes over EtherCAT, with a TwinCAT HMI frontend. `PrintSignalDemo.sln` contains two projects:

- `PrintSignalDemo/`: the TwinCAT XAE system project (`PrintSignalDemo.tsproj`)
  - `PLC/`: PLC project (`PLC.plcproj`, references ApplicationBase, Tc2_Standard, Tc2_System, Tc3_Module). The PLC task is `PlcTask.TcTTO`. `MAIN` instantiates the components and calls their `CyclicLogic()`. `IO/GVL_IO` holds the `AT %I*`/`%Q*` variables linked to the terminals.
  - `_Config/NC/Axes/`: three NC axes: `PulseTrainAxis`, `Encoder`, `ConfirmationAxis`.
  - `_Config/IO/`: two EtherCAT masters. Device 2: EK1100 → EL2252 (DC-timestamped digital out). Device 3: EK1100/EK1818 couplers with ED2504, EL5101 (encoder), EL1252 (timestamped digital in), EL7041 (stepper).
  - `_Config/PLC/`: PLC instance config and its links to IO/NC.
- `PrintSignalDemo_HMI/`: TwinCAT HMI project (`.hmiproj`, `Desktop.view`, server extension configs under `Server/`, NuGet packages in `packages.config`, TypeScript through `tsconfig.json`).

## Building and tooling

There is no command-line build, lint, or test setup. You build, activate, and run the project in TwinCAT XAE (Visual Studio). From Claude Code, use the `sysman-mcp` MCP tools against the open XAE instance, for example `plc_build`, `plc_errorlist`, `plc_read_code`/`plc_write_code`, `plc_create_pou`, `plc_add_library`, `map_variables`, `activate`, `get_target_state`, and `scan_io_hardware`. Use the `infosys-search` MCP tools to look up Beckhoff documentation (terminals, libraries, NC).

## Editing conventions

- `.TcPOU`, `.TcTTO`, `.plcproj`, `.tsproj`, `.xti`, and `.tmc` files are XML that XAE generates. They carry GUIDs, links, and process-image offsets. Change PLC code, libraries, IO, and mappings through the sysman-mcp tools (or XAE) rather than by hand-editing XML. Only edit the ST inside `<![CDATA[...]]>` blocks directly if no tool is available.
- `PLC.tmc` is tracked on purpose (see `.gitignore`). Commit it along with PLC changes.
- sysman-mcp `plc_create_pou` limits: it can't add methods or properties to an `INTERFACE` (add those in XAE). Adding properties to an FB inside a folder failed once but works now; if it fails again, create the FB at the PLC project root. New properties get Get and Set; delete the `Set` child with `plc_delete_pou` to make one read-only. To write an accessor, call `plc_write_code` with the FB's tid plus `child_name` and `accessor`. Create children one call at a time, not in parallel.
- Distributed-clock (DC) settings on the EtherCAT terminals and couplers matter for print-signal timing (see commits "Adjust DC time settings" and "Fixed EK1818"). Don't reset terminal DC/sync settings unintentionally.

## ApplicationBase library (PLC OOP framework)

PLC function blocks follow the ApplicationBase library (Beckhoff Automation LLC, version `*`, currently resolves to 2.3.1). Infosys has no documentation for it, and the `.library` file is compiled.
- **Source and docs:** read them in `C:\Prj\ApplicationDevelopment_Sample` (outside this repo):
  - its `CLAUDE.md` describes the architecture;
  - `Documentation/*.md` covers each subsystem;
  - the source lives in `ApplicationBase/ApplicationBase/`;
  - `ApplicationDevelopment/Template/` shows how a project is wired (`MAIN` → `Machine` module → `Initialize()`/`CyclicLogic()`).
- **Class names:** list them from the `browsercache` file under `C:\ProgramData\Beckhoff\TwinCAT\PlcEngineering\Managed Libraries\Beckhoff Automation LLC\ApplicationBase\<version>\` (it holds names only, no signatures).
- **Base classes:** components extend `Component` (`FB_Init(..., Name : T_MaxString)`, which stores `_Name`) or `CyclicComponent` (adds `METHOD ABSTRACT CyclicLogic`). Modules (`Module`, `PackMLModule`) collect components through `RegisterWithParent(THIS^)`.
- **IO pattern** (see `AnalogOutput`, `DigitalOutput`):
  - IO comes in as extra `FB_Init` inputs typed `REFERENCE TO <type>`;
  - `FB_Init` stores each one with `THIS^.X REF= X;`;
  - the instance is declared with the inputs bound to GVL IO variables, e.g. `Pwm : PwmOutput_ED2504(Name := 'Pwm', DutyCycleOutput := GVL_IO.ED2504_Ch1_DutyCycle, ...)`;
  - guard every access with `__ISVALIDREF`.
- **Base `FB_Init`:** it runs implicitly. Repeat its parameters (`bInitRetains`, `bInCopyCode`, `Name`) in the derived FB, and don't call `SUPER^.FB_Init`.
- **Interfaces to reuse:**
  - `I_Resettable.Reset()`;
  - `I_TaskResult` (`Busy`/`Error`/`ErrorId`);
  - `I_TransformLRealValue.Transform(Value : LREAL; Reverse : BOOL) : LREAL` for scaling and transfer functions (examples: `AnalogScale` and this project's `RpmToDutyCycle`);
  - `I_Cyclic`.
- **Naming** (no `FB_`/`fb` prefixes):
  - FB names describe the object (`PwmOutput_ED2504`);
  - interfaces use `I_`, structs `ST_`, and private members `_` (`_DutyCycle`);
  - state is exposed through properties with `{attribute 'monitoring' := 'call'}`.
- **Existing components in this project:** `PwmOutput_ED2504` (ED2504 PWM channel: `SetDutyCycle`, `SetFrequency`, `Reset`) and `RpmToDutyCycle` (`RpmLow` → 0 %, `RpmHigh` → 100 %).

## HMI agents (`.coagent/`)

`.coagent/agents/HMI/**/Agents.md` holds instructions for the TwinCAT HMI coding agents (main HMI agent plus server, javascript, and extension-generator subagents). `.coagent/mcp.json` points those agents at three local HMI MCP websocket servers (`hmi-main`, `hmi-serveragent`, `hmi-pythonextension`). Their ports change every engineering session, so port-only diffs in `.coagent/mcp.json` are expected noise. The `tools:` frontmatter in each `Agents.md` uses `<server>__<tool>` names (e.g. `hmi-main__FindVariables`); in Claude Code the same tool appears as `mcp__hmi-main__FindVariables`.

To use the same servers from Claude Code, open the HMI project, then run `pwsh scripts/Sync-McpConfig.ps1` (PowerShell 7, because it uses `utf8NoBOM`). It regenerates the gitignored `.mcp.json` from `.coagent/mcp.json`. Then restart Claude Code or run `/mcp`. If the `hmi-*` servers fail to connect, `.mcp.json` is usually stale. Re-run the script. Key rule from those docs: always resolve PLC symbol names through HMI `FindVariables` before binding, reading, or writing. Never bind to user-typed names.
