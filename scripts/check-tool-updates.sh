#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DOCKERFILE=${DOCKERFILE:-"$ROOT_DIR/Dockerfile"}
CHECK_TOOL_UPDATES_STRICT=${CHECK_TOOL_UPDATES_STRICT:-0}

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 2
    fi
}

arg_default() {
    sed -n "s/^ARG $1=//p" "$DOCKERFILE" | tail -n 1
}

json_get() {
    python3 -c '
import json
import sys

value = json.load(sys.stdin)
for part in sys.argv[1].split("."):
    value = value[part]
print(value)
' "$1"
}

latest_github_release() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" | json_get tag_name
}

latest_pypi_version() {
    curl -fsSL "https://pypi.org/pypi/$1/json" | json_get info.version
}

latest_npm_version() {
    curl -fsSL "https://registry.npmjs.org/$1/latest" | json_get version
}

latest_matching_git_tag() {
    repo=$1
    pattern=$2
    git ls-remote --tags --refs "https://github.com/${repo}.git" "$pattern" \
        | awk '{ sub("refs/tags/", "", $2); print $2 }' \
        | python3 -c '
import re
import sys

tags = [line.strip() for line in sys.stdin if line.strip()]
if not tags:
    raise SystemExit(1)

def key(tag):
    return tuple(int(part) for part in re.findall(r"\d+", tag))

print(max(tags, key=key))
'
}

print_row() {
    tool=$1
    current=$2
    latest=$3

    if [ "$current" = "$latest" ]; then
        status=ok
    else
        status=update-available
        updates_available=1
    fi

    printf '%-12s %-28s %-28s %s\n' "$tool" "$current" "$latest" "$status"
}

need curl
need git
need python3

updates_available=0

yosys_ref=$(arg_default YOSYS_REF)
nextpnr_ref=$(arg_default NEXTPNR_REF)
sv2v_ref=$(arg_default SV2V_REF)
apycula_version=$(arg_default APYCULA_VERSION)
netlistsvg_version=$(arg_default NETLISTSVG_VERSION)
verible_ref=$(arg_default VERIBLE_REF)

printf '%-12s %-28s %-28s %s\n' "tool" "current" "latest" "status"
printf '%-12s %-28s %-28s %s\n' "----" "-------" "------" "------"

print_row yosys "$yosys_ref" "$(latest_github_release YosysHQ/yosys)"
print_row nextpnr "$nextpnr_ref" "$(latest_matching_git_tag YosysHQ/nextpnr 'nextpnr-*')"
print_row sv2v "$sv2v_ref" "$(latest_github_release zachjs/sv2v)"
print_row apycula "$apycula_version" "$(latest_pypi_version apycula)"
print_row netlistsvg "$netlistsvg_version" "$(latest_npm_version netlistsvg)"
print_row verible "$verible_ref" "$(latest_github_release chipsalliance/verible)"

echo
echo "Debian-packaged runtime tools are updated by rebuilding from the current base image repositories."

if [ "$updates_available" -ne 0 ] && [ "$CHECK_TOOL_UPDATES_STRICT" = "1" ]; then
    exit 1
fi
