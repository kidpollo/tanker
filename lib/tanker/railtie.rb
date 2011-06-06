require 'rails'

module Tanker
  class Railtie < Rails::Railtie
    config.index_tank_url = nil
    config.tanker_pagination_backend = nil

    initializer "tanker.boot" do
      Tanker.configuration = {}.tap do |_new_conf|
        _new_conf[:url] = config.index_tank_url if config.index_tank_url
        _new_conf[:pagination_backend] = config.tanker_pagination_backend if config.tanker_pagination_backend
      end
    end

    config.after_initialize do
      Tanker.configuration = {}.tap do |_new_conf|
        _new_conf[:url] = config.index_tank_url if config.index_tank_url
        _new_conf[:pagination_backend] = config.tanker_pagination_backend if config.tanker_pagination_backend
      end
    end

    rake_tasks do
      load "tanker/tasks/tanker.rake"
    end
  end
end
