# frozen_string_literal: true

require 'spec_helper'

describe 'patching::puppet_facts' do
  def modulepath
    File.join(__dir__, '../fixtures/modules')
  end

  let(:targets_name) { ['foo', 'bar'] }
  let(:targets) { targets_name.map { |t| Bolt::Target.new(t) } }
  let(:targets_obj) do
    h = {}
    targets_name.each { |t| h[t] = Bolt::Target.new(t) }
    h
  end
  let(:plan_name) { 'patching::puppet_facts' }

  def results(values)
    Bolt::ResultSet.new(
      values.map { |t, v| Bolt::Result.new(targets_obj[t], value: v) },
    )
  end

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

      result = run_plan(plan_name, 'nodes' => targets_name)
      expect(result).to be_ok
      expect(result.value.class).to eq(Bolt::ResultSet)
      expect(result.value).to eq(results('foo' => { 'values' => { 'fact1' => 1 } },
                                         'bar' => { 'values' => { 'fact2' => 2 } }))
    end
  end
end
