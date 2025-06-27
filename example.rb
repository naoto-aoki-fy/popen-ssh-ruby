require "net/ssh"
load "my_ssh.rb"

HOST = "hostname"
USER = "username"
DELIM = "----------------\n".freeze

commands = [
  "hostname",
  "date '+%F %T'",
  "whoami"
]

net_ssh = MySSH
# net_ssh = Net::SSH

net_ssh.start(HOST, USER) do |ssh|
  ssh.open_channel do |ch|
    # 必要なら擬似端末を要求
    # ch.request_pty(term: "xterm") {}

    ch.exec("bash -l") do |sh, success|
      raise "exec failed" unless success

      stdout_buf = +""
      stderr_buf = +""
      results    = []                       # [{cmd:, out:, err:}, ...]

      # ---- 次のコマンドを送信するクロージャ ----
      send_next = lambda do
        if commands.empty?
          sh.send_data("exit\n")
        else
          cmd = commands.shift
          sh.instance_variable_set(:@current_cmd, cmd) # 現在のコマンドを覚える
          sh.send_data("#{cmd}\n")                     # コマンド本体
          sh.send_data("echo #{DELIM.chomp}\n")        # stdout デリミタ
          sh.send_data("echo #{DELIM.chomp} 1>&2\n")   # stderr デリミタ
        end
      end

      # 最初のコマンドを投げる
      send_next.call

      # ---- 標準出力 ----
      sh.on_data do |_c, data|
        stdout_buf << data
        while (idx = stdout_buf.index(DELIM))
          chunk = stdout_buf.slice!(0, idx)
          stdout_buf.slice!(0, DELIM.size)             # デリミタ除去

          # 結果格納
          cur = sh.instance_variable_get(:@current_cmd)
          results << { cmd: cur, out: chunk, err: "" }
          puts "\n[stdout] #{cur}\n#{chunk}"
          send_next.call                               # 次のコマンドへ
        end
      end

      # ---- 標準エラー ----
      sh.on_extended_data do |_c, _type, data|
        stderr_buf << data
        while (idx = stderr_buf.index(DELIM))
          chunk = stderr_buf.slice!(0, idx)
          stderr_buf.slice!(0, DELIM.size)

          # 直近の results に stderr を追記
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