# shared bash functions to use in workflows

get_latest_wednesday() {
    if [ $(date +%u) -eq 3 ]; then
    date +%Y-%m-%d
    else
    date -d'last wednesday' +%Y-%m-%d
    fi
}