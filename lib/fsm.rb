class Proc
    # Case equality for a proc is defined as the result of calling the proc.
    def ===(arg)
        call arg
    end

    # :stopdoc:
    # Following is a bit of trickery to allow named procs in dot files produced
    # by FSM#write_graph.

    @@fsm_name = {}

    def self.named(name, &block)
        obj = lambda(&block)
        @@fsm_name[obj] = "<#{name}>"
        obj
    end

    alias old_inspect inspect
    def inspect
        @@fsm_name[self] or old_inspect
    end
end

# Most programs, if not all, make use of *finite* *state* *machines* for
# processing the logic of the program. This can be done implicitly or
# explicitly. By using the FSM class, you move the +if+ statements out of your
# code and instead supply tables of possible states, the events that can occur,
# and the code blocks that shall be executed when a certain event occurs while
# the program is in a certain state.
#
# You build the state/event table by:
# 1. creating it with FSM.new
# 1. supplying states, expected events, and actions through FSM#add
# 1. invoking FSM#run with an array of actual events
#
# States are usually represented by Symbols (e.g., <tt>:init</tt>) but can be
# any Ruby object.
#
# Expected events are objects that support the case equality operator,
# <tt>===</tt>. The beauty of using case equality for checking if an event
# given to FSM#run matches an _expected_ _event_ given to FSM#add is that you
# can, for example, give a Regexp to FSM#add and
# Regexp#===[http://www.ruby-doc.org/core/classes/Regexp.html] (i.e., pattern
# matching) will be used to determine equality. The fsm.rb file also redefines
# case equality for Proc objects, so that you can write your own _expected_
# _events_ of arbitrary complexity (see +is_prime+ in the example below).
#
# Usage:
#
#   require 'fsm'
#
#   output = []
#   name = nil
#   is_prime = proc { |n| not (2...n.to_i).find { |x| n % x == 0 } }
#
#   fsm = FSM.new(:init) { |event, oldState, newState|
#       output << "#{oldState}-(#{event})->#{newState}"
#   }
#
#   fsm.add(:init, 'start', :started)
#   fsm.add(:started, /^[A-Z][a-z]+/) { |ev,| fsm.act; name = ev }
#   fsm.add(FSM.either(:started, :ended), is_prime, :ended) { |ev,|
#       fsm.act
#       output << "[prime #{ev}]"
#   }
#   fsm.add(:ANY, Integer)
#
#   fsm.run ['start', 'Bob', 36, 37, 38]
#
#   puts output.join("\n"), name
#
# Output:
#
#   init-(start)->started
#   started-(Bob)->started
#   started-(36)->started
#   started-(37)->ended
#   [prime 37]
#   ended-(38)->ended
#   Bob
#
# Author:: Jonas Arvidsson <joning@home.se>
# Copyright:: Jonas Arvidsson (C) 2005. Use under same license as Ruby.
#
class FSM
    # Represents a choice of states to go from when an event shall take the FSM
    # from one of many possible old states to a certain new state. FSM.either
    # is a factory generating instances of this class.
    class Either
        def initialize(*args) @members = args end
        def ===(other) @members.include? other end
    end

    # Creates an FSM in state _initialState_. If a block is given, it will be
    # the default action executed for all rules that don't have their own
    # action.
    #
    # :call-seq:
    #   new(initialState) { |event, old_state, new_state| ... }
    #   new(initialState)
    #
    def initialize(initialState, &defaultAction)
        @state, @defaultAction = initialState, defaultAction
        @matrix = []
        @newState = nil
    end

    # Creates an instance of the Either class. It takes two or more states as
    # arguments.
    def self.either(*args) Either.new(*args) end

    # Adds a state/event transition (a rule). If no block is given, the default
    # action will be used. If no _newState_ is given, the FSM will remain in
    # the same state. You can use the value <tt>:ANY</tt> for _state_ or
    # _expectedEvent_. When the action is called, the arrays _peek_ahead_ and
    # _peek_back_ contain the events after and before the current one.
    #
    # :call-seq:
    #   add(state, expectedEvent, newState = state) { |event, old_state, new_state, peek_ahead, peek_back| ... } 
    #   add(state, expectedEvent, newState = state)
    #
    def add(state, event, newState = state, &action)
        @matrix << [state, event, newState,
                    action || @defaultAction || proc { }]
    end

    # Feeds the given array of actual events to the FSM, causing state
    # transitions to occur and actions to be executed. After returning from
    # run, the FSM remains in whatever state it was, and +run+ may be called
    # again.
    def run(events)
        events.each_with_index { |ev, ix|
            @event = ev
            state, event, newState, action = @matrix.find { |s, e, |
                (s === @state or s == :ANY) and (e === @event or e == :ANY)
            }
            $stderr << "#@event #@state->#{newState}\n" if $DEBUG
            unless state
                raise "Event #{@event.inspect} in state #{@state.inspect}"
            end
            @newState = newState unless newState == :ANY || Either === newState
            action.call(@event, @state, @newState, events[(ix + 1)..-1],
                        events[0...ix])
            @state = @newState if @newState
        }
    end

    # Executes the default action. Typically used from within an action when
    # you want to execute the default action plus something more.
    def act
        # Note that we can't send peek_ahead/peek_back arguments here. That's
        # why they don't appear in the documentation for new/initialize.
        @defaultAction.call @event, @state, @newState
    end

    # Jumps to the given state, but remembers the current state so that it can
    # be restored later by a call to FSM#pop_state.
    def push_state(state)
        @newState = nil
        @stack ||= []
        @stack.push @state
        @state = state
    end

    # Restores the state from the state stack created by FSM#push_state.
    def pop_state
        @newState = nil
        @state = @stack.pop
    end

    # Jumps to the given state. Use with care, since this state transition is
    # not part of the model built up by FSM#add, meaning for instance, that it
    # won't show up in the graph created by FSM#write_graph. This goes for
    # FSM#push_state and FSM#pop_state too.
    def goto(state)
        @newState = nil
        @state = state
    end

    # Writes a dot file displaying the state machine graph. Use _dotty_,
    # available from http://www.graphviz.org, to view the graph.
    def write_graph(fileName)
        s = ("digraph finite_state_machine {\n\trankdir=LR;\n" +
             "\tsize=\"A4\";\n\torientation=land;\n" +
             "\tnode [shape = circle];\n" +
             @matrix.map { |ln|
                 label = ln[1].inspect
                 label = '"' + label + '"' if label[0, 1] != '"'
                 "\t#{ln[0]} -> #{ln[2] || ln[0]} [ label = #{label} ];\n"
             }.join +
             "}\n")
        File.open(fileName, 'w') { |file| file.write(s) }
    end
end
