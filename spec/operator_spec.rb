# frozen_string_literal: true

require 'spec_helper'
require 'yaml'
require 'stringio'

RSpec.describe Operator do
  let(:config) do
    YAML.load(<<~EOS)
      commands:
        test_cmd: test_inv_cmd
        test_cmd_nl: test_inv_cmd_nl
        test_cmd_with_param %{param1}: test_inv_cmd_with_param %{param1}

      nl_adders:
        - test_cmd_nl
      EOS
  end

  let(:content) { 'test content' }
  let(:cmd) { 'test_cmd' }
  let(:output) { 'test output' }
  let(:args) { {arg1: 123} }

  subject { described_class.new(cmd: cmd, args: args, content: content) }

  before(:each) do
    allow(described_class).to receive(:operators_config).and_return(config)
  end

  describe '#exec' do
    context 'simple operators' do
      it 'executes the command, passing it the correct content' do
        pipe = double('pipe')
        expect(IO).to receive(:popen).with(cmd, 'r+').and_yield(pipe)
        expect(pipe).to receive(:write).with(content).ordered
        expect(pipe).to receive(:close_write).ordered
        expect(pipe).to receive(:read).ordered.and_return(output)

        subject.exec
      end

      context "when newline shouldn't be removed" do
        it 'returns the command output untouched' do
          pipe = spy('pipe')
          allow(IO).to receive(:popen).with(cmd, 'r+').and_yield(pipe)
          allow(pipe).to receive(:read).and_return(output)

          expect(subject.exec).to eq(output)
        end
      end

      context 'when newline should be removed' do
        let(:cmd) { 'test_cmd_nl' }
        let(:output) { "content with newline\n" }

        it 'returns the command output with trailing newline removed' do
          pipe = spy('pipe')
          allow(IO).to receive(:popen).with(cmd, 'r+').and_yield(pipe)
          allow(pipe).to receive(:read).and_return(output)

          expect(subject.exec).to eq(output.chomp("\n"))
        end
      end

      context 'when command expects param' do
        let(:cmd) { 'test_cmd_with_param %{param1}' }
        let(:args) { { param1: 123 } }

        it 'does the param substitution' do
          pipe = spy('pipe')
          parameterized_cmd = cmd % args
          expect(IO).to receive(:popen).with(parameterized_cmd, 'r+').and_yield(pipe)
          subject.exec
        end
      end

      context 'when command is on the inverse side of the config' do
        let(:cmd) { 'test_inv_cmd_with_param %{param1}' }
        let(:args) { { param1: 123 } }

        it 'still works as expected' do
          pipe = spy('pipe')
          parameterized_cmd = cmd % args
          expect(IO).to receive(:popen).with(parameterized_cmd, 'r+').and_yield(pipe)
          subject.exec
        end
      end
    end
  end

  describe '#serialize' do
    let(:cmd) { 'test_cmd_with_param %{param1}' }
    let(:output) { 'test output' }
    let(:args) { { param1: 123 } }

    it 'returns the serialized value' do
      allow(subject).to receive(:exec).and_return(output)
      expect(subject.serialize).to eq(
        ">><<test_inv_cmd_with_param %{param1}:param1=123:#{output.bytes.length}:#{output}"
      )
    end

    context 'when command is on the inverse side of the config' do
      let(:cmd) { 'test_inv_cmd_with_param %{param1}' }
      let(:output) { 'test output' }
      let(:args) { { param1: 123 } }

      it 'still works as expected' do
        allow(subject).to receive(:exec).and_return(output)
        expect(subject.serialize).to eq(
          ">><<test_cmd_with_param %{param1}:param1=123:#{output.bytes.length}:#{output}"
        )
      end
    end
  end

  describe '.deserialize' do
    let(:stream) do
      StringIO.new(
        ">><<#{cmd}:param1=123;param2=456:#{output.bytes.length}:#{output}"
      )
    end

    it 'returns nil if the stream is at EOF' do
      stream = spy('stream')
      allow(stream).to receive(:eof).and_return(true)
      expect(described_class.deserialize(from: stream)).to be_nil
    end

    it 'correctly deserializes a serialized operator' do
      op = described_class.deserialize(from: stream)
      expect(op.cmd).to eq(cmd)
      expect(op.args).to eq(param1: '123', param2: '456')
      expect(op.content_len).to eq(output.bytes.length)
      expect(op.content).to eq(output)
    end

    context 'when the magic marker is missing' do
      let(:stream) { StringIO.new('garbage') }

      it 'raises an error' do
        expect{ described_class.deserialize(from: stream) }.to raise_error(ArgumentError, 'Magic marker not found')
      end
    end
  end
end
