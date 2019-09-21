# frozen_string_literal: true

require 'bolt/error'

# Returns a hash of the 'vars' (variables) at the global scope in the inventory file.
Puppet::Functions.create_function(:'patching::vars') do
  # @return A hash of the 'vars' (variables) at the global scope in the inventory file.
  # @example Get global vars
  #   $some_var = patching::vars()['some_var']
  dispatch :vars do
    return_type 'Hash[String, Data]'
  end

  def vars()
    inventory = Puppet.lookup(:bolt_inventory)
    inventory.instance_variable_get(:@data)['vars']
  end
end
