
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
  class NoIndexName < StandardError; end

  autoload :Configuration, 'tanker/configuration'
  extend Configuration

  class << self
    attr_reader :included_in

    def api
      @api ||= IndexTank::ApiClient.new(Tanker.configuration[:url])
    end

    def included(klass)
      configuration # raises error if not defined

      @included_in ||= []
      @included_in << klass
      @included_in.uniq!

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
      index    = models.first.tanker_index
      query    = query.join(' ') if Array === query
      paginate = extract_setup_paginate_options(options, :page => 1, :per_page => models.first.per_page)

      if (index_names = models.map(&:tanker_config).map(&:index_name).uniq).size > 1
        raise "You can't search across multiple indexes in one call (#{index_names.inspect})"
      end

      # move conditions into the query body
      if conditions = options.delete(:conditions)
        conditions.each do |field, value|
          value = [value].flatten.compact
          value.each do |item|
            query += " #{field}:(#{item})"
          end
        end
      end

      # rephrase filter_functions
      if filter_functions = options.delete(:filter_functions)
        filter_functions.each do |function_number, ranges|
          options[:"filter_function#{function_number}"] = ranges.map{|r|r.join(':')}.join(',')
        end
      end

      # rephrase filter_docvars
      if filter_docvars = options.delete(:filter_docvars)
        filter_docvars.each do |var_number, ranges|
          options[:"filter_docvar#{var_number}"] = ranges.map{|r|r.join(':')}.join(',')
        end
      end

      options[:fetch] = "__type,__id"

      query = "__any:(#{query.to_s}) __type:(#{models.map(&:name).map {|name| "\"#{name.split('::').join(' ')}\"" }.join(' OR ')})"
      options = { :start => paginate[:per_page] * (paginate[:page] - 1), :len => paginate[:per_page] }.merge(options) if paginate
      results = index.search(query, options)
      instantiated_results = instantiate_results(results)

      @entries = paginate === false ? instantiated_results :
                                      WillPaginate::Collection.create(paginate[:page], paginate[:per_page], results['matches']) { |pager| pager.replace instantiated_results }
    end

    protected

      def instantiate_results(index_result)
        results = index_result['results']
        return [] if results.empty?

        id_map = results.inject({}) do |acc, result|
          model = result["__type"]
          id = constantize(model).tanker_parse_doc_id(result)
          acc[model] ||= []
          acc[model] << id
          acc
        end

        id_map.each do |klass, ids|
          # replace the id list with an eager-loaded list of records for this model
          id_map[klass] = constantize(klass).find(ids)
        end
        # return them in order
        results.map do |result|
          model, id = result["__type"], result["__id"]
          id_map[model].detect {|record| id == record.id.to_s }
        end
      end

      # borrowed from Rails' ActiveSupport::Inflector
      def constantize(camel_cased_word)
        names = camel_cased_word.split('::')
        names.shift if names.empty? || names.first.empty?

        constant = Object
        names.each do |name|
          constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
        end
        constant
      end

      def extract_setup_paginate_options(options, defaults)
        # extract
        paginate_options = if options[:paginate] or options[:paginate] === false
          options.delete(:paginate)
        else
          { :page => options.delete(:page), :per_page => options.delete(:per_page) }
        end
        # setup defaults and ensure we got integer values
        unless paginate_options === false
          paginate_options[:page] = defaults[:page] unless paginate_options[:page]
          paginate_options[:per_page] = defaults[:per_page] unless paginate_options[:per_page]
          paginate_options.each { |key, value| paginate_options[key] = value.to_i }
        end
        paginate_options
      end
  end

  # these are the class methods added when Tanker is included
  # They're kept to a minimum to prevent namespace pollution
  module ClassMethods

    attr_accessor :tanker_config

    def tankit(name = nil, options = {}, &block)
      if block_given?
        raise(NoIndexName, 'Please provide an index name') if name.nil? && self.tanker_config.nil?

        self.tanker_config ||= ModelConfig.new(name, options, Proc.new)
        name ||= self.tanker_config.index_name

        self.tanker_config.index_name = name

        config = ModelConfig.new(name, block)
        config.indexes.each do |key, value|
          self.tanker_config.indexes << [key, value]
        end

        unless config.variables.empty?
          self.tanker_config.variables do
            instance_exec &config.variables.first
          end
        end
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

    def tanker_parse_doc_id(result)
      result['docid'].split(' ').last
    end
  end

  class ModelConfig
    attr_accessor :index_name
    attr_accessor :options

    def initialize(index_name, options = {}, block)
      @index_name = index_name
      @options    = options
      @indexes    = []
      @variables  = []
      @functions  = {}
      instance_exec &block
    end

    def indexes(field = nil, &block)
      @indexes << [field, block] if field
      @indexes
    end

    def variables(&block)
      @variables << block if block
      @variables
    end

    def functions(&block)
      @functions = block.call if block
      @functions
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
      data[:__type] = type_name
      data[:__id] = self.id

      data
    end

    def tanker_index_options
      options = {}

      unless tanker_variables.empty?
        options[:variables] = tanker_variables.inject({}) do |hash, variables|
          hash.merge(instance_exec(&variables))
        end
      end

      options
    end

    # create a unique index based on the model name and unique id
    def it_doc_id
      type_name + ' ' + self.id.to_s
    end

    def type_name
      tanker_config.options[:as] || self.class.name
    end
  end
end
