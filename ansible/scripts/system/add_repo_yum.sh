#!/bin/bash
#
# Script to run on machines to add a "rpm" repository, for Linux distributions
# like RedHat and CentOS.
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

# FIXME what about repository signing key?

# Initialize variables.
repo_name=""
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -n <repo_name>   Repository name or full URL." "$script_name"
}

# Get script arguments.
while getopts 'n:' flag; do
  case "${flag}" in
    n) repo_name="${OPTARG}" ;;
    *) print_usage
       die "Unknown option provided." ;;
  esac
done

# Must run using superuser privileges.
if [ "$user_id" -ne 0 ]; then
    die "This script must be run as root."
fi

# Mandatory options must have been provided.
if [ -z "$repo_name" ]; then
    print_usage
    die 'Option -n is required.'
fi

# FIXME add a joker to the repo package name so we can get the last version
# Add repository.
yum -y install "$repo_name"

