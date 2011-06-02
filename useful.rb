# -*- coding: iso-8859-1 -*-
require 'fsm'

# Simplifies the syntax a little bit so we can write
#   discard_exception(RuntimeError) { some_function }
# instead of
#   begin
#      some_function
#   rescue RuntimeError
#   end
def discard_exception(*types)
    types = [Object] if types.empty?
    raise LocalJumpError, 'no block given' if not block_given?
    begin
        yield
    rescue *types
        return $!
    end
    nil
end

class Object
    # Printing an object by calling a member function. Was suggested in a
    # paper comparing ruby to python. Perhaps a tad misguided.
    def write(stream = $stdout) stream << to_s; end
    def writeln(stream = $stdout) (to_s + "\n").write(stream); end
end

class Range
    # The method 'last' returns 3 for 0..3 and 3 for 0...3, and you have to
    # call exclude_end? to find out the actual end point of the range. This
    # method makes life a bit easier for you.
    def effective_last() exclude_end? ? last - 1 : last; end
end

module Enumerable
    # Iterates over the elements, each time yielding the current element plus
    # a few of its successors (depending on window_length). When we get near
    # the end and the window extends past the last element, slide() still
    # yields the same number of elements by adding nil values to the list of
    # aguments to yield.
    #
    # If a block is given, an array with the results of each yield is returned
    # (like collect/map). If no block is given, an array of windows is
    # returned, each window being an array of the arguments that would have
    # been sent to the block if there was one.
    def slide(window_length)
        result = []
        (0...to_a.size).each { |i|
            args = to_a[i, window_length]
            args << nil until args.size == window_length
            result << (block_given? ? yield(*args) : args)
        }
        result
    end

    def sum
        result = block_given? ? yield(first, 0) : first
        (1...to_a.size).each { |i|
            result += block_given? ? yield(entries[i], i) : entries[i]
        }
        result
    end

    def product() inject { |memo, n| memo * n } end
    def average() sum.to_f / size end

    def sort_on(sym) sort_by { |x| x.send(sym) } end
    def sort_on!(sym) replace sort_on(sym) end

    # According to solution suggested by matz on ruby-talk.
    def stable_sort_by
        n = 0
        sort_by { |x| [yield(x), n += 1] }
    end

    def stable_sort() stable_sort_by { |x| x } end
end

class Array
    def rand_elem() self[rand(size)] end
    def delete_rand_elem() delete_at rand(size) end
end

class Object
    def deep_copy() Marshal.load Marshal.dump(self) end

    # Like python's "if x in [...]" - an alternative to include?/member?.
    def is_in?(aCollection) aCollection.include? self end
    def not_in?(aCollection) not aCollection.include? self end
end

# A straight-forward assert method. Named assert_that to avoid clash with
# Test::Unit::TestCase#assert. Takes a condition (boolean) or a block.
def assert_that(cond = false)
    raise 'Assertion failed.' unless (block_given? ? yield : cond)
end

class Regexp
    # Replaces space characters with \s* and returns a new multi-line regexp.
    # Simplifies regexp syntax when matching things where whitespace is
    # insignificant. E.g., /(unsigned)? (int)? \w+ ;/.aws becomes
    # /(unsigned)?\s*(int)?\s*\w+\s*;/m
    def aws
        @@aws_cache ||= {}
        key = inspect
        cached_value = @@aws_cache[key]
        return cached_value if cached_value

        result = ''
        fsm = FSM.new(:normal) { |char,| result << char }

        fsm.add(:normal,          / /,  :normal) { result << '\s*' }
        fsm.add :normal,          '\\', :escape_normal
        fsm.add :escape_normal,   /./,  :normal
        fsm.add :normal,          '[',  :brackets
        fsm.add :brackets,        ']',  :normal
        fsm.add :brackets,        '\\', :escape_brackets
        fsm.add :escape_brackets, /./,  :brackets
        fsm.add :ANY,             /./

        fsm.run source.scan(/ +|\w+|./)

        @@aws_cache[key] = Regexp.new result, options
    end

    alias any_white_space aws
end

class Integer
    # Returns a string containing the given number plus the correct suffix like
    # 1st, 2nd, 3rd, 4th, etc.
    def order
        to_s + (is_group(1) ? 'st' :
                is_group(2) ? 'nd' :
                is_group(3) ? 'rd' : 'th')
    end

    # Same as 'order' but in Swedish.
    def ordning
        to_s + ':' + (is_group(1) || is_group(2) ? 'a' : 'e')
    end

    private
    def is_group(i) abs % 10 == i and abs % 100 != 10 + i end
end

# -*- encoding: utf-8 -*-
  
class String
    HTML_CHAR_MAP = {
        '&aring;'  => 'å', '&auml;'   => 'ä', '&aacute;' => 'á',
        '&agrave;' => 'à', '&acirc;'  => 'â',
        '&Aring;'  => 'Å', '&Auml;'   => 'Ä', '&Aacute;' => 'Á',
        '&Agrave;' => 'À', '&Acirc;'  => 'Â',
        '&ouml;'   => 'ö', '&ocirc;'  => 'ô',
        '&Ouml;'   => 'Ö', '&Ocirc;'  => 'Ô',
        '&eacute;' => 'é', '&egrave;' => 'è', '&ecirc;' => 'ê',
        '&euml;'   => 'ë',
        '&Eacute;' => 'É', '&Egrave;' => 'È', '&Ecirc;' => 'Ê',
        '&Euml;'   => 'Ë',
    }

    def to_html_esc
        result = dup.gsub '&', '&amp;'
        HTML_CHAR_MAP.invert.each { |regexp, char| result.gsub!(regexp, char) }
        result
    end

    def from_html_esc
        result = dup
        HTML_CHAR_MAP.each { |regexp, char| result.gsub!(regexp, char) }
        result
    end

    # Usage: aString.match_with_line(re, file_name) { |match, line| ... }
    #        aString.match_with_line(re, file_name, true) { |match, line, pos| ... }
    def match_with_line(re, file_name, include_pos = false, only_match = false)
        pos = 0
        proper_name = {
            'NIL' => 'ASCII-8BIT',
            'EUC' => 'EUC-JP',
            'UTF' => 'UTF-8'
        }
       loop {
          if RUBY_VERSION =~ /\b1\.8/
             raw_text = self[pos..-1]
          else
             raw_text = self[pos..-1].dup.force_encoding('ASCII-8BIT')
          end
          begin
             if RUBY_VERSION !~ /\b1\.8/ and raw_text =~ /coding: ([\w-]+)/n
                self[pos..-1].force_encoding proper_name[$1.upcase] || $1
                break unless self[pos..-1].valid_encoding?
             end
             relpos = self[pos..-1] =~ re or break
          rescue ArgumentError
             puts "Warning: #$! in #{file_name}"
             break
          end
          line   = self[0..pos+relpos].count("\n") + 1
          match  = only_match ? "#$1 #$2 #$3 #$4 #$5 #$6 #$7 #$8 #$9".strip || $& : $&
          if $&.empty?
             pos += 1 # avoid infinite loop
          else
             args = [match, line]
             args << (pos + relpos) if include_pos
             yield(*args) if block_given?
             pos += relpos + $&.length
          end
       }
    end
 end

#==============================================================================

if $0 == __FILE__
    require 'test/unit'

    class TestUseful < Test::Unit::TestCase
        MyClass = Struct.new :value

        def test_html_esc
            assert_equal '&aring;&auml;&ouml;', "åäö".to_html_esc
        end

        def test_match_with_line
            result = []
            "a b\nc".match_with_line(/\w/, 'my_file.c', true) { |match, line, pos|
                result << [match, line, pos]
            }

            assert_equal [
                ['a', 1, 0],
                ['b', 1, 2],
                ['c', 2, 4]], result

            ## Match "a b", but return only "b".
            result = []
            "a b\nc".match_with_line(/. (.)/, 'my_file.c', false, true) { |match, line|
                result << [match, line]
            }
            assert_equal [['b', 1]], result
        end

        def test_order
            %w(0th 1st 2nd 3rd 4th).each_with_index { |w,i|
                assert_equal w, i.order
            }
            (5..20).each { |i| assert_equal "#{i}th", i.order }
            %w(21st 22nd 23rd 24th).each_with_index { |w,i|
                assert_equal w, (i+21).order
            }
            assert_equal '100th', 100.order
            assert_equal '101st', 101.order
            assert_equal '-1st', -1.order
        end

        def test_ordning
            %w(0:e 1:a 2:a 3:e).each_with_index { |w,i|
                assert_equal w, i.ordning
            }
            (4..20).each { |i| assert_equal "#{i}:e", i.ordning }
            %w(21:a 22:a 23:e).each_with_index { |w,i|
                assert_equal w, (i+21).ordning
            }
            assert_equal '100:e', 100.ordning
            assert_equal '101:a', 101.ordning
            assert_equal '-1:a', -1.ordning
        end

        def test_deep_copy
            txt = 'Hello'
            obj1 = MyClass.new(txt.dup) # Shallow copy of txt, which is enough.
            obj2 = obj1.dup
            obj3 = obj1.deep_copy

            obj1.value[0] = 'J' # Also affects obj2, since it is a shallow copy
            txt[0] = 'C' # Only affects txt

            assert_equal 'Jello', obj1.value
            assert_equal 'Jello', obj2.value
            assert_equal 'Hello', obj3.value
        end

        def test_any_space
            assert_equal('\s*a\s*test\[\s*[ \]_]\s*with\s*spaces\s*',
                         / a test\[ [ \]_] with  spaces /.aws.source)

            assert_equal(Regexp::MULTILINE | Regexp::IGNORECASE,
                         /abc/mi.aws.options)

            # Check that we cache the result in Regexp#aws
            assert_equal /a b/.aws.object_id, /a b/.aws.object_id
        end

        def test_assertion
            assert_that 3 < 4
            assert_raises(RuntimeError) { assert_that 3 == 4 }
            assert_raises(RuntimeError) { assert_that { 3 == 4 } }
            assert_that { 3 < 4 }
        end

        def test_reverse_include
            assert 3.is_in?([1, 2, 3])
            assert 3.is_in?(1..3)
            assert !'3'.is_in?([1, 2, 3])
            assert '23'.is_in?('123')
        end

        def test_inject
            assert_equal 10, (1..4).sum
            assert_equal 24, (1..4).product
            assert_equal 12, (3..4).product
            assert_equal 7.0/3, [2, 2, 3].average
        end

        def test_slide
            assert_equal [[1, 2], [2, 3], [3, nil]], (1..3).slide(2)
            assert_equal [], [].slide(3)
            assert_equal [[]], [1].slide(0)
            assert_equal [[1]], [1].slide(1)
            assert_equal [[1, nil, nil]], [1].slide(3)
            assert_equal([['h', 'e'], ['e', 'j'], ['j', nil]],
                         'hej'.split('').slide(2))
            str = ''
            ['1', '2', '3'].slide(2) { |a, b| str += a + (b || '[nil]') + '-'}
            assert_equal '12-23-3[nil]-', str
        end

        def test_sort
            assert_equal [0, -1, -2, 3, 4], [-2, -1, 0, 3, 4].sort_on(:abs)

            a = [-2, -1, 0, 3, 4]
            a.sort_on! :abs
            assert_equal [0, -1, -2, 3, 4], a

            assert_equal(%w(A a A a a A B c),
                         %w(A B a A a c a A).stable_sort_by { |x| x.downcase })
        end

        def test_rand_elem
            arr = Array.new(100) { rand 100 }.uniq

            arr.size.downto(1) { |exp_size|
                assert_equal exp_size, arr.size
                assert_equal false, arr.include?(arr.delete_rand_elem)
            }

            assert_equal 0, arr.size
            assert_equal nil, arr.delete_rand_elem
        end

        def test_add_hashes
            x = { 'a' => 10, 'b' => 20, 'c' => 30 }
            y = { 'a' => 1, 'b' => 2, 'd' => 4 }
            sum = { 'a' => 11, 'b' => 22, 'c' => 30, 'd' => 4 }

            assert_equal(sum, x.merge2(y) { |v1,v2| (v1||0) + (v2||0) })
        end
    end

    def test_discard_exception
	assert_nil discard_exception {}

	assert_raises(LocalJumpError) { discard_exception }
	assert_raises(LocalJumpError) { discard_exception(LocalJumpError) }

	var = 0
	discard_exception { var = 1; raise "one" }
	assert_equal 1, var

	result = discard_exception(RuntimeError) { raise "two" }
	assert_equal RuntimeError, result.class
	assert_equal "two",        result.message

	assert_raises(RuntimeError) {
	    discard_exception(NameError, LocalJumpError) { raise "three" }
	}
    end

    def test_member_print
	arr = []
	'Hello'.write(arr)
	' world'.writeln(arr)
	assert_equal ["Hello", " world\n"], arr
    end

    def test_range_last
	assert_equal 7, (2..7).effective_last
	assert_equal 6, (2...7).effective_last
    end
end
