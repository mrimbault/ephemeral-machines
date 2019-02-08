#!/bin/bash
#
# Script to run on machines to configure NTP and setup timezone.
# This script must be run with superuser privileges (as "root" or using
# "sudo").
#
# Put bash on "strict mode".
# See: http://redsymbol.net/articles/unofficial-bash-strict-mode/
# And: https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# Immediately exit on any error.
set -o errexit
# Raise an error when using an undefined variable, instead of silently using
# the empty string.
set -o nounset
# Raise an error when any command involved in a pipe fails, not just the last
# one.
set -o pipefail
# Remove whitespace from default word split characters.
IFS=$'\n\t'

# Declare "die" function, used to exit with an error when preliminary checks
# fail on a script.
die() {
    echo "ERROR: $*"
    exit 1
}

# Initialize variables.
# FIXME allow to setup ntp pools?
init_system="SysV"
timezone=""
timezone_file=""
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  NOT MANDATORY OPTIONS:
    -i <init_system>    Init system if not SysV (like systemd)
    -p <ntp_pool>       Specify NTP pool
    -t <timezone>       Select timezone name
" "$script_name"
}

# Get script arguments.
while getopts 'i:p:t:' flag; do
  case "${flag}" in
    i) init_system="${OPTARG}" ;;
    t) timezone="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Must run using superuser privileges.
if [ "$user_id" -ne 0 ]; then
    die "This script must be run as root."
fi

if [ -n "$timezone" ]; then
    # Setup the timezone.
    timezone_file="/usr/share/zoneinfo/${timezone}"
    if [ -w /etc/localtime ]; then
        rm /etc/localtime
    fi
    ln -s "$timezone_file" /etc/localtime
fi

if [ "$init_system" == "SysV" ]; then
    # SysV initialization.
    chkconfig ntpd on
    service ntpd start
elif [ "$init_system" == "systemd" ]; then
    # systemd initialization.
    systemctl enable ntpd.service
    systemctl start ntpd.service
else
    die "Unsupported init system: \"${init_system}\""
fi


