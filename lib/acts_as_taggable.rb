module ActiveRecord #:nodoc:
  module Acts #:nodoc:
    module Taggable #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_taggable
          has_many :taggings, :as => :taggable, :dependent => :destroy, :include => :tag
          has_many :tags, :through => :taggings
          
          before_save :save_cached_tag_list
          after_save  :save_tags
          
          include ActiveRecord::Acts::Taggable::InstanceMethods
          extend ActiveRecord::Acts::Taggable::SingletonMethods
          
          alias_method_chain :reload, :tag_list
        end
        
        def cached_tag_list_column_name
          "cached_tag_list"
        end
        
        def set_cached_tag_list_column_name(value = nil, &block)
          define_attr_method :cached_tag_list_column_name, value, &block
        end
      end
      
      module SingletonMethods
        # Pass either a tag, string, or an array of strings or tags.
        # 
        # Options:
        # 
        # - +:match_any+ - match any of the given tags (default).
        # - +:match_all+ - match all of the given tags.
        # 
        def tagged_with(tags, options = {})
          records = select("DISTINCT #{quoted_table_name}.*")
          
          if options[:match_all]
            TagList.from(tags).each_with_index do |tag_name, index|
              records = records.joins_tags(:suffix => index, :tag_name => tag_name)
            end
          else
            records = records.joins(:tags).where(Tag.arel_table[:name].matches_any(*tags))
          end
        end
        
        # Matches records that have none of the given tags.
        def not_tagged_with(tags)
          tags = TagList.from(tags)
          joins(:tags).where(Tag.arel_table[:name].not_matches_all(*tags))
        end
        
        # Returns an array of related tags. Related tags are all the other tags
        # that are found on the models tagged with the provided tags.
        def related_tags(tags)
          tags = {}
          search_related_tags(tags).each { |tag| tags[tag.name] = tag.count_all }
          tags
        end
        
        # Counts the number of occurences of all tags.
        # See <tt>Tag.counts</tt> for options.
        def tag_counts(options = {})
          Tag.joins(:taggings).where("taggings.taggable_type" => model_name).counts(options)
#          tags.counts(options)
        end
        
        # Returns an array of related tags.
        # Related tags are all the other tags that are found on the models
        # tagged with the provided tags.
        # 
        # Pass either a tag, string, or an array of strings or tags.
        # 
        # Options:
        # 
        # - +:order+ - SQL Order how to order the tags. Defaults to "count_all DESC, tags.name".
        # 
        # DEPRECATED: use #related_tags instead.
        def find_related_tags(tags, options = {})
          tags = search_related_tags(tags)
          tags = tags.order(options[:order]) if (options[:order])
          tags
        end
        
        # Pass either a tag, string, or an array of strings or tags.
        # 
        # Options:
        #   :exclude - Find models that are not tagged with the given tags
        #   :match_all - Find models that match all of the given tags, not just one
        #   :conditions - A piece of SQL conditions to add to the query
        # 
        # DEPRECATED: use #tagged_with and #without_tags instead.
        def find_tagged_with(*args)
          options = args.extract_options!
          
          records = tagged_with(*args)
          records = records.without_tags(options[:exclude]) if options[:exclude]
          records = records.where(options[:conditions]) if options[:conditions]
          records
        end
        
        def caching_tag_list?
          column_names.include?(cached_tag_list_column_name)
        end
        
        protected
          def joins_tags(options = {}) # :nodoc:
            options[:suffix] = "_#{options[:suffix]}" if options[:suffix]
            
            taggings_alias = connection.quote_table_name(Tagging.table_name + options[:suffix].to_s)
            tags_alias = connection.quote_table_name(Tag.table_name + options[:suffix].to_s)
            
            taggings = "INNER JOIN #{Tagging.quoted_table_name} AS #{taggings_alias} " +
              "ON #{taggings_alias}.taggable_id = #{quoted_table_name}.#{primary_key} " +
              "AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)}"
            
            tags = "INNER JOIN #{Tag.quoted_table_name} AS #{tags_alias} " +
              "ON #{tags_alias}.id = #{taggings_alias}.tag_id "
            tags += "AND #{tags_alias}.name LIKE #{quote_value(options[:tag_name])}" if options[:tag_name]
            
            joins([taggings, tags])
          end
          
          def search_related_tags(tags)
            sub = select("#{quoted_table_name}.#{primary_key}").with_any_tags(tags)
            
            rq = joins(:tags)
            rq = rq.select("#{Tag.quoted_table_name}.*, COUNT(#{Tag.quoted_table_name}.id) AS count_all")
            rq = rq.where("#{quoted_table_name}.#{primary_key} IN (" + sub.to_sql + ")")
            rq = rq.without_tags(tags)
            rq = rq.group("#{Tag.quoted_table_name}.id")
            rq = rq.order("count_all DESC, #{Tag.quoted_table_name}.name")
          end
      end
      
      module InstanceMethods
        def tag_list
          return @tag_list if @tag_list
          
          if self.class.caching_tag_list? and !(cached_value = send(self.class.cached_tag_list_column_name)).nil?
            @tag_list = TagList.from(cached_value)
          else
            @tag_list = TagList.new(*tags.map(&:name))
          end
        end
        
        def tag_list=(value)
          @tag_list = TagList.from(value)
        end
        
        def save_cached_tag_list
          if self.class.caching_tag_list?
            self[self.class.cached_tag_list_column_name] = tag_list.to_s
          end
        end
        
        def save_tags
          return unless @tag_list
          
          new_tag_names = @tag_list - tags.map(&:name)
          old_tags = tags.reject { |tag| @tag_list.include?(tag.name) }
          
          self.class.transaction do
            if old_tags.any?
              taggings.where(:tag_id => old_tags.map(&:id)).each(&:destroy)
              taggings.reset
            end
            
            new_tag_names.each do |new_tag_name|
              tags << Tag.find_or_create_with_like_by_name(new_tag_name)
            end
          end
          
          true
        end
        
        # Calculate the tag counts for the tags used by this model.
        # See <tt>Tag.counts</tt> for available options.
        def tag_counts(options = {})
          return [] if tag_list.blank?
          self.class.tagged_with(tag_list).tag_counts(options)
        end
        
        def reload_with_tag_list(*args) #:nodoc:
          @tag_list = nil
          reload_without_tag_list(*args)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Taggable)

