$:.unshift '.'
require 'test/unit'
require_relative '../lib/skip_stuff'

class TestSkipStuff < Test::Unit::TestCase
  def test_python_strings
    pythonCode = <<EOT
'''
This is a comment.
'''
EOT
    assert_equal("'''\n\n'''\n", pythonCode.withoutPythonStrings)
  end
end
