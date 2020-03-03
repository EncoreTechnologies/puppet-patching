# @summary Plan to deploy scripts from a bolt control node to a bunch of hosts using Puppet.
#
# TODO support deploying without Puppet on the end node?
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @param [Hash] scripts
#   Scripts hash that each represent patching::script reasources for deploying our scripts
#
# @param [Optional[String]] patching_dir
#   Global directory as the base for `bin_dir` and `log_dir`
#
# @param [Optional[String]] bin_dir
#   Global directory where the scripts will be installed
#
# @param [Optional[String]] bin_dir
#   Directory where log files will be written during patching

# @param [Optional[String]] owner
#   Default owner of installed scripts
#
# @param [Optional[String]] group
#   Default group of installed scripts
#
# @param [Optional[String]] mode
#   Default file mode of installed scripts
#
# @example CLI deploy a pre patching script
#   bolt plan run patching::deploy_scripts scripts='{"pre_patch.sh": {"source": "puppet:///modules/test/patching/pre_patch.sh"}}'
#
# @example CLI deploy a pre and post patching script
#   bolt plan run patching::deploy_scripts scripts='{"pre_patch.sh": {"source": "puppet:///modules/test/patching/pre_patch.sh"}, "post_patch.sh": {"source": "puppet:///modules/test/patching/post_patch.sh"}}'
plan patching::deploy_scripts(
  TargetSpec $targets,
  Hash $scripts,
  Optional[String] $patching_dir = undef,
  Optional[String] $bin_dir      = undef,
  Optional[String] $log_dir      = undef,
  Optional[String] $owner        = undef,
  Optional[String] $group        = undef,
  Optional[String] $mode         = undef,
) {
  $_targets = run_plan('patching::get_targets', $targets)
  return apply($_targets) {
    include patching::params
    class { 'patching':
      scripts      => $scripts,
      patching_dir => pick($patching_dir, $patching::params::patching_dir),
      bin_dir      => pick($bin_dir, $patching::params::bin_dir),
      log_dir      => pick($log_dir, $patching::params::log_dir),
      owner        => pick($owner, $patching::params::owner),
      group        => pick($group, $patching::params::group),
      mode         => pick($mode, $patching::params::mode),
    }
  }
}
