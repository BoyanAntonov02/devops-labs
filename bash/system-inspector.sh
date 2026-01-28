#!/usr/bin/env bash
set -euox pipefail
IFS=$'\n\t'

# ==========================================
# System Inspector - Mid-level Bash Tool
# ==========================================

# -------- GLOBALS --------
OUTPUT_TEXT=""
OUTPUT_JSON=""
EXIT_CODE=0

# -------- COLORS --------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -------- LOGGING --------
log()   { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; EXIT_CODE=1; }
error() { echo -e "${RED}[ERROR]${NC} $1"; EXIT_CODE=2; }

cleanup() {
    log "System inspection finished."
}
trap cleanup EXIT

# -------- USAGE --------
usage() {
    cat <<EOF
Usage: $0 [-o report.txt] [-j report.json]

Options:
    -o   Output text report
    -j   Output JSON report
EOF
    exit 1
}

# -------- FLAGS --------
while getopts "o:j:" opt; do
    case $opt in
        o) OUTPUT_TEXT="$OPTARG" ;;
        j) OUTPUT_JSON="$OPTARG" ;;
        *) usage ;;
    esac
done

# -------- FUNCTIONS --------

get_system_info() {
    OS_NAME=""
    OS_VERSION=""

    if [[ -f /etc/os-release ]]; then
        # Linux
        OS_NAME=$(grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '"')
    else
        # macOS / BSD
        OS_NAME="$(uname -s)"
        OS_VERSION="$(sw_vers -productVersion 2>/dev/null || uname -r)"
        OS_NAME="$OS_NAME $OS_VERSION"
    fi

    KERNEL=$(uname -r)
    UPTIME=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
}

get_resources() {
    CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}')

    # ---- DISK ----
    DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')

    echo "CPU Load:$CPU_LOAD"
    echo "Disk Usage: $DISK"
}

check_internet() {
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log "Internet connectivity: OK"
    else
        warn "Internet connectivity: FAILED"
    fi
}

top_processes() {
    echo "Top 5 CPU consuming processes:"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -6
}

check_tools() {
    echo
    echo "Installed tools check:"
    for tool in git docker curl jq; do
        if command -v "$tool" &>/dev/null; then
        log "$tool is installed"
        else
        warn "$tool is missing"
        fi
    done
}

check_thresholds() {
    DISK_PERCENT=$(df / | awk 'NR==2 {gsub("%",""); print $5}')

    if (( DISK_PERCENT > 85 )); then
        warn "Disk usage critical: ${DISK_PERCENT}%"
    else
        log "Disk usage normal: ${DISK_PERCENT}%"
    fi
}

generate_report() {
        echo "=================================="
        echo "      SYSTEM INSPECTOR REPORT     "
        echo "=================================="
        date
        echo

        echo "--- SYSTEM INFO ---"
        get_system_info
        echo

        echo "--- RESOURCES ---"
        get_resources
        echo

        echo "--- TOP PROCESSES ---"
        top_processes
        echo

        echo "--- CONNECTIVITY ---"
        check_internet
        echo

        echo "--- TOOLS ---"
        check_tools
        echo

        echo "--- HEALTH CHECK ---"
        check_thresholds
        echo
}

generate_json() {
cat > "$OUTPUT_JSON" <<EOF
{
    "os": "$OS",
    "kernel": "$KERNEL",
    "uptime": "$UPTIME",
    "cpu_load": "$CPU_LOAD",
    "disk": "$DISK"
}
EOF
log "JSON report written to $OUTPUT_JSON"
}

# -------- MAIN --------
main() {
    log "Starting System Inspector..."

    get_system_info >/dev/null
    get_resources >/dev/null

    generate_report

    [[ -n "$OUTPUT_JSON" ]] && generate_json

    exit $EXIT_CODE
}

main
