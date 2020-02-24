# frozen_string_literal: true

require 'spec_helper'

describe 'patching::check_online' do
  let(:targets_names) { ['foo', 'bar'] }
  let(:targets) { bolt_targets_arr(targets_names) }
  let(:targets_obj) { bolt_targets_obj(targets_names) }
  let(:plan_name) { 'patching::check_online' }

  context 'with nodes passed' do
    it 'returns a default value' do
      expect_task('puppet_agent::version')
        .with_targets(targets)
        .with_params('_catch_errors' => true)
      expect_out_message.with_params('All nodes succeeded!')

      result = run_plan(plan_name, 'nodes' => targets_names)
      expect(result).to be_ok
      expect(result.value).to be_nil
    end
  end
end
