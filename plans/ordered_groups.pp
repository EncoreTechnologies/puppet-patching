# @summary Takes a set of targets then groups and sorts them by the <code>patching_order</code> var set on the target.
#
# When patching hosts it is common that you don't want to patch them all at the same time,
# for obvious reasons. To facilitate this we devised the concept of a "patching order".
# Patching order is a mechanism to allow nodes to be organized into groups and
# then sorted so that a custom order can be defined for your specific usecase.
#
# The way one assigns a patching order to a target or group is using <code>vars</code>
# in the Bolt inventory file.
#
# Example:
#
# ```yaml
# ---
# groups:
#   - name: primary_nodes
#     vars:
#       patching_order: 1
#     targets:
#       - sql01.domain.tld
#
#   - name: backup_nodes
#     vars:
#       patching_order: 2
#     targets:
#       - sql02.domain.tld
# ```
#
# When the <code>patching_order</code> is defined at the group level, it is inherited
# by all nodes within that group.
#
# The reason this plan exists is that there is no concept of a "group" in the bolt
# runtime, so we need to artificially recreate them using our <code>patching_order</code>
# vars paradigm.
#
# An added benefit to this paradigm is that you may have grouped your nodes logically
# on a different dimension, say by application. If it's OK that multiple applications be
# patched at the same time, we can assign the same patching order to multiple groups
# in the inventory. Then, when run through this plan, they will be aggregated together
# into one large group of nodes that will all be patched concurrently.
#
# Example, app_xxx and app_zzz both can be patched at the same time, but app_yyy needs to go
# later in the process:
#
# ```yaml
# ---
# groups:
#   - name: app_xxx
#     vars:
#       patching_order: 1
#     targets:
#       - xxx
#
#   - name: app_yyy
#     vars:
#       patching_order: 2
#     targets:
#       - yyy
#
#   - name: app_zzz
#     vars:
#       patching_order: 1
#     targets:
#       - zzz
# ```
#
# @param [TargetSpec] nodes
#   Set of targets to created ordered groups of.
#
# @return [Array[Struct[{'order' => Data, 'nodes' => Array[Target]}]]]
#   An array of hashes, each hash containing two properties:
#
#     - 'order' : This is the value of the <code>patching_order</code> defined
#       in the inventory. This can be any datatype you wish, as long as it's
#       comparable with the <code>sort()</code> function.
#     - 'nodes' : An array of targets in this group.
#
#  This is returned as an Array, because an Array has a defined order when
#  you iterate over it using <code>.each</code>. Ordering is important in patching
#  so we wanted this to be very concrete.
#
# @example Basic usage
#   $ordered_groups = run_plan('patching::ordered_groups', nodes => $targets)
#   $ordered_groups.each |$group_hash| {
#     $group_order = $group_hash['order']
#     $group_nodes = $group_hash['nodes']
#     # run your patching process for the group
#   }
#
#
plan patching::ordered_groups (
  TargetSpec $nodes,
) {
  $targets = get_targets($nodes)

  ## The following parses the nodes for their patching_order variable.
  ## patching_order will dictate the order the systems are processed.
  $ordered_hash = $targets.reduce({}) |$memo, $t| {
    $order_unknown_type = vars($t)['patching_order']
    $order = String($order_unknown_type)
    if $order in $memo {
      $ordered_array = $memo[$order] << $t
      $memo + {$order => $ordered_array}
    }
    else {
      $memo + {$order => [$t]}
    }
  }

  # when iterating over a hash, it isn't guaranteed to iterate in the sorted order
  # of the keys, this pulls the keys out of the hash and sorts them
  # $ordered_hash = {'2' => ['b'], '3' => ['c'], '1' => ['a']}
  #
  # $ordered_keys = ['1', '2', '3']
  $ordered_keys = sort(keys($ordered_hash))
  out::message("Groups = ${ordered_keys}")
  $ordered_groups = $ordered_keys.map |$o| {
    $ordered_nodes = $ordered_hash[$o].map |$t| {$t.host}
    out::message("Group '${o}' nodes = ${ordered_nodes}")
    # trust me, we have to assign to a variable here, it's a detail of the puppet
    # language parser that gets mad, but only because there is the loop above
    $group = {'order' => $o, 'nodes' => $ordered_hash[$o]}
    $group
  }

  return $ordered_groups
}
