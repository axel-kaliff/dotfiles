#!/usr/bin/env bash
# Use Codex's TOML writer so comments and machine-local keys survive deployment.
set -euo pipefail

package=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)
config=$HOME/.codex/config.toml
if [ -L "$config" ]; then
    echo "Refusing to write runtime state through symlinked config: $config" >&2
    exit 1
fi

defaults=$(python3 -c 'import json, sys, tomllib; print(json.dumps(tomllib.load(sys.stdin.buffer)))' < "$package/.codex/dotfiles.config.toml")
request=$(jq -cn --argjson defaults "$defaults" '
    def edits($prefix):
        to_entries[] | ($prefix + [.key]) as $path |
        if (.value | type) == "object" then .value | edits($path)
        else {keyPath: ($path | map(@json) | join(".")), value: .value, mergeStrategy: "replace"} end;
    {id: 2, method: "config/batchWrite", params: {
        reloadUserConfig: false, edits: [$defaults | edits([])]
    }}')

coproc CODEX_CONFIG { exec timeout 30 codex app-server --stdio; }
server_pid=$CODEX_CONFIG_PID
exec {server_in}>&"${CODEX_CONFIG[1]}" {server_out}<&"${CODEX_CONFIG[0]}"
trap 'kill "$server_pid" 2>/dev/null || :; wait "$server_pid" 2>/dev/null || :' EXIT

response_for() {
    local response
    while IFS= read -r -t 15 response <&"$server_out"; do
        if jq -e --argjson id "$1" '.id == $id' <<< "$response" >/dev/null; then
            if jq -e 'has("error")' <<< "$response" >/dev/null; then
                jq -r '.error.message' <<< "$response" >&2
                return 1
            fi
            return 0
        fi
    done
    echo "Codex config API closed or timed out waiting for response $1" >&2
    return 1
}

printf '%s\n' '{"id":1,"method":"initialize","params":{"clientInfo":{"name":"dotfiles","version":"1"}}}' >&"$server_in"
response_for 1
printf '%s\n' '{"method":"initialized"}' "$request" >&"$server_in"
response_for 2
echo "Applied repo preferences to $config"
