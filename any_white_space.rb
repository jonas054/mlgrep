require 'fsm'

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

#==============================================================================

if $0 == __FILE__
    require 'test/unit'

    class TestAnyWhiteSpace < Test::Unit::TestCase
        def test_any_space
            assert_equal('\s*a\s*test\[\s*[ \]_]\s*with\s*spaces\s*',
                         / a test\[ [ \]_] with  spaces /.aws.source)

            assert_equal(Regexp::MULTILINE | Regexp::IGNORECASE,
                         /abc/mi.aws.options)

            # Check that we cache the result in Regexp#aws
            assert_equal /a b/.aws.object_id, /a b/.aws.object_id
        end
    end
end  
