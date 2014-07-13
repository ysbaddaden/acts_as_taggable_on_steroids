# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rails/test_help"

Rails.backtrace_cleaner.remove_silencers!

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }


class ActiveSupport::TestCase #:nodoc:
  include ActiveRecord::TestFixtures
  
  self.fixture_path = File.dirname(__FILE__) + "/fixtures/"
  
  self.use_transactional_fixtures = true  
  self.use_instantiated_fixtures  = false
  
  fixtures :all
  
  def assert_equivalent(expected, actual, message = nil)
    if expected.first.is_a?(ActiveRecord::Base)
      assert_equal expected.sort_by(&:id), actual.sort_by(&:id), message
    else
      assert_equal expected.sort, actual.sort, message
    end
  end
  
  def assert_tag_counts(tags, expected_values)
    # Map the tag fixture names to real tag names
    expected_values = expected_values.inject({}) do |hash, (tag, count)|
      hash[tags(tag).name] = count
      hash
    end
    
    tags.each do |tag|
      value = expected_values.delete(tag.name)
      
      assert_not_nil value, "Expected count for #{tag.name} was not provided"
      assert_equal value, tag.count, "Expected value of #{value} for #{tag.name}, but was #{tag.count}"
    end
    
    unless expected_values.empty?
      assert false, "The following tag counts were not present: #{expected_values.inspect}"
    end
  end
  
  def assert_queries(expected_count = 1)
    actual_count = ActiveRecord::Base.count_queries do
      yield
    end
  ensure
    assert_equal expected_count, actual_count, "Instead of the expected #{expected_count} queries, #{actual_count} actual queries were executed."
  end
  
  def assert_no_queries(&block)
    assert_queries(0, &block)
  end
  
end
