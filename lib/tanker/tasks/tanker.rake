namespace :tanker do
  
  task :reindex do
    puts "reinexing all models"
    Tanker::Utilities.reindex_all_models
  end
  
  task :clear_indexes do 
    Tanker::Utilities.clear_all_indexes
  end
end
