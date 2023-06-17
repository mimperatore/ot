# frozen_string_literal: true

module Cmds
  class Store < Generic
    STORAGE_DIR = "#{Dir.home.chomp('/')}/.ot/".freeze

    def self.exec(input_stream:)
      temp_filename = "#{STORAGE_DIR}temp-#{Process.pid}"
      store_op = Operator.new(name: 'store',
                              pipeline: ["tee #{temp_filename}", 'sha256sum -bz',
                                         "awk '{printf $1}'", 'tr -d "\n"'])
      fetch_op = Operator.new(name: 'fetch', pipeline: ["cat #{STORAGE_DIR}%<sha256sum>s"])
      super(
        fwd_op: store_op,
        fwd_args: {},
        input_stream:,
        inv_op: fetch_op,
        inv_args: {}
      ) do |fwd_output:, inv_arguments:|
        sha256sum = fwd_output
        dest_filename = "#{STORAGE_DIR}#{sha256sum}"
        if File.exist?(dest_filename)
          FileUtils.rm(temp_filename)
        else
          FileUtils.mv(temp_filename, dest_filename)
        end
        {
          fwd_output: '',
          inv_arguments: inv_arguments.merge(sha256sum:)
        }
      end
    end
  end
end
