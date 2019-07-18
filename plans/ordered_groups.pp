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
