# frozen_string_literal: true

require 'spec_helper'

describe 'patching::puppet_facts' do
  let(:targets_names) { ['foo', 'bar'] }
  let(:targets) { bolt_targets_arr(targets_names) }
  let(:targets_obj) { bolt_targets_obj(targets_names) }
  let(:plan_name) { 'patching::puppet_facts' }

  context 'with nodes passed' do
    it 'returns a default value' do
      expect_task('patching::puppet_facts').with_targets(targets).return_for_targets(
        'foo' => { 'values' => { 'fact1' => 1 } },
        'bar' => { 'values' => { 'fact2' => 2 } },
      )
      expect(inventory).to receive(:add_facts)
        .with(targets_obj['foo'], 'fact1' => 1)
        .and_return('fact1' => 1)
      expect(inventory).to receive(:add_facts)
        .with(targets_obj['bar'], 'fact2' => 2)
        .and_return('fact2' => 2)

      result = run_plan(plan_name, 'nodes' => targets_names)
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
      expect(result.value).to eq(bolt_results('foo' => { 'values' => { 'fact1' => 1 } },
                                              'bar' => { 'values' => { 'fact2' => 2 } }))
    end
  end
end
