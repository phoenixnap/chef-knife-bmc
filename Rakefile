$LOAD_PATH.push File.expand_path("lib", __dir__)
require "knife-bmc/version"

task :install do
  sh %(gem build knife-bmc.gemspec)
  sh %(gem install knife-bmc-#{Knife::BMC::VERSION}.gem)
end

task :push do
  sh %(gem push knife-bmc-#{Knife::BMC::VERSION}.gem)
end

