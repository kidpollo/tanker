require 'rails'

module Tanker
  class Railtie < Rails::Railtie
    config.index_tank_url = ''

    initializer "tanker.initializating", :after => :load_application_initializers do |app|
      Tanker.configuration = {:url => config.index_tank_url }
    end

    rake_tasks do
      load "tanker/tasks/tanker.rake"
    end

  end
end
