require_relative 'lib/popen_ssh/version'

Gem::Specification.new do |spec|
  spec.name          = 'popen_ssh'
  spec.version       = PopenSSH::VERSION
  spec.authors       = ['Naoto AOKI']
  spec.summary       = 'ssh command backend for ruby Net::SSH'
  spec.description   = 'Minimal wrapper around the system ssh command with a Net::SSH-like API.'
  spec.license       = 'MIT'
  spec.files         = Dir['lib/**/*.rb', 'LICENSE', 'README.md']
  spec.require_paths = ['lib']
end
