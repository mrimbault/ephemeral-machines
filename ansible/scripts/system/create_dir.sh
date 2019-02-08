#!/bin/bash
#
# Script to run on machines to create a directory, optionally specifying its
# owner (required to be super-user to do so) and access permissions.
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
dir_path=""
dir_owner=""
dir_permissions=""
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -P <dir_path>         Full path for the directory to be created
  NOT MANDATORY OPTIONS:
    -o <dir_owner>        User to be set as owner for the directory (requires
                          super-user access)
    -p <dir_permissions>  Access permissions to set on the directory
  " "$script_name"
}

# Get script arguments.
while getopts 'o:p:P:' flag; do
  case "${flag}" in
    o) dir_owner="${OPTARG}" ;;
    p) dir_permissions="${OPTARG}" ;;
    P) dir_path="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Mandatory options must have been provided.
if [ -z "$dir_path" ]; then
    print_usage
    die 'Option "-P" is required.'
fi

# Must run using superuser privileges if changing directory owner.
if [ -n "$dir_owner" ] && [ "$user_id" -ne 0 ]; then
    print_usage
    die 'Option "-o" requires this script to be run as super-user.'
fi

# Create the directory if it does not exist already.
# FIXME what about adding "-p" option?
[ ! -d "$dir_path" ] && mkdir "$dir_path"

# Change the owner if required.
[ -n "$dir_owner" ] && chown "$dir_owner": "$dir_path"

# Change the access permissions if required.
[ -n "$dir_permissions" ] && chmod "$dir_permissions" "$dir_path"

