require 'rails'

module Tanker
  class Railtie < Rails::Railtie
    config.index_tank_url = ''

    config.after_initialize do
      Tanker.configuration = {:url => config.index_tank_url }
    end

    rake_tasks do
      load "tanker/tasks/tanker.rake"
    end

  end
end
