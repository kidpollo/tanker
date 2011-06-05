require 'rails'

module Tanker
  class Railtie < Rails::Railtie
    config.index_tank_url = nil
    config.tanker_pagination_backend = nil

    initializer "tanker.boot" do
      setup_tanker_configuration
    end

    config.after_initialize do
      setup_tanker_configuration
    end

    rake_tasks do
      load "tanker/tasks/tanker.rake"
    end

  private
    def setup_tanker_configuration
      Tanker.configuration = {}.tap do |_new_conf|
        _new_conf[:url] = config.index_tank_url if config.index_tank_url
        _new_conf[:pagination_backend] = config.tanker_pagination_backend if config.tanker_pagination_backend
      end
    end
  end
end
