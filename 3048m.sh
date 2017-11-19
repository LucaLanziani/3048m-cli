#!/bin/bash
set -o errexit

API_URL="https://app.10000ft.com/api"
COOKIE_FILE=".3048.cookie"

COMMANDS=$(grep "^function\s\+cmd_" < "$0" | awk '{gsub("cmd_", ""); $1=$3=""; print "\t", $0}' )

function usage {
    echo "Possible commands:"
    echo "$COMMANDS"
}

function authenticate {

    if [ -z "$PASSWORD" ]; then
        # shellcheck source=/dev/null
        [ -f ~/.3048m ] && source ~/.3048m

        if [ -n "$PASSWORD_PGP" ]; then
            PASSWORD=$(echo -e "$PASSWORD_PGP" | gpg2 -q --decrypt)
        fi

        if [ -z "$USERNAME" ]; then
            echo "Please enter your username:"
            read -r USERNAME
        fi

        if [ -z "$PASSWORD" ]; then
            echo "Please enter your password:"
            read -r PASSWORD
        fi

        AUTH=$(curl -s -j -c $COOKIE_FILE "${API_URL}/sessions/signin" -H 'Content-Type: application/json' --data-binary "{\"user_id\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
        USERID=$(echo "$AUTH" | jq '.user_id')
    fi
}

function set_dates {
    month_shift=$1
    [ -n "$month_shift" ] || month_shift=0

    FIRST_DAY=$(date -d "-$(($(date +%d)-1)) days -$month_shift month" +"%Y-%m-%d")
    LAST_DAY=$(date -d "-$(date +%d) days +1 month -$month_shift month" +"%Y-%m-%d")
}

function cmd_entries { # entries [<MONTH_BEHIND>]
    authenticate
    set_dates "$1"
    ENTRIES=$(curl -s -L -b $COOKIE_FILE  "${API_URL}/v1/users/$USERID/time_entries?from=$FIRST_DAY&to=$LAST_DAY")
    ENTRIES_DATA=$(echo "$ENTRIES" | jq -r '.data')
    # echo "$ENTRIES_DATA" | jq -r '"Total = \(map(.hours) | add) hours"'

    PROJECTS=$(cmd_projects)
    echo "{\"projects\": ${PROJECTS}, \"entries\": ${ENTRIES_DATA} }" | jq -r '.entries[] as $entry | (.projects[]  | select ($entry.assignable_id == .id) ) as $project | [ $project + $entry ]' | jq -rs 'add'
}

function cmd_full_month_report { # full_month_report [<MONTH_BEHIND>]
    authenticate
    set_dates "$1"
    ENTRIES=$(cmd_entries "$@")

    echo -e "DATE\t\tHOURS\tPROJECT\t\tNOTES"
    echo "$ENTRIES" | jq -r '.[] | select(.hours > 0) | ([ .date, .hours, .name, .notes ]) | @tsv'
}

function cmd_month_report { # month_report [<MONTH_BEHIND>]
    ENTRIES=$(cmd_entries "$@")
    echo "$ENTRIES" | jq -r 'group_by(.assignable_type) | map({ name: .[0].name, hours: map(.hours) | add })'
}

function cmd_assignments {
    authenticate
    curl -s -L -b $COOKIE_FILE  "${API_URL}/v1/users/$USERID/assignments"
}

function cmd_projects {
    authenticate
    JSON_PROJECTS=""
    for project in projects holidays leave_types; do
        JSON_PROJECTS="$JSON_PROJECTS$(curl -s -L -b $COOKIE_FILE  ${API_URL}/$project)"
    done
    echo "$JSON_PROJECTS" | jq -rs add
}

function cmd_project_by_name {
    PROJECT_NAME=$1

    cmd_projects | jq -r "map(select(.name == \"$PROJECT_NAME\")) | map({ name: .name, id: .id })"
}

function cmd_entry { # enter_work_day <PROJECT_ID> [<HOURS> <DATE>] (DATE format is YYYY-MM-DD)
    authenticate
    PROJECT_ID=$1
    HOURS=$2
    DATE=$3

    [ -n "$HOURS" ] || HOURS=8
    [ -n "$DATE" ] || DATE=$(date +"%Y-%m-%d")

    ENTRIES=$(curl -s -L -b $COOKIE_FILE "${API_URL}/v1/users/$USERID/time_entries?from=$DATE&to=$DATE")
    N_ENTRIES=$(echo "${ENTRIES}" | jq ".data | length")

    echo "Enter your note for ($DATE): "
    read -r NOTES

    if [ "$N_ENTRIES" -lt 1 ]; then
        curl -X POST -L -b $COOKIE_FILE "${API_URL}/v1/users/$USERID/time_entries" -H 'Content-Type: application/json' --data-binary "{\"user_id\": \"$USERID\", \"assignable_id\": \"$PROJECT_ID\", \"date\": \"$DATE\", \"hours\": \"$HOURS\", \"notes\":\"$NOTES\"}"
    fi

    if [ "$N_ENTRIES" -eq 1 ]; then
        ENTRY_ID=$(echo "${ENTRIES}" | jq ".data | .[0].id")
        curl -X PUT -L -b $COOKIE_FILE "${API_URL}/v1/users/$USERID/time_entries/$ENTRY_ID" -H 'Content-Type: application/json' --data-binary "{\"user_id\": \"$USERID\", \"assignable_id\": \"$PROJECT_ID\", \"date\": \"$DATE\", \"hours\": \"$HOURS\", \"notes\":\"$NOTES\"}"
    fi
}

if [ "$#" == "0" ]; then
    usage
else
    command=$1 && shift

    cmd_"$command" "${@}" || usage
fi