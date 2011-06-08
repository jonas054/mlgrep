# -*- coding: iso-8859-1 -*-
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
