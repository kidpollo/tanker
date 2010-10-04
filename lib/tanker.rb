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

  end

  # these are the instace methods included que
  module InstanceMethods

    def tanker_indexes
      self.class.tanker_indexes
    end

    def api
      @api ||= IndexTank::ApiClient.new(Tanker.configuration[:url])
    end

    def index
      @index ||= api.get_index(self.class.index_name)
    end

    def search_tank(query, page = 1, per_page = self.class.per_page)

      results = index.search(query, :start => page, :len => per_page )
      ids = results[:results].map{|res| res[:docid]}

      @entries = WillPaginate::Collection.create(page, per_page) do |pager|
        result = self.class.find(ids)
        # inject the result array into the paginated collection:
        pager.replace(result)

        unless pager.total_entries
          # the pager didn't manage to guess the total count, do it manually
          pager.total_entries = results[:matches]
        end
      end
    end

    def update_tank_indexes
      hash = {}
      tanker_indexes.each do |idx|
        hash[idx] = self.send(idx.to_s)
      end
      index.add_document(id, hash)
    end

    def delete_tank_indexes
      index.delete_document(id)
    end

  end
end
