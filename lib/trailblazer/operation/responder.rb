module Trailblazer::Operation::Responder
  # TODO: test me.
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def model_name
      ::ActiveModel::Name.new(self.parent, nil, model_class.to_s) # FIXME: dependency to CRUD.
    end
  end

  def to_param
    @model.to_param
  end

  def errors
    return [] if @valid
    [1]
  end

  def to_json(*)
    self.class.representer_class.new(model).to_json
  end
end
