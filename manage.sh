#!/bin/bash
#
# This script is provided to easily deploy new virtual machines configuration
# directories, or manage existing ones.
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

# Variables definition.
script_name="$0"
source_dir="$(dirname "$0")"
templates_dir="${source_dir}/config-templates/"
# This variable content can be changed using "EM_MAIN_DIR" environement
# variable, or "-d" flag.
global_dir="${HOME}/ephemeral-machines"
configuration_name=""

die() {
    echo "ERROR: $*"
    exit 1
}

print_usage() {
    printf "Usage: %s <ACTION> <OPTIONS>
  ACTIONS (must provide only one, and it must be the first argument):
    list:            List existing configurations
    init:            Initialize new configuration
    upgrade:         Upgrade configuration to installed project version
    help:            Print this help

  To show detailed usage for a specific action, type:
    %s <ACTION> -h
" "$script_name" "$script_name"
}

print_init_usage() {
    printf "Initialize new configuration.
Usage: %s init <OPTIONS>
  MANDATORY OPTIONS:
    -n <configuration_name>  Name of the configuration, used to name the final
                             directory
  OPTIONAL OPTIONS:
    -d <global_dir>    Main directory used for the configurations
    -f                 Erase configuration directory if it already exists
    -h                 Print this help
" "$script_name"
}

print_upgrade_usage() {
    printf "Upgrade configuration to installed project version.
Usage: %s upgrade <OPTIONS>
  MANDATORY OPTIONS (mutually exclusives):
    -n <configuration_name>  Name of the configuration to be upgraded
    -A                       Upgrade all configurations into the main directory
  OPTIONAL OPTIONS:
    -d <global_dir>    Main directory used for the configurations
    -f                 Force upgrade, even if the version is already installed
    -h                 Print this help
" "$script_name"
}

print_list_usage() {
    printf "List existing configurations.
Usage: %s list <OPTIONS>
  OPTIONAL OPTIONS:
    -d <global_dir>  Main directory used for the configurations
    -h               Print this help
    -v               Also print configurations files, size, version.
" "$script_name"
}

# Extract ephemeral-machines version number from the Vagrantfile passed as an
# argument.
get_em_version() {
    local em_version
    local filepath
    em_version=""
    filepath="$1"

    # Extract line containing the version, and then only keep the version
    # number.
    em_version="$(grep "^EM_VERSION" "$filepath" | sed 's/^.*"\(.*\)".*$/\1/')"

    # Outputs the version number.
    echo "$em_version"
}

# Compare version numbers passed as parameters, returns true if the first one
# is strictly greater than the second one.
version_gt() {
    local first_version
    local second_version
    local lowest_version
    first_version="$1"
    second_version="$2"
    lowest_version="$(printf "%s\n%s" "$first_version" "$second_version" \
                        | sort -V | head -n1)"

    # Returns true if the first version number is different from the lowest
    # one.
    [ "$first_version" != "$lowest_version" ]
}

initialize() {
    local erase_project
    erase_project=""

    # Get action arguments.
    while getopts 'd:fhn:' flag; do
      case "${flag}" in
        d) global_dir="${OPTARG}" ;;
        f) erase_project="true" ;;
        h) print_init_usage
           exit 0 ;;
        n) configuration_name="${OPTARG}" ;;
        *) print_init_usage
           die "Unknown option for action ${action}: ${flag}" ;;
      esac
    done

    # Prepare project files.
    if [ -z "$configuration_name" ]; then
        print_init_usage
        die "Option \"-n\" is mandatory for action ${action}."
    fi

    configuration_dir="${global_dir}/${configuration_name}"
    ansible_dir="${configuration_dir}/ansible/"

    # Prepare main project directory.
    if [ ! -d "$global_dir" ]; then
        mkdir "$global_dir"
    fi

    # If the project directory already exists, remove it if "-e" option is
    # specified, abort otherwise.
    if [ -d "$configuration_dir" ] ; then
        if [ -n "$erase_project" ]; then
            echo "Erasing directory contents \"${configuration_dir}\"."
            rm -r "$configuration_dir"
        else
            die "Directory \"${configuration_dir}\" already exists."
        fi
    fi

    # Create the project directory and get the Vagrantfile.
    mkdir "$configuration_dir"
    cp "${source_dir}/Vagrantfile-template.rb" "${configuration_dir}/Vagrantfile"

    # Get the project template configuration files.
    cp -r "$templates_dir" "${configuration_dir}/config-templates"

    # Copy Ansible playbooks, scripts and tasks templates.
    cp -r "${source_dir}/ansible/" "${ansible_dir}"


    echo "==========================="
    echo "Projet initialisation done."
    echo "==========================="
    echo "Edit \"${configuration_dir}/vagrant.yaml\" file to define the boxes to be created."
    echo "You can use one template from \"${configuration_dir}/config-templates/\"."
    echo "You may also want to define one playbook into \"${ansible_dir}/\"."
    echo "Several templates are provided in \"${configuration_dir}/ansible/\"."
    echo "Then run: \"cd ${configuration_dir} && vagrant up\""
    echo

}


upgrade() {
    local force_upgrade
    force_upgrade=""
    local upgrade_all
    upgrade_all=""

    # Get action arguments.
    while getopts 'Ad:fhn:' flag; do
      case "${flag}" in
        A) upgrade_all="true" ;;
        d) global_dir="${OPTARG}" ;;
        f) force_upgrade="true" ;;
        h) print_upgrade_usage
           exit 0 ;;
        n) configuration_name="${OPTARG}" ;;
        *) print_upgrade_usage
           die "Unknown option for action ${action}: ${flag}" ;;
      esac
    done

    # Mandatory options must have been provided.
    if [ -n "$configuration_name" ] && [ -n "$upgrade_all" ]; then
        print_upgrade_usage
        die "Either option \"-n\" or \"-A\" must be specified for action ${action}."
    fi
    if [ -z "$configuration_name" ] && [ -z "$upgrade_all" ]; then
        print_upgrade_usage
        die "Either option \"-n\" or \"-A\" must be specified for action ${action}."
    fi

    # If global directory does not exist, abort.
    if [ ! -d "$global_dir" ]; then
        die "Directory ${global_dir} does not exist."
    fi

    upgraded_version="$(get_em_version "${source_dir}/Vagrantfile-template.rb")"

    if [ -n "${configuration_name}" ]; then
        configuration_dir="${global_dir}/${configuration_name}"
        ansible_dir="${configuration_dir}/ansible/"
        if [ ! -d "$configuration_dir" ]; then
            die "Directory ${configuration_dir} does not exist."
        fi
        project_version="$(get_em_version "${configuration_dir}/Vagrantfile")"
        if [ -z "$project_version" ]; then
            die "Project version not found, aborting."
        fi
        # Check if installed version is already current version.
        if ! version_gt "$upgraded_version" "$project_version" && [ -z "$force_upgrade" ]; then
            echo "Project ${configuration_name} is already in version \"$upgraded_version\"."
            echo "Nothing to do."
            exit 0
        fi
        echo "Upgrading project ${configuration_name} from version \"$project_version\" to version \"$upgraded_version\"."
        # Copy latest version of Vagrantfile.
        rsync "${source_dir}/Vagrantfile-template.rb" "${configuration_dir}/Vagrantfile"
        # Upgrade configuration templates.
        rsync -r "$templates_dir" "${configuration_dir}/config-templates"
        # Upgrade playbooks, scripts and tasks templates.
        rsync -r "${source_dir}/ansible/" "${ansible_dir}"
        echo "Project ${configuration_name} upgraded to version \"$upgraded_version\"."

    else
        # If all projects must be upgraded, loop over found projets
        # directories.
        while IFS=  read -r -d $'\0'; do
            configuration_dir=$(dirname "$REPLY")
            ansible_dir="${configuration_dir}/ansible/"
            configuration_name=$(basename "$configuration_dir")
            project_version="$(get_em_version "${configuration_dir}/Vagrantfile")"
            if [ -z "$project_version" ]; then
                echo "Project version not found for project ${configuration_name}, skipping."
                continue
            fi
            # Check if installed version is already current version.
            if ! version_gt "$upgraded_version" "$project_version" && [ -z "$force_upgrade" ]; then
                echo "Project ${configuration_name} is already in version \"$upgraded_version\"."
                echo "Nothing to do."
                continue
            fi
            echo "Upgrading project ${configuration_name} from version \"$project_version\" to version \"$upgraded_version\"."
            # Copy latest version of Vagrantfile.
            rsync "${source_dir}/Vagrantfile-template.rb" "${configuration_dir}/Vagrantfile"
            # Upgrade configuration templates.
            rsync -r "$templates_dir" "${configuration_dir}/config-templates"
            # Upgrade playbooks, scripts and tasks templates.
            rsync -r "${source_dir}/ansible/" "${ansible_dir}"
            echo "Project ${configuration_name} upgraded to version \"$upgraded_version\"."
        done < <(find "${global_dir}" -maxdepth 2 -name "Vagrantfile" -print0)
    fi

}

list() {
    local verbose
    verbose=""

    # Get action arguments.
    while getopts 'd:hv' flag; do
      case "${flag}" in
        d) global_dir="${OPTARG}" ;;
        h) print_list_usage
           exit 0 ;;
        v) verbose="true" ;;
        *) print_list_usage
           die "Unknown option for action ${action}: ${flag}" ;;
      esac
    done

    # If project directory does not exist, abort.
    if [ ! -d "$global_dir" ]; then
        die "Directory ${global_dir} does not exist."
    fi

    # From the configured global directory, loop over all directories that
    # contain a Vagrantfile, and print the list.
    while IFS=  read -r -d $'\0'; do
        configuration_dir=$(dirname "$REPLY")
        configuration_name=$(basename "$configuration_dir")
        # FIXME print in a friendly manner
        printf "\n========== %s ==========\n\n" "$configuration_name"
        printf "== Configuration directory ==\n\n"
        ls -ld "$configuration_dir"
        if [ -n "$verbose" ]; then
            printf "\n== Configuration version ==\n\n"
            get_em_version "$REPLY"
            printf "\n== Configuration full size ==\n\n"
            du -hs "$configuration_dir"
            printf "\n== Configuration contents ==\n\n"
            # Print configuration contents using tree if installed, find otherwise.
            if command -v tree >/dev/null; then
                tree "$configuration_dir"
            else
                find "$configuration_dir" -not -path '*/\.*' | sed "s/^${configuration_dir}\(.\)/|- \1/"
            fi
        fi
    done < <(find "${global_dir}" -maxdepth 2 -name "Vagrantfile" -print0)
}

# Check EM_MAIN_DIR environment variable to set global directory if necessary.
if [ -n "${EM_MAIN_DIR:-}" ]; then
    global_dir="$EM_MAIN_DIR"
fi

# An action must be provided as the first parameter.
if [ -z "$1" ]; then
    print_usage
    die "An action must be provided."
fi

# Get action name, as first argument.
action="$1"
shift

# Execute specified action.
case "${action}" in
  "list") list "$@" ;;
  "init") initialize "$@" ;;
  "upgrade") upgrade "$@" ;;
  "help"|"-h"|"--help") print_usage ;;
  *) print_usage
     die "Unknown action: ${action}." ;;
esac



