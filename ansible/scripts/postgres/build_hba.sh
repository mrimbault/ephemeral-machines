#!/bin/bash
#
# Script to run to dynamically build a pg_hba.conf file.
# This script must be run with PostgreSQL instance owner (as "postgres" for
# instance).
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
hba_location=""
init_hba=""
line_content=""
script_name="$0"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS (mutually exclusives):
    -i                 Initialize hba file, removing all existing lines
    -l <line_content>  String to be added to the hba file as a new line" "$script_name"
}

# Get script arguments.
while getopts 'il:' flag; do
  case "${flag}" in
    i) init_hba="true" ;;
    l) line_content="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Mandatory options must have been provided.
if [ -n "$line_content" ] && [ -n "$init_hba" ]; then
    print_usage
    die "Options -l and -i are not mutually exclusives."
fi
if [ -z "$line_content" ] && [ -z "$init_hba" ]; then
    print_usage
    die "Either -l or -i must be provided."
fi

# FIXME check if running with PostgreSQL hba file owner

# Get hba file location.
hba_location=$(psql -w -At -c "SELECT current_setting('hba_file');")

# Check we have write permissions to the hba file.
if [ ! -w "$hba_location" ]; then
    die "Cannot write to \"${hba_location}\" file."
fi

# Create a new hba file.
if [ "$init_hba" = "true" ]; then
    tmsp=$(date +"%T")
    cp -p "$hba_location" "${hba_location}.${tmsp}"
    cat > "$hba_location" <<EOF
# hba file generated by Ansible at $tmsp
# TYPE  DATABASE        USER            ADDRESS             METHOD
EOF
fi
if [ -n "$line_content" ]; then
    echo "${line_content}" >> "$hba_location"
fi
