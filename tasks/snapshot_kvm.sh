#!/bin/bash

# convert JSON list into spaced list for Bash to be happy with
IFS=$'\n' vm_names=($(echo "$PT_vm_names" | sed -E -e 's/(\["|"\])//g' | sed -e 's/","/'"\n"'/g'))
echo "vm_names = $vm_names"
echo "snapshot_name = $PT_snapshot_name"
echo "snapshot_description = $PT_snapshot_description"
echo "snapshot_memory = $PT_snapshot_memory"
echo "snapshot_quiesce = $PT_snapshot_quiesce"
echo "action = $PT_action"

extra_args=""
if [[ "${PT_snapshot_memory}" == "false" ]]; then
  extra_args="$extra_args --disk-only"
fi
if [[ "${PT_snapshot_quiesce}" == "true" ]]; then
  extra_args="$extra_args --quiesce"
fi

for vm in "${vm_names[@]}"; do
  echo "snapshot vm=${vm} action=${PT_action}"
  if [[ "${PT_action}" == "create" ]]; then
    virsh snapshot-create-as --domain "${vm}" \
          --name "${PT_snapshot_name}" \
          --description "${PT_snapshot_description}" \
          --atomic
  elif [[ "${PT_action}" == "delete" ]]; then
    virsh snapshot-delete --domain "${vm}" \
          --snapshotname "${PT_snapshot_name}"
  else
    echo "ERROR: action='${PT_action}' is not supported. Valid actions are: 'create', 'delete'"
    exit 1
  fi
done
