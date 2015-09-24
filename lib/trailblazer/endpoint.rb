module Trailblazer
  # To be used in Lotus, Roda, Rails, etc.
  class Endpoint
    def initialize(operation_class, params, request, options)
      @operation_class = operation_class
      @params  = params
      @request = request
      @is_document  = options[:is_document]
    end

    def call
      document_body! if document_request?
      yield # Create.run(params)
    end

  private
    attr_reader :params, :operation_class, :request

    def document_request?
      @is_document
    end

    def document_body!
      # this is what happens:
      # respond_with Comment::Update::JSON.run(params.merge(comment: request.body.string))
      concept_name = operation_class.model_class.to_s.underscore # this could be renamed to ::concept_class soon.
      request_body = request.body.respond_to?(:string) ? request.body.string : request.body.read

      params.merge!(concept_name => request_body)
    end
  end
end