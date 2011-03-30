
begin
  require "rubygems"
  require "bundler"

  Bundler.setup :default
rescue => e
  puts "Tanker: #{e.message}"
end
require 'indextank_client'
require 'tanker/configuration'
require 'tanker/utilities'
require 'will_paginate/collection'


if defined? Rails
  begin
    require 'tanker/railtie'
  rescue LoadError
  end
end

module Tanker

  class NotConfigured < StandardError; end
  class NoBlockGiven < StandardError; end

  autoload :Configuration, 'tanker/configuration'
  extend Configuration

  class << self
    attr_reader :included_in

    def api
      @api ||= IndexTank::ApiClient.new(Tanker.configuration[:url])
    end

    def included(klass)
      @included_in ||= []
      @included_in << klass
      @included_in.uniq!

      configuration # raises error if not defined
      klass.send :include, InstanceMethods
      klass.extend ClassMethods

      class << klass
        define_method(:per_page) { 10 } unless respond_to?(:per_page)
      end
    end

    def batch_update(records)
      return false if records.empty?
      data = records.map do |record|
        options = record.tanker_index_options
        options.merge!( :docid => record.it_doc_id, :fields => record.tanker_index_data )
        options
      end
      records.first.class.tanker_index.add_documents(data)
    end

    def search(models, query, options = {})
      ids      = []
      models   = [models].flatten.uniq
      page     = (options.delete(:page) || 1).to_i
      per_page = (options.delete(:per_page) || models.first.per_page).to_i
      index    = models.first.tanker_index

      if (index_names = models.map(&:tanker_config).map(&:index_name).uniq).size > 1
        raise "You can't search across multiple indexes in one call (#{index_names.inspect})"
      end


      # transform fields in query
      if conditions = options.delete(:conditions)
        conditions.each do |field, value|
          value = [value].flatten
          value.each do |item|
            query += " #{field}:(#{item})"
          end
        end
      end

      query = "__any:(#{query.to_s}) __type:(#{models.map(&:name).join(' OR ')})"
      options = { :start => per_page * (page - 1), :len => per_page }.merge(options)
      results = index.search(query, options)

      @entries = WillPaginate::Collection.create(page, per_page) do |pager|
        # inject the result array into the paginated collection:
        pager.replace instantiate_results(results)

        unless pager.total_entries
          # the pager didn't manage to guess the total count, do it manually
          pager.total_entries = results["matches"]
        end
      end
    end

    protected

      def instantiate_results(index_result)
        results = index_result['results']
        return [] if results.empty?

        id_map = results.inject({}) do |acc, result|
          model, id = result["docid"].split(" ", 2)
          acc[model] ||= []
          acc[model] << id.to_i
          acc
        end

        if 1 == id_map.size # check for simple case, just one model involved
          klass = constantize(id_map.keys.first)
          # eager-load and return just this model's records
          klass.find(id_map.values.flatten)
        else # complex case, multiple models involved
          id_map.each do |klass, ids|
            # replace the id list with an eager-loaded list of records for this model
            id_map[klass] = constantize(klass).find(ids)
          end
          # return them in order
          results.map do |result|
            model, id = result["docid"].split(" ", 2)
            id_map[model].detect {|record| id.to_i == record.id }
          end
        end
      end

      def constantize(klass_name)
        Object.const_defined?(klass_name) ?
                  Object.const_get(klass_name) :
                  Object.const_missing(klass_name)
      end
  end

  # these are the class methods added when Tanker is included
  # They're kept to a minimum to prevent namespace pollution
  module ClassMethods

    attr_accessor :tanker_config

    def tankit(name, &block)
      if block_given?
        self.tanker_config = ModelConfig.new(name, block)
      else
        raise(NoBlockGiven, 'Please provide a block')
      end
    end

    def search_tank(query, options = {})
      Tanker.search([self], query, options)
    end

    def tanker_index
      tanker_config.index
    end

    def tanker_reindex(options = {})
      puts "Indexing #{self} model"

      batches = []
      options[:batch_size] ||= 200
      records = options[:scope] ? send(options[:scope]).all : all
      record_size = records.size

      records.each_with_index do |model_instance, idx|
        batch_num = idx / options[:batch_size]
        (batches[batch_num] ||= []) << model_instance
      end

      timer = Time.now
      batches.each_with_index do |batch, idx|
        Tanker.batch_update(batch)
        puts "Indexed #{batch.size} records   #{(idx * options[:batch_size]) + batch.size}/#{record_size}"
      end
      puts "Indexed #{record_size} #{self} records in #{Time.now - timer} seconds"
    end
  end

  class ModelConfig
    attr_reader :indexes, :variables, :index_name

    def initialize(index_name, block)
      @index_name = index_name
      @indexes = []
      instance_exec &block
    end

    def indexes(field = nil, &block)
      @indexes << [field, block] if field
      @indexes
    end

    def variables(&block)
      @variables = block if block
      @variables
    end

    def index
      @index ||= Tanker.api.get_index(index_name)
    end

  end

  # these are the instance methods included
  module InstanceMethods

    def tanker_config
      self.class.tanker_config || raise(NotConfigured, "Please configure Tanker for #{self.class.inspect} with the 'tankit' block")
    end

    def tanker_indexes
      tanker_config.indexes
    end

    def tanker_variables
      tanker_config.variables
    end

    # update a create instance from index tank
    def update_tank_indexes
      tanker_config.index.add_document(
        it_doc_id, tanker_index_data, tanker_index_options
      )
    end

    # delete instance from index tank
    def delete_tank_indexes
      tanker_config.index.delete_document(it_doc_id)
    end

    def tanker_index_data
      data = {}

      # attempt to autodetect timestamp
      if respond_to?(:created_at)
        data[:timestamp] = created_at.to_i
      end

      tanker_indexes.each do |field, block|
        val = block ? instance_exec(&block) : send(field)
        val = val.join(' ') if Array === val
        data[field.to_sym] = val.to_s unless val.nil?
      end

      data[:__any] = data.values.sort_by{|v| v.to_s}.join " . "
      data[:__type] = self.class.name

      data
    end

    def tanker_index_options
      options = {}

      if tanker_variables
        options[:variables] = instance_exec(&tanker_variables)
      end

      options
    end

    # create a unique index based on the model name and unique id
    def it_doc_id
      self.class.name + ' ' + self.id.to_s
    end
  end
end
