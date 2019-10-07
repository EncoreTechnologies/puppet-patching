# @summary manages a script for custom patching actions
#
# @param source
#   Source (puppet path) for the `file` resource of the script.
#   Either `source` our `content` must be specified. If neither are specified an error will be thrown.
#
# @param content
#   Content (raw string, result of `template()`, etc) for the `file` resource of the script.
#   Either `source` our `content` must be specified. If neither are specified an error will be thrown.
#
# @param bin_dir
#   Directory where the script will be installed
#
# @param owner
#   Owner of the script file
#
# @param group
#   Group of the script file
#
# @param mode
#   File mode to set on the script
#
# @example Basic usage from static file
#  include patching
#  patching::script { 'pre_patch.sh':
#    source => 'puppet://mymodule/patching/custom_app_pre_patch.sh',
#  }
#
# @example Basic usage from template
#  include patching
#  patching::script { 'pre_patch.sh':
#    content => template('mymodule/patching/custom_app_pre_patch.sh'),
#  }
#
# @example Installing the script into a different path with a different name
#  include patching
#  patching::script { 'custom_app_pre_patch.sh':
#    content => template('mymodule/patching/custom_app_pre_patch.sh'),
#    bin_dir => '/my/custom/app/patching/dir',
#  }
#
# @example Installing multiple scripts into a different path
#  class {'patching':
#    bin_dir => '/my/custom/app/patching/dir',
#  }
#
#  # we don't have to override bin_dir on each of these because
#  # we configured it gobally in the patching class above
#  patching::script { 'custom_app_pre_patch.sh':
#    content => template('mymodule/patching/custom_app_pre_patch.sh'),
#  }
#  patching::script { 'custom_app_post_patch.sh':
#    content => template('mymodule/patching/custom_app_post_patch.sh'),
#  }
#
# @example From hiera
#  patching::bin_dir: '/my/custom/app/patching/dir'
#  patching::scripts:
#    custom_app_pre_patch.sh:
#      source: 'puppet:///mymodule/patching/custom_app_pre_patch.sh'
#    custom_app_post_patch.sh:
#      source: 'puppet:///mymodule/patching/custom_app_post_patch.sh'
#
define patching::script (
  $source       = undef,
  $content      = undef,
  $bin_dir      = $patching::bin_dir,
  $owner        = $patching::owner,
  $group        = $patching::group,
  $mode         = $patching::mode,
) {
  if $source {
    file { "${bin_dir}/${name}":
      ensure => file,
      source => $source,
      owner  => $owner,
      group  => $group,
      mode   => $mode,
    }
  }
  elsif $content {
    file { "${bin_dir}/${name}":
      ensure  => file,
      content => $content,
      owner   => $owner,
      group   => $group,
      mode    => $mode,
    }
  }
  else {
    fail("Must specify either 'source' or 'content', we received 'undef' for both.")
  }
}
