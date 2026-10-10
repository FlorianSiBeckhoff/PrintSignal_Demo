# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Beckhoff TwinCAT 3 demo project (TcVersion 3.1.4026.x, 64-bit target) built around generating print signals from NC axes over EtherCAT, with a TwinCAT HMI frontend. `PrintSignalDemo.sln` contains two projects:

- `PrintSignalDemo/`: the TwinCAT XAE system project (`PrintSignalDemo.tsproj`)
  - `PLC/`: PLC project (`PLC.plcproj`, references Tc2_Standard, Tc2_System, Tc3_Module). `MAIN.TcPOU` is still empty; the PLC task is `PlcTask.TcTTO`.
  - `_Config/NC/Axes/`: three NC axes: `PulseTrainAxis`, `Encoder`, `ConfirmationAxis`.
  - `_Config/IO/`: two EtherCAT masters. Device 2: EK1100 → EL2252 (DC-timestamped digital out). Device 3: EK1100/EK1818 couplers with ED2504, EL5101 (encoder), EL1252 (timestamped digital in), EL7041 (stepper).
  - `_Config/PLC/`: PLC instance config and its links to IO/NC.
- `PrintSignalDemo_HMI/`: TwinCAT HMI project (`.hmiproj`, `Desktop.view`, server extension configs under `Server/`, NuGet packages in `packages.config`, TypeScript through `tsconfig.json`).

## Building and tooling

There is no command-line build, lint, or test setup. You build, activate, and run the project in TwinCAT XAE (Visual Studio). From Claude Code, use the `sysman-mcp` MCP tools against the open XAE instance, for example `plc_build`, `plc_errorlist`, `plc_read_code`/`plc_write_code`, `plc_create_pou`, `plc_add_library`, `map_variables`, `activate`, `get_target_state`, and `scan_io_hardware`. Use the `infosys-search` MCP tools to look up Beckhoff documentation (terminals, libraries, NC).

## Editing conventions

- `.TcPOU`, `.TcTTO`, `.plcproj`, `.tsproj`, `.xti`, and `.tmc` files are XML that XAE generates. They carry GUIDs, links, and process-image offsets. Change PLC code, libraries, IO, and mappings through the sysman-mcp tools (or XAE) rather than by hand-editing XML. Only edit the ST inside `<![CDATA[...]]>` blocks directly if no tool is available.
- `PLC.tmc` is tracked on purpose (see `.gitignore`). Commit it along with PLC changes.
- Distributed-clock (DC) settings on the EtherCAT terminals and couplers matter for print-signal timing (see commits "Adjust DC time settings" and "Fixed EK1818"). Don't reset terminal DC/sync settings unintentionally.

## HMI agents (`.coagent/`)

`.coagent/agents/HMI/**/Agents.md` holds instructions for the TwinCAT HMI coding agents (main HMI agent plus server, javascript, and extension-generator subagents). `.coagent/mcp.json` points those agents at local HMI MCP websocket servers (ports 499xx; these ports change between sessions and show up in many commits). To use the same servers from Claude Code, run `scripts/Sync-McpConfig.ps1` after the HMI project is open. It regenerates the gitignored `.mcp.json` from `.coagent/mcp.json`. Then restart Claude Code or run `/mcp`. Key rule from those docs: always resolve PLC symbol names through HMI `FindVariables` before binding, reading, or writing. Never bind to user-typed names.
