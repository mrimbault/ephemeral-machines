#!/bin/bash
#
# Add a known host to current user ssh configuration.
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
ip=""
resolvname=""
domain=""
fqdn=""
script_name="$0"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -i    IP address of the host to be authorized
    -r    name used to resolv on this address
  NOT MANDATORY OPTIONS:
    -d    domain name used to resolv on this address
" "$script_name"
}

# Get script arguments.
while getopts 'd:i:r:' flag; do
  case "${flag}" in
    d) domain="${OPTARG}" ;;
    i) ip="${OPTARG}" ;;
    r) resolvname="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# Mandatory options must have been provided.
if [ -z "$ip" ]; then
    print_usage
    die 'Option -i is required.'
fi
if [ -z "$resolvname" ]; then
    print_usage
    die 'Option -h is required.'
fi

# Create ssh directory if it does not already exist.
if [ ! -d "${ssh_dir}" ]; then
    mkdir "${ssh_dir}"
fi

# Add host and IP fingerprints to known hosts.
ssh-keyscan -H "${ip}" >> "${ssh_dir}/known_hosts"
ssh-keyscan -H "${resolvname}" >> "${ssh_dir}/known_hosts"
# Also add FQDN fingerprint if domain was provided.
if [ -n "${domain}" ]; then
    fqdn="${resolvname}.${domain}"
    ssh-keyscan -H "${fqdn}" >> "${ssh_dir}/known_hosts"
fi

# Setup correct permissions on .ssh directory and under it.
restorecon -R "$ssh_dir"

