# Changelog

All notable changes to this project will be documented in this file.

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
