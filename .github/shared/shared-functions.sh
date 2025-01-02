# shared bash functions to use in workflows

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