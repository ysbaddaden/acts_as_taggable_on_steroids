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
      where("LOWER(name) = ?", name.downcase).first || create(:name => name)
    end

    # Calculate the tag counts for all tags.
    # 
    # - +:start_at+ - restrict the tags to those created after a certain time
    # - +:end_at+   - restrict the tags to those created before a certain time
    # - +:at_least+ - exclude tags with a frequency less than the given value
    # - +:at_most+  - exclude tags with a frequency greater than the given value
    # 
    def counts(options = {})
      options.assert_valid_keys :start_at, :end_at, :at_least, :at_most
      
      rq = joins(:taggings).group(:name)
      
      rq = rq.having('count_all >= ?', options[:at_least]) if options[:at_least]
      rq = rq.having('count_all <= ?', options[:at_most])  if options[:at_most]
      
      rq = rq.where("#{quoted_table_name}.created_at >= ?", options[:start_at]) if options[:start_at]
      rq = rq.where("#{quoted_table_name}.created_at <= ?", options[:end_at])   if options[:end_at]
      
      tags = {}
      rq.count.each { |tag_name, count| tags[tag_name] = count }
      
      tags
    end
  end
end
