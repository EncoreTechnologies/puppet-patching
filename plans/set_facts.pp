# @summary Sets patching facts on targets
#
# For Linux targets the facts will be written to <code>/etc/facter/facts.d/patching.yaml</code>.
# For Windows targets the facts will be written to <code>'C:/ProgramData/PuppetLabs/facter/facts.d/patching.yaml'</code>.
#
# The contents of the <code>patching.yaml</code> file will be overwritten by this plan.
# TODO: Provide an option to merge with existing facts.
#
# Once the facts are written, by default, the facts will be ran and uploaded to PuppetDB.
# If you wish to disable this, simply set <code>upload=false</code>
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @param [Optional[String]] patching_group
#   Name of the patching group that the targets are a member of. This will be the value for the
#   <code>patching_group</code> fact.
#
# @param [Hash] custom_facts
#   Hash of custom facts that will be set on these targets. This can be anything you like
#   and will merged with the other facts above.
#
# @param [Boolean] upload
#   After setting the facts, perform a <code>puppet facts upload</code> so the new
#   facts are stored in PuppetDB.
#
# @example Set the patching_group fact
#   bolt plan run patching::set_facts --targets xxx patching_group=tuesday_night
#
# @example Set the custom facts
#   bolt plan run patching::set_facts --targets xxx custom_facts='{"fact1": "blah"}'
#
# @example Don't upload facts to PuppetDB
#   bolt plan run patching::set_facts --targets xxx patching_group=tuesday_night upload=false
#
plan patching::set_facts (
  TargetSpec $targets,
  Optional[String] $patching_group = undef,
  Hash $custom_facts = {},
  Boolean $upload = true,
) {
  # this will set all of the facts on the targets if they have Puppet or not
  $_targets = run_plan('patching::get_targets', $targets)

  # split by linux vs windows because of the different paths for custom facts
  $targets_linux = $_targets.filter |$t| { facts($t)['os']['family'] != 'windows' }
  $targets_windows = $_targets.filter |$t| { facts($t)['os']['family'] == 'windows' }

  # merge our facts
  # the explicitly defined facts always win
  $_facts = $custom_facts + { 'patching_group' => $patching_group }
  $_facts_yaml = stdlib::to_yaml($_facts)
  out::message('============= writing facts.d/patching.yaml =============')
  out::message($_facts_yaml)

  if !$targets_linux.empty() {
    write_file($_facts_yaml,
      '/etc/facter/facts.d/patching.yaml',
    $targets_linux)
    $results_linux = run_command('/opt/puppetlabs/bin/puppet facts upload', $targets_linux)
  }
  else {
    $results_linux = ResultSet([])
  }

  if !$targets_windows.empty() {
    write_file($_facts_yaml,
      'C:/ProgramData/PuppetLabs/facter/facts.d/patching.yaml',
    $targets_windows)
    $results_windows =  run_command("& 'C:/Program Files/Puppet Labs/Puppet/bin/puppet' facts upload", $targets_windows)
  }
  else {
    $results_windows = ResultSet([])
  }
  return ResultSet($results_linux.results + $results_windows.results)
}
