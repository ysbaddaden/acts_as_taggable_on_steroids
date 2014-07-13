require 'rails/all'

module ActsAsTaggable
  class Engine < Rails::Engine

    initializer 'acts_as_taggable' do |app|

      ActiveSupport.on_load(:active_record) do
        require File.join(File.dirname(__FILE__), 'active_record_extension')
        ::ActiveRecord::Base.send :include, ActsAsTaggable::ActiveRecordExtension
      end
      
    end

  end
end