# @summary <code>get_targets()</code> except it also performs online checks and gathers facts in one step.
#
# A very common requirement when running individual plans from the commandline is that
# each plan would need to perform the following steps:
#  - Convert the TargetSpec from a string into an Array[Target] using <code>get_targets($targets)</code>
#  - Check for targets that are online (calls plan <code>patching::check_puppet</code>
#  - Gather facts about the targets
#
# This plan combines all of that into one so that it can be reused in all of the other
# plans within this module. It also adds some smart checking so that, if multiple plans
# invoke each other, each of which call this plan. The online check and facts gathering
# only hapens once.
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @return [Array[Target]] Targets converted to an array for use later in the calling plan
#
# @example Plan - Basic usage
#   plan mymodule::myplan (
#     TargetSpec $targets
#   ) {
#     $targets = run_plan('patching::get_targets', $targets)
#     # do normal stuff with your $targets
#   }
plan patching::get_targets (
  TargetSpec $targets,
) {
  $_targets = get_targets($targets)
  $target_first_facts = facts($_targets[0])
  if !$target_first_facts['os'] or !$target_first_facts['os']['family'] {
    run_plan('patching::check_puppet', $_targets)
  }
  return $_targets
}
