# Changelog

All notable changes to this project will be documented in this file.

## Development


## Release 1.7.0 (2022-04-18)

* Added support for AlmaLinux. (Enhancement)

  Contributed by Vadym Chepkov (@vchepkov)

* Fixing issue where the update history was not being reported
  back on RHEL8 systems.

  Contributed by Bradley Bishop (@bishopbm1)

## Release 1.6.0 (2021-07-08)

* Added support for Oracle Linux.

  Contributed by Sean Millichamp (@seanmil)

## Release 1.5.1 (2021-07-08)

* remove unused hiera configuration

  Contributed by Vadym Chepkov (@vchepkov)

## Release 1.5.0 (2021-07-07)

* Added disconnect_wait input to be passed to the reboot plan so that
  there can be controls around when the plan checks if the server has
  rebooted.

  Contributed by Bradley Bishop (@bishopbm1)

* Added support for Rocky Linux. (Enhancement)

  Contributed by Vadym Chepkov (@vchepkov)

## Release 1.4.0 (2021-04-30)

* Added a new plan and task `patching::snapshot_kvm` for creating/deleting
  snapshots on KVM/libvirt.

  Contributed by Nick Maludy (@nmaludy)

## Release 1.3.0 (2021-03-05)

* Fixed issue where puppet facts were not in the expected spot causing
  puppet_facts plan to fail. We added a conditional to check for the facts
  in both places

  Contributed by Bradley Bishop (@bishopbm1)

* Bumped module `puppetlabs/puppet_agent` to `< 5.0.0`

  Contributed by @fetzerms

* Added module `puppetlabs/reboot` to `>= 3.0.0 < 5.0.0`

  Contributed by @fetzerms

* Bumped `puppet` requirement to `< 8.0.0` to support Puppet 7

  Contributed by Nick Maludy (@nmaludy)

* PDK update to `2.0.0`

  Contributed by Nick Maludy (@nmaludy)

* Remove tests for Puppet `5`.
  **NOTICE** Puppet 5 support will be removed in next major version.

  Contributed by Nick Maludy (@nmaludy)

* Added tests for Puppet `7`

  Contributed by Nick Maludy (@nmaludy)

## Release 1.2.1 (2021-02-02)

* Fixed issue where agruments for reboot strategy are being overridden by
  inventory file.

  Contributed by Bradley Bishop (@bishopbm1)

* Switch from Travis to GitHub Actions

  Contributed by Nick Maludy (@nmaludy)

## Release 1.2.0 (2020-12-02)

* Added monitoring_prometheus bolt plan and task to optionally create/delete silences
  in Prometheus to suppress alerts for the given targets.

* Added monitoring_multiple bolt plan to enable/disable monitoring for multiple
  different services at once.

  Contributed by John Schoewe (@jschoewe)

## Release 1.1.1 (2020-06-09)

* Fixed header line for CSV

  Contributed by Haroon Rafique

* Fixed trivial bug with useless use of cat

  Contributed by Haroon Rafique

* Added new configuration option:
  * `patching_update_provider`: Parameter sets the provider in the update tasks.

  Contributed by Bill Sirinek (@sirinek)

* Fixed bug in `patching::available_updates_windows` where if `choco outdated` printed an
  error, but returned a `0` exit status our output parsing code was throwing an exception
  causing a unhelpful error to be printed. Now, we check for this condition and if we
  can't successfully parse the output of `choco outdated` we explicitly fail the task
  and return the raw output from the command.

  Contributed by Nick Maludy (@nmaludy)

## Release 1.1.0 (2020-04-15)

* Added new plans `patching::get_facts` to retrieve a set of facts from a list of targets
  and `patching::set_facts` to set facts on a list of targets. This is used to assign
  the `patching_group` fact so that we can query PuppetDB for group information in dynamic
  Bolt inventories.

  Contributed by Nick Maludy (@nmaludy)

* Fixed a bug with a hard coded wait for reboot. (Bug Fix)

  Contributed by Michael Surato (@msurato)

* Add `hostname` as a choice for patching::snapshot_vmware::target_name_property
  It can be used in cases where target discovery uses fully qualified domain names
  and VM names don't have domain name component

  Contributed by Vadym Chepkov (@vchepkov)

* Fixed a bug in `patching::monitoring_solarwinds` plan where `patching_monitoring_name_property`
  config value wasn't being honored. (Bug Fix)

  Contributed by Nick Maludy (@nmaludy)

* Fixed a bug in `patching::update` task on RHEL where errors in the `yum` command we're
  being reported due to the use of a `|`. Now we check `$PIPESTATUS[0]` instead of `$?`. (Bug Fix)

  Contributed by Nick Maludy (@nmaludy)

* Added new configuration options:
  * `patching_reboot_wait`: Parameter controls the `reboot_wait` option for the number of seconds
    to wait between reboots. Default = 300
  * `paching_report_file`: Customize the name of the report file to write to disk. You
    can disable writing the report files by specifying this as `'disabled'`.
    NOTE: for PE users writing files to disk throws an error, so you'll be happy you can
    now disable writing these files!
    Default = `patching_report.csv`
  * `patching_report_format`: Customize the format of the reports written to the report file.
    Default = `pretty`

  (Enhancement)

  Contributed by Nick Maludy (@nmaludy)

* To support the new configuration options above, the `patching::reboot_required` plan
  had its parameter `reboot_wait` renamed to `wait`.  (Enhancement)

  Contributed by Nick Maludy (@nmaludy)

## Release 1.0.1 (2020-03-04)

* Ensure the `patching.json` file exists on Windows by creating a blank file if it was previously missing.

  Contributed by Bill Sirinek (@sirinek)

* use `name` instead of `host` to better represent targets in inventory

  Contributed by Vadym Chepkov (@vchepkov)

* Fixed a bug where if `patching::update_history` task was called and no results were returned
  the `patching::update_history` plan would fail. Now, we default to an empty array so a 0
  is displayed.

  Contributed by Nick Maludy (@nmaludy)

## Release 1.0.0 (2020-02-28)

* **BREAKING CHANGE**
  Converted from `nodes` to `targets` for all plans and tasks. This is in support of Bolt `2.0`.
  Any calling plans or CLI will need to use the `targets` parameter to pass in the hosts
  to be patched. (Feature)

  Contributed by Nick Maludy (@nmaludy)

* Fixed inconsistent documentation for result file location, proper location is: `C:/ProgramData/patching/log/patching.json`. (Bug Fix) #28

  Contributed by Nick Maludy (@nmaludy)

* Added documentation for patching with PE and `pcp` timeouts. (Documentation) #28

  Contributed by Nick Maludy (@nmaludy)

* PDK sync to 1.17.0 template (Enhancement)

  Contributed by Nick Maludy (@nmaludy)

## Release 0.5.0 (2020-02-20)

* Made the timeout after reboot a configurable parameter. (Enhancement)

  Contributed by Michael Surato (@msurato)

* Fixed bug in `patching::snapshot_vmware` where the wrong snapshot name was printed to the user. (Bug Fix)

  Contributed by Nick Maludy (@nmaludy)

* Fixed bug in `patching::available_updates_windows` where using `provider=windows` threw an error. (Bug Fix)

  Contributed by Nick Maludy (@nmaludy)

* Add support for Fedora Linux. (Enhancement)

  Contributed by Vadym Chepkov (@vchepkov)

* Modified location of the puppet executable on Linux to use the supported wrapper. This sets
  library paths to solve consistency issues. (Bug Fix)

  Contributed by Michael Surato (@msurato)

## Release 0.4.0 (2020-01-06)

* Add support for SUSE Linux Enterprise. (Enhancement)

  Contributed by Michael Surato (@msurato)

* Modify the scripts to use /etc/os-release. This will fallback to older methods in the absense of /etc/os-release. (Enhancement)

  Contributed by Michael Surato (@msurato)

* Re-establish all targets availability after reboot

  Contributed by Vadym Chepkov (@vchepkov)

* Fixed a bug in `patching::puppet_facts` where the sub command would fail to run on
  installations with custom `GEM_PATH` settings. (Bug Fix)

  Contributed by Nick Maludy (@nmaludy)

* Changed the property we use to look up SolarWinds nodes from `'Caption'` to `'DNS'` by
  default. Also made the property configurable using the `patching_monitoring_name_property`.
  There are now new parameters on the `patching::monitoring_solarwinds` task and plans
  to allow specifying what property we are matching for on the SolarWinds side. (Enhancement)

  Contributed by Nick Maludy (@nmaludy)


## Release 0.3.0 (2019-10-30)

* Add support for RHEL 8 based distributions (Enhancement)

  Contributed by Vadym Chepkov (@vchepkov)

* Added shields/badges to the README. (Enhancement)

  Contributed by Nick Maludy (@nmaludy)

* Added the ability to enable/disable monitoring during patching. The first implementation
  is to do this in the SolarWinds monitoring tool:
  * Task - `patching::monitoring_solarwinds` : This task enables/disbles monitoring for a list
    of node names.
  * Plan - `patching::monitoring_solarwinds` : Wraps the `patching::monitoring_solarwinds` task in an
    easier to consume fashion, along with configuration option parsing and pretty printing.
  (Enhancement)

  Contributed by Nick Maludy (@nmaludy)

* Changed the name of the configuration option `patching_vm_name_property` to `patching_snapshot_target_name_property`.
  This correlates to the new property that was just added (below). (Enhancement)

  Contributed by Nick Maludy (@nmaludy)

* Added a new configs:
    - `patching_monitoring_plan` Name of the plan to execute for monitoring alerts control.
      (default: `patching::monitoring_solarwinds`)
    - `patching_monitoring_enabled` Enable/disable the monitoring phases of patching.
      (default: `true`)
    - `patching_monitoring_target_name_property` Determines what property on the target
      maps to the node's name in the monitoring tool (SolarWinds).
      This was intentionally made discinct from `patching_snapshot_target_name_property` in case
      the tools used different names for the same node/target.

  Contributed by Nick Maludy (@nmaludy)

* Empty strings `''` for plan names no longer disable the execution of plans (the
  `pick()` function removes these, so it gets ignored). Instead pass in the string
  `'disabled'` to disable the use of a pluggable plan. (Bug fix)

  Contributed by Nick Maludy (@nmaludy)


## Release 0.2.0

* Renamed task implementations to `_linux` and `_windows` to work around a Forge bug
  where it didn't support that Bolt feature and was denying module submission.
  Due to this i also had to create matching task metadata for `_linux` and `_windows`
  and mark them as `"private": true` so that they are not visible in `bolt task show`.
  (Enhancement)

  Contributed by Nick Maludy (@nmaludy)

## Release 0.1.0

**Features**

**Bugfixes**

**Known Issues**
