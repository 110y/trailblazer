class Trailblazer::Operation
  module Resolver
    def self.import!(operation, import)
      operation.extend Model::BuildMethods
      operation.| operation.Builder(operation.builders)
    end

    # def self.included(includer)
    #   includer.class_eval do
    #     extend Model::DSL  # ::model
    #     extend Model::BuildMethods  # ::model!
    #     extend Policy::DSL # ::policy
    #     extend Policy::BuildPermission
    #   end

    #   includer.> Model::Build, prepend: true
    #   includer.& Policy::Evaluate, after: Model::Build
    # end
  end

  DSL.macro!(:Resolver, Resolver)
end
