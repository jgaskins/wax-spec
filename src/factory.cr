require "interro/validations"

def create(type : T.class, **args) forall T
  {% begin %}
    {{T}}Factory.new.create(**args)
  {% end %}
end

abstract struct Wax::Factory
  include Interro::Validations

  def noise
    Random::Secure.hex
  end

  def valid!(object)
    case object
    when Failure
      invalid! object
    else
      object
    end
  end

  def invalid!(result : Failure)
    raise InvalidModel.new(result.errors.join(", "))
  end

  class InvalidModel < Exception
  end

  macro define(name)
    struct {{name}}Factory < {{@type}}
      {{yield}}
    end
  end
end
