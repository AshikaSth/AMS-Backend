module ErrorFormatter
  extend ActiveSupport::Concern

  private

  def formatted_errors(resource)
    resource.errors.messages.flat_map do |attribute, messages|
      messages.map do |msg|
        {
          field: attribute.to_s,
          message: msg,
          type: 'validation_error'
        }
      end
    end
  end
end
