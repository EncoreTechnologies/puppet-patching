# @summary Sets patching facts on targets
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @param [Variant[String, Array[String]]] names
#   Name or list of fact names to retrieve from the targets
#
# @example Get the patching_group fact (default)
#   bolt plan run patching::get_facts --targets xxx
#
# @example Get different facts
#   bolt plan run patching::get_facts --targets xxx names='["fact1", "fact2"]'
#
plan patching::get_facts (
  TargetSpec $targets,
  Variant[String, Array[String]] $names = ['patching_group'],
) {
  # this will set all of the facts on the targets if they have Puppet or not
  $_targets = run_plan('patching::get_targets', $targets)

  # make sure facts is an array so we can treat it consistently
  if $names =~ Array {
    $_names = $names
  }
  else {
    $_names = [$names]
  }

  $_results = $_targets.map |$t| {
    $target_facts = $_names.reduce({}) |$memo, $n| {
      $memo + { $n => facts($t)[$n] }
    }
    Result($t, $target_facts)
  }
  return ResultSet($_results)
}
