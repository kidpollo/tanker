module Tanker
  module Configuration
    def configuration
      @@configuration || raise(NotConfigured, "Please configure Tanker. Set Tanker.configuration = {:url => ''}")
    end

    def configuration=(new_configuration)
      # the default pagination backend is WillPaginate
      @@configuration = new_configuration.tap do |_config|
        _config.replace({ :pagination_backend => :will_paginate }.merge(_config)) if _config.is_a?(Hash)
      end
    end
  end
end
