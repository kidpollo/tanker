namespace :tanker do
 
  desc "Reindex all models"
  task :reindex => :environment do
    puts "reinexing all models"
    load_models
    Tanker::Utilities.reindex_all_models
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
