# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# This Vagrantfile comes from "ephemeral-machines" project:
# https://github.com/mrimbault/ephemeral-machines/
#
# It is designed to extract all necessary informations for creating virtual
# machines from configuration files.  So this file should not have to be
# modified, except to correct a bug or add a feature (like support for other
# providers).
#
# Use YAML syntax for configuration files, and for Ansible hosts variables
# files generation.
require "yaml"

# ephemeral-machines version.
EM_VERSION = "0.1"

# Initialize variables.
config_file = String.new
config_file_ext = String.new
conf = Hash.new
included_conf = Hash.new

def log(msg)
    puts "INFO: #{msg}"
end

def warn(msg)
    STDERR.puts "WARNING: #{msg}"
end

def die(msg)
    abort("ERROR: #{msg}")
end

# Extend Hash class with custom methods.
class ::Hash

    # Add deep_merge method so it is possible to merge nested hashes.  This is
    # used with "defaults" and "includes" keys from configuration file.  Note
    # that this method does not allow to merge hashes included into an array.
    # Taken from: https://stackoverflow.com/a/30225093
    def deep_merge(second)
        # FIXME I do not quite get this one liner, need to be studied
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
        self.merge(second.to_h, &merger)
    end

    # Method to convert hashes (aka dicts) values whose key name starts with
    # "_listitem_" to arrays (aka lists).  The "deep_merge" method previously
    # defined does not support merging hashes included into arrays, so if there
    # is any into the configuration file, "defaults" and "includes" keys will
    # not work for those.  So the idea is to declare these arrays as dicts
    # first, using a specific key name (anything starting with "_listitem_"),
    # so "deep_merge" will work on them... and then, convert these to proper
    # arrays based on their name.
    #
    # So this YAML structure:
    # ---
    # defaults:
    #   private_networks:
    #     _listitems_1:
    #       type: "dhcp"
    #     _listitems_2:
    #       type: "dhcp"
    # srv1:
    #   private_networks:
    #     _listitems_1:
    #       ip_private: "192.168.122.11"
    #     _listitems_2:
    #       ip_private: "192.168.142.11"
    # srv2:
    #   private_networks:
    #     _listitems_1:
    #       ip_private: "192.168.122.12"
    #     _listitems_2:
    #       ip_private: "192.168.142.12"
    #
    # Would give the following final configuration:
    # ---
    # srv1:
    #   private_networks:
    #   - ip_private: "192.168.122.11"
    #     type: "dhcp"
    #   - ip_private: "192.168.142.11"
    #     type: "dhcp"
    # srv2:
    #   private_networks:
    #   - ip_private: "192.168.122.12"
    #     type: "dhcp"
    #   - ip_private: "192.168.142.12"
    #     type: "dhcp"
    #
    # That is a ugly hack, but it seems necessary to keep both the deep merge
    # feature and the array properties (most notably to allow loops in Ansible
    # playbooks).
    # FIXME seems excessively complicated, I must have missed something obvious
    # here.
    def dict_to_list()
        # Entry loop, on the basic level of the hash.
        self.each do |key, value|
            # No need to search further if the value affected to the current
            # key is not a hash.
            if value.class == Hash
                # Reset the new value as an empty array.
                new_value ||= []
                # Inner loop, for every sub key found into the value hash.
                self[key].each do |sub_key, sub_value|
                    # Find out if the sub key has been named using the specific
                    # prefix.
                    if sub_key =~ /^_listitem_/ && defined?(sub_value)
                        # Add values associated with the current key to the new
                        # values array.
                        new_value << sub_value
                    end
                end
                # If new values have been added, erase the current key values
                # with the new values array.
                self[key] = new_value if new_value.any?
            end
        end
        # Now, if any of the values for the current level are hashes, call
        # recursively this method on them so we can find deeply nested hashes.
        self.values.each { |v| v.dict_to_list() if v.class == Hash }
    end
end

if ENV.key?("EM_VAGRANT_CONF")
    config_file = ENV["EM_VAGRANT_CONF"]
    if ! File.file?(env_config_file)
        die("Configuration file #{config_file} specified in EM_VAGRANT_CONF environament variable does not exist, aborting.")
    end
elsif File.file?("vagrant.toml")
    config_file = "vagrant.toml"
elsif File.file?("vagrant.yaml")
    config_file = "vagrant.yaml"
else
    die("No configuration file found on current directory, aborting.")
end

# Extract configuration file extension.
config_file_ext = config_file[/.*\.([^\.]*)/,1]

# Read current project configuration file, based on its extension.
if config_file_ext == "toml"
    # FIXME change to TOML configuration syntax for configuration files?
    # see: https://github.com/toml-lang/toml
    # TOML parser must be installed.
    require "toml-rb"
    conf = TomlRB.load_file(config_file) ||
        die("Loading configuration file #{config_file} failed, aborting.")
elsif config_file_ext == "yaml"
    conf = YAML.load_file(config_file) ||
        die("Loading configuration file #{config_file} failed, aborting.")
else
    die("File extention not supported for file #{config_file}, aborting.")
end

# Merge configuration from main file with included files if any.  Precedence
# order for duplicate keys is the include files order: values defined in last
# files replace values for the same key defined on previous include files or on
# the main configuration file.
if ( conf.key?("includes") && !conf["includes"].nil? )
    # Loop over specified include files.
    conf["includes"].each do |include_file|
        # Read ncluded configuration file, based on chosen extension.
        if config_file_ext == "toml"
            included_conf = TomlRB.load_file(include_file["file"]) ||
                die("Loading configuration file #{include_file["file"]} failed, aborting.")
        elsif config_file_ext == "yaml"
            included_conf = YAML.load_file(include_file["file"]) ||
                die("Loading configuration file #{include_file["file"]} failed, aborting.")
        else
            die("File extention not supported for file #{include_file["file"]}, aborting.")
        end
        # Merge hash keys from include file into the main "conf" hash.
        conf = conf.deep_merge(included_conf)
    end
end

# Abort if no machine definition found.
if ( !conf.key?("machines") || conf["machines"].empty? )
    die("At least one machine must be defined on the configuration.")
end

# Check if default values are defined for some parameters.  If they are, merge
# default values into every machine definition.
if ( conf.key?("defaults") && !conf["defaults"].nil? )
    conf["machines"].each do |machine, content|
        conf["machines"][machine] = conf["defaults"].deep_merge(conf["machines"][machine])
    end
end

# Finally, now that merging hashes is done, convert hash to lists if their key
# name says so.
conf.dict_to_list

# Set Vagrantfile API/syntax version.
VAGRANTFILE_API_VERSION = "2"

###############################################################################
# Begin machines configuration main section.
###############################################################################
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

    #############################
    # Set global configuration.
    #############################
    # Disable default synced folder, custom synced folders can be defined into
    # the configuration file.
    config.vm.synced_folder ".", "/vagrant", disabled: true
    # Disable the default behavior introduced in Vagrant 1.7, to ensure that
    # all Vagrant machines will use the same SSH key pair.
    # See: https://github.com/hashicorp/vagrant/issues/5005
    # FIXME this seems to be necessary for Ansible provisionning? see:
    # https://docs.ansible.com/ansible/latest/scenario_guides/guide_vagrant.html
    config.ssh.insert_key = false
    # If provisioning is asked, setup an array to register machines to be
    # provisioned as vagrant creates them.  This is so we can detect when the
    # last machine has been created, and start provisionning.
    ansible_hosts = [] if conf.key?("ansible")

    # Loop over each machine definition.
    conf["machines"].each do |machinekey, machinedesc|
        # Define machine using configuration, and set its internal Vagrant name
        # to the name of the key.
        config.vm.define machinekey do |vmdef|

            ################################
            # Global machine configuration #
            ################################
            # Set box to use.
            if machinedesc["box"]
                vmdef.vm.box = machinedesc["box"]
            elsif machinedesc["box_url"]
                vmdef.vm.box_url = machinedesc["box_url"]
            else
                die("No box defined for machine #{machinekey}!")
            end
            if machinedesc["box_version"]
                vmdef.vm.box_version = machinedesc["box_version"]
            end
            if machinedesc["box_check_update"]
                vmdef.vm.box_check_update = machinedesc["box_check_update"]
            end

            #############################
            # Provider specific actions #
            #############################
            # libvirt special configuration.
            vmdef.vm.provider :libvirt do |libvirt|
                # Set machine's resources.
                libvirt.memory = machinedesc["memory"]
                libvirt.cpus = machinedesc["cpus"]
            end
            # virtualbox special configuration (FIXME untested).
            vmdef.vm.provider :virtualbox do |virtualbox|
                # Set machine's resources.
                virtualbox.memory = machinedesc["memory"]
                virtualbox.cpus = machinedesc["cpus"]
            end
            # FIXME TODO other providers.

            ####################
            # OS configuration #
            ####################
            # Set machine's hostname.
            vmdef.vm.host_name = machinedesc["hostname"]

            #########################
            # Network configuration #
            #########################
            # Private networks
            # FIXME dynamically extract options to set from yaml file
            # FIXME auto_config does not always work well, for instance it
            # results in strage behaviour (2 IP on the same if) with
            # debian/jessie64 box
            if machinedesc.key?("private_networks")
                machinedesc["private_networks"].each do |privnetcontent|
                    # Define new private network.
                    if ( privnetcontent.key?("type") && privnetcontent["type"] == "dhcp" )
                        # DHCP type configuration.
                        vmdef.vm.network "private_network",
                            auto_config: privnetcontent["auto_config"],
                            type: privnetcontent["type"]
                    elsif ( privnetcontent.key?("ip_private") )
                        # Static IP type configuration.
                        vmdef.vm.network "private_network",
                            ip: privnetcontent["ip_private"],
                            auto_config: privnetcontent["auto_config"]
                    end
                end
            end
            # Public network
            # FIXME TODO?

            # Forwarded ports.
            if machinedesc.key?("fw_ports")
                if machinedesc["fw_ports"]
                    machinedesc["fw_ports"].each do |fw_port|
                        vmdef.vm.network "forwarded_port",
                        guest: fw_port["guest"],
                        host: fw_port["host"],
                        auto_correct: true
                    end
                end
            end

            # Synced folders.
            # FIXME should get arguments and setup things more dynamically
            if machinedesc.key?("sync_folders")
                if machinedesc["sync_folders"]
                    machinedesc["sync_folders"].each do |sync_folder|
                        vmdef.vm.synced_folder sync_folder["host"],
                            sync_folder["guest"],
                            create: true
                    end
                end
            end

            ################
            # Provisioning #
            ################
            # Ansible provisioning.
            # Write host vars files that will be used from within Ansible.
            if conf.key?("ansible")
                # The file will be written directly into the Ansible directory
                # "host_vars/", the filename will be the same that the host
                # defined on the automatically generated inventory.  This way,
                # Ansible will directly load all variables for each hosts
                # without further instruction.
                conf_file = "#{conf["ansible"]["dir"]}/host_vars/#{machinekey}.yaml"
                File.open(conf_file,"w") do |file|
                    file.write machinedesc.to_yaml
                end
                # Add the defined machine to the list of machines to be
                # provisionned, so we know when we are dealing with the last
                # one.
                ansible_hosts.push(machinekey)
            end
            # Only run provisioning when the last machine has been defined, and
            # only run it once.  Without this check, the default vagrant
            # behaviour would be to run "ansible-playbook" once for every
            # defined machine.  This would not work because in many cases the
            # playbook to run will require back and forth steps between
            # machines.  This is because some tasks may affect several machines
            # at a time, for instance configuring PostgreSQL replication.  So
            # we need to ensure every tasks will run in the order they were
            # defined, and that they will run only once.
            if ( conf.key?("ansible") && ansible_hosts.size == conf["machines"].size )
                config.vm.provision "ansible" do |ansible|

                    # Define Ansible playbook name and location.
                    if conf["ansible"]["playbook"]
                        ansible.playbook = "#{conf["ansible"]["dir"]}/#{conf["ansible"]["playbook"]}"
                    end

                    # Define Ansible groups.
                    if conf["ansible"].key?("groups")
                        ansible.groups = conf["ansible"]["groups"]
                    end

                    # Change Ansible verbosity, useful for debugging.
                    if conf["ansible"]["verbose"]
                        ansible.verbose = conf["ansible"]["verbose"]
                    end

                    # Pass extra_vars to ansible-playbook if provided.
                    if conf["ansible"].key?("extra_vars")
                        ansible.extra_vars = conf["ansible"]["extra_vars"]
                    end

                    # Provision all defined machines.
                    ansible.limit = ansible_hosts

                end
            end
        end
    end
end

