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

# Create a JSON array of weekly dates, working backwards from an input date,
# for a specified number of weeks. Used to populate a matrix strategy in the
# GitHub workflow that creates target data.
generate_weekly_dates() {
    if [ $# -ne 2 ]; then
        echo "Usage: generate_weekly_dates YYYY-MM-DD number_of_weeks" >&2
        return 1
    fi

    local start_date=$1
    local weeks=$2
    local dates=("$start_date")
    local current_date=$start_date

    # Generate dates and format as JSON array
    echo -n '{"nowcast-date":"['
    echo -n "'$start_date'"
    
    for ((i=1; i<=$weeks; i++)); do
        current_date=$(gdate -d "$current_date - 7 days" +%Y-%m-%d)
        echo -n ",'$current_date'"
    done
    echo ']"}'
}