
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

      klass.instance_variable_set('@tanker_configuration', configuration)
      klass.instance_variable_set('@tanker_indexes', [])
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
      records.first.class.index.add_documents(data)
    end
  end

  # these are the class methods added when Tanker is included
  module ClassMethods

    attr_reader :tanker_indexes, :tanker_variables, :index_name

    def tankit(name, &block)
      if block_given?
        @index_name = name
        self.instance_exec(&block)
      else
        raise(NoBlockGiven, 'Please provide a block')
      end
    end

    def indexes(field, &block)
      @tanker_indexes << [field, block].flatten
    end

    def index_variables(&block)
      @tanker_variables = block
    end

    def index
      @index ||= Tanker.api.get_index(self.index_name)
    end

    def search_tank(query, options = {})
      ids      = []
      page     = (options.delete(:page) || 1).to_i
      per_page = (options.delete(:per_page) || self.per_page).to_i

      # transform fields in query
      if conditions = options.delete(:conditions)
        conditions.each do |field,value|
          if value.is_a?(Array)
            value.each do |item|
              query += " #{field}:(#{item})"
            end
          else
            query += " #{field}:(#{value})"
          end
        end
      end

      query = "__any:(#{query.to_s}) __type:#{self.name}"
      options = { :start => per_page * (page - 1), :len => per_page }.merge(options)
      results = index.search(query, options)

      ids = unless results["results"].empty?
        results["results"].map{ |res| res["docid"].split(" ", 2)[1].to_i }
      else
        []
      end

      @entries = WillPaginate::Collection.create(page, per_page) do |pager|
        result = self.find(ids)
        # inject the result array into the paginated collection:
        pager.replace(result)

        unless pager.total_entries
          # the pager didn't manage to guess the total count, do it manually
          pager.total_entries = results["matches"]
        end
      end
    end
  end

  # these are the instance methods included
  module InstanceMethods

    def tanker_indexes
      self.class.tanker_indexes
    end

    def tanker_variables
      self.class.tanker_variables
    end

    # update a create instance from index tank
    def update_tank_indexes
      self.class.index.add_document(
        it_doc_id, tanker_index_data, tanker_index_options
      )
    end

    # delete instance from index tank
    def delete_tank_indexes
      self.class.index.delete_document(it_doc_id)
    end

    def tanker_index_data
      data = {}

      # attempt to autodetect timestamp
      if respond_to?(:created_at)
        data[:timestamp] = created_at.to_i
      end

      tanker_indexes.each do |field, block|
        val = block ? block.call(self) : self.instance_eval(field.to_s)
        val = val.join(' ') if Array === val
        data[field.to_s] = val.to_s unless val.nil?
      end

      if tanker_variables
        options[:variables] = tanker_variables.call(self)
      end

      data[:__any] = data.values.join " . "
      data[:__type] = self.class.name

      data
    end

    def tanker_index_options
      options = {}

      if tanker_variables
        options[:variables] = tanker_variables.call(self)
      end

      options
    end

    # create a unique index based on the model name and unique id
    def it_doc_id
      self.class.name + ' ' + self.id.to_s
    end
  end
end
