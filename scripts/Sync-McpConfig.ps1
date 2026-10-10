# Regenerates .mcp.json (Claude Code project MCP config) from .coagent/mcp.json.
# The TwinCAT HMI MCP servers get new websocket ports every engineering session,
# so run this after opening the HMI project, then restart Claude Code or run /mcp.
$root = Split-Path $PSScriptRoot -Parent
$source = Get-Content (Join-Path $root '.coagent/mcp.json') -Raw | ConvertFrom-Json

$servers = [ordered]@{}
foreach ($p in $source.mcpServers.PSObject.Properties) {
    $servers[$p.Name] = [ordered]@{ type = 'ws'; url = $p.Value.url }
}

[ordered]@{ mcpServers = $servers } |
    ConvertTo-Json -Depth 5 |
    Set-Content (Join-Path $root '.mcp.json') -Encoding utf8NoBOM

$servers.GetEnumerator() | ForEach-Object { "$($_.Key) -> $($_.Value.url)" }
