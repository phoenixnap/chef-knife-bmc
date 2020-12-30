$LOAD_PATH.push File.expand_path("lib", __dir__)
require "knife-bmc/version"

Gem::Specification.new do |s|
  s.name = "knife-bmc"
  s.version = Knife::BMC::VERSION
  s.summary = "Knife plugin to manage BMC resources."
  s.description = "Knife plugin to manage BMC resources. See https://developers.phoenixnap.com/docs/bmc/1/overview."
  s.email = 'support@phoenixnap.com'
  s.authors = ["PhoenixNAP"]
  s.homepage = 'https://github.com/phoenixnap/knife-bmc'
  s.license = "MPL-2.0"
  s.files = %w{LICENSE} + Dir.glob("lib/**/*")
  s.add_dependency "chef", ">= 15.11"
  s.add_dependency "bmc-sdk", ">= 0.1.0"
  s.require_paths = ["lib"]
end
