#!/bin/bash
#
# Script to run on machines to add a "deb" repository, for Linux distributions
# like Debian and Ubuntu.
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
distro_name=""
repo_key=""
repo_name=""
repo_url=""
update_flag=""
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -n <repo_name>   Repository name.
    -u <repo_url>    Repository full URL.
    -c <distro_name> Distribution codename.
  NOT MANDATORY OPTIONS:
    -k <repo_key>    Repository signing key.
    -U               Update repositories cache." "$script_name"
}

# Get script arguments.
while getopts 'c:k:n:u:U' flag; do
  case "${flag}" in
    c) distro_name="${OPTARG}" ;;
    k) repo_key="${OPTARG}" ;;
    n) repo_name="${OPTARG}" ;;
    u) repo_url="${OPTARG}" ;;
    U) update_flag="true" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Must run using superuser privileges.
if [ "$user_id" -ne 0 ]; then
    die "This script must be run as root."
fi

# Mandatory options must have been provided.
if [ -z "$distro_name" ]; then
    print_usage
    die 'Option -c is required.'
fi
if [ -z "$repo_name" ]; then
    print_usage
    die 'Option -n is required.'
fi
if [ -z "$repo_url" ]; then
    print_usage
    die 'Option -u is required.'
fi

# Set repository file path.
repo_file="/etc/apt/sources.list.d/${repo_name}.list"

# Create repository file.
cat > "$repo_file" << EOF
     deb ${repo_url} ${distro_name}-${repo_name} main
EOF

# If repository signing key has been provided, add it.
if [ -n "$repo_key" ]; then
    wget --quiet -O - "$repo_key" | apt-key add -
fi

# Update repositories.
if [ "$update_flag" == "true" ]; then
    apt-get update
fi

