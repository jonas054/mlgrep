require 'test/unit'
require_relative '../lib/skip_stuff'

class TestSkipStuff < Test::Unit::TestCase
  def test_python_strings
    python_code = <<EOT
'''
This is a comment.
'''
EOT
    assert_equal("'''\n\n'''\n", python_code.without_python_strings)
  end
end
