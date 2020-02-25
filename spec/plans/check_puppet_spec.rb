# frozen_string_literal: true

require 'spec_helper'

describe 'patching::check_puppet' do
  let(:targets_names) { ['foo', 'bar'] }
  let(:targets) { bolt_targets_arr(targets_names) }
  let(:targets_obj) { bolt_targets_obj(targets_names) }
  let(:plan_name) { 'patching::check_puppet' }

  context 'with nodes passed' do
    it 'returns a default value' do
      expect_task('puppet_agent::version')
        .with_targets(targets)
        .with_params('_catch_errors' => false)
        .return_for_targets(
          'foo' => { 'values' => { 'version' => '6.5.4' } },
          'bar' => { 'values' => { 'version' => :undef } },
        )

      # expect_plan('patching::puppet_facts')
      #   .with_params('nodes' => [targets_obj['foo']])
      expect_plan('facts')
        .with_params('targets' => [targets_obj['foo'], targets_obj['bar']])

      result = run_plan(plan_name, 'nodes' => targets_names)
      puts "result = #{result}"
      expect(result).to be_ok
    end
  end
end
