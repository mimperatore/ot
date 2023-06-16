# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'splat' do
  it 'execs the Splat command with STDIN in binmode' do
    expect(Cmds::Splat).to receive(:exec).with($stdin.binmode)
    load('bin/splat')
  end
end
