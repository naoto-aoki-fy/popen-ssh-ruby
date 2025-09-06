require 'popen_ssh'

HOST = 'hostname'
USER = 'username'
DELIM = "----------------\n".freeze

commands = [
  'hostname',
  "date '+%F %T'",
  'whoami'
]

PopenSSH.start(HOST, USER) do |ssh|
  ssh.open_channel do |ch|
    # Request a pseudo terminal if needed
    # ch.request_pty(term: 'xterm') {}

    ch.exec('bash -l') do |sh, success|
      raise 'exec failed' unless success

      stdout_buf = +''
      stderr_buf = +''
      results    = [] # [{cmd:, out:, err:}, ...]

      send_next = lambda do
        if commands.empty?
          sh.send_data("exit\n")
        else
          cmd = commands.shift
          sh.instance_variable_set(:@current_cmd, cmd)
          sh.send_data("#{cmd}\n")
          sh.send_data("echo #{DELIM.chomp}\n")
          sh.send_data("echo #{DELIM.chomp} 1>&2\n")
        end
      end

      send_next.call

      sh.on_data do |_c, data|
        stdout_buf << data
        while (idx = stdout_buf.index(DELIM))
          chunk = stdout_buf.slice!(0, idx)
          stdout_buf.slice!(0, DELIM.size)

          cur = sh.instance_variable_get(:@current_cmd)
          results << { cmd: cur, out: chunk, err: '' }
          puts "\n[stdout] #{cur}\n#{chunk}"
          send_next.call
        end
      end

      sh.on_extended_data do |_c, _type, data|
        stderr_buf << data
        while (idx = stderr_buf.index(DELIM))
          chunk = stderr_buf.slice!(0, idx)
          stderr_buf.slice!(0, DELIM.size)

          results.last[:err] = chunk
          puts "\n[stderr] #{results.last[:cmd]}\n#{chunk}"
        end
      end

      sh.on_close do
        puts "\n[channel closed]"
      end
    end
  end

  ssh.loop
end
