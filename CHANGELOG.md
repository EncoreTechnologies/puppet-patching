# Changelog

All notable changes to this project will be documented in this file.

## Development

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

* Added a new config option `patching_monitoring_target_name_property` that determines
  what property on the target maps to the node's name in the monitoring tool (SolarWinds).
  This was intentionally made discinct from `patching_snapshot_target_name_property` in case
  the tools used different names for the same node/target. (Enhancement)
  
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
