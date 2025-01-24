# shared bash functions to use in workflows

# Get the most recent Wednesday. Used to determine the most recent nowcast_date
# for the variant-nowcast-hub.
get_latest_wednesday() {
    local input_date="$1"
    if [ -n "$input_date" ]; then
        echo "$input_date"
    else
        if [ $(date +%u) -eq 3 ]; then
            date +%Y-%m-%d
        else
            date -d'last wednesday' +%Y-%m-%d
        fi
    fi
}

# Create a series of dates formatted to work with a GitHub actions matrix
generate_weekly_dates() {
    if [ $# -ne 2 ]; then
        echo "Usage: generate_weekly_dates YYYY-MM-DD number_of_weeks" >&2
        return 1
    fi

    local start_date=$1
    local weeks=$2
    local current_date=$start_date

    # Format a series of dates for GitHub Actions matrix
    seq 0 7 $(echo "7 * $weeks" | bc) \
    | xargs -I {} date -d "$start_date -{} days" +%Y-%m-%d \
    | jq -R \
    | jq -s '. | map({"nowcast-date": .}) | {"include": .}'
}