# Changelog

All notable changes to this project will be documented in this file.

## Development

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
