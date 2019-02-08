#!/bin/bash
#
# Script to run on machines to initialize and start PostgreSQL instance as a
# standby of a primary instance.
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

# FIXME it should be possible to specify some parameters, like PGDATA or
# WAL_DIR
# Initialize variables.
init_system="SysV"
pgversion=""
instance_name="main"
# FIXME allow an option to change user name
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -v <pgversion>      PostgreSQL major version
  NOT MANDATORY OPTIONS:
    -n <instance_name>  PostgreSQL instance name (default to \"main\")
    -i <init_system>    Init system if not SysV (like systemd)
" "$script_name"
}

# Get script arguments.
while getopts 'i:n:v:' flag; do
  case "${flag}" in
    i) init_system="${OPTARG}" ;;
    n) instance_name="${OPTARG}" ;;
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
if [ -z "$pgversion" ]; then
    print_usage
    die "Option -v is required."
fi

# The instance has been created using pg_basebackup, we need to use Debian
# wrapper to integrate this instance management.
pg_createcluster "$pgversion" "$instance_name"

# In Debian, services are already enabled by default when the package is
# installed.  FIXME so we just need to call the manage script?
if [ "$init_system" == "SysV" ]; then
    # SysV initialization.
    pgservice="postgresql@${pgversion}-${instance_name}"
    service "${pgservice}" start
elif [ "$init_system" == "systemd" ]; then
    # systemd initialization.
    pgunit="postgresql@${pgversion}-${instance_name}.service"
    systemctl start "${pgunit}"
else
    die "Unsupported init system: \"${init_system}\""
fi

