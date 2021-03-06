# -*- coding: utf-8 -*-
require_relative '../lib/mlgrep'
require 'test/unit'
require 'stringio'
require 'fileutils'

# rubocop:disable Syntax, WordArray

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
    assert expected === $stderr.string
    $stderr = StringIO.new
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
  # 'exclude' property in .mlgrep.yml, but -X requires another flag such as -S
  # that states which files to search for in the first place.
  def test_only_X_flag # rubocop:disable MethodName
    assert_equal 0, mlgrep(%w'-X class lib/fsm.rb')
    $stdout.string = ''
    check(Regexp.new('Exclusion flag .* but no pattern flag ' +
                     '\(-C,-E,-H,-J,-L,-M,-P,-R,-T,-V,-W,-S,-r\) or file list'),
          '-X', 'abc')
  end

  # Just as the capital -X, the -x flag (which takes a regexp argument), is
  # meaningless without a pattern flag.
  def test_only_x_flag
    check(/Exclusion flag .* but no pattern flag/,
          '-x', '/test/', 'abc')
  end

  # Flags that are not supported should be reported.
  def test_unknown_flag
    check %r"Unknown flag:", '-y', 'abc', 'lib/fsm.rb'
  end

  # Test giving arguments in the wrong order. Flags must come before regular
  # expression and files.
  def test_flag_after_regexp
    check %r"Flag -i encountered after regexp", 'abc', '-i', 'lib/fsm.rb'
  end

  # Line mode (-n) works like the classic grep command, by searching for lines
  # that match a regexp. Then we can't have newline characters in the regexp.
  def test_newline_in_line_mode
    check(/Don't use \\n in regexp when in line mode/,
          '-n', 'class FSM\n', 'lib/fsm.rb')
  end

  def test_mlgrep_yml_with_no_source_property
    File.open('mlgrep.yml', 'w') { |f|
      f.puts 'junk:'
      f.puts '  nothing'
    }
    check(/No line starting with source: found in mlgrep.yml/,
          '-f', 'mlgrep.yml', '-Sl', '.')
  ensure
    File.unlink 'mlgrep.yml'
  end

  def check(regexp, *args)
    assert_equal 1, mlgrep(*args)
    assert_match regexp, $stderr.string
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
    assert_equal 1, mlgrep(*%w'xyz123 lib/fsm.rb')
    assert_equal 1, mlgrep(*%w'-k xyz123 lib/fsm.rb')
    check_stdout("--------------------------------------------------",
                 "    0 TOTAL /xyz123/")
  end

  # Basic functionality. File name is given as argument so no search for files.
  def test_searching_one_file_for_string
    assert_equal 0, mlgrep('class FSM', 'lib/fsm.rb')
    check_stdout "lib/fsm.rb:86: class FSM"
  end

  # Default is to print relative paths. With -a flag, the absolute path is
  # printed.
  def test_absolute_paths
    mlgrep '-a', 'class FSM', 'lib/fsm.rb'
    assert $stdout.string =~ %r'^/'
    $stdout.string = ''
  end

  # Long matches are shortened in output.
  def test_quiet_mode
    # Default length is 20 charactes before and after "...".
    mlgrep '-q', 'class FSM.*end', 'lib/fsm.rb'
    check_stdout "lib/fsm.rb:86: class FSM # Represen ... e.write(s) } end end"

    # Specify length.
    mlgrep '-q10', 'class FSM.*end', 'lib/fsm.rb'
    check_stdout "lib/fsm.rb:86: class FSM  ...  } end end"
  end

  def test_case_sensitivity
    # Default is case sensitive.
    mlgrep *%w'either lib/fsm.rb'
    check_stdout("lib/fsm.rb:63: either",
                 "lib/fsm.rb:88: either",
                 "lib/fsm.rb:111: either")

    # Case insensitive with -i flag.
    mlgrep *%w'-i either lib/fsm.rb'
    check_stdout("lib/fsm.rb:63: either",
                 "lib/fsm.rb:88: either",
                 "lib/fsm.rb:90: Either",
                 "lib/fsm.rb:109: Either",
                 "lib/fsm.rb:111: either",
                 "lib/fsm.rb:111: Either",
                 "lib/fsm.rb:142: Either")
  end

  def test_searching_one_file_for_regex
    mlgrep *%w'\$\w+ lib/fsm.rb'
    check_stdout("lib/fsm.rb:138: $stderr",
                 "lib/fsm.rb:138: $DEBUG")
  end

  def test_whole_word
    mlgrep *%w'-nN default lib/fsm.rb'
    # Without the -w flag, we get a match on 'default' and 'default_action'.
    lines =
      ["# the default action executed for all rules that don't have their own",
       "def initialize(initialState, &default_action)",
       "@state, @default_action = initialState, default_action",
       "# Adds a state/event transition (a rule). If no block is given, the " +
       "default",
       "action || @default_action || proc {}]",
       "# Executes the default action. Typically used from within an action " +
       "when",
       "# you want to execute the default action plus something more.",
       "@default_action.call @event, @state, @new_state"]
    check_stdout(*lines)

    mlgrep *%w'-wnN default lib/fsm.rb'
    # With the -w flag, we only match the word 'default'.
    lines =
      ["# the default action executed for all rules that don't have their own",
       "# Adds a state/event transition (a rule). If no block is given, the " +
       "default",
       "# Executes the default action. Typically used from within an action " +
       "when",
       "# you want to execute the default action plus something more."]
    check_stdout(*lines)
  end

  def test_exclude_self
    mlgrep *%w'-R -l fsm'
    check_sorted_stdout("./test/test_mlgrep.rb",
                        "./lib/any_white_space.rb",
                        "./lib/mlgrep.rb",
                        "./test/test_fsm.rb",
                        "./lib/fsm.rb")

    # lib/fsm.rb is excluded but not test_fsm.rb.
    mlgrep *%w'-Re -l fsm'
    check_sorted_stdout("./test/test_mlgrep.rb",
                        "./lib/any_white_space.rb",
                        "./lib/mlgrep.rb",
                        "./test/test_fsm.rb")
  end

  def test_searching_two_files_for_regex
    mlgrep *%w'\$\w+ lib/fsm.rb lib/any_white_space.rb'
    check_stdout("lib/fsm.rb:138: $stderr",
                 "lib/fsm.rb:138: $DEBUG")
  end

  def test_searching_all_ruby_files_for_regex_excluding_test_files
    mlgrep *%w'-x test_ -r *.rb \$\S+'
    check_sorted_stdout("./lib/fsm.rb:138: $DEBUG",
                        "./lib/fsm.rb:138: $stderr")
  end

  def test_explicit_directory_that_doesnt_exist
    assert_equal 0, mlgrep(*%w'-r lib/fsm.rb \$\S+ non-existent/')
    check_sorted_stdout("./lib/fsm.rb:138: $DEBUG",
                        "./lib/fsm.rb:138: $stderr")
    check_stderr /mlgrep: No such file or directory(.*)?- non-existent/u
  end

  def test_line_mode
    mlgrep *%w'without_xml_comments lib/skip_stuff.rb'
    check_stdout "lib/skip_stuff.rb:12: without_xml_comments"

    mlgrep *%w'-n without_xml_comments lib/skip_stuff.rb'
    check_stdout "lib/skip_stuff.rb:12: def without_xml_comments"
  end

  def test_source_flag
    mlgrep *%w'-S -x test_ without_xml_comments'
    check_stdout("./lib/skip_stuff.rb:12: without_xml_comments",
                 %r"./lib/mlgrep.rb:\d+: without_xml_comments")
  end

  def test_source_flag_with_explicit_directory
    mlgrep *%w'-S -x test_ without_xml_comments ./'
    check_stdout("./lib/skip_stuff.rb:12: without_xml_comments",
                 %r"./lib/mlgrep.rb:\d+: without_xml_comments")
  end

  def test_source_flag_when_rc_file_is_missing
    mlgrep *%w'-f mlgrep.yml -S -x test_ without_xml_comments'
    check_stdout("./lib/skip_stuff.rb:12: without_xml_comments",
                 %r"./lib/mlgrep.rb:\d+: without_xml_comments")
  ensure
    File.unlink 'mlgrep.yml'
  end

  def test_only_group_match
    mlgrep *%w'-o without_(x..)_comments lib/skip_stuff.rb'
    check_stdout "lib/skip_stuff.rb:12: xml"
  end

  def test_statistics
    assert_equal 0, mlgrep(*%w'-k F.. lib/fsm.rb')
    check_stdout("   26 lib/fsm.rb",
                 "--------------------------------------------------",
                 "   23 FSM",
                 "    1 Fee",
                 "    1 Fil",
                 "    1 Fol",
                 "   26 TOTAL /F../")
  end

  def test_statistics_ending_with_space
    assert_equal 0, mlgrep(*%w'-k .E. lib/skip_stuff.rb')
    check_stdout('    5 lib/skip_stuff.rb',
                 '--------------------------------------------------',
                 '    2 "RE "',
                 '    3 RE,',
                 '    5 TOTAL /.E./')
  end

  def test_statistics_with_stdin
    $stdin.string = IO.read 'lib/fsm.rb'
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
    mlgrep *%w'-c class lib/fsm.rb'
    check_sorted_stdout("lib/fsm.rb:1: class",
                        "lib/fsm.rb:86: class",
                        "lib/fsm.rb:90: class")
  end

  def test_skipping_strings
    mlgrep *%w'name lib/fsm.rb'
    check_stdout("lib/fsm.rb:8: name",
                 "lib/fsm.rb:11: name",
                 "lib/fsm.rb:13: name",
                 "lib/fsm.rb:13: name",
                 "lib/fsm.rb:15: name",
                 "lib/fsm.rb:15: name",
                 "lib/fsm.rb:21: name",
                 "lib/fsm.rb:54: name",
                 "lib/fsm.rb:62: name",
                 "lib/fsm.rb:71: name")

    mlgrep *%w'-s name lib/fsm.rb'
    check_stdout("lib/fsm.rb:8: name",
                 "lib/fsm.rb:11: name",
                 "lib/fsm.rb:13: name",
                 "lib/fsm.rb:13: name",
                 "lib/fsm.rb:15: name", # one less match on line 15
                 "lib/fsm.rb:21: name",
                 "lib/fsm.rb:54: name",
                 "lib/fsm.rb:62: name",
                 "lib/fsm.rb:71: name")
  end

  def test_space_in_regexp
    mlgrep 'nil @state', 'lib/fsm.rb'
    check_stdout("lib/fsm.rb:168: nil @state",
                 "lib/fsm.rb:177: nil @state")
  end

  def test_until_in_regexp
    mlgrep *%w'<\u[>\n] lib/fsm.rb'
    check_stdout('lib/fsm.rb:15: <#{name}>',
                 'lib/fsm.rb:37: <tt>',
                 'lib/fsm.rb:37: </tt>',
                 'lib/fsm.rb:41: <tt>',
                 'lib/fsm.rb:41: </tt>',
                 'lib/fsm.rb:58: << "#{oldState}-(#{event})->',
                 'lib/fsm.rb:65: << "[prime #{ev}]" ',
                 'lib/fsm.rb:83: <joning@home.se>',
                 'lib/fsm.rb:115: <tt>',
                 'lib/fsm.rb:115: </tt>',
                 'lib/fsm.rb:124: << [state, event, new_state, ',
                 'lib/fsm.rb:138: << "#{@event} #{@state}->')
  end

  def test_bad_encoding
    name = "testfile.txt"
    File.open(name, "w") { |f| f.puts "# -*- coding: bogus-8 -*-" }
    if RUBY_VERSION !~ /1.8/
      mlgrep '.*', name
      check_stderr(/mlgrep: Warning: unknown encoding name - bogus-8/)
    end
  ensure
    File.unlink name
  end

  def test_zero_length_match
    mlgrep '(class FSM)?', 'lib/fsm.rb'
    check_stdout 'lib/fsm.rb:86: class FSM'
  end

  def test_searching_stdin
    # Empty stdin
    $stdin.string = ""
    assert_equal 1, mlgrep('class FSM')

    # File contents on stdin
    $stdin.string = IO.read 'lib/fsm.rb'
    assert_equal 0, mlgrep('class FSM')
    check_stdout "class FSM"
  end

  def test_file_error
    File.open_with_error_handling('lib/fsm.rb') { fail Errno::ENXIO, "Hej" }
    check_stdout /mlgrep: No such device or address - Hej|mlgrep: Device not configured - Hej/
  end

  def test_skipping_python_strings
    check_tmp_file('tmp.py',
                   ['foo1 = "foo"',
                    '"""',
                    'foo',
                    '"""',
                    "foo2 = 'foo'",
                   ],
                   ['-ns', 'foo'],
                   ['tmp.py:1: foo1 = ""',
                    "tmp.py:5: foo2 = ''"])
  end

  def test_recursive_search
    FileUtils.mkdir_p "tmp"
    check_tmp_file('tmp/tmp.rb',
                   ['fsm = 0'],
                   ['-Rl', 'fsm', '.'],
                   ["./test/test_mlgrep.rb",
                    "./lib/any_white_space.rb",
                    "./lib/mlgrep.rb",
                    "./test/test_fsm.rb",
                    "./lib/fsm.rb",
                    "./tmp/tmp.rb",
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
                   ["./test/test_mlgrep.rb",
                    "./lib/any_white_space.rb",
                    "./lib/mlgrep.rb",
                    "./test/test_fsm.rb",
                    "./lib/fsm.rb",
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
    expected.each_index { |ix|
      assert(expected[ix] === actual[ix],
             "No match: #{expected[ix]} === #{actual[ix]}")
    }
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
    check_regex(%r'^.*\b(?:123)\b.*[\n$]', '123',
                :line => true, :whole_word => true)
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
