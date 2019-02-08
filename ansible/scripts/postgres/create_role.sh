#!/bin/bash
#
# Script to run to dynamically change a PostgreSQL instance settings.
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

# FIXME at this point, custom PGDATA is not supported
# Initialize variables.
role_name=""
role_password=""
role_attributes=""
script_name="$0"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -n <role_name>       Name of the role to be created
  NOT MANDATORY OPTIONS:
    -P <role_password>   Password of the role to be created (WARNING: not secured)
    -A <role_attributes> List of role's attributes
" "$script_name"
}

# Get script arguments.
while getopts 'A:n:P:' flag; do
  case "${flag}" in
    A) role_attributes="${OPTARG}" ;;
    n) role_name="${OPTARG}" ;;
    P) role_password="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Must run using PostgreSQL superuser privileges.
# FIXME how to check this? Just the user name would not be strict enough

# Mandatory options must have been provided.
if [ -z "$role_name" ]; then
    print_usage
    die "Role name to be created must be provided."
fi

# Define SQL query.
sql="CREATE ROLE ${role_name}"
if [ -n "${role_attributes}" ]; then
    sql="${sql} ${role_attributes}"
fi
if [ -n "${role_password}" ]; then
    # FIXME add an option to provide encrypted password?
    sql="${sql} PASSWORD '${role_password}'"
fi
sql="${sql};"

# Check if superuser.
is_super=$(psql -w -At -c "SELECT current_setting('is_superuser') = 'on';")
if [ "$is_super" != "t" ]; then
    die "The connected user must be a superuser, like \"postgres\"."
fi

# Create the role.
psql -w -c "$sql"

