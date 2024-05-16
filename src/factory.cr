require "interro/validations"

abstract struct Wax::Factory
  include Interro::Validations

  def noise
    Random::Secure.hex
  end

  def invalid!(result)
    raise InvalidModel.new(result.errors.join(", "))
  end

  class InvalidModel < Exception
  end

  macro define(name)
    struct {{name}}Factory < ::Wax::Factory
      {{yield}}
    end
  end
end
