def add_if_present(version)
  `which #{version} 2>&1`
  $rubies << "#{version}" if $? == 0
end

def run_suite(r)
  sh "#{r} -v; #{r} -e 'load(*Dir[%{test_*.rb}])'"
end

$rubies = %w(ruby)
default_version = `#{$rubies[0]} -v`

case default_version
when /1\.8/ then add_if_present 'ruby1.9'
when /1\.9/ then add_if_present 'ruby1.8'
end
add_if_present 'jruby'
add_if_present 'jruby-1.5.0'

task :test do
  $rubies.each { |r| run_suite r }
end

# Example:
# > rake test_with_ruby-1.9.2-p180
task $& do run_suite $1 end if ARGV[0] =~ /test_with_(.*)/

task :default => :test
