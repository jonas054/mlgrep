# encoding: utf-8

class String
    CPP_RE =
        %r'"(?:\\.|[^\\"])*"|\'.*?[^\\]?\'|//[^\n]*|/\*(?m:.*?)\*/|[^"\'/]+|.'

    PYTHON_RE = /['"]{3}.*?['"]{3}|'[^']*'|"[^"]*"|\s+|[^"'\s]*|./m

    # Returns a string that is the same as the original, except that all
    # angle-bracket-exclamaton-point comments are removed. Newlines are
    # preserved.
    def without_xml_comments
        replace_stuff %r'<.*?>|[^<]*', /^<!/ do |x|
            x.gsub(/[^\n]/, '')
        end
    end

    # Returns a string that is the same as the original, except that all
    # hash-mark-to-eol comments are removed. Newlines are preserved.
    def without_script_comments
        replace_stuff %r'[^\n]+|\n', /^\s*#/ do |x|
            ''
        end
    end

    # Returns a string that is the same as the original, except that all
    # C/C++/Java comments are removed. Newlines are preserved.
    def without_cpp_comments
        replace_stuff CPP_RE, %r'^/[/*]' do |x|
            x.gsub /[^\n]/, ''
        end
    end

    # Returns a string that is the same as the original, except that all string
    # literals are replaced by empty strings.
    def without_cpp_strings
        replace_stuff CPP_RE, /^"/ do
            '""'
        end
    end

    def without_python_strings
        replace_stuff PYTHON_RE, /\A["'].*/ do |x|
            x.gsub /[^\n'"]/, ''
        end
    end

    private

    def replace_stuff(scan_re, repl_re)
        scan(scan_re).map { |x|
            if x =~ repl_re
                yield x
            else
                x
            end
        }.join
    rescue
        self
    end
end
