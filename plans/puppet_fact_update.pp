# @summary Update the given Puppet fact in the corresponding facts file on the targets
#
# @param [TargetSpec] targets
#   Set of targets to run against.
#
# @param [String[1]] fact_name
#   Name of the Puppet fact to update on the target
#
# @param [String] fact_value
#   Value to set the given Puppet fact to on the target
#
# @param [Optional[String]] $json_fact_file_linux
#   Path to the fact file that will be updated on a Linux server
#
# @param [Optional[String]] $json_fact_file_linux
#   Path to the fact file that will be updated on a Windows server
#
# @example vars defined in inventory file
#   vars:
#     puppet_linux_facts_file: '/etc/facter/facts.d/facts.json'
#     puppet_windows_facts_file: 'C:/ProgramData/PuppetLabs/facter/facts.d/facts.json'
#
plan patching::puppet_fact_update (
  TargetSpec $targets,
  String[1] $fact_name,
  String $fact_value,
  Optional[String] $json_fact_file_linux = get_targets($targets)[0].vars['puppet_linux_facts_file'],
  Optional[String] $json_fact_file_windows = get_targets($targets)[0].vars['puppet_windows_facts_file'],
) {
  # Separate Windows and Linux VMs
  $linux_targets = get_targets($targets).filter |$n| { $n.protocol == 'ssh' }
  $windows_targets = get_targets($targets).filter |$n| { $n.protocol == 'winrm' }

  # Convert the fact value to boolean if it's true or false
  if ($fact_value == 'true') or ($fact_value == 'false') {
    $new_fact_value = str2bool($fact_value)
  }
  else {
    $new_fact_value = $fact_value
  }

  $new_fact = {$fact_name => $new_fact_value}

  $linux_targets.each |$target| {
    # Extract the directory from the file path
    $dir_arr = split($json_fact_file_linux, '/')
    $directory = join($dir_arr[0,-2], '/')

    # Verify that the given directory exists
    $check_dir = run_command("if test -d ${directory}; then exit 0; else exit 1; fi", $target, _catch_errors => true)
    if $check_dir.first.status == 'failure' {
      fail_plan('Error: The path to the given directory does not exist!')
    }

    # Check if the file exists and create it if it doesn't
    $check_file = run_command("if test -f ${json_fact_file_linux}; then exit 0; else exit 1; fi", $target, _catch_errors => true)
    if $check_file.first.status == 'success' {
      $file = run_command("cat ${json_fact_file_linux}", $target)
      $external_facts = parsejson($file.first.value['stdout'])
      $new_facts = $external_facts + $new_fact
    }
    else {
      $new_facts = $new_fact
    }

    $facts_string = to_json_pretty($new_facts)
    write_file($facts_string, $json_fact_file_linux, $target)

    run_command('/opt/puppetlabs/bin/puppet facts upload', $target)
  }

  $windows_targets.each |$target| {
    # Extract the directory from the file path
    $dir_arr = split($json_fact_file_windows, '/')
    $directory = join($dir_arr[0,-2], '/')

    # Check if the file exists and create it if it doesn't
    $check_dir = run_command("if(Test-Path -Path '${directory}'){Exit 0}else{Exit 1}", $target, _catch_errors => true)
    if $check_dir.first.status == 'failure' {
      fail_plan('Error: The path to the given directory does not exist!')
    }

    # Check if the file exists and create it if it doesn't
    $check_file = run_command("if(Test-Path -Path '${json_fact_file_windows}'){Exit 0}else{Exit 1}", $target, _catch_errors => true)
    if $check_file.first.status == 'success' {
      $file = run_command("Get-Content '${json_fact_file_windows}'", $target)
      $external_facts = parsejson($file.first.value['stdout'])
      $new_facts = $external_facts + $new_fact
    }
    else {
      $new_facts = $new_fact
    }

    $facts_string = to_json_pretty($new_facts)
    write_file($facts_string, $json_fact_file_windows, $target)

    run_command('& "C:/Program Files/Puppet Labs/Puppet/bin/puppet" facts upload', $target)
  }
}