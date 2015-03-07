require_relative '02_searchable'
require 'active_support/inflector'

# Phase IIIa
class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    class_name.constantize
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    self.foreign_key = "#{name}_id".to_sym
    if options.key?(:foreign_key)
      self.foreign_key = options[:foreign_key]
    end

    self.class_name = "#{name}".camelcase
    if options.key?(:class_name)
      self.class_name = options[:class_name]
    end

    self.primary_key = :id
    if options.key?(:primary_key)
      self.primary_key = options[:primary_key]
    end
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    self.class_name = "#{name}".singularize.camelcase
    if options.key?(:class_name)
      self.class_name = options[:class_name]
    end

    self.foreign_key = "#{self_class_name.underscore}_id".to_sym
    if options.key?(:foreign_key)
      self.foreign_key = options[:foreign_key]
    end

    self.primary_key = :id
    if options.key?(:primary_key)
      self.primary_key = options[:primary_key]
    end
  end
end

module Associatable
  # Phase IIIb
  def belongs_to(name, options = {})
    define_method(name) do
      names = BelongsToOptions.new(name, options)
      f_key_val = self.send(names.foreign_key)
      table = names.table_name
      results = DBConnection.execute(<<-SQL, f_key_val)
        SELECT
          *
        FROM
          #{table}
        WHERE
          #{names.primary_key} = ?
      SQL
      return nil if results.empty?
      names.model_class.parse_all(results).first
    end
  end

  def has_many(name, options = {})
    define_method(name) do
      names = HasManyOptions.new(name, self.class.to_s, options)
      p_key_val = self.send(names.primary_key)
      table = names.table_name
      results = DBConnection.execute(<<-SQL, p_key_val)
        SELECT
          *
        FROM
          #{table}
        WHERE
          #{names.foreign_key} = ?
      SQL
      return [] if results.empty?
      names.model_class.parse_all(results)
    end
  end

  def assoc_options
    # Wait to implement this in Phase IVa. Modify `belongs_to`, too.
  end
end

class SQLObject
  extend Associatable
end
