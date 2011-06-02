class String
    CPP_RE =
        %r'"(?:\\.|[^\\"])*"|\'.*?[^\\]?\'|//[^\n]*|/\*(?m:.*?)\*/|[^"\'/]+|.'

    # Returns a string that is the same as the original, except that all
    # angle-bracket-exclamaton-point comments are removed. Newlines are preserved.
    def withoutXmlComments
        replaceStuff %r'<.*?>|[^<]*', %r'^<!' do |x|
            x.gsub(/[^\n]/, '')
        end
    end

    # Returns a string that is the same as the original, except that all
    # hash-mark-to-eol comments are removed. Newlines are preserved.
    def withoutScriptComments
        replaceStuff %r'[^\n]+|\n', %r'^\s*#' do |x|
            ''
        end
    end

    # Returns a string that is the same as the original, except that all
    # C/C++/Java comments are removed. Newlines are preserved.
    def withoutCppComments
        replaceStuff CPP_RE, %r'^/[/*]' do |x|
            x.gsub %r"[^\n]", ''
        end
    end

    # Returns a string that is the same as the original, except that all string
    # literals are replaced by empty strings.
    def withoutCppStrings
        replaceStuff CPP_RE, %r'^"' do
            '""'
        end
    end

    private

    def replaceStuff(scan_re, repl_re)
        scan(scan_re).map { |x|
            if x =~ repl_re
                yield x
            else
                x
            end
        }.join
    end
end
