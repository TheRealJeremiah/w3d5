require 'byebug'
require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    col_info_hashes = DBConnection.execute <<-SQL
      PRAGMA table_info(#{self.table_name});
    SQL

    cols = col_info_hashes.map do |hash|
      hash['name'].to_sym
    end

    create_get_set(cols) unless cols.nil?
    cols
  end

  def self.finalize!
    columns
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || name.to_s.tableize
  end

  def self.all
    cat_rows = DBConnection.execute <<-SQL
      SELECT
        *
      FROM
        #{table_name};
    SQL

    cat_rows.map { |row| self.new(row) }
  end

  def self.parse_all(results)
    results.map { |result| new(result) }
  end

  def self.find(id)
    results = DBConnection.execute <<-SQL
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = #{id};
    SQL
    #debugger
    return nil if results.empty?
    new(results.first)
  end

  def initialize(params = {})
    @attributes ||= {}
    params.each do |col, val|
      if self.respond_to?(col)
        @attributes[col.to_sym] = val
      else
        raise "unknown attribute '#{col}'"
      end
    end
  end

  def attributes
    @attributes
  end

  def attribute_values
    @attributes.values
  end

  def insert
    keys = []
    vals = []
    @attributes.each do |key, val|
      keys << key
      if val.is_a? Fixnum
        vals << val
      else
        vals << "'" + val.to_s + "'"
      end
    end
    cols = '(' + keys.map(&:to_s).join(', ') + ')'
    col_vals = '(' + vals.join(', ') + ')'

    DBConnection.execute <<-SQL
      INSERT INTO #{self.class.table_name} #{cols}
      VALUES #{col_vals};
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    keys = []
    vals = []
    @attributes.each do |key, val|
      keys << key
      if val.is_a? Fixnum
        vals << val
      else
        vals << "'" + val.to_s + "'"
      end
    end

    sets = keys.zip(vals).map { |pair| pair.join('=') }.join(', ')
    DBConnection.execute <<-SQL
      UPDATE #{self.class.table_name}
      SET #{sets}
      WHERE id = #{@attributes[:id]};
    SQL
  end

  def save
    if @attributes[:id].nil?
      insert
    else
      update
    end
  end

  def self.create_get_set(names)
    names.each do |name|
      define_method(name) do
        @attributes ||= {}
        @attributes[name]
      end

      define_method("#{name}=") do |val|
        @attributes ||= {}
        @attributes[name] = val
      end
    end
    nil
  end
end
