#!/bin/bash
#
# Set machines names and IP into "/etc/hosts" file.
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

# FIXME check /etc/nsswitch.conf?
# FIXME check if IP is in correct format?

# Initialize variables.
ip=""
resolvname=""
domain=""
# FIXME add the possibility to specify aliases?
fqdn=""
line_to_add=""
hostsfile="/etc/hosts"
hostsfilecopy="$HOME/hosts.copy"
script_name="$0"
user_id="$(id -u)"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -i <ip>          IP for the virtual machine
    -r <resolvname>  Name associated with this IP
  NOT MANDATORY OPTIONS:
    -d <domain>      Domain for FQDN." "$script_name"
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

# Must run using superuser privileges.
if [ "$user_id" -ne 0 ]; then
    die "This script must be run as root."
fi

# Mandatory options must have been provided.
if [ -z "$ip" ]; then
    print_usage
    die 'Option -i is required.'
fi
if [ -z "$resolvname" ]; then
    print_usage
    die 'Option -r is required.'
fi

# The hosts file must be available for writing.
if [ ! -w "$hostsfile" ]; then
    die "\"${hostsfile}\" is not available for writing."
fi

# Before we start modifying the hosts file, we copy it.
cp -p "$hostsfile" "$hostsfilecopy"

# First it is necessary to clean the hosts file from existing lines that may
# contain the hostname.  For instance, when using the "host_name" method,
# Vagrant adds a line "127.0.0.1  <hostname>" into the hosts file.
# First remove resolvname string found at the end of any line.
sed -i "s/\(\s\)${resolvname}$/\1/" "$hostsfilecopy"
# And then in the middle of any line.
sed -i "s/\(\s\)${resolvname}\(\s\)/\1\2/g" "$hostsfilecopy"

# If domain has been provided, also setup FQDN, and cleanup the hosts file from
# this string.
if [ -n "${domain}" ]; then
    fqdn="${resolvname}.${domain}"
    sed -i "s/\(\s\)${fqdn}$/\1/" "$hostsfilecopy"
    sed -i "s/\(\s\)${fqdn}\(\s\)/\1\2/g" "$hostsfilecopy"
    line_to_add="${ip}   ${fqdn} ${resolvname}"
else
    line_to_add="${ip}   ${resolvname}"
fi

# If after these modifications any line has an IP without any associated name,
# completely remove it.
sed -i -n '/^[[:alnum:]\.:]\+\s\+$/!p' "$hostsfilecopy"

# Then, add the line to the hosts file.
echo "${line_to_add}" >> "$hostsfilecopy"
# Erase the existing file with the modified copy.
cp -p "$hostsfilecopy" "$hostsfile"

