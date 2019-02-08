#!/bin/bash
#
# Generate ssh key for one user.
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
print_stdout=""
ssh_dir="${HOME}/.ssh"
script_name="$0"

print_usage() {
    printf "Usage: %s <OPTIONS>
  NOT MANDATORY OPTIONS:
    -p    Print public key to stdout
" "$script_name"
}

# Get script arguments.
while getopts 'p' flag; do
  case "${flag}" in
    p) print_stdout="true" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Generate key without passphrase.
ssh_key="${ssh_dir}/id_rsa"
ssh-keygen -q -f "${ssh_key}" -t "rsa" -N ""
if [ -n "$print_stdout" ]; then
    # Print the public key to stdout.
    cat "${ssh_key}.pub"
fi

