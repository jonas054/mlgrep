$:.unshift '.'
require 'test/unit'
require_relative '../lib/any_white_space'

class TestAnyWhiteSpace < Test::Unit::TestCase
  def test_any_space
    assert_equal('\s*a\s*test\[\s*[ \]_]\s*with\s*spaces\s*',
                 %r' a test\[ [ \]_] with  spaces '.aws.source)

    assert_equal(Regexp::MULTILINE | Regexp::IGNORECASE,
                 /abc/mi.aws.options)

    # Check that we cache the result in Regexp#aws
    assert_equal(/a b/.aws.object_id, /a b/.aws.object_id)
  end
end
