namespace :tanker do
 
  desc "Reindex all models"
  task :reindex => :environment do
    puts "reindexing all models"
    load_models
    Tanker::Utilities.reindex_all_models
  end
  
  desc "Update IndexTank functions"
  task :functions => :environment do
    puts "reindexing all IndexTank functions"
    load_models
    indexes = {}
    Tanker::Utilities.get_model_classes.each do |model|
      model.tanker_config.functions.each do |idx, definition|
        indexes[model.tanker_config.index_name] ||= {}
        indexes[model.tanker_config.index_name][idx] = definition
      end
    end
    if indexes.blank?
      puts <<-HELP
No IndexTank functions defined.
Define your server-side functions inside your model's tankit block like so:
  tankit 'myindex' do
    functions do
      {
        1 => "-age",
        2 => "relevance / miles(d[0], d[1], q[0], q[1])"
      }
    end
  end
HELP
    else
      indexes.each do |index_name, functions|
        index = Tanker.api.get_index(index_name)
        functions.each do |idx, definition|
          index.add_function(idx, definition)
          puts "Index #{index_name.inspect} function: #{idx} => #{definition.inspect}"
        end
      end
    end
  end
  
  desc "Clear all Index Tank indexes"
  task :clear_indexes => :environment do
    puts "clearing all indexes"
    load_models
    Tanker::Utilities.clear_all_indexes
  end
  
  def load_models
    app_root = Rails.root
    dirs = ["#{app_root}/app/models/"] + Dir.glob("#{app_root}/vendor/plugins/*/app/models/")
    
    dirs.each do |base|
      Dir["#{base}**/*.rb"].each do |file|
        model_name = file.gsub(/^#{base}([\w_\/\\]+)\.rb/, '\1')
        next if model_name.nil?
        model_name.camelize.constantize
      end
    end
  end
end
