# @summary params for the patching module resources
class patching::params {
  case $facts['os']['family'] {
    'Windows': {
      $patching_dir = 'C:/ProgramData/patching'
      $bin_dir = "${patching_dir}/bin"
      $log_dir = "${patching_dir}/log"
      $owner = 'Administrator'
      $group = 'Administrator'
      $mode = '0770'
    }
    'RedHat': {
      $patching_dir = '/opt/patching'
      $bin_dir = "${patching_dir}/bin"
      $log_dir = "${patching_dir}/log"
      $owner = 'root'
      $group = 'root'
      $mode = '0770'
    }
    'Debian': {
      $patching_dir = '/opt/patching'
      $bin_dir = "${patching_dir}/bin"
      $log_dir = "${patching_dir}/log"
      $owner = 'root'
      $group = 'root'
      $mode = '0770'
    }
    'Suse': {
      $patching_dir = '/opt/patching'
      $bin_dir = "${patching_dir}/bin"
      $log_dir = "${patching_dir}/log"
      $owner = 'root'
      $group = 'root'
      $mode = '0770'
    }
    default: {
      fail("Unsupported OS family: ${facts['os']['family']}")
    }
  }
}
