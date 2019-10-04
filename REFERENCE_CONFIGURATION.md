
# Configuration Options

#### Table of Contents

- [Overview](#overview)
- [patching_order](#patching_order)
- [patching_reboot_strategy](#patching_reboot_strategy)
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

### Overview

This module allows many aspects of its runtime to be customized using configuration options
in the inventory file. 

Example: Let's say we want to prevent some nodes from rebooting during patching.
This can be customized with the `patching_reboot_strategy` variable in inventory:

``` yaml
groups:
  - name: no_reboot_nodes
    vars:
      patching_reboot_strategy: 'never'
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

For more information see the [`patching::ordered_groups`](plans/patching_ordered_groups.pp) plan
documentation.


### patching_reboot_strategy

``` yaml
type: Enum
values:
 - 'only_required'
 - 'never'
 - 'always'
default: 'only_required'
```

Determines the way we handle reboots on nodes during the patching process.

* `'only_required'`[default]  This value performs a "smart" check,
  asking the target OS if it thinks it needs a reboot. A lot of times this does
  a good job (usually Linux hosts). There are some instances however where it
  doesn't return accurate results every time, so there are other options below.
* `'never'` Allows you to completely disable rebooting of a host. This might be used
  if you're patching in one window and allowed reboots in another. Another potential
  use case is that you're patching a critical asset that should not be rebooted
  except only under specific circumstances.
* `'always'` This value will reboot the targets no matter what. We often see this
  used in Windows environments where the OS doesn't always report back good data
  about if a reboot is required or not. Also, on Windows many updates don't run
  through their post-install process until a reboot is performed.


### patching_reboot_message

``` yaml
type: String
default: 'NOTICE: This system is currently being updated.'
```

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
