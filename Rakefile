task :test do
  sh "ruby -v"
  Dir['test/test_*.rb'].each { |f| load f }
end

# RCov doesn't work reliably under ruby 1.9. There's a gem called cover_me
# that works for 1.9, but doesn't seem to produce HTML in all situations. We
# can get all the uncovered lines anyway. You'll need to
# gem install cover_me
task :cover_me do
  rm_f "coverage.data"
  ruby "-rcover_me test/test_mlgrep.rb"
  eval(IO.read('coverage.data'))['mlgrep'].each_with_index { |cov, ix|
    puts "mlgrep:#{ix+1}: Not covered" if cov == 0
  }
end

task :todo do
  system 'bin/mlgrep -Ro "# (TODO:[^\n]*)(\n[ \t]*#[^\n]*)*"'
end

task :default => [:todo, :test]
