#!/bin/bash
#
# Script to run on machines to initialize a PostgreSQL instance as a standby of
# a primary instance.
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
# FIXME it should be possible to specify some parameters, like PGDATA or
# WAL_DIR, and fallback to primary values if not provided.
# FIXME a simpler way would be to add a config parameter to directly specify
# the script additional options (like basebackup_opts: "-o '-k -X /pgwal'")
# FIXME at this point, only creation with the same values that primary instance
# is supported.
pgdata_dir=""
# FIXME not supported for now
#basebackup_opts=""
pgversion=""
super_user=""
repli_user=""
primary_host=""
wal_get_method=""
# FIXME maybe another value could be passed as an option
application_name="$(hostname)"
script_name="$0"

print_usage() {
    printf "Usage: %s <OPTIONS>
  MANDATORY OPTIONS:
    -v <pgversion>      Major version of PostgreSQL
    -U <repli_user>     PostgreSQL user used to connect streaming replication
    -P <primary_host>   Hostname or IP address of primary PostgreSQL instance
  NOT MANDATORY OPTIONS:
    -S <super_user>     PostgreSQL superuser used to get informations from primary (defaults to <repli_user>)
" "$script_name"
}

# Get script arguments.
while getopts 'n:P:S:U:v:' flag; do
  case "${flag}" in
    P) primary_host="${OPTARG}" ;;
    S) super_user="${OPTARG}" ;;
    U) repli_user="${OPTARG}" ;;
    v) pgversion="${OPTARG}" ;;
    *) print_usage
       die "Unknown option." ;;
  esac
done

# FIXME must run using PostgreSQL superuser privileges.

# Mandatory options must have been provided.
if [ -z "$pgversion" ]; then
    print_usage
    die "Option -v is required."
fi
if [ -z "$repli_user" ]; then
    print_usage
    die "Option -U is required."
fi
if [ -z "$primary_host" ]; then
    print_usage
    die "Option -P is required."
fi

# Set super_user to repli_user if not specified.
if [ -z "$super_user" ]; then
    super_user="$repli_user"
fi

if ! command -v pg_basebackup >/dev/null; then
    die "pg_basebackup is not installed."
    # FIXME we should support other methods than pg_basebackup, like hot or
    # event cold rsync (this is a provisioning script after all, stopping the
    # primary would be trivial)
    # FIXME should specifically require rsync from options, and fail here if
    # not?  Or silently fallback to rsync if pg_basebackup is not present?
fi

# Get PGDATA location.
pgdata_dir=$(psql -w -U "$super_user" -h "$primary_host" -d "postgres" -At -c "SELECT current_setting('data_directory');")
# FIXME in theory, we should also get various configuration files locations,
# like hba_file or config_file (espacially on Debian-like systems).  For now,
# this is not supported.

# Remove all the files from the default instance.
# FIXME check that the isntance is not running
find "${pgdata_dir:?}" -mindepth 1 -delete

# FIXME at this point, we do not support replication slots or archive_command.

# Initialize standby using pg_basebackup.
# Some considerations regarding initializing a standby with pg_basebackup:
# - in 9.1, WAL files can only be fetched after the end of the transfer, so in
#   theorie oldest WAL files could have been recycled at this point ... should
#   not be a problem while doing provisioning though
# - starting with 9.2, the "stream" method becomes available
# - starting with 9.4, it can be used with a replication slot, but not directly
#   (require a workaround using pg_receivexlog)
# - starting with 9.6, it can be used directly with a replication slot
# - starting with 10, it can automatically create one temporary replication slot
# - starting with 10, the "-x" option does not exist anymore, pg_basebackup
#   defaults to "-X stream", with possibility to change this to "fetch" or
#   disable with "none"

# Get comparable version number.
pglongversion=$(psql -w -U "$super_user" -h "$primary_host" -d "postgres" -At -c "SELECT current_setting('server_version_num');")

if [ "$pglongversion" -lt 90100 ]; then
    # Before PG 9.1, pg_basebackup was not available.  Initializing a standby
    # would require building complex scripts involving calls to
    # pg_start_backup() and pg_stop_backup(), and copying files from one server
    # to another.  Probably not worth it for provisioning scripts, these
    # versions are quite old and not supported anymore.
    die "Initializing standby is not supported by this script for PostgreSQL version older than 9.1."
elif [ "$pglongversion" -lt 90200 ]; then
    # In PG 9.1, the only existing WAL get method is "fetch", and "-X" does not
    # exist.
    wal_get_method="-x"
else
    # Starting with PG 9.2 and up to PG 9.6, we better use "stream" option,
    # that that is less prone to a WAL recycling problem that the default
    # "fetch" method (highly improbable in a provisioning context).  We could
    # also use replication slots starting with PG 9.4, but that seems overkill.
    wal_get_method="-Xs"
    # Starting with PG 10, pg_basebackup defaults to stream the WAL files, and
    # even creates a temporary replication slot.  In that case we could just
    # leave the option unspecified, but setting "wal_get_method" to an empty
    # string won't work.
fi

# Initialize the standby using pg_basebackup.
pg_basebackup -w -U "$repli_user" -c "fast" -h "$primary_host" "$wal_get_method" -D "$pgdata_dir"

# The "-R" option of pg_basebackup to automatically build recovery.conf only
# appeared with 9.3, and does not support non-streaming recovery options like
# "restore_command".  So we may as well build the "recovery.conf" file
# ourselves.
# FIXME this should probably be done using a different script, so we can pass
# other values, like "restore_command"
# FIXME this will probably be broken starting with PG 12, as recovery.conf file
# may go away.
recovery_conf_file="${pgdata_dir}/recovery.conf"
cat > "$recovery_conf_file" <<EOF
standby_mode = 'on'
primary_conninfo = 'host=${primary_host} user=${repli_user} application_name=${application_name}'
recovery_target_timeline = 'latest'
EOF

# Get configuration files directory.
config_file=$(psql -w -U "$super_user" -h "$primary_host" -d "postgres" -At -c "SELECT current_setting('config_file');")
config_dir="$(dirname "$config_file")"

# Synchronize configuration files if not in PGDATA.
if [ -n "$config_dir" ] && [ "$config_dir" != "." ] && [ "$config_dir" != "$pgdata_dir" ]; then
    rsync -a "${primary_host}:${config_dir}/" "$config_dir"
fi

