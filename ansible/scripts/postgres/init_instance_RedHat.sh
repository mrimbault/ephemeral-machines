#!/bin/bash
#
# Script to run on machines to initialize and start PostgreSQL instance.
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
# checksums, and fallback to defaults if not provided.
# FIXME a simpler way would be to add a config parameter to directly specify
# the initdb additional options (like initdb_opts: "-o '-k -X /pgwal'")
# FIXME at this point, only creation with default values for the OS is
# supported.
# Initialize variables.
init_system="SysV"
# FIXME not supported for now
#initdb_opts=""
#pgdata_dir="default"
#use_checksums="false"
pgversion=""
script_name="$0"
# FIXME allow an option to change user name
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -v <pgversion>      PostgreSQL major version to be installed
  NOT MANDATORY OPTIONS:
    -i <init_system>    Init system if not SysV (like systemd)
" "$script_name"
}

# Get script arguments.
while getopts 'i:v:' flag; do
  case "${flag}" in
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
if [ -z "$pgversion" ]; then
    print_usage
    die "Option -v is required."
fi

# Set PostgreSQL major version without dots, for versions before PG 10.
pgshortversion="${pgversion//./}"

# FIXME these are not supported for now.
# Setup instance initialization options.
#if [ "$pgdata_dir" != "default" ]; then
#    initdb_opts="${initdb_opts} -D \"${pgdata_dir}\""
#fi
#if [ "$use_checksums" != "false" ]; then
#    initdb_opts="${initdb_opts} -k"
#fi

if [ "$init_system" == "SysV" ]; then
    # SysV initialization.
    pgservice="postgresql-${pgversion}"
    service "${pgservice}" initdb
    chkconfig "${pgservice}" on
    service "${pgservice}" start
elif [ "$init_system" == "systemd" ]; then
    # systemd initialization.
    pgunit="postgresql-${pgversion}.service"
    pgsetup="/usr/pgsql-${pgversion}/bin/postgresql-${pgshortversion}-setup"
    "${pgsetup}" initdb
    systemctl enable "${pgunit}"
    systemctl start "${pgunit}"
else
    die "Unsupported init system: \"${init_system}\""
fi


