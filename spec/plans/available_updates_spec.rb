# frozen_string_literal: true

require 'spec_helper'

describe 'patching::available_updates' do
  let(:targets_names) { ['foo', 'bar'] }
  let(:targets) { bolt_targets_arr(targets_names) }
  let(:targets_obj) { bolt_targets_obj(targets_names) }
  let(:plan_name) { 'patching::available_updates' }

  context 'with nodes passed' do
    it 'returns a default value' do
      expect_task('patching::available_updates')
        .with_targets(targets)
        .with_params('_noop' => false)
        .return_for_targets(
          'foo' => { 'values' => { 'updates' => ['a'] } },
          'bar' => { 'values' => { 'updates' => ['b'] } },
        )

      result = run_plan(plan_name,
                        'nodes' => targets_names,
                        'format' => 'none')
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
      expect(result.value).to eq(bolt_results('foo' => { 'values' => { 'updates' => ['a'] } },
                                              'bar' => { 'values' => { 'updates' => ['b'] } }))
    end
  end
end
