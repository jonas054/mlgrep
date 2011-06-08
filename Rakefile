def add_if_present(version)
  `which #{version} 2>&1`
  $rubies << "#{version}" if $? == 0
end

def run_suite(r)
  sh "#{r} -v; #{r} -e 'Dir[%{test_*.rb}].each {|f|load f}'"
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

# RCov doesn't work reliably under ruby 1.9. There's a gem called cover_me
# that works for 1.9, but doesn't seem to produce HTML in all situations. We
# can get all the uncovered lines anyway. You'll need to
# gem install cover_me
task :cover_me do
  sh "rm coverage.data"
  ruby "-rcover_me test_mlgrep.rb"
  eval(IO.read('coverage.data'))['mlgrep'].each_with_index { |cov, ix|
    puts "mlgrep:#{ix+1}: Not covered" if cov == 0
  }
end

task :default => :test
