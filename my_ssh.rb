require "open3"

module MySSH

    def self.start(host, user, **opts, &block)
        @session = Session.new(host, user, opts)
        yield @session if block
    end

    class Session
        def initialize(host, user, opts = {})
            # puts host, user, opts
            @host = host
            @user = user
        end

        def host; @host; end
        def user; @user; end
        def channel; @channel; end

        def open_channel(&block)
            @channel = Channel.new(self)
            yield @channel if block
        end

        def loop()
            @channel.wait
        end

    end


    class Channel
        def initialize(session)
            @session = session
            # puts session
        end

        def exec(command, &block)
            args = ["ssh", "-l", @session.user, @session.host, "--"]
            args.concat(command.split(/\s+/))
            # puts args
            @stdin, @stdout, @stderr, @wait_thr = *Open3.popen3(*args)
            yield self, true if block
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

        def wait()
            ios = [@stdout, @stderr]
            loop do
                break if ios.length == 0
                ready = IO.select(ios, nil, nil, 5)
                # puts "ready=#{ready} stdout=#{@stdout} stderr=#{@stderr}"
                break unless ready

                ready[0].each do |io|
                    begin
                        data = io.read_nonblock(1024)
                        case io
                        when @stdout
                            @on_data_block.call(self, data)
                        when @stderr
                            @on_extended_data_block.call(self, 1, data)
                            # SSH_EXTENDED_DATA_STDERR=1
                        end
                    rescue IO::WaitReadable
                        next
                    rescue EOFError
                        ios.delete(io)
                        io.close
                    end
                end
            end
            exit_status = @wait_thr.value
            puts "Process exited with #{exit_status.exitstatus}"
            @on_close_block.call()
        end
    end



end