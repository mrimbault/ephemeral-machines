#!/bin/bash
#
# Script to run on machines to manage (start, stop, restart, reload) a
# PostgreSQL instance using the specified init system.
# This script must be run with PostgreSQL superuser privileges (as "postgres"
# for instance).
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
pgversion=""
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -a    Action, like reload, restart, stop, start
    -v    PostgreSQL major version
  NOT MANDATORY OPTIONS:
    -i <init_system>    Init system if not SysV (like systemd)
" "$script_name"
}

# Get script arguments.
while getopts 'a:i:v:' flag; do
  case "${flag}" in
    a) action="${OPTARG}" ;;
    i) init_system="${OPTARG}" ;;
    v) pgversion="${OPTARG}" ;;
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
if [ -z "$pgversion" ]; then
    print_usage
    die "Option -v is required."
fi

# FIXME check for supported actions before?
if [ "$init_system" == "SysV" ]; then
    # SysV initialization.
    pgservice="postgresql-${pgversion}"
    service "${pgservice}" "${action}"
elif [ "$init_system" == "systemd" ]; then
    # systemd initialization.
    pgunit="postgresql-${pgversion}.service"
    systemctl "${action}" "${pgunit}"
else
    die "Unsupported init system: \"${init_system}\""
fi


