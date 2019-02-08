#!/bin/bash
#
# Script to run on machines to install a package, for Linux distributions like
# RedHat and CentOS.
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
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <package_name> [other packages...]" "$script_name"
}

# Read script arguments as an array of packages.
IFS=" " read -r -a package_list <<< "$@"

# Check that at least one package has been provided.
if [ ${#package_list[@]} -lt 1 ]; then
    pring_usage
    die "At least one package must be provided."
fi

# Must run using superuser privileges.
if [ "$user_id" -ne 0 ]; then
    die "This script must be run as root."
fi

# Install packages.
yum -y install "${package_list[@]}"

