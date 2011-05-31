unless defined?(Kaminari)
  raise(Tanker::BadConfiguration, "Tanker: Please add 'kaminari' to your Gemfile to use kaminari pagination backend")
end

module Tanker
  class KaminariPaginatedArray < Array
    include ::Kaminari::ConfigurationMethods::ClassMethods
    include ::Kaminari::PageScopeMethods

    attr_reader :limit_value, :offset_value, :total_count

    def initialize(original_array, limit_val = default_per_page, offset_val, total_count)
      @limit_value, @offset_value, @total_count = limit_val, offset_val, total_count
      super(original_array)
    end

    def page(num = 1)
      self
    end

    def limit(num)
      self
    end

    def current_page
      offset_value+1
    end
  end
end
