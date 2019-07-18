# Plan the runs 'puppet facts' on the target nodes and sets them as facts on
# the Target objects.
#
# This is inspired by: https://github.com/puppetlabs/puppetlabs-facts/blob/master/plans/init.pp
# Except instead of just running `facter` it runs `puppet facts` to set additional
# facts that are only present when in the context of puppet.
plan patching::puppet_facts(TargetSpec $nodes) {
  $result_set = run_task('patching::puppet_facts', $nodes)
  # puppet facts returns a structure like:
  #   name: mynodename.domain.tld
  #   values:
  #     fact1: abc
  #     fact2: def
  #
  # We only want to set the "values" as facts on the node
  $result_set.each |$result| {
    add_facts($result.target, $result.value['values'])
  }
  return $result_set
}
