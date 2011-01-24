require 'active_support/core_ext/module/deprecation'

class Tag < ActiveRecord::Base
  cattr_accessor :destroy_unused
  self.destroy_unused = false

  has_many :taggings, :dependent => :delete_all

  validates_presence_of :name
  validates_uniqueness_of :name

  def ==(object)
    super || (object.is_a?(Tag) && name == object.name)
  end
  
  def to_s
    name
  end
  
  def count
    read_attribute(:count).to_i
  end
  
  class << self
    def find_or_create_with_like_by_name(name)
      where(arel_table[:name].matches(name)).first || create(:name => name)
    end

    # Calculate the tag counts for all tags.
    # 
    # - +:start_at+ - restrict the tags to those created after a certain time
    # - +:end_at+   - restrict the tags to those created before a certain time
    # - +:at_least+ - exclude tags with a frequency less than the given value
    # - +:at_most+  - exclude tags with a frequency greater than the given value
    # 
    # Deprecated:
    # 
    # - +:conditions+
    # - +:limit+
    # - +:order+
    # 
    def counts(options = {})
      options.assert_valid_keys :start_at, :end_at, :at_least, :at_most, :conditions, :limit, :order
      
      tags = joins(:taggings).group(:name)
      tags = tags.having(['count >= ?', options[:at_least]]) if options[:at_least]
      tags = tags.having(['count <= ?', options[:at_most]])  if options[:at_most]
      tags = tags.where("#{Tagging.quoted_table_name}.created_at >= ?", options[:start_at]) if options[:start_at]
      tags = tags.where("#{Tagging.quoted_table_name}.created_at <= ?", options[:end_at])   if options[:end_at]
      
      # TODO: deprecation warning
      tags = tags.where(options[:conditions]) if options[:conditions]
      tags = tags.limit(options[:limit])      if options[:limit]
      tags = tags.order(options[:order])      if options[:order]
      
      tags.select("#{quoted_table_name}.*, COUNT(#{quoted_table_name}.id) AS count")
    end
  end
end
