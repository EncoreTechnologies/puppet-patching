# frozen_string_literal: true

require 'spec_helper'

# bolt_results({
# 'foo' => { 'values' => { 'fact1' => 1 } },
# 'bar' => { 'values' => { 'fact2' => 2 } }))
#
# - This accepts a Hash
# - Each key is the name of a target
# - Each value is a hash with a key 'values'. The 'values' key then contains
#   a hash of the result data for that target.
def bolt_results(targets_values)
  Bolt::ResultSet.new(
    targets_values.map { |t, v| Bolt::Result.new(targets_obj[t], value: v) },
  )
end

# Converts an array of names into an array of Bolt::Target objects
def bolt_targets_arr(target_names_a)
  target_names_a.map { |t| Bolt::Target.new(t) }
end

# Converts an array of names into a hash where the keys are target names
# and the values are Bolt::Target objects
def bolt_targets_obj(target_names_a)
  h = {}
  target_names_a.each { |t| h[t] = Bolt::Target.new(t) }
  h
end
