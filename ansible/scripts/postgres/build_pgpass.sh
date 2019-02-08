#!/bin/bash
#
# Script to run to dynamically build a .pgpass file.
# This script must be run with the user that will connect to the PostgreSQL
# instance.
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
# Use the connected user homedir.
pgpass_location="${HOME}/.pgpass"
hostname="*"
port="*"
database="*"
username="*"
password=""
script_name="$0"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -P <password>    Password to provide
  NOT MANDATORY OPTIONS:
    -h <hostname>    Hostname concerned by the rule
    -p <port>        Port concerned by the rule
    -d <database>    Database concerned by the rule
    -U <username>    User concerned by the rule
" "$script_name"
}

# Get script arguments.
while getopts 'd:h:p:P:U:' flag; do
  case "${flag}" in
    d) database="${OPTARG}" ;;
    h) hostname="${OPTARG}" ;;
    p) port="${OPTARG}" ;;
    P) password="${OPTARG}" ;;
    U) username="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Mandatory options must have been provided.
if [ -z "$password" ]; then
    print_usage
    die "Option -P is required."
fi

# Create line.
line_content="${hostname}:${port}:${database}:${username}:${password}"
# Add line to the password file.
echo "${line_content}" >> "$pgpass_location"
# Set permissions to 600 so the file will be read by PostgreSQL client.
chmod 600 "$pgpass_location"

