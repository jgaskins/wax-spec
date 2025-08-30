def expect(&block : -> T) forall T
  Wax::Spec::BlockExpectation.new(block)
end

def change(&block : -> T) forall T
  Wax::Spec::ChangeValue.new(block)
end

module Wax::Spec
  VERSION = "0.1.0"

  class BlockExpectation(T)
    @block : -> T

    def initialize(@block)
    end

    def to(change : ChangeValue)
      before = change.call
      result = @block.call
      after = change.call
      should HaveChanged.new(expected: nil, actual: after - before)

      result
    end

    def to(change : ChangeValue::By)
      before = change.call
      result = @block.call
      after = change.call
      should HaveChanged.new(expected: change.value, actual: after - before)

      result
    end

    def not_to(change : ChangeValue)
      before = change.call
      result = @block.call
      after = change.call
      should_not HaveChanged.new(expected: nil, actual: after - before)

      result
    end

    def not_to(change : ChangeValue::By)
      before = change.call
      result = @block.call
      after = change.call
      should_not HaveChanged.new(expected: change.value, actual: after - before)

      result
    end

    record HaveChanged(Expected, Actual), expected : Expected, actual : Actual do
      def match(expectation : BlockExpectation)
        if expected
          actual == expected
        else
          actual != 0
        end
      end

      def failure_message(expectation : BlockExpectation)
        if actual == 0
          message = "did not change"
        else
          message = "changed by #{actual.inspect}"
        end

        if expected
          expected_message = " by #{expected.inspect}"
        end

        "Expected block to change value#{expected_message}, but it #{message}"
      end

      def negative_failure_message(expectation : BlockExpectation)
        if actual == 0
          message = "did change"
        else
          message = "changed by #{actual.inspect}"
        end

        if expected
          expected_message = " by #{expected.inspect}"
        end

        "Expected block not to change value#{expected_message}, but it #{message}"
      end
    end
  end

  class ChangeValue(T)
    @block : -> T

    def initialize(@block)
    end

    def by(value : Value) forall Value
      By.new(self, value)
    end

    def call
      @block.call
    end

    class By(T, Value)
      getter change_value : ChangeValue(T)
      getter value : Value

      def initialize(@change_value, @value)
      end

      def call
        @change_value.call
      end
    end
  end
end
