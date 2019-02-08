#!/bin/bash
#
# Add a public ssh key to one user.
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
ssh_dir="${HOME}/.ssh"
ssh_pubkey=""
script_name="$0"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -k    Public key to be added, as a text string
" "$script_name"
}

# Get script arguments.
while getopts 'd:h:i:k:' flag; do
  case "${flag}" in
    k) ssh_pubkey="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Mandatory options must have been provided.
if [ -z "$ssh_pubkey" ]; then
    print_usage
    die 'Option -k is required.'
fi

# Create ssh directory if it does not already exist.
if [ ! -d "${ssh_dir}" ]; then
    mkdir "${ssh_dir}"
fi

# Add the key to authorized keys.
echo "$ssh_pubkey" >> "${ssh_dir}/authorized_keys"

# Setup correct permissions on .ssh directory and under it.
restorecon -R "$ssh_dir"

