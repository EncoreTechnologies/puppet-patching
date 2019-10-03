
# patching

#### Table of Contents

- [Description](#description)
- [Setup](#setup)
  - [Setup Requirements](#setup-requirements)
  - [Getting started](#getting-started)
- [Architecture](#architecture)
- [Design](#design)
- [Patching Workflow](#patching-workflow)
- [Usage](#usage)
  - [Check for available updates](#check-for-available-updates)
  - [Create snapshots](#create-snapshots)
  - [Perform pre-patching checks and actions](#perform-pre-patching-checks-and-actions)
  - [Run a the full patching workflow end-to-end](#run-a-the-full-patching-workflow-end-to-end)
- [Configuration Options](#configuration-options)
  - [patching_order](#patching_order)
  - [patching_reboot](#patching_reboot)
  - [patching_reboot_message](#patching_reboot_message)
  - [patching_pre_patch_plan](#patching_pre_patch_plan)
  - [patching_pre_patch_script_linux](#patching_pre_patch_script_linux)
  - [patching_pre_patch_script_windows](#patching_pre_patch_script_windows)
  - [patching_post_patch_plan](#patching_post_patch_plan)
  - [patching_post_patch_script_linux](#patching_post_patch_script_linux)
  - [patching_post_patch_script_windows](#patching_post_patch_script_windows)
  - [patching_snapshot_plan](#patching_snapshot_plan)
  - [patching_snapshot_create](#patching_snapshot_create)
  - [patching_snapshot_delete](#patching_snapshot_delete)
  - [patching_vm_name_property](#patching_vm_name_property)
  - [patching_snapshot_name](#patching_snapshot_name)
  - [patching_snapshot_description](#patching_snapshot_description)
  - [patching_snapshot_memory](#patching_snapshot_memory)
  - [patching_snapshot_quiesce](#patching_snapshot_quiesce)
  - [vsphere_host](#vsphere_host)
  - [vsphere_username](#vsphere_username)
  - [vsphere_password](#vsphere_password)
  - [vsphere_insecure](#vsphere_insecure)
  - [vsphere_datacenter](#vsphere_datacenter)
- [TODO: Reference (start here)](#todo-reference-start-here)
- [Limitations](#limitations)
- [Development](#development)
- [Release Notes/Contributors/Etc. **Optional**](#release-notescontributorsetc-optional)

## Description

A framework for building patching workflows. This module is designed to be used as building
blocks for complex patching environments of Windows and Linux (RHEL, Ubuntu) systems.

No Puppet agent is required on the end nodes. The node executing the patching will need to 
have `bolt` installed.

## Setup

### Setup Requirements

Module makes heavy use of [bolt](https://puppet.com/docs/bolt/latest/bolt.html), you'll need to isntall it to get started.

### Getting started

``` shell
cat <<EOF >> ~/.puppetlabs/bolt/Puppetfile
mod 'puppetlabs/stdlib'
mod 'encore/patching'
EOF

bolt puppetfile install
bolt plan run patching::available_updates --nodes group_a
```

## Architecture

This module is designed to work in enterprise patching environments.

Assumptions:
* RHEL nodes are registered to Satellite / Foreman or the internet
* Ubuntu nodes are registered to Landscape or the internet
* Windows nodes are registered to WSUS and Chocolatey (optional)

Registration to a central patching server is preferred for speed of software downloads 
and control of phased patching promotions.

At some point in the future we will include tasks and plans to promote patches through
these central patching server tools.

TODO: Diagram

## Design

`patching` is designed around `bolt` tasks and plans. 

Individual tasks have been written to accomplish targeted steps in the patching process.
Examples: `patching::available_updates` is used to check for available updates on target nodes.

Plans are then used to pretty up output and tie tasks together.

This way end users can use the tasks and plans as build blocks to create their own custom
patching workflows (we all know, there is no such thing as one size fits all).

_For more info on tasks and plans, see the Usage and Reference sections._

Going further, many of the settings for the plans are configurable by setting `vars` 
on your groups in the bolt inventory file.

_For more info on customizing settings using vars, see the Configuration Options section_

## Patching Workflow

Our default patching workflow is implented in the `patching` plan [patching/init.pp](patching.init.pp).

This workflow consists of the following phases:
* Organize inventory into groups, in the proper order required for patching
* For each group...
* Check for available updates
* Snapshot the VMs
* Pre-patch custom tasks
* Update the host (patch)
* Post-patch custom tasks
* Reboot that require a reboot
* Delete snapshots

## Usage

### Check for available updates

This will reach out to all nodes in `group_a` in your inventory and check for any available
updates through the system's package manager:
* RHEL = yum
* Ubuntu = apt
* Windows = Windows Update + Chocolatey (if installed)

``` shell
bolt plan run patching::available_updates --nodes group_a
```

### Create snapshots

This plan will snapshot all of the hosts in VMware. The name of the VM in VMware is assumed to 
be the `uri` of the node the inventory file.

``` shell
/opt/puppetlabs/bolt/bin/gem install rbvmomi

bolt plan run patching::snapshot_vmware --nodes group_a action='create' vsphere_host='vsphere.domain.tld' vsphere_username='xyz' vsphere_password='abc123' vsphere_datacenter='dctr1'
```

### Perform pre-patching checks and actions

This plan is designed to perform custom service checks and shutdown actions before 
applying patches to a node.
If you have custom actions that need to be perform prior to patching, place them in the
`pre_patch` scripts and this plan will execute them. 
Best practice is to define and distribute these scripts as part of your normal Puppet code
as part of othe role for that node.

``` shell
bolt plan run patching::pre_patch --nodes group_a
```

By default this executes the following scripts (nodes where the script doesn't exist are ignored):
* Linux = `/opt/patching/bin/pre_patch.sh`
* Windows = `C:\ProgramData\PuppetLabs\patching\pre_patch.ps1`
 

### Run a the full patching workflow end-to-end

This executes the following for each group:
* `patching::cache_updates`
* `patching::available_updates`
* `patching::snapshot_vmware action='create'`
* `patching::pre_patch`
* `patching::update`
* `patching::post_patch`
* `patching::reboot_required`
* `patching::snapshot_vmware action='delete'`

``` shell
bolt plan run patching --nodes group_a
```

## Configuration Options

This module allows many aspects of its runtime to be customized using configuration options
in the inventory file. 

Example: Let's say we want to prevent some nodes from rebooting during patching.
This can be customized with the `patching_reboot` variable in inventory:

``` yaml
groups:
  - name: no_reboot_nodes
    vars:
      patching_reboot: false
    targets:
      - abc123.domain.tld
      - def4556.domain.tld
```

### patching_order

``` yaml
type: Integer
default: <none>
```

Allows groups in the inventory file to have a defined patching order. 
This is useful in large environments with HA services. You might want to patch 
the standby database first, then the priamry database second. In this case
you would declare two groups with different patching orders.

The datatype is assumed to be an integer. Lower numbered groups will be patched first.
In reality, this can be any datatype you want, as long as `sort()` will produce an order
that you desire.

Example:

``` yaml
groups:
  - name: primary_nodes
    vars:
      patching_order: 1
    targets:
      - sql01.domain.tld
  - name: backup_nodes
    vars:
      patching_order: 2
    targets:
      - sql02.domain.tld
```


### patching_reboot

``` yaml
type: Boolean
default: true
```

Toggle for allowing nodes to reboot during patching. 
`patching_reboot: true` means that nodes are allowed to reboot during patching, but only if
reboot is required as signaled by the OS.
`patching_reboot: false` means that the node will not reboot, even if it's required.


### patching_reboot_message

``` yaml
type: String
default: 'NOTICE: This system is currently being updated.'
```

Type: String`

Message to display on any nodes that are rebooted during patching.

### patching_pre_patch_plan

```yaml
type: String
default: 'patching::pre_patch'
```

Name of the plan to use for the `pre_patch` phase of patching.
If you would like to use a custom plan for patching all of your nodes (say you don't like our default approach). 
Or, maybe there is just a specific group of nodes you would like to perform a custom
plan for just those nodes before executing the updates on the host, then this is for you!

Example:

``` yaml
vars:
  patching_pre_patch_plan: mymodule::custom_pre_patching

groups:
  # these nodes will use the pre patching plan defined in the vars above
  - name: regular_nodes
    targets:
      - tomcat01.domain.tld
      - tomcat02.domain.tld
      - tomcat03.domain.tld
      
  # these nodes will use the customized patching plan set for this group
  - name: sql_nodes
    vars:
      patching_pre_patch_plan: mymodule::database_pre_patching
    targets:
      - sql01.domain.tld
```

### patching_pre_patch_script_linux

``` yaml
type: String
default: '/opt/patching/bin/pre_patch.sh'
```

If you're using our default plan for pre patching (`patching::pre_patch`), then
this is a way to customize what script is executed within that plan.

This allows for a smaller "hammer" when it comes to customization. Say you don't mind
that our default plan runs shell scripts, but you just want to change script
that is being executed (for whatever reason). Then, this is the option for you.

Example:

``` yaml
vars:
  patching_pre_patch_script_linux: /usr/local/bin/mysweetpatchingscript.sh

groups:
  # these nodes will use the pre patching script defined in the vars above
  - name: regular_nodes
    targets:
      - tomcat01.domain.tld
      
  # these nodes will use the customized patching script set for this group
  - name: sql_nodes
    vars:
      patching_pre_patch_script_linux: /bin/sqlpatching.sh
    targets:
      - sql01.domain.tld
```

### patching_pre_patch_script_windows

``` yaml
type: String
default: 'C:\ProgramData\patching\bin\pre_patch.ps1'
```

Same as our `patching_pre_patch_script_linux` above, execpt the path to the script
to customize on Windows hosts.

Example:

``` yaml
vars:
  patching_pre_patch_script_windows: C:\awesome\patch_script.ps1

groups:
  # these nodes will use the pre patching script defined in the vars above
  - name: regular_nodes
    targets:
      - tomcat01.domain.tld
      
  # these nodes will use the customized patching script set for this group
  - name: sql_nodes
    vars:
      patching_pre_patch_script_windows: C:\MSSQL\stop_services.ps1
    targets:
      - sql01.domain.tld
```

### patching_post_patch_plan

```yaml
type: String
default: 'patching::post_patch'
```

Same as `patching_pre_patch_plan` except executed after patches have been applied.

### patching_post_patch_script_linux

``` yaml
type: String
default: '/opt/patching/bin/post_patch.sh'
```

Same as `patching_pre_patch_script_linux` except executed after patches have been applied on Linux hosts.

### patching_post_patch_script_windows

``` yaml
type: String
default: 'C:\ProgramData\PuppetLabs\patching\post_patch.ps1'
```

Same as `patching_pre_patch_script_windows` except executed after patches have been applied on Windows hosts.


### patching_snapshot_plan

``` yaml
type: String
default: 'patching::snapshot_vmware'
```

Used to customize the plan for the snapshot step in the workflow.

Set this to whatever custom plan you would like in this module or another.

To disable snapshotting all together (physical boxes for example) then set this to `undef` or an empty string `''`.


``` yaml
groups:
  # these nodes will use the default snapshot plan (they are VMware)
  - name: vmware_nodes
    targets:
      - tomcat01.domain.tld

  # these nodes will use a custom snapshot plan for Xenserver
  - name: xen_nodes
    vars:
      patching_snapshot_plan: 'xenserver::snapshot'
    targets:
      - citrix01.domain.tld
      
  # these nodes will not perform the snapshot step because they're physical
  - name: physical_nodes
    vars:
      patching_snapshot_plan: ''
    targets:
      - sql01.domain.tld
```


### patching_snapshot_create

``` yaml
type: Boolean
default: true
```

Used to customize the snapshot creation process. 

Some common usecases:
* Setting this to `false` as an alternate way of disabling snapshots as opposed to 
  customizing `patching_snapshot_plan: ''`. To accomplish this fully, you'll also need
  to set `patching_snapshot_delete: false` at the same time.
* Say you ran the patching workflow and it failed halfway through, example a pre-patch failed.
  On that first patch run you used the default `patching_snapshot_create: true`.
  Well, on the second run to try and execute patching again, i don't want to create MORE 
  snapshots since they were already created the first time. 
  To accomplish this simply set `patching_snapshot_create: false`

### patching_snapshot_delete

``` yaml
type: Boolean
default: true
```

Similar to `patching_snapshot_create` this handles the customization of the snapshot deletion.

Some common usecases:
* Setting this to `false` as an alternate way of disabling snapshots as opposed to 
  customizing `patching_snapshot_plan: ''`. To accomplish this fully, you'll also need
  to set `patching_snapshot_create: false` at the same time.
  
* Say you want to run patching and wait until the next day to delete snapshots because
  an App team might realize patching broke their app 8 hours after it's been patched
  (that never happens right?).
  Well, we can allow snapshots to be created during patching by doing leaving
  `patching_snapshot_create` to its default of `true` and then preventing snapshots
  from being deleted at the end of patching by customizing `patching_snapshot_delete: false`.
  This hopefully allows our workflwo to adapt to your usecase.
  
### patching_vm_name_property

``` yaml
type: Enum
values:
 - 'uri'
 - 'name'
default: 'uri'
```

When performing the snapshotting process, Bolt needs to know how to associate a `target`
to a VM in the hypervisor. 

To accomplish this we provide the `patching_vm_name_property` setting that allows you to select
the `uri` (default) or the `name` of the target as the property that will be used.


Example:
``` yaml
groups:
  # these nodes will use the default 'uri' as their VM name property
  # this is because targets listed in this fashion have their 'uri' set to the 
  # string present in the list
  - name: vmware_nodes
    targets:
      - tomcat01.domain.tld

  # these nodes will use a custom VM name associated with the 'name' property
  - name: xen_nodes
    vars:
      patching_vm_name_property: 'name'
    targets:
      - uri: citrix01.domain.tld
        name: CITRIX01
```


### patching_snapshot_name

``` yaml
type: String
default: 'Bolt Patching Snapshot'
```

Name of the snapshot to create in the hypervisor.


### patching_snapshot_description

``` yaml
type: String
default: ''
```

Description of the snapshot to set in the hypervisor.

### patching_snapshot_memory

``` yaml
type: Boolean
default: false
```

Enable or disable snapshotting the VM's memory when creating snapshots during patching.

### patching_snapshot_quiesce

``` yaml
type: Boolean
default: true
```

Enable or disable quiescing the VM's filesystem when creating snapshots during patching.

### vsphere_host

``` yaml
type: String[1]
default: <none>
```

Hostname/IP of the vSphere to connect to when snapshotting with `patching::snapshot_vmware`.

``` yaml
vars:
  vsphere_host: vsphere.domain.tld
```

### vsphere_username

``` yaml
type: String[1]
default: <none>
```

Username to use when authenticating with vSphere during `patching::snapshot_vmware`.

``` yaml
vars:
  vsphere_username: user@domain.tld
```

### vsphere_password

``` yaml
type: String[1]
default: <none>
```

Password to use when authenticating with vSphere during `patching::snapshot_vmware`.

**SECURITY NOTE** It is recommended to use the `pkcs7` plugin to encrypt passwords if storing them in your inventory file.

Example:

```yaml
vars:
  vsphere_username: user@domain.tld
  vsphere_password: 
    _plugin: pkcs7
    encrypted_value: >
      ENC[PKCS7,MIIBe...]
```

### vsphere_insecure
  
``` yaml
type: Boolean
default: <none>
```

Allow insecure connections. This disables SSL verification and allows self-signed certs.

### vsphere_datacenter

``` yaml
type: String[1]
default: <none>
```

Name of the datacenter in vSphere where we will search for VMs.


## TODO: Reference (start here)
  
If you aren't ready to use Strings yet, manually create a REFERENCE.md in the root of your module directory and list out each of your module's classes, defined types, facts, functions, Puppet tasks, task plans, and resource types and providers, along with the parameters for each.

For each element (class, defined type, function, and so on), list:

  * The data type, if applicable.
  * A description of what the element does.
  * Valid values, if the data type doesn't make it obvious.
  * Default value, if any.

For example:

```
### `pet::cat`

#### Parameters

##### `meow`

Enables vocalization in your cat. Valid options: 'string'.

Default: 'medium-loud'.
```

## Limitations

In the Limitations section, list any incompatibilities, known issues, or other warnings.

## Development

In the Development section, tell other users the ground rules for contributing to your project and how they should submit their work.

Generate table of contents for this document:
https://github.com/thlorenz/doctoc

``` yaml
npm install -g doctoc
doctoc README.md
```

## Release Notes/Contributors/Etc. **Optional**

If you aren't using changelog, put your release notes here (though you should consider using changelog). You can also add any additional sections you feel are necessary or important to include here. Please use the `## ` header.
