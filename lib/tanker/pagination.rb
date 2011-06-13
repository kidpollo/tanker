module Tanker
  module Pagination

    autoload :WillPaginate, 'tanker/pagination/will_paginate'
    autoload :Kaminari, 'tanker/pagination/kaminari'

    def self.create(results, total_hits, options = {})
      begin
        backend = Tanker.configuration[:pagination_backend].to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase } # classify pagination backend name
        Object.const_get(:Tanker).const_get(:Pagination).const_get(backend).create(results, total_hits, options)
      rescue NameError
        raise(BadConfiguration, "Unknown pagination backend")
      end
    end
  end
end