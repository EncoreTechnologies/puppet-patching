# @summary allows global customization of the patching resources
#
# @param patching_dir
#   Global directory as the base for `bin_dir` and `log_dir`
#
# @param bin_dir
#   Global directory where the scripts will be installed
#
# @param log_dir
#   Directory where log files will be written during patching
#
# @param owner
#   Default owner of installed scripts
#
# @param group
#   Default group of installed scripts
#
# @param mode
#   Default file mode of installed scripts
#
# @param scripts
#   Hash of script resources to instantiate. Useful for declaring script installs from hiera.
#
# @example Basic usage
#  include patching
#
# @example Customizing script location
#  class {'patching':
#    bin_dir => '/my/custom/patching/scripts',
#  }
#
# @example Customizing the owner/group/mode of the scripts
#  class {'patching':
#    owner => 'svc_patching',
#    group => 'svc_patching',
#    mode  => '0700',
#  }
#
# @example Customizing from hiera
#  patching::bin_dir: '/my/custom/app/patching/dir'
#  patching::owner: 'svc_patching'
#  patching::group: 'svc_patching'
#  patching::mode: '0700'
#
# @example Deploying scripts from hiera
#  patching::scripts:
#    custom_app_pre_patch.sh:
#      source: 'puppet:///mymodule/patching/custom_app_pre_patch.sh'
#    custom_app_post_patch.sh:
#      source: 'puppet:///mymodule/patching/custom_app_post_patch.sh'
#
class patching (
  $patching_dir           = $patching::params::patching_dir,
  $bin_dir                = $patching::params::bin_dir,
  $log_dir                = $patching::params::log_dir,
  $owner                  = $patching::params::owner,
  $group                  = $patching::params::group,
  $mode                   = $patching::params::mode,
  Optional[Hash] $scripts = undef,
) inherits patching::params {
  if $patching_dir {
    ensure_resource('file', $patching_dir, {
        ensure => directory,
        owner  => $owner,
        group  => $group,
    })
  }

  if $bin_dir {
    ensure_resource('file', $bin_dir, {
        ensure => directory,
        owner  => $owner,
        group  => $group,
    })
  }

  if $log_dir {
    ensure_resource('file', $log_dir, {
        ensure => directory,
        owner  => $owner,
        group  => $group,
    })
  }

  if $scripts {
    $defaults = {
      bin_dir => $bin_dir,
      owner   => $owner,
      group   => $group,
      mode    => $mode,
    }
    ensure_resources('patching::script', $scripts, $defaults)
  }
}
