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
setting_name="$1"
setting_value="$2"
script_name="$0"

print_usage() {
    printf "Usage: %s <setting_name> <setting_value>" "$script_name"
}

# Must run using PostgreSQL superuser privileges.
# FIXME how to check this? Just the user name would not be strict enough

# Mandatory options must have been provided.
if [ -z "$setting_name" ]; then
    print_usage
    die "Setting name to be changed must be provided."
fi
if [ -z "$setting_value" ]; then
    print_usage
    die "Value to be set for ${setting_name} setting must be provided."
fi

# Get comparable version number.
pglongversion=$(psql -w -At -c "SELECT current_setting('server_version_num');")

# Check if we can use ALTER SYSTEM based on version.
if [ -z "$pglongversion" ] || [ "$pglongversion" -lt 90400 ]; then
    # PG version is lower than 9.4, or not found (possibly 8.1 or lower).
    use_altersystem="false"
else
    # PG version is at least 9.4.
    use_altersystem="true"
fi

# Change configuration parameter, using ALTER SYSTEM if possible.
if [ "$use_altersystem" = "true" ]; then
    # Check if superuser.
    is_super=$(psql -w -At -c "SELECT current_setting('is_superuser') = 'on';")
    if [ "$is_super" != "t" ]; then
        die "The connected user must be a superuser, like \"postgres\"."
    fi
    sql="ALTER SYSTEM SET ${setting_name} = ${setting_value};"
    psql -w -c "$sql"
else
    # If PG version is older than 9.4, we fall back to using an include file.
    # Get current configuration file path.
    pg_config_file=$(psql -w -At -c "SELECT current_setting('config_file');")
    # Extract only the path, if relative get PGDATA directory instead.
    pg_config_dir="$(dirname "$pg_config_file")"
    if [ -z "$pg_config_dir" ] || [ "$pg_config_dir" == "." ]; then
        pg_config_dir=$(psql -w -At \
                             -c "SELECT current_setting('data_directory');")
    fi
    # Set the full path to the file to be included, using the same directory.
    provisioning_config_file="${pg_config_dir}/provisioning.conf"
    # If include parameter is not already enabled, add it at the end of the
    # file.
    if ! grep -q "^include = " "$pg_config_file" 2>/dev/null; then
        echo "include = '${provisioning_config_file}'" >> "$pg_config_file"
    fi
    # Add setting to be modified at the end of the include file.
    echo "${setting_name} = ${setting_value}" >> "$provisioning_config_file"
fi

