#!/bin/bash
#
# Script to run on machines to manage (start, stop, restart, reload, enable or
# disable) a service using the specified init system.
# This script must be run with superuser priviledges (as "root" or using
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

# FIXME it should be possible to specify some parameters, like PGDATA or
# checksums, and fallback to defaults if not provided.
# FIXME at this point, only creation with default values for the OS is
# supported.
# Initialize variables.
init_system="SysV"
action=""
service=""
enable_cmd=""
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -a    Action, like reload, restart, stop, start
    -s    Service to be managed
  NOT MANDATORY OPTIONS:
    -i <init_system>    Init system if not SysV (like systemd)
    -e <enable_cmd>     Command to enable or disable a service
" "$script_name"
}

# Get script arguments.
while getopts 'a:e:i:s:' flag; do
  case "${flag}" in
    a) action="${OPTARG}" ;;
    e) enable_cmd="${OPTARG}" ;;
    i) init_system="${OPTARG}" ;;
    s) service="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Must run using superuser privileges.
if [ "$user_id" -ne 0 ]; then
    die "This script must be run as root."
fi

# Mandatory options must have been provided.
if [ -z "$action" ] ; then
    print_usage
    die "Option -a is required."
fi
if [ -z "$service" ]; then
    print_usage
    die "Option -s is required."
fi

# FIXME check for supported actions before?
if [ "$init_system" == "SysV" ]; then
    # SysV.
    if [ "$action" == "enable" ] && [ "$enable_cmd" == "chkconfig" ]; then
        chkconfig "$service" on
    elif [ "$action" == "disable" ] && [ "$enable_cmd" == "chkconfig" ]; then
        chkconfig "$service" off
    elif [ "$action" == "enable" ] && [ "$enable_cmd" == "update-rc.d" ]; then
        update-rc.d "$service" enable
    elif [ "$action" == "disable" ] && [ "$enable_cmd" == "update-rc.d" ]; then
        update-rc.d "$service" disable
    else
        service "${service}" "${action}"
    fi
elif [ "$init_system" == "systemd" ]; then
    # systemd.
    pgunit="${service}.service"
    systemctl "${action}" "${pgunit}"
else
    die "Unsupported init system: \"${init_system}\""
fi


