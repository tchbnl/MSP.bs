#!/usr/bin/env bash
# MSP.sh: MSP-like mail server log parser in Bash
# Nathan P. <me@tchbnl.net>
# 0.2a (Postfix)
set -euo pipefail

# Version and mail server variant
# Right now MSP.sh supports Postfix and has a WIP version for Exim
VERSION='0.2a (Postfix)'

# Nice text formatting options
TEXT_BOLD='\e[1m'
TEXT_RED='\e[31m'
TEXT_GREEN='\e[32m'
TEXT_UNSET='\e[0m'

# Path to the Postfix log file. We do rotation stuff further down.
LOG_FILE='/var/log/maillog'

# The RBLs we check against
RBL_LIST=('b.barracudacentral.org'
          'bl.spamcop.net'
          'dnsbl.sorbs.net'
          'spam.dnsbl.sorbs.net'
          'ips.backscatterer.org'
          'zen.spamhaus.org')

# Help message
# Email Steve to discuss current rates and senior discounts
show_help() {
    cat << YOUR_ADVERTISEMENT_HERE
$(echo -e "${TEXT_BOLD}")MSP.sh:$(echo -e "${TEXT_UNSET}") MSP-like mail server log parser in Bash

USAGE: MSP.sh [OPTION]
    --auth              Show mail server stats
    --rotated           Use rotated log files
    --rbl               Check IPs against common RBLs
    --help -h           Show this message
    --version -v        Show version information
YOUR_ADVERTISEMENT_HERE
}

# --auth/mail server stats run
auth_check() {
    # There's no reason to run all this if there's no log file...
    if ! [[ -e "${LOG_FILE}" ]]; then
        echo "No Postfix log found. Check for ${LOG_FILE} or update LOG_FILE in MSP.sh."

        return
    fi

    # If --rotated is passed, we fetch the rotated logs as well using find. Not
    # sure if the basename stuff below is smart or really dumb (maybe both?).
    # shellcheck disable=SC2312
    if [[ "${use_rotated}" = true ]]; then
        mapfile -t LOG_FILE< <(find /var/log -maxdepth 1 -type f \( -name "$(basename "${LOG_FILE}")" -o -name "$(basename "${LOG_FILE}")-*" \) | sort)

        echo -e "${TEXT_BOLD}Heads up:${TEXT_UNSET} Using rotated log files. This could take a bit longer."
        echo
    fi

    echo 'Getting cool Postfix facts...'
    echo

    # Dead simple queue size check. Might expand this in the future to alert if
    # the queue size is too high.
    # shellcheck disable=SC2312
    queue_size="$(postqueue -j 2>/dev/null | wc -l)"

    echo -e "📨 ${TEXT_BOLD}Queue Size:${TEXT_UNSET} ${queue_size}"

    echo "There's nothing else to show here. Have a llama: 🦙"
    echo

    # These are senders that have logged in to actual email accounts
    echo -e "🔑 ${TEXT_BOLD}Authenticated Senders${TEXT_UNSET}"

    # First fetch our list of senders into an array
    # shellcheck disable=SC2312
    if grep -q 'sasl_username=' "${LOG_FILE[@]}"; then
        auth_senders="$(grep 'sasl_username=' "${LOG_FILE[@]}" \
            | awk -F 'sasl_username=' '{print $2}' | awk '{print $1}')"
    else
        auth_senders=
    fi

    # Now sort them into the top 10 results
    if [[ -n "${auth_senders[*]}" ]]; then
        # shellcheck disable=SC2312
        for sender in ${auth_senders}; do
            echo "${sender}"
        done | sort | uniq -c | sort -rn | head -n 10
    fi

    # Or report if no results were found
    if [[ -z "${auth_senders[*]}" ]]; then
        echo 'No authenticated senders found.'
    fi

    echo

    # Directories where unauthenticated mail was sent... IF POSTFIX SUPPORTED
    # THIS. Somebody running a shared mail server should definitely be using
    # Exim. Postfix is much too simple, which is great, except for stuff like
    # detailed logging, which is needed for that use case. This is also where
    # I admit that I do not like Postfix.
    #echo -e "📂 ${TEXT_BOLD}Directories${TEXT_UNSET}"
    #echo

    # System users that have sent mail (like with PHP's mail function)
    echo -e "🧔 ${TEXT_BOLD}User Senders${TEXT_UNSET}"

    # First fetch our list of senders into an array
    # shellcheck disable=SC2312
    if grep -q 'uid=' "${LOG_FILE[@]}"; then
        user_senders="$(grep 'uid=' "${LOG_FILE[@]}" \
            | awk -F 'uid=' '{print $2}' | awk '{print $1}')"
    else
        user_senders=
    fi

    # Now sort them into the top 10 results
    if [[ -n "${user_senders[*]}" ]]; then
        # shellcheck disable=SC2312
        for user in ${user_senders}; do
            getent passwd "${user}" | awk -F ':' '{print $1}'
        done | sort | uniq -c | sort -rn | head -n 10
    fi

    # Or report if no results were found
    if [[ -z "${user_senders[*]}" ]]; then
        echo 'No user senders found.'
    fi

    echo

    # Postfix supports logging subjects as well, but it's not enabled in the
    # default configuration. I've written instructions at
    # https://github.com/tchbnl/MSP.sh/LOGGING.md.
    # Yes I named this function so it lines up with the others. I'm like that.
    echo -e "💌 ${TEXT_BOLD}The Usual Subjects™${TEXT_UNSET}"

    # First fetch our list of subjects into an array
    # shellcheck disable=SC2312
    if grep -q 'Subject:' "${LOG_FILE[@]}"; then
        subjects="$(grep 'Subject:' "${LOG_FILE[@]}" \
            | awk -F 'header Subject: ' '{print $2}' \
            | awk -F ' from localhost\\[127.0.0.1\\]' '{print $1}')"
    else
        subjects=
    fi

    # Now sort them into the top 10 results
    if [[ -n "${subjects[*]}" ]]; then
        # shellcheck disable=SC2312
        for subject in "${subjects[@]}"; do
            echo "${subject}"
        done | sort | uniq -c | sort -rn | head -n 10
    fi

    # Or report if no results were found
    if [[ -z "${subjects[*]}" ]]; then
        echo 'No subjects found (or subject logging is disabled in Postfix).'
    fi
}

# --rbl/RBL check
# TODO: Add support for IPv6 addresses. Oh God.
rbl_check() {
    # Get our list of public IPs
    # shellcheck disable=SC2312
    server_ips="$(hostname -I | xargs -n 1 \
        | grep -Ev '^10.0.0|^127.0.0.1|^172.16.0|^192.168.0|^169.254.0|::')"

    # Not sure when this'd happen, but just in case...
    if [[ -z "${server_ips}" ]]; then
        echo 'No IP addresses found. MSP.sh checks public IPv4 addresses.'

        return
    fi

    echo 'Running RBL checks...'

    # And loop through each one
    for ip in ${server_ips}; do
        # We need to reverse the IP order for checks to "work"
        # This is a quick and dirty solution and will need to be replaced when
        # I add IPv6 support. I'm not looking forward to that.
        reversed_ip="$(echo "${ip}" | awk -F '.' '{print $4 "." $3 "." $2 "." $1}')"

        echo
        echo -e "${TEXT_BOLD}${ip}${TEXT_UNSET}"

        # Now we loop through each RBL inside the IP loop
        for rbl in "${RBL_LIST[@]}"; do
            # These two RBLs are too short for only one tab :(
            if [[ "${rbl}" = 'bl.spamcop.net' || "${rbl}" = 'dnsbl.sorbs.net' ]]; then
                echo -ne "\t${rbl}\t\t"
            else
                echo -ne "\t${rbl}\t"
            fi

            # We dig our reversed IP against each RBL. This might not work for
            # all RBLs, but I haven't been able to fully test it.
            rbl_result="$(dig "${reversed_ip}"."${rbl}" +short)"

            # And now we return the block result depending on what the response
            # from dig was (none = good, something = bad)
            if [[ -n "${rbl_result}" ]]; then
                echo -e "${TEXT_BOLD}${TEXT_RED}LISTED${TEXT_UNSET}"
            else
                echo -e "${TEXT_BOLD}${TEXT_GREEN}GOOD${TEXT_UNSET}"
            fi
        done
    done
}

# Command options
while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
        --auth)
            shift 1

            # New! Support for rotated log files. If --rotated is passed with
            # --auth, we round up the rotated logs as well into LOG_FILE... in
            # the function above. No nutso stuff in the while loop.
            if [[ "${#}" -gt 0 && "${1}" = '--rotated' ]]; then
                use_rotated=true
            else
                use_rotated=
            fi

            auth_check
            exit
            ;;

        # MSP requires --all to check all RBLs. We don't, but I figured I
        # should/might as well add this.
        --rbl | '--rbl --all')
            rbl_check
            exit
            ;;

        --help | -h)
            show_help
            exit
            ;;

        --version | -v)
            echo -e "${TEXT_BOLD}MSP.sh${TEXT_UNSET} ${VERSION}"
            exit
            ;;

        -*)
            echo -e "Not sure what ${1} is supposed to mean..."
            echo
            show_help
            exit
            ;;

        *)
            break
            ;;
    esac
done

# If no options are passed, we show the help message. I might renege on this
# and default to running auth_check.
show_help
