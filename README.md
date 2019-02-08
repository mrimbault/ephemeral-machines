
# Ephemeral machines

The purpose of this project is to use Vagrant and Ansible to easily generate
and provision virtual machines based on configuration files.  These machines
are not to be used on any serious production environment, but for training and
testing.


## Quickstart

Initialize a project using template configuration files.
~~~
manage.sh init -n "myfirstconfiguration"
~~~

This will create a directory in a defined location (by default,
`~/ephemeral-machines/<project name>`).

Then, all future commands should be launched from within this directory.  So
the next step is to change directory to the newly created:
~~~
cd ~/ephemeral-machines/myfirstconfiguration/
~~~

Then create the `vagrant.yaml` file, and optionnaly `ansible/playbook.yaml`
file.  You can use the templates provided into `config-templates` and
`ansible/playbook-templates` directories.  Editing the local Vagrantfile or any
other file should not be necessary.

Finally, the following command will create the machines described on the
`vagrant.yaml` configuration, optionnally launch the provisioning using the
specified Ansbile playbook file, and start the machines.
~~~
vagrant up
~~~

Then, the following command will allow to check these machines status:
~~~
vagrant status
~~~

To connect to any machine, use this command (`<machine name>` is required in a
multi-machines deployment):
~~~
vagrant ssh <machine name>
~~~


## Prerequisites

- Vagrant (tested with version 2.2.3)
- Ansible (for provisioning actions, tested with version 2.7.6)
- libvirt (tested with version 5.0.0)
- or virtualbox (untested)

If you want to use the TOML configuration file format instead of YAML format,
installing `toml-rb` parser is also required (tested with version 1.1.2):
```
vagrant plugin install toml-rb
```

### Notes regarding libvirt as a provider

Using libvirt as a provider is not yet supported by Vagrant.  One must install
[vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt) plugin to
make it work (tested with version 0.0.45).  To find libvirt compatible boxes on
Vagrant cloud, use [this
link](https://app.vagrantup.com/boxes/search?provider=libvirt).

If using both firewalld and libvirt on the host, one must ensure that the
firewall backend used is iptables and not nftables (which is the default).
[See this article for
details](https://bbs.archlinux.org/viewtopic.php?id=239362).  Symptoms: DHCP
not working with NATed virtual network (like `default`), guest machines not
getting IP address.


## Manage script

This script is provided to easily deploy new virtual machines configuration
directories, or manage existing ones.

One simple way to use this script is to configure an alias:
~~~bash
alias ephman='/var/lib/git/ephemeral-machines/manage.sh'
~~~

- Main script usage:
~~~
manage.sh <ACTION> <OPTIONS>
  ACTIONS (must provide only one, and it must be the first argument):
    list:            List existing configurations
    init:            Initialize new configuration
    upgrade:         Upgrade configuration to installed project version
    help:            Print this help

  To show detailed usage for a specific action, type:
    manage.sh <ACTION> -h
~~~

- Initialize new configuration directory:
~~~
manage.sh init <OPTIONS>
  MANDATORY OPTIONS:
    -n <project_name>  Name of the configuration, used to name the final directory
  OPTIONAL OPTIONS:
    -d <global_dir>    Main directory used for the configuration
    -e                 Erase configuration directory if it already exists
    -h                 Print this help
~~~

- Upgrade configuration directory to current project version:
~~~
manage.sh upgrade <OPTIONS>
  MANDATORY OPTIONS (mutually exclusives):
    -n <project_name>  Name of the configuration to be upgraded
    -A                 Upgrade all configurations into the main directory
  OPTIONAL OPTIONS:
    -d <global_dir>    Main directory used for the configurations
    -h                 Print this help
~~~

- List configuration directories:
~~~
manage.sh list <OPTIONS>
  OPTIONAL OPTIONS:
    -d <global_dir>  Main directory used for the configurations
    -h               Print this help
    -v               Also print configurations files, size, version.
~~~


## Machines configuration

To start machines configuration, first initialize a configuration directory
using the `manage.sh` script.  Then, you can create a new `vagrant.yaml`
configuration file at the root of this directory.  The configuration files use
[YAML syntax](https://yaml.org/).  Sadly, this syntax is not very user
friendly, specifically regarding indentation, so always double-check your
syntax.  I thought about using [TOML syntax](https://github.com/toml-lang/toml)
instead, but as most Ansible configurations files and playboooks use YAML, for
starters I decided to kept things consistent.  I'm still considering it though,
especially now that the Vagrantfile generates all of Ansible hosts
configuration (but not playbooks).

The configuration file is separated in the following sections (root keys in the
`machines` dictionnary).

### Machines

This section defines configuration related to machines to be created, grouped
under the `machines` main key.  This is a dictionary, so several machines can
be defined under it.

Each machine configuration is created as a separate dictionnary.  The key name
used for this dictionnary entry will be used to name the created machine in
Vagrant.

Under this key will be the parameters that describe the machine.  These are the
list of parameters supported directtly by Vagrant without provisioning (there
are also other parameters supported by Ansible playbooks, see the next
sections).

#### Vagrant machine creation settings

The following apply specifically to [Vagrant creation of the virtual
machines](https://www.vagrantup.com/docs/vagrantfile/machine_settings.html):
- `hostname`: Mandatory, name that will be used as the hostname (usually will
  be the same as the key name).
- `box`: Name of the box to be used.  Check [the Vagrant
  cloud](https://app.vagrantup.com/boxes/search) to find easy to use boxes, but
  you can also use your own boxes, for example using
  [Packer](https://www.packer.io/).  This parameter is mandatory, unless you
  set `bux_url` below.
- `box_url`: Full URL of the box to use.
- `box_version`: Specific version of the box to be used.
- `box_check_update`: Determines if Vagrant checks for newer versions of
  specified box. Boolean, defaults to `true`.

#### Provider specific settings

The following parameters are [provider specific
parameters](https://www.vagrantup.com/docs/providers/) (tested with [Libvirt
and vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt):
- `memory`: Size of RAM that will be allocated to the VM.
- `cpus`: Number of vCPU that will be allocated to the VM.


#### Private networks

The following parameters allow to define [private
networks](https://www.vagrantup.com/docs/networking/private_network.html):
- `private_networks`: Contains multiple dictionnaries, each describing a
  private network to be used by the VM.  Each dictionnary can define:
  - `ip_private`: IP address to use.
  - `auto_config`: Boolean, defines if Vagrant will automatically configure the
    interface.
  - `type`: Network type, like `dhcp`.
  - `local_domain`: Local domain name, if one is used.

NOTE: the key name of each of these dictionnaries should start with
`_listitem_`.  This is a limitation to allow default and include features to
work, and still be able to transform the final merged dictionary into a list.

#### Forwarded ports

The following parameters allow to define [forwarded
ports](https://www.vagrantup.com/docs/networking/forwarded_ports.html):
- `fw_ports`: Contains multiple dictionnaries describing ports to be forwarded
  between guest and host.  Each dictionnary can define:
  - `guest`: Port number on the VM.
  - `host`: The port on the host machine that will be redirected.

NOTE: the key name of each of these dictionnaries should start with
`_listitem_`.  This is a limitation to allow default and include features to
work, and still be able to transform the final merged dictionary into a list.


#### Synced folders

The following parameters allow to define [synced
folders](https://www.vagrantup.com/docs/synced-folders/basic_usage.html):
- `synced_folders`: Contains multiple dictionnaries describing directories to
  be shared between host and guest.  Each dictionnary can define:
  - `host`: Name on the host of the folder to be shared.
  - `guest`: Path on the guest of the folder to be shared.

NOTE: the key name of each of these dictionnaries should start with
`_listitem_`.  This is a limitation to allow default and include features to
work, and still be able to transform the final merged dictionary into a list.


#### Example

Defines one single machine, named `srv1` (both internally for Vagrant and as
its `hostname`):
~~~yaml
---
machines:
  srv1:
    hostname:            "srv1"
    box:                 "centos/7"
    memory:              1024
    cpus:                1
    private_networks:
      ip_private:        "192.168.122.11"
      auto_config:       true
      type:              "dhcp"
      local_domain:      "vagrant.local"
    fw_ports:
      _listitem_pgport
        guest:           5432
        host:            55431
    sync_folders:
      _listitem_share:
        host:            "share"
        guest:           "/share"
~~~


### Defaults

This section is used to define default values for some parameters.  Any key
that can be specified under the `machines` key can also be specified under the
`defauts` key: both definitions will be merged eventually.  The value specified
under `defaults` key will be used by all defined machines, unless some
parameters are overwritten in one or several machines definition.

#### Example

Defines two machines, the common configuration is registered under the
`defaults` key (note that the configuration for `srv2` overwrites the default
`box` configuration):
~~~yaml
---
defaults:
    box:                 "centos/7"
    memory:              1024
    cpus:                1
    private_networks:
      _listitem_122:
        auto_config:     true
        type:            "dhcp"
        local_domain:    "vagrant.local"
    sync_folders:
      _listitem_share:
        host:            "share"
        guest:           "/share"
machines:
  srv1:
    hostname:            "srv1"
    private_networks:
      _listitem_122:
        ip_private:      "192.168.122.11"
    fw_ports:
      _listitem_pgport
        guest:           5432
        host:            55431
  srv2:
    hostname:            "srv2"
    box:                 "debian/jessie64"
    private_networks:
      _listitem_122:
        ip_private:      "192.168.122.12"
    fw_ports:
      _listitem_pgport
        guest:           5432
        host:            55432
~~~


### Provisioning

Vagrant supports [several
methods](https://www.vagrantup.com/docs/provisioning/) for provisioning the
newly created machines.  This project supports exclusively
[Ansible](https://www.vagrantup.com/docs/provisioning/ansible.html).

#### Ansible

The `ansible` key is used to define the global provisioning settings.  It
supports the following parameters:
- `dir`: Path of the folder containing Ansible files.
- `playbook`: Name of the
  [playbook](https://docs.ansible.com/ansible/latest/user_guide/playbooks.html)
  to use (it must be into the Ansible folder).
- `groups`: Contains several dictionnaries named after an [Ansible
  group](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html#group-variables)
  used by the selected playbook.  Each one defines a list of guests to include
  in this group.
- `verbose`: Change Ansible verbosity, useful for debugging.
- `extra_vars`: Allows to setup [additionnal
  settings](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#passing-variables-on-the-command-line)
  directly to Ansible at startup.

#### Machines provisioning settings

Depending on the playbook used, any number of additional parameters may be
used.  Before launching Ansible, Vagrant writes every machine's configuration
(FIXME link) into the [host_vars
directory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html#splitting-out-host-and-group-specific-data).
This way, any setting defined into a machine's dictionary key will be available
from the playbook.

Also see the description of the playbooks templates and the supported settings
(FIXME internal link).

#### Example

This creates two machines, and for each on it installs PostgreSQL 11, and
creates and starts a PostgreSQL instance (note: for this to work, the
`ansible/playbook.yaml` file must have been created, for example using an
existing template (FIXME internal link)):
~~~yaml
---
defaults:
    box:                 "centos/7"
    memory:              1024
    cpus:                1
    private_networks:
      _listitem_122:
        auto_config:     true
        type:            "dhcp"
        local_domain:    "vagrant.local"
    sync_folders:
      _listitem_share:
        host:            "share"
        guest:           "/share"
    postgresql:
      version:           "11"
      repo:              "https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-centos11-11-2.noarch.rpm"
      packages:
        - "postgresql11-server"
        - "postgresql11-contrib"
      settings:
        listen_addresses: "'*'"
machines:
  srv1:
    hostname:            "srv1"
    private_networks:
      _listitem_122:
        ip_private:      "192.168.122.11"
    fw_ports:
      _listitem_pgport
        guest:           5432
        host:            55431
  srv2:
    hostname:            "srv2"
    private_networks:
      _listitem_122:
        ip_private:      "192.168.122.12"
    fw_ports:
      _listitem_pgport
        guest:           5432
        host:            55432
ansible:
  dir:                   "ansible"
  playbook:              "playbook-simple.yaml"
  groups:
    pg:
    - "srv1"
    - "srv2"
~~~


### Includes

This section allows to specify several files that will be read and merged with
the global configuration.  These files are loaded in the specified order, but
after all the main configuration file has been completely loaded.  If a
parameter is specified more than once, the last value read is kept.  While not
mandatory, it is recommanded that this section is put at the end of the main
file, precedence order will be more intuitive this way.  This section has no
effect if put into an included file (only one level of includes is supported,
no nesting).


#### Example

The following file could be used to separate the previous example into four
files:
~~~yaml
---
includes:
- file: "defaults.yaml"
- file: "srv1.yaml"
- file: "srv2.yaml"
- file: "ansible.yaml"
~~~

## Configuration template files

Several configuration template files are provided under the `config-templates/`
directory.  They can be used as a basis to build your own.

The provided configuration templates include the following sub-directories:
- `basic-machines/`: various configuration files to define very basic machines,
  without provisioning.
- `simple-machines/`: various configuration files to define simple Linux
  machines, provisioned using the `simple-playbook.yaml` Ansible playbook.
- `pg/`: various configuration files to define Linux machines with an installed
  and configured PostgreSQL instance, provisioned using the `pg-playbook.yaml`
  Ansible playbook.
- `pg-repli/`: various configuration files to define Linux machines with an
  installed and configured PostgreSQL instance using streaming replication,
  provisioned using the `pg-repli-playbook.yaml` Ansible playbook.


## Environment variables

The following environment variables are supported:
- `EM_MAIN_DIR`: used by `manage.sh` script to set the global projects
  directory (defaults to `~/ephemeral-machines/`).
- `EM_VAGRANT_CONF`: used by `vagrant` commands to find the main configuration
  file to be used within the current directory (defaults to `vagrant.yaml`).


## Ansible template playbooks

Several Ansible template playbooks are provided.  This section describes what
options they support.  These options are to be specified exactly like the
Vagrant options, in the main configurations files, under the
`machines: { <host> }` dictionnaries, or under the `defaults` dictionnary.

Note: Ansible as a provisioning system strongly relies on the
[idempotency](https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html#term-idempotency)
of tasks executed by playbooks.  However, these playbooks templates are
designed to work on fresh, newly created virtual machines.  Idempotency is not
enforced, and executing these playbooks on an already existing machine (using
`vagrant provision` or directly `ansible-playbook`) is not supported.  If you
want to reset a machine, you should first `vagrant destroy`, then `vagrant up`.
These machines are called ephemeral after all.

Note: The Ansible directory includes various tasks and scripts designed for
these playbooks.  Obviously, these should not be used for any other goal than
provisioning newly created machines.  Other uses may result in service
interruption and data loss.


### Simple machines

The template playbook `ansible/playbook-templates/simple-playbook.yaml` is
designed to provision simple Linux machines, with several added useful
softwares.  The supported options to add to the machine definition are:
- `private_networks`: See [the description on the Vagrant configuration
  section](FIXME).  These parameters are used to configure local name
  resolution (`/etc/hosts`).  Specifically, the ones used by the playbook are:
  - `ip_private`: Adresse IP privée pour cette règle de résolution.
  - `resolvname`: Nom qui va résoudre sur l'adresse IP privée spécifiée pour
    toutes les machines de la configuration.
  - `local_domain`: Nom de domaine qui sera ajoutée au `resolvname` pour
    construire le FQDN.


### PostgreSQL

The template playbook `ansible/playbook-templates/pg-playbook.yaml` is
designed to provision Linux machines with PostgreSQL installed and an instance
created, configured and started.  The supported options to add to the machine
definition are:
- The options supported by `simple-playbook.yaml`.
- `postgresql`: Main dictionary key for specifying PostgreSQL configuration.
  - `version`: PostgreSQL major version number (ie 9.4, 11) to be installed.
  - `repo`: PostgreSQL repository name to be added.
  - `repo_url`: PostgreSQL repository full URL to be added.
  - `packages`: List of PostgreSQL packages to be installed from the repository.
  - `settings`: Dictionary of [PostgreSQL settings](FIXME link) to be modified, specified as
    keys and values (for example, `  listen_addresses: "'*'"`).
  - `hba_lines`: List of lines to be added to the PostgreSQL [authentication
    file](FIXME link), specified as strings (for exemple,
    `  - "local   all  postgres                                  peer"`).

The supported Ansible group is:
- `pg`: Machines where a PostgreSQL instance will be created.


### PostgreSQL with replication

The template playbook `ansible/playbook-templates/pg-repli-playbook.yaml` is
designed to provision Linux machines with PostgreSQL installed and an instance
created, configured and started, and others with a standby PostgreSQL instances
created and connected to the primary using streaming replication.  The
supported options to add to the machine definition are:
- The options supported by the `simple-playbook.yaml`.
- The options supported by the `pg-playbook.yaml`.
- `postgresql`
  - `replication`: Dictionary of replication specifics settings.
    - `rolename`: Name of the PostgreSQL replication role.
    - `password`: Password of the PostgreSQL replication role.

The supported Ansible groups are:
- `pgprimary`: machines where a PostgreSQL primary instance will be created.
- `pgstandby`: machines where a PostgreSQL standby instance will be created.


### PostgreSQL with replication and automatic failover

FIXME

The template playbook `ansible/playbook-templates/pg-repli-paf-playbook.yaml` is
designed to provision Linux machines with PostgreSQL installed and an instance
created, configured and started, and others with a standby PostgreSQL instances
created and connected to the primary using streaming replication.  The
supported options to add to the machine definition are:
- FIXME specific, custom package list?
- FIXME postgres
- FIXME postgres replication

The supported Ansible groups are:
- `pgprimary`: machines where a PostgreSQL primary instance will be created.
- `pgstandby`: machines where a PostgreSQL standby instance will be created.




