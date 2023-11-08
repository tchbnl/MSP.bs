#!/usr/bin/env bash
# MSP.sh: MSP-like mail server log parser in Bash
# Nathan P. <me@tchbnl.net>
# 0.1b (Postfix)
set -euo pipefail

# Version and mail server variant
# Right now MSP.sh supports Postfix and has a WIP version for Exim
VERSION='0.1b (Postfix)'

# Nice text formatting options
TEXT_BOLD='\e[1m'
TEXT_RED='\e[31m'
TEXT_GREEN='\e[32m'
TEXT_UNSET='\e[0m'

# Path to the ${MAIL_SERVER} log file
# TODO: Add support for rotated log files
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
    --rbl               Check IPs against common RBLs
    --help -h           Show this message
    --version -v        Show version information
YOUR_ADVERTISEMENT_HERE
}

# --auth/mail server stats run
# TODO: Add check for log file/empty log file
auth_check() {
    echo 'Getting cool Postfix facts...'
    echo

    # Dead simple queue size check. Might expand this in the future to alert if
    # the queue size is too high.
    queue_size="$(postqueue -j 2>/dev/null | wc -l || true)"

    echo -e "📨 ${TEXT_BOLD}Queue Size:${TEXT_UNSET} ${queue_size}"

    echo "There's nothing else to show here. Have a llama: 🦙"
    echo

    # These are senders that have logged in to actual email accounts
    echo -e "🔑 ${TEXT_BOLD}Authenticated Senders${TEXT_UNSET}"

    # First fetch our list of senders
    auth_senders="$(grep 'sasl_username=' "${LOG_FILE}" \
        | awk -F 'sasl_username=' '{print $2}' | awk '{print $1}' || true)"

    # And then sort through them - or return none with a message
    if [[ -n "${auth_senders}" ]]; then
        for sender in ${auth_senders}; do
            echo "${sender}"
        done | sort | uniq -c | sort -rn | head -n 10 || true
    else
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

    # First fetch our list of senders
    user_senders="$(grep 'uid=' "${LOG_FILE}" | awk -F 'uid=' '{print $2}' \
        | awk '{print $1}' || true)"

    # And then sort through them - or return none with a message
    if [[ -n "${user_senders}" ]]; then
        for user in ${user_senders}; do
            getent passwd "${user}" | awk -F ':' '{print $1}' || true
        done | sort | uniq -c | sort -rn | head -n 10 || true
    else
        echo 'No user senders found.'
    fi
    echo

    # Postfix supports logging subjects as well, but it's not enabled in the
    # default configuration. I've written instructions at
    # https://github.com/tchbnl/MSP.sh/LOGGING.md.
    echo -e "💌 ${TEXT_BOLD}The Usual Subjects™${TEXT_UNSET}"

    # First fetch our list of send- *COUGH* I mean subjects
    # THIS LOOKS CURSED BUT I SWEAR IT WORKS
    subjects="$(grep 'Subject:' "${LOG_FILE}" | awk -F 'header Subject: ' '{print $2}' \
        | awk -F ' from localhost\\[127.0.0.1\\]' '{print $1}' || true)"

    # And then sort through them - or return none with a message
    if [[ -n "${subjects}" ]]; then
        for subject in "${subjects}"; do
            echo "${subject}"
        done | sort | uniq -c | sort -rn | head -n 10 || true
    else
        echo 'No subjects found (or subject logging is disabled in Postfix).'
    fi
}

# --rbl/RBL check
# TODO: Add support for IPv6 addresses. Oh God.
rbl_check() {
    echo 'Running RBL checks...'

    # Get our list of public IPs
    server_ips="$(hostname -I | xargs -n 1 \
        | grep -Ev '^10.0.0|^127.0.0.1|^172.16.0|^192.168.0|^169.254.0|::' || true)"

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
