module Tanker

  module Configuration

    def configuration
      @@configuration || raise(NotConfigured, "Please configure Tanker. Set Tanker.configuration = {:url => ''}")
    end

    def configuration=(new_configuration)
      @@configuration = new_configuration
    end

  end

end
