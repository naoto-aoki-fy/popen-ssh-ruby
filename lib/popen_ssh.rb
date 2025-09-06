# frozen_string_literal: true

require 'open3'
require_relative 'popen_ssh/version'

module PopenSSH
  def self.start(host, user, **opts)
    session = Session.new(host, user, **opts)
    return session unless block_given?
    yield session
  end

  class Session
    attr_reader :host, :user, :channel

    def initialize(host, user, opts = {})
      @host = host
      @user = user
    end

    def open_channel
      @channel = Channel.new(self)
      return @channel unless block_given?
      yield @channel
    end

    def loop
      @channel.wait
    end
  end

  class Channel
    def initialize(session)
      @session = session
    end

    def exec(command)
      args = ['ssh', '-l', @session.user, @session.host, '--']
      args.concat(command.split(/\s+/))
      @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(*args)
      return self unless block_given?
      yield self, true
    end

    def send_data(data)
      @stdin.write(data)
    end

    def on_data(&block)
      @on_data_block = block
    end

    def on_extended_data(&block)
      @on_extended_data_block = block
    end

    def on_close(&block)
      @on_close_block = block
    end

    def wait
      ios = [@stdout, @stderr]
      loop do
        break if ios.empty?
        ready = IO.select(ios, nil, nil, nil)
        break unless ready

        ready[0].each do |io|
          begin
            data = io.read_nonblock(1024)
            case io
            when @stdout
              @on_data_block&.call(self, data)
            when @stderr
              @on_extended_data_block&.call(self, 1, data)
            end
          rescue IO::WaitReadable
            next
          rescue EOFError
            ios.delete(io)
            io.close
          end
        end
      end
      @wait_thr.value
      @on_close_block&.call
    end
  end
end
