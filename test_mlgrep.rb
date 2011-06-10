# -*- coding: utf-8 -*-
load 'mlgrep'
require 'test/unit'
require 'stringio'

class TestMlgrep < Test::Unit::TestCase
  def setup
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  def teardown
    assert_equal "", $stdout.string
    assert_equal "", $stderr.string
    $stdout = STDOUT
    $stderr = STDERR
  end

  def test_no_args
    assert_equal 1, mlgrep
    assert $stderr.string =~ /No regexp was given.*Usage:/m
    $stderr.string = ''
  end

  def test_only_X_flag
    assert_equal 1, mlgrep('-X', 'abc')
    assert $stderr.string =~ /Exclusion flag .* but no pattern flag/
    $stderr.string = ''
  end

  def test_only_x_flag
    assert_equal 1, mlgrep('-x', '/test/', 'abc')
    assert $stderr.string =~ /Exclusion flag .* but no pattern flag/
    $stderr.string = ''
  end

  def test_help
    assert_equal 1, mlgrep('-h')
    assert $stdout.string =~ /can be compounded. I.e., -ics means -i -c -s./
    $stdout.string = ''
  end

  def test_return_value_when_nothing_is_found
    assert_equal 1, mlgrep(*%w'xyz123 fsm.rb')
    assert_equal 1, mlgrep(*%w'-k xyz123 fsm.rb')
    check_stdout("--------------------------------------------------",
                 "    0 TOTAL /xyz123/")
  end

  def test_searching_one_file_for_string
    assert_equal 0, mlgrep('class FSM', 'fsm.rb')
    check_stdout "fsm.rb:86: class FSM"
  end

  def test_absolute_paths
    mlgrep '-a', 'class FSM', 'fsm.rb'
    assert $stdout.string =~ %r'^/'
    $stdout.string = ''
  end

  def test_quiet_mode
    mlgrep '-q', 'class FSM.*end', 'fsm.rb'
    check_stdout "fsm.rb:86: class FSM # Represen ... e.write(s) } end end"
  end

  def test_newline_in_line_mode
    mlgrep '-n', 'class FSM\n', 'fsm.rb'
    assert $stderr.string =~ /Don't use \\n in regexp when in line mode/
    $stderr.string = ''
  end

  def test_case_insensitive
    mlgrep(*%w'either fsm.rb')
    check_stdout("fsm.rb:63: either",
                 "fsm.rb:88: either",
                 "fsm.rb:111: either")

    mlgrep(*%w'-i either fsm.rb')
    check_stdout("fsm.rb:63: either",
                 "fsm.rb:88: either",
                 "fsm.rb:90: Either",
                 "fsm.rb:109: Either",
                 "fsm.rb:111: either",
                 "fsm.rb:111: Either",
                 "fsm.rb:142: Either")
  end
 
  def test_searching_one_file_for_regex
    mlgrep(*%w'\$\w+ fsm.rb')
    check_stdout("fsm.rb:138: $stderr",
                 "fsm.rb:138: $DEBUG")
  end

  def test_whole_word
    mlgrep(*%w'default fsm.rb')
    check_stdout("fsm.rb:96: default",
                 "fsm.rb:103: default",
                 "fsm.rb:104: default",
                 "fsm.rb:104: default",
                 "fsm.rb:113: default",
                 "fsm.rb:125: default",
                 "fsm.rb:149: default",
                 "fsm.rb:150: default",
                 "fsm.rb:154: default")

    mlgrep(*%w'-w default fsm.rb')
    check_stdout("fsm.rb:96: default",
                 "fsm.rb:113: default",
                 "fsm.rb:149: default",
                 "fsm.rb:150: default")
  end

  def test_exclude_self
    mlgrep(*%w'-R -l fsm')
    check_sorted_stdout("./test_mlgrep.rb",
                        "./any_white_space.rb",
                        "./mlgrep",
                        "./test_fsm.rb",
                        "./fsm.rb")

    # fsm.rb is ecluded but not test_fsm.rb.
    mlgrep(*%w'-Re -l fsm')
    check_sorted_stdout("./test_mlgrep.rb",
                        "./mlgrep",
                        "./any_white_space.rb",
                        "./test_fsm.rb")
  end

  def test_searching_two_files_for_regex
    mlgrep(*%w'\$\w+ fsm.rb any_white_space.rb')
    check_stdout("fsm.rb:138: $stderr",
                 "fsm.rb:138: $DEBUG")
  end

  def test_searching_all_ruby_files_for_regex_excluding_test_files
    mlgrep(*%w'-x test_ -r *.rb \$\S+')
    check_sorted_stdout("./fsm.rb:138: $DEBUG",
                        "./fsm.rb:138: $stderr")
  end

  def test_searching_file_with_explicit_directory
    mlgrep(*%w'-r fsm.rb \$\S+ non-existent/')
    check_sorted_stdout("./fsm.rb:138: $DEBUG",
                        "./fsm.rb:138: $stderr")
  end

  def test_line_mode
    mlgrep(*%w'withoutXmlComments skip_stuff.rb')
    check_stdout "skip_stuff.rb:9: withoutXmlComments"

    mlgrep(*%w'-n withoutXmlComments skip_stuff.rb')
    check_stdout "skip_stuff.rb:9: def withoutXmlComments"
  end


  def test_only_group_match
    mlgrep(*%w'-o without(X..)Comments skip_stuff.rb')
    check_stdout "skip_stuff.rb:9: Xml"
  end

  def test_statistics
    assert_equal 0, mlgrep(*%w'-k F.. fsm.rb')
    check_stdout("   26 fsm.rb",
                 "--------------------------------------------------",
                 "   23 FSM",
                 "    1 Fee",
                 "    1 Fil",
                 "    1 Fol",
                 "   26 TOTAL /F../")
  end

  def test_skipping_comments
    mlgrep(*%w'-c class fsm.rb mlgrep')
    check_sorted_stdout("fsm.rb:1: class",
                        "fsm.rb:86: class",
                        "fsm.rb:90: class",
                        "mlgrep:16: class",
                        "mlgrep:32: class",
                        "mlgrep:364: class")
  end

  def test_skipping_strings
    mlgrep(*%w'name fsm.rb')
    check_stdout("fsm.rb:8: name",
                 "fsm.rb:11: name",
                 "fsm.rb:13: name",
                 "fsm.rb:13: name",
                 "fsm.rb:15: name",
                 "fsm.rb:15: name",
                 "fsm.rb:21: name",
                 "fsm.rb:54: name",
                 "fsm.rb:62: name",
                 "fsm.rb:71: name")

    mlgrep(*%w'-s name fsm.rb')
    check_stdout("fsm.rb:8: name",
                 "fsm.rb:11: name",
                 "fsm.rb:13: name",
                 "fsm.rb:13: name",
                 "fsm.rb:15: name", # one less match on line 15
                 "fsm.rb:21: name",
                 "fsm.rb:54: name",
                 "fsm.rb:62: name",
                 "fsm.rb:71: name")
  end

  def test_space_in_regexp
    mlgrep 'nil @state', 'fsm.rb'
    check_stdout("fsm.rb:168: nil @state",
                 "fsm.rb:177: nil @state")
  end

  def test_until_in_regexp
    mlgrep(*%w'<\u[>\n] fsm.rb')
    check_stdout('fsm.rb:15: <#{name}>',
                 'fsm.rb:37: <tt>',
                 'fsm.rb:37: </tt>',
                 'fsm.rb:41: <tt>',
                 'fsm.rb:41: </tt>',
                 'fsm.rb:58: << "#{oldState}-(#{event})->',
                 'fsm.rb:65: << "[prime #{ev}]" ',
                 'fsm.rb:83: <joning@home.se>',
                 'fsm.rb:115: <tt>',
                 'fsm.rb:115: </tt>',
                 'fsm.rb:124: << [state, event, newState, ',
                 'fsm.rb:138: << "#@event #@state->')
  end
  
  def test_bad_encoding
    name = "testfile.txt"
    File.open(name, "w") { |f| f.puts "# -*- coding: bogus-8 -*-" }
    if RUBY_VERSION !~ /1.8/
      mlgrep '.', name
      check_stdout "Warning: unknown encoding name - bogus-8 in testfile.txt"
    end
  ensure
    File.unlink name
  end

  def test_zero_length_match
    mlgrep('(class FSM)?', 'fsm.rb')
    check_stdout('fsm.rb:86: class FSM')
  end

  private
  
  def check_stdout(*lines)
    check_any_stdout(lines) { |lines| lines }
  end

  def check_sorted_stdout(*lines)
    check_any_stdout(lines) { |lines| lines.sort }
  end

  def check_any_stdout(lines)
    expected = yield lines
    # The _flymake files are temporary files created by Emacs.
    actual = yield $stdout.string.split(/\n/).reject { |n| n =~ /_flymake.rb/ }
    assert_equal expected, actual
    $stdout.string = ''
  end
end
