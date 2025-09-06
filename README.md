# PopenSSH

`popen_ssh` provides a tiny wrapper around the system `ssh` command with a subset of the `Net::SSH` API. It is useful when you want to drive `ssh` but do not want the full `net-ssh` dependency.

## Installation

Add to your Gemfile or install directly from the repository:

```ruby
gem 'popen_ssh', git: 'https://github.com/naoto-aoki-fy/popen-ssh-ruby.git'
```

## Usage

```ruby
require 'popen_ssh'

PopenSSH.start('example.com', 'user') do |ssh|
  ssh.open_channel do |ch|
    ch.exec('echo hello') do |_, success|
      raise 'exec failed' unless success

      ch.on_data { |_, data| puts data }
      ch.on_close { puts 'channel closed' }
    end
  end

  ssh.loop
end
```

See `examples/basic.rb` for a more complete demonstration.

## License

MIT
