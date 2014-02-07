module Tanker
  module Pagination

    autoload :WillPaginate, 'tanker/pagination/will_paginate'
    autoload :Kaminari, 'tanker/pagination/kaminari'

    def self.create(results, total_hits, options = {}, categories = {})
      begin
        backend = Tanker.configuration[:pagination_backend].to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase } # classify pagination backend name
        page = Object.const_get(:Tanker).const_get(:Pagination).const_get(backend).create(results, total_hits, options)
        page.extend Categories
        page.categories = categories
        page
      rescue NameError
        raise(BadConfiguration, "Unknown pagination backend")
      end
    end

    module Categories
      def categories
        @categories
      end

      def categories=(val)
        @categories = val
      end
    end
  end
end
