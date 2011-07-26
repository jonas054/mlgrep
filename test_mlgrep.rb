# -*- coding: utf-8 -*-
load 'mlgrep'
require 'test/unit'
require 'stringio'
require 'fileutils'

class TestOutput < Test::Unit::TestCase
  def setup
    $stdin  = StringIO.new
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  def teardown
    assert_equal "", $stdout.string
    assert_equal "", $stderr.string
    $stdin  = STDIN
    $stdout = STDOUT
    $stderr = STDERR
  end

  def test_nothing
  end

  protected

  def check_stderr(expected)
    assert_equal expected, $stderr.string
    $stderr.string = ''
  end
end

# These are test cases that call mlgrep with the wrong arguments.
# Something is printed on stderr.
class TestUsageErrors < TestOutput
  # The absolute minimum of arguments is to supply a regular expression and
  # nothing more. Then mlgrep will search stdin. Test calling mlgrep with
  # no arguments.
  def test_no_args
    check %r"No regexp was given.*Usage:"m
  end

  # With -X we say that we want to exclude files from the search based on the
  # 'exclude' property in .mlgreprc, but -X requires another flag such as -S
  # that states which files to search for in the first place.
  def test_only_X_flag
    assert_equal 0, mlgrep(%w'-X class fsm.rb')
    $stdout.string = ''
    check(Regexp.new('Exclusion flag .* but no pattern flag ' +
                     '\(-C,-H,-J,-L,-M,-P,-R,-S,-r\) or file list'),
          '-X', 'abc')
  end

  # Just as the capital -X, the -x flag (which takes a regexp argument), is
  # meaningless without a pattern flag.
  def test_only_x_flag
    check(%r"Exclusion flag .* but no pattern flag",
          '-x', '/test/', 'abc')
  end

  # Flags that are not supported should be reported.
  def test_unknown_flag
    check %r"Unknown flag:", '-g', 'abc', 'fsm.rb'
  end

  # Test giving arguments in the wrong order. Flags must come before regular
  # expression and files.
  def test_flag_after_regexp
    check %r"Flag -i encountered after regexp", 'abc', '-i', 'fsm.rb'
  end

  # Line mode (-n) works like the classic grep command, by searching for lines
  # that match a regexp. Then we can't have newline characters in the regexp.
  def test_newline_in_line_mode
    check(%r"Don't use \\n in regexp when in line mode",
          '-n', 'class FSM\n', 'fsm.rb')
  end

  def test_mlgreprc_with_no_source_property
    File.open('mlgreprc', 'w') {}
    check(%r"No line starting with source: found in mlgreprc",
          '-f', 'mlgreprc', '-Sl', '.')
  ensure
    File.unlink 'mlgreprc'
  end

  def test_mlgreprc_with_double_source_property
    File.open('mlgreprc', 'w') { |f|
      f.puts 'source: *.c'
      f.puts 'source: *.java'
    }
    check(%r"Multiple entries for property source found in mlgreprc",
          '-f', 'mlgreprc', '-Sl', '.')
  ensure
    File.unlink 'mlgreprc'
  end

  def check(regexp, *args)
    assert_equal 1, mlgrep(*args)
    assert $stderr.string =~ regexp
    $stderr.string = ''
  end
end

class TestMlgrep < TestOutput
  def test_help
    assert_equal 1, mlgrep('-h')
    assert $stdout.string =~ /can be compounded. I.e., -ics means -i -c -s./
    $stdout.string = ''
  end

  # This is the same as unix grep. When nothing is found an error code is
  # returned.
  def test_return_value_when_nothing_is_found
    assert_equal 1, mlgrep(*%w'xyz123 fsm.rb')
    assert_equal 1, mlgrep(*%w'-k xyz123 fsm.rb')
    check_stdout("--------------------------------------------------",
                 "    0 TOTAL /xyz123/")
  end

  # Basic functionality. File name is given as argument so no search for files.
  def test_searching_one_file_for_string
    assert_equal 0, mlgrep('class FSM', 'fsm.rb')
    check_stdout "fsm.rb:86: class FSM"
  end

  # Default is to print relative paths. With -a flag, the absolute path is
  # printed.
  def test_absolute_paths
    mlgrep '-a', 'class FSM', 'fsm.rb'
    assert $stdout.string =~ %r'^/'
    $stdout.string = ''
  end

  # Long matches are shortened in output.
  def test_quiet_mode
    # Default length is 20 charactes before and after "...".
    mlgrep '-q', 'class FSM.*end', 'fsm.rb'
    check_stdout "fsm.rb:86: class FSM # Represen ... e.write(s) } end end"

    # Specify length.
    mlgrep '-q10', 'class FSM.*end', 'fsm.rb'
    check_stdout "fsm.rb:86: class FSM  ...  } end end"
  end

  def test_case_sensitivity
    # Default is case sensitive.
    mlgrep *%w'either fsm.rb'
    check_stdout("fsm.rb:63: either",
                 "fsm.rb:88: either",
                 "fsm.rb:111: either")

    # Case insensitive with -i flag.
    mlgrep *%w'-i either fsm.rb'
    check_stdout("fsm.rb:63: either",
                 "fsm.rb:88: either",
                 "fsm.rb:90: Either",
                 "fsm.rb:109: Either",
                 "fsm.rb:111: either",
                 "fsm.rb:111: Either",
                 "fsm.rb:142: Either")
  end

  def test_searching_one_file_for_regex
    mlgrep *%w'\$\w+ fsm.rb'
    check_stdout("fsm.rb:138: $stderr",
                 "fsm.rb:138: $DEBUG")
  end

  def test_whole_word
    mlgrep *%w'-nN default fsm.rb'
    # Without the -w flag, we get a match on 'default' and 'defaultAction'.
    check_stdout("# the default action executed for all rules that don't have their own",
                 "def initialize(initialState, &defaultAction)",
                 "@state, @defaultAction = initialState, defaultAction",
                 "# Adds a state/event transition (a rule). If no block is given, the default",
                 "action || @defaultAction || proc {}]",
                 "# Executes the default action. Typically used from within an action when",
                 "# you want to execute the default action plus something more.",
                 "@defaultAction.call @event, @state, @newState")

    mlgrep *%w'-wnN default fsm.rb'
    # With the -w flag, we only match the word 'default'.
    check_stdout("# the default action executed for all rules that don't have their own",
                 "# Adds a state/event transition (a rule). If no block is given, the default",
                 "# Executes the default action. Typically used from within an action when",
                 "# you want to execute the default action plus something more.")
  end

  def test_exclude_self
    mlgrep *%w'-R -l fsm'
    check_sorted_stdout("./test_mlgrep.rb",
                        "./any_white_space.rb",
                        "./mlgrep",
                        "./test_fsm.rb",
                        "./fsm.rb")

    # fsm.rb is excluded but not test_fsm.rb.
    mlgrep *%w'-Re -l fsm'
    check_sorted_stdout("./test_mlgrep.rb",
                        "./mlgrep",
                        "./any_white_space.rb",
                        "./test_fsm.rb")
  end

  def test_searching_two_files_for_regex
    mlgrep *%w'\$\w+ fsm.rb any_white_space.rb'
    check_stdout("fsm.rb:138: $stderr",
                 "fsm.rb:138: $DEBUG")
  end

  def test_searching_all_ruby_files_for_regex_excluding_test_files
    mlgrep *%w'-x test_ -r *.rb \$\S+'
    check_sorted_stdout("./fsm.rb:138: $DEBUG",
                        "./fsm.rb:138: $stderr")
  end

  def test_explicit_directory_that_doesnt_exist
    assert_equal 0, mlgrep(*%w'-r fsm.rb \$\S+ non-existent/')
    check_sorted_stdout("./fsm.rb:138: $DEBUG",
                        "./fsm.rb:138: $stderr")
    check_stderr "mlgrep: No such file or directory - non-existent/\n"
  end

  def test_line_mode
    mlgrep *%w'withoutXmlComments skip_stuff.rb'
    check_stdout "skip_stuff.rb:9: withoutXmlComments"

    mlgrep *%w'-n withoutXmlComments skip_stuff.rb'
    check_stdout "skip_stuff.rb:9: def withoutXmlComments"
  end

  def test_source_flag
    mlgrep *%w'-S -x test_ withoutXmlComments'
    check_stdout("./skip_stuff.rb:9: withoutXmlComments",
                 "./mlgrep:340: withoutXmlComments")
  end

  def test_source_flag_with_explicit_directory
    mlgrep *%w'-S -x test_ withoutXmlComments ./'
    check_stdout("./skip_stuff.rb:9: withoutXmlComments",
                 "./mlgrep:340: withoutXmlComments")
  end

  def test_source_flag_when_rc_file_is_missing
    mlgrep *%w'-f mlgreprc -S -x test_ withoutXmlComments'
    check_stdout("./skip_stuff.rb:9: withoutXmlComments",
                 "./mlgrep:340: withoutXmlComments")
  ensure
    File.unlink 'mlgreprc'
  end

  def test_only_group_match
    mlgrep *%w'-o without(X..)Comments skip_stuff.rb'
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

  def test_statistics_ending_with_space
    assert_equal 0, mlgrep(*%w'-k .E. skip_stuff.rb')
    check_stdout('    5 skip_stuff.rb',
                 '--------------------------------------------------',
                 '    2 "RE "',
                 '    3 RE,',
                 '    5 TOTAL /.E./')
  end

  def test_statistics_with_stdin
    $stdin.string = IO.read 'fsm.rb'
    assert_equal 0, mlgrep(*%w'-k F..')
    check_stdout("   26 STDIN",
                 "--------------------------------------------------",
                 "   23 FSM",
                 "    1 Fee",
                 "    1 Fil",
                 "    1 Fol",
                 "   26 TOTAL /F../")
  end

  def test_skipping_comments
    mlgrep *%w'-c class fsm.rb'
    check_sorted_stdout("fsm.rb:1: class",
                        "fsm.rb:86: class",
                        "fsm.rb:90: class")
  end

  def test_skipping_strings
    mlgrep *%w'name fsm.rb'
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

    mlgrep *%w'-s name fsm.rb'
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
    mlgrep *%w'<\u[>\n] fsm.rb'
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
      check_stderr "mlgrep: Warning: unknown encoding name - bogus-8 in testfile.txt\n"
    end
  ensure
    File.unlink name
  end

  def test_zero_length_match
    mlgrep '(class FSM)?', 'fsm.rb'
    check_stdout 'fsm.rb:86: class FSM'
  end

  def test_searching_stdin
    # Empty stdin
    $stdin.string = ""
    assert_equal 1, mlgrep('class FSM')

    # File contents on stdin
    $stdin.string = IO.read 'fsm.rb'
    assert_equal 0, mlgrep('class FSM')
    check_stdout "class FSM"
  end

  def test_file_error
    File.open_with_error_handling('fsm.rb') { raise Errno::ENXIO, "Hej" }
    check_stdout 'mlgrep: No such device or address - Hej'
  end

  def test_skipping_python_strings
    check_tmp_file('tmp.py',
                   ['foo1 = "foo"',
                    "foo2 = 'foo'",
                    '"""',
                    'foo',
                    '"""'],
                   ['-nNs', 'foo'],
                   ["foo1 =",
                    "foo2 ="])
  end

  def test_recursive_search
    FileUtils.mkdir_p "tmp"
    check_tmp_file('tmp/tmp.rb',
                   ['fsm = 0'],
                   ['-Rl', 'fsm', '..'],
                   ["../mlgrep/test_mlgrep.rb",
                    "../mlgrep/any_white_space.rb",
                    "../mlgrep/mlgrep",
                    "../mlgrep/test_fsm.rb",
                    "../mlgrep/fsm.rb",
                    "../mlgrep/tmp/tmp.rb",
                    'tmp/tmp.rb'])
  ensure
    FileUtils.rm_rf "tmp"
  end

  # There was a bug affecting recursive searches where the pattern could match
  # directories.
  def test_recursive_search_asterisk
    FileUtils.mkdir_p "tmp"
    check_tmp_file('tmp/tmp.rb',
                   ['fsm = 0'],
                   %w'-x coverage|\.git -lr * fsm .',
                   ["./test_mlgrep.rb",
                    "./any_white_space.rb",
                    "./mlgrep",
                    "./test_fsm.rb",
                    "./fsm.rb",
                    "./tmp/tmp.rb",
                    'tmp/tmp.rb'])
  ensure
    FileUtils.rm_rf "tmp"
  end

  def test_skipping_comments_in_xml_file
    check_tmp_file('tmp.xml',
                   ['<?xml version="1.0" encoding="ISO-8859-1"?>',
                    '<! foo>',
                    '<foo>',
                    '</foo>'],
                   ['-nNc', 'foo'],
                   ["<foo>", "</foo>"])
  end

  def test_skipping_comments_in_hashbang_file
    check_tmp_file('tmp',
                   ['#!/bin/sh',
                    'echo foo',
                    '# foo bar'],
                   ['-nNc', 'foo'],
                   ["echo foo"])
  end

  def test_skipping_comments_in_cpp_file
    check_tmp_file('tmp.cpp',
                   ['int main() {',
                    '  // foo',
                    '  foo(); /* foo */',
                    '}'],
                   ['-nNc', 'foo'],
                   ["foo();"])
  end

  private

  def check_tmp_file(file_name, contents, options, expected)
    File.open(file_name, 'w') { |f|
      contents.each { |line| f.puts line }
    }
    mlgrep *options + [file_name]
    check_sorted_stdout *expected
  ensure
    File.unlink file_name
  end

  def check_stdout(*lines)
    check_any_stdout(lines) { |a| a }
  end

  def check_sorted_stdout(*lines)
    check_any_stdout(lines) { |a| a.sort }
  end

  def check_any_stdout(lines)
    expected = yield lines
    # The _flymake files are temporary files created by Emacs.
    actual = yield $stdout.string.split(/\n/).reject { |n| n =~ /_flymake.rb/ }
    assert_equal expected, actual
    $stdout.string = ''
  end
end

class TestMethods < Test::Unit::TestCase
  def test_make_regexp_flags
    check_regex %r'123'm,                  '123',       {}
    check_regex %r'123'mi,                 '123',       :ignore_case => true
    check_regex %r'^.*123.*[\n$]',         '123',       :line => true
    check_regex %r'^.*12[^\n]*3.*[\n$]',   '12[^\n]*3', :line => true
    check_regex %r'\b(?:123)\b'm,          '123',       :whole_word => true
    check_regex %r'^.*\b(?:123)\b.*[\n$]', '123',       :line => true, :whole_word => true
  end

  def test_make_regexp_special_additions
    check_regex %r'12\s*3'm,             '12 3',      {}
    check_regex %r'12[^3]*3'm,           '12\u3',     {}
    check_regex %r'12[^\{]*\{'m,         '12\u\{',    {}
    check_regex %r'12[^abc]*[abc]'m,     '12\u[abc]', {}
  end

  def check_regex(regex, string, flags)
    assert_equal regex, make_regex(string, flags)
  end
end
