require 'rails'

module Tanker
  class Railtie < Rails::Railtie
    config.index_tank_url = ''
    
    initializer "tanker.boot" do
      Tanker.configuration = {:url => config.index_tank_url }
    end
    
    config.after_initialize do
      Tanker.configuration = {:url => config.index_tank_url }
    end

    rake_tasks do
      load "tanker/tasks/tanker.rake"
    end
  end
end