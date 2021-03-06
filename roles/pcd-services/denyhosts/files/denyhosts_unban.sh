#!/bin/bash

#################
# CONFIGURATION #
#################
# The $WORK_DIR as set in /etc/denyhosts.conf. You can let this script find the
# setting automatically, or you can set it yourself.
DENYHOSTS_WORK_DIR=$(grep 'WORK_DIR' /etc/denyhosts.conf | grep -v '#' | cut -d '=' -f 2 | sed 's/ //')
#DENYHOSTS_WORK_DIR="/var/lib/denyhosts"

# All the files that contain the blocked IP address and hostname
DENYHOSTS_FILES=(\
    '/etc/hosts.deny' \
    "${DENYHOSTS_WORK_DIR}/hosts" \
    "${DENYHOSTS_WORK_DIR}/hosts-restricted" \
    "${DENYHOSTS_WORK_DIR}/hosts-root" \
    "${DENYHOSTS_WORK_DIR}/hosts-valid" \
    "${DENYHOSTS_WORK_DIR}/users-hosts" \
)
# The file containing the IP addresses and hostnames that can't be blocked
DENYHOSTS_ALLOWED_FILE="${DENYHOSTS_WORK_DIR}/allowed-hosts"
# The command needed to start denyhosts after the IP and/or hostname is unbanned
START_COMMAND='/etc/init.d/denyhosts start'
# The command needed to stop denyhosts before the IP and/or hostname is unbanned
STOP_COMMAND='/etc/init.d/denyhosts stop'

#############################################
# ACTUAL SCRIPT do not edit below this line #
#############################################
# set some default values to a few vars used in the script
# Don't remove an IP address (N=remove, Y=don't remove)
NO_IP='N'
# Don't remove an hostname (N=remove, Y=don't remove)
NO_HOST='N'
# Add the IP address and/or hostname to the allowed list
ADD_ALLOW='N'
# The IP address that has to be removed
IP=''
# The hostname that has to be removed
HOST=''

function show_help()
{
    echo $0
    echo "a small script to unblock an IP address and/or hostname from denyhosts.
-h  | --host    | --hostname     : Specify the hostname to unblock (required, unless -nh is added).
-i  | --ip      | --ipaddress    : Specify the IP address to unblock (required, unless -ni is added).
-nh | --no-host | --no-hostname  : Don't require a hostname to start unblocking things.
-ni | --no-ip   | --no-ipaddress : Don't require an IP address to start unblocking things.
-a  | --add     | --add-allow    : Add the specified IP address and/or hostname to the unblock file, thus preventing that the specified IP address and/or hostname get blocked again.
-H  | --help                     : show this help."
}

# Handle the commandline options
while [ -n "$(echo $1 | grep -- '-')" -a $# -gt 0 ]; do
    case $1 in
        -h  | --host | --hostname) HOST=$2; shift 2;;
        -i  | --ip | --ipaddress) IP=$2; shift 2;;
        -nh | --no-host | --no-hostname) NO_HOST='Y'; shift;;
        -ni | --no-ip | --no-ipaddress) NO_IP='Y'; shift;;
        -a  | --add | --add-allow) ADD_ALLOW='Y'; shift;;
        *)
            echo "Unknown argument $1" 1>&2
            echo ''
            show_help $0
            exit 1
        ;;
    esac
done

# Checks to see if the required IP address and/or hostname are given
if [ "${NO_IP}" == 'N' -a "${IP}" == '' ]; then
    echo 'No IP address given, exiting now' 1>&2
    exit 1
fi
if [ "${NO_HOST}" == 'N' -a "${HOST}" == '' ]; then
    echo 'No hostname given, exiting now' 1>&2
    exit 2
fi

# Show warnings if removing of an IP address and/or hostname is disabled
if [ "${NO_IP}" == 'Y' ]; then
    echo 'WARNING: You disabled removing an IP address. Most bans consist of both an IP address and a hostname. Please double check if you want this. Continuing now.' 1>&2
fi
if [ "${NO_HOST}" == 'Y' ]; then
    echo 'WARNING: You disabled removing a hostname. Most bans consist of both an IP address and a hostname. Please double check if you want this. Continuing now.' 1>&2
fi

# Stopping denyhosts
${STOP_COMMAND}

# Loop through all the denyhost files, to remove the IP address and/or hostname
for FILE in ${DENYHOSTS_FILES[@]}; do
    # Check to see if the current denyhosts file exists, is a normal file, is
    # readable and is writable
    if [ -f "${FILE}" -a -r "${FILE}" -a -w "${FILE}" ] ; then
        # Check to see if there is an IP address to remove
        if [ "${NO_IP}" = 'N' ] ; then
            # Check that the IP address exists in the current denyhosts file
            if grep -q "${IP}" "${FILE}" ; then
                # Remove the IP address from the current denyhosts file
                sed -i "/${IP}/d" "${FILE}"
                echo "Removed ip address ${IP} from ${FILE}"
            else
                # The IP address doesn't exists in the current denyhosts file,
                # notify user
                echo "The ip address ${IP} wasn't in ${FILE}"
            fi
        fi

        # Check to see if there is a hostname to remove
        if [ "${NO_HOST}" = 'N' ] ; then
            # Check that the hostname exists in the current denyhosts file
            if grep -q "${HOST}" "${FILE}" ; then
                # Remove the hostname from the current denyhosts file
                sed -i "/${HOST}/d" "${FILE}"
                echo "Removed hostname ${HOST} from ${FILE}"
            else
                # The hostname doesn't exists in the current denyhosts file,
                # notify user
                echo "The hostname ${HOST} wasn't in ${FILE}"
            fi
        fi
    fi
done

# Check to see if the IP address and/or hostname needs to be added to the
# allowed-hosts file
if [ ${ADD_ALLOW} = 'Y' ] ; then
    # Check to see if there is an IP address to add
    if [ "${NO_IP}" = 'N' ] ; then
        echo "${IP}" >> "${DENYHOSTS_ALLOWED_FILE}"
    fi

    # Check to see if there is a hostname to add
    if [ "${NO_HOST}" = 'Y' ] ; then
        echo "${HOST}" >> "${DENYHOSTS_ALLOWED_FILE}"
    fi
fi

# Start denyhosts again
${START_COMMAND}
