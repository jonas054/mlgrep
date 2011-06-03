require 'fsm'
require 'test/unit'

class TestFSM < Test::Unit::TestCase
    def setup
        $output = []
        name = nil
        is_prime = Proc.named('is_prime') { |n|
            not (2...n.to_i).find { |x| n % x == 0 }
        }

        $fsm = FSM.new(:init) { |ev, old, new|
            $output << (old.to_s[0,1].upcase + "-(#{ev})->" +
                        new.to_s[0,1].upcase)
        }
        $fsm.add(:init,    'start',  :started)
        $fsm.add(:started, /^[A-Z][a-z]+/) { |ev,| $fsm.act; name = ev }
        $fsm.add(:started, 'run',    :running)
        $fsm.add(:running, is_prime, :ended) {
            $fsm.act; $output << "[#{name.upcase}]"
        }
        $fsm.add(:ANY,     Integer)
    end

    def test_normal
        $fsm.run ['start', 'Bob', 'run']
        $fsm.run [33, 37]
        assert_equal 'I-(start)->S, S-(Bob)->S, S-(run)->R, R-(33)->R, ' +
            "R-(37)->E, [BOB]", $output.join(', ')
        $fsm.write_graph 'fsm.dot'
    end

    def test_error
        assert_equal 'Event "x" in state :init',
            assert_raise(RuntimeError) { $fsm.run ['x'] }.message
    end

    def test_no_default_action
        fsm = FSM.new :init
        n = nil
        out = ''
        fsm.add(:init,  Float,   :float) { |ev,| n = ev  }
        fsm.add(:init,  Fixnum,  :int)   { |ev,| n = ev  }
        fsm.add(:float, 'FLOOR', :int)   { n = n.floor }
        fsm.add(:ANY,   'PRINT')         { out << "n = #{n}" }
        fsm.add(:ANY,   'RESET', :init)

        fsm.run [3.3, 'FLOOR', 'PRINT']

        assert_equal 'n = 3', out

        assert_equal('Event "FLOOR" in state :int',
                     assert_raise(RuntimeError) {
                         fsm.run ['RESET', 3, 'FLOOR']
                     }.message)

        fsm.write_graph 'fsm2.dot'
    end
end
