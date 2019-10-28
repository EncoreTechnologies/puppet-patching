# @summary Returns an array of names, one for each target, based on the $name_property
#
# @param [TargetSpec] targets
#   List of targets to extract the name from
#
# @param [Enum['name', 'uri']] name_property
#   Property in the Target to use as the name
#
# @return [Array[String]] Array of names, one for each target
function patching::target_names(
  TargetSpec          $targets,
  Enum['name', 'uri'] $name_property,
) >> Array[String] {
  $targets.map |$n| {
    case $name_property {
      'name': {
        $n.name
      }
      'uri': {
        $n.uri
      }
      default: {
        fail_plan("Unsupported patching_target_name_property: ${name_property}")
      }
    }
  }
}
