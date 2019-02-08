#!/bin/bash
#
# Script to run on machines to create PostgreSQL PGDATA directory if required.
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

# Initialize variables.
pgdata_dir=""
pgdata_opts=""
use_checkums=""
script_name="$0"
# FIXME allow an option to change user name
pguser="postgres"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <pgdata_dir>
" "$script_name"
}

# Get script arguments.
while getopts ':D:k' flag; do
  case "${flag}" in
    D) pgdata_dir="${OPTARG}" ;;
    k) use_checkums="true" ;;
    i) ip="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Must run using superuser privileges.
if [ "$user_id" -ne 0 ]; then
    die "This script must be run as root."
fi

# Setup instance initialization options.
if [ -n "$pgdata_dir" ]; then
    init_opts="${init_opts} -D \"${pgdata_dir}\""
fi
if [ -n "$use_ckecksums" ]; then
    init_opts="${init_opts} -k"
fi


# FIXME initdb


