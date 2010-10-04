require "rubygems"
require "bundler"
require 'indextank_client'

require 'tanker/configuration'
require 'will_paginate/collection'

Bundler.setup :default

module Tanker

  class NotConfigured < StandardError; end
  class NoBlockGiven < StandardError; end

  autoload :Configuration, 'tanker/configuration'

  extend Configuration

  class << self
    def included(klass)
      klass.instance_variable_set('@tanker_configuration', configuration)
      klass.instance_variable_set('@tanker_indexes', [])
      klass.send :include, InstanceMethods
      klass.extend ClassMethods

      class << klass
        define_method(:per_page) { 10 } unless respond_to?(:per_page)
      end

    end
  end

  # these are the class methods added when Tanker is included
  module ClassMethods

    attr_reader :tanker_indexes, :index_name

    def tankit(name, &block)
      if block_given?
        @index_name = name
        self.instance_exec(&block)
      else
        raise(NoBlockGiven, 'Please provide a block')
      end
    end

    def indexes(field)
      @tanker_indexes << field
    end

    def api
      @api ||= IndexTank::ApiClient.new(Tanker.configuration[:url])
    end

    def index
      @index ||= api.get_index(self.index_name)
    end

    def search_tank(query, options = {})
      page     = options.delete(:page) || 1
      per_page = options.delete(:per_page) || self.per_page

      # transform fields in query
      if options.has_key? :conditions
        options[:conditions].each do |field,value|
          query += " #{field}:(#{value})"
        end
      end

      query = "__any:(#{query.to_s}) __type:#{self.name}"
      options = { :start => page - 1, :len => per_page }.merge(options)

      results = index.search(query, options)

      unless results[:results].empty?
        ids = results[:results].map{|res| res[:docid].split(" ", 2)}
      else
        return nil
      end


      @entries = WillPaginate::Collection.create(page, per_page) do |pager|
        result = self.find(ids)
        # inject the result array into the paginated collection:
        pager.replace(result)

        unless pager.total_entries
          # the pager didn't manage to guess the total count, do it manually
          pager.total_entries = results[:matches]
        end
      end
    end

  end

  # these are the instace methods included que
  module InstanceMethods

    def tanker_indexes
      self.class.tanker_indexes
    end

    def update_tank_indexes
      data = {}

      tanker_indexes.each do |field|
        val = self.instance_eval(field.to_s)
        data[field.to_s] = val.to_s unless val.nil?
      end

      data[:__any] = data.values.join " . "
      data[:__type] = self.class.name

      self.class.index.add_document(it_doc_id, data)
    end

    def delete_tank_indexes
      self.class.index.delete_document(it_doc_id)
    end

    def it_doc_id
      self.class.name + ' ' + self.id.to_s
    end

  end
end
