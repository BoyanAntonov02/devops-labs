#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

DB_FILE="trips.txt"
touch "$DB_FILE"

usage() {
cat <<EOF

✈️  Trip CLI — Travel Budget Inspector

    Commands:
    add <city> <amount>        Add expense
    report <city>              Show city report
    status <city> <budget>     Compare with budget
    stats                      Global statistics
    reset                      Clear all data
    help                       Show help

EOF
}

# -------- VALIDATION --------
is_number() {
    [[ $1 =~ ^[0-9]+([.][0-9]+)?$ ]]
}

require_args() {
    if [[ $# -lt $1 ]]; then
        error "Missing arguments"
        usage
        exit 1
    fi
}

# -------- CORE --------
add_expense() {
    require_args 2 "$@"

    local city="$1"
    local amount="$2"

    if ! is_number "$amount"; then
        error "Amount must be a positive number"
        exit 2
    fi

    echo "$city:$amount" >> "$DB_FILE"
    echo "Added $amount to $city"
}

city_total() {
    local city="$1"
    local total=0
    
    if [[ -f "$DB_FILE" ]]; then
        total=$(awk -F: -v target="$city" '$1 == target {sum += $2} END {print sum+0}' "$DB_FILE")
    fi
    
    printf "%.2f" "$total"
}

report_city() {
    require_args 1 "$@"
    local city="$1"

    echo "Report for $city"
    echo "--------------------"

    local found=false
    
    while IFS=":" read -r c a || [ -n "$c" ]; do
        if [[ "$c" == "$city" ]]; then
            printf "• %-10s %8.2f\n" "$c" "$a"
            found=true
        fi
    done < "$DB_FILE"

    if [ "$found" = false ]; then
        echo "No data for $city"
        return
    fi

    echo "--------------------"
    echo "Total: $(city_total "$city")"
}

status_city() {
    require_args 2 "$@"

    local city="$1"
    local budget="$2"

    is_number "$budget" || { error "Budget must be number"; exit 2; }

    local total
    total=$(city_total "$city")

    echo "Status for $city"
    echo "Spent:  $total"
    echo "Budget: $budget"

    awk -v t="$total" -v b="$budget" 'BEGIN {
        if (t > b) exit 2;
        else if (t > b*0.8) exit 1;
        else exit 0
    }'
}

stats() {
    echo "Global statistics"
    echo "--------------------"
    
    if [[ ! -s "$DB_FILE" ]]; then
        echo "No data yet."
        return
    fi

    awk -F: '{arr[$1]+=$2} END {for (i in arr) printf "• %-10s %8.2f\n", i, arr[i]}' "$DB_FILE"
}

reset_all() {
    > "$DB_FILE"
    echo "All data cleared"
}

COMMAND="${1:-}"

case "$COMMAND" in
    add) shift; add_expense "$@" ;;
    report) shift; report_city "$@" ;;
    status) shift; status_city "$@" ;;
    stats) stats ;;
    reset) reset_all ;;
    help|"") usage ;;
    *) error "Unknown command"; usage; exit 1 ;;
esac