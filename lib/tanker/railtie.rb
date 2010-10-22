require 'rails'

module Tanker
  class Railtie < Rails::Railtie
    config.index_tank_url = ''
    
    initializer "tanker.boot" do
      get_config
    end
    
    config.after_initialize do
      get_config
    end

    rake_tasks do
      load "tanker/tasks/tanker.rake"
    end
    
    def get_config
      Tanker.configuration = {:url => config.index_tank_url }
    end
  end
end