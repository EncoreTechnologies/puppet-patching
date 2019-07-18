#!/bin/bash

if [[ -z "$PT_script" ]]; then
  PT_script='/etc/puppetlabs/patching/pre_patch.sh'
fi

if [[ -x "$PT_script" ]]; then
  "$PT_script"
  exit $?
else
  exit 0
fi
