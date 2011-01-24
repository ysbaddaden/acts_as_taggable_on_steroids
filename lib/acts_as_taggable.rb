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
        # - +:match_any+ - match any of the given tags (default).
        # - +:match_all+ - match all of the given tags.
        # 
        def tagged_with(tags, options = {})
          tags = tags.is_a?(Array) ? TagList.new(tags.map(&:to_s)) : TagList.from(tags)
          return [] if tags.empty?
          
          records = select("DISTINCT #{quoted_table_name}.*")
          
          if options[:match_all]
            records.search_all_tags(tags)
          else
            records.search_any_tags(tags)
          end
        end
        
        # Matches records that have none of the given tags.
        def not_tagged_with(tags)
          tags = tags.is_a?(Array) ? TagList.new(tags.map(&:to_s)) : TagList.from(tags)
          
          sub = Tagging.select("#{Tagging.table_name}.taggable_id").joins(:tag).
            where(:taggable_type => base_class.name, "#{Tag.table_name}.name" => tags)
          
          where("#{quoted_table_name}.#{primary_key} NOT IN (" + sub.to_sql + ")")
        end
        
        # Returns an array of related tags. Related tags are all the other tags
        # that are found on the models tagged with the provided tags.
        def related_tags(tags)
          search_related_tags(tags)
        end
        
        # Counts the number of occurences of all tags.
        # See <tt>Tag.counts</tt> for options.
        def tag_counts(options = {})
          tags = Tag.joins(:taggings).
            where("#{Tagging.table_name}.taggable_type" => base_class.name)
          
          if options[:tags]
            tags = tags.where("#{Tag.table_name}.name" => options.delete(:tags))
          end
          
          unless descends_from_active_record?
            tags = tags.joins("INNER JOIN #{quoted_table_name} ON " +
              "#{quoted_table_name}.#{primary_key} = #{Tagging.quoted_table_name}.taggable_id")
            tags = tags.where(type_condition)
          end
          
          if scoped != unscoped
            sub  = scoped.except(:select).select("#{quoted_table_name}.#{primary_key}")
            tags = tags.where("#{Tagging.quoted_table_name}.taggable_id IN (#{sub.to_sql})")
          end
          
          tags.counts(options)
        end
        
        # Returns an array of related tags.
        # Related tags are all the other tags that are found on the models
        # tagged with the provided tags.
        # 
        # Pass either a tag, string, or an array of strings or tags.
        # 
        # Options:
        # - +:order+ - SQL Order how to order the tags. Defaults to "count_all DESC, tags.name".
        # - +:include+
        # 
        # DEPRECATED: use #related_tags instead.
        def find_related_tags(tags, options = {})
          rs = related_tags(tags).order(options[:order] || "count DESC, #{Tag.quoted_table_name}.name")
          rs = rs.includes(options[:include]) if options[:include]
          rs
        end
        
        # Pass either a tag, string, or an array of strings or tags.
        # 
        # Options:
        # - +:exclude+    - Find models that are not tagged with the given tags
        # - +:match_all+  - Find models that match all of the given tags, not just one
        # - +:conditions+ - A piece of SQL conditions to add to the query
        # - +:include+
        # 
        # DEPRECATED: use #tagged_with and #not_tagged_with instead.
        def find_tagged_with(*args)
          options = args.extract_options!
          tags = args.first
          
          records = self
          records = records.where(options[:conditions]) if options[:conditions]
          records = records.includes(options[:include]) if options[:include]
          records = records.order(options[:order])      if options[:order]
          
          if options[:exclude]
            records.not_tagged_with(tags)
          else
            records.tagged_with(tags, options)
          end
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
          
          def search_all_tags(tags)
            records = self
            
            tags.dup.each_with_index do |tag_name, index|
              records = records.joins_tags(:suffix => index, :tag_name => tag_name)
            end
            
            records
          end
          
          def search_any_tags(tags)
            joins(:tags).where(Tag.arel_table[:name].matches_any(tags.dup))
          end
          
          def search_related_tags(tags)
            tags = tags.is_a?(Array) ? TagList.new(tags.map(&:to_s)) : TagList.from(tags)
            sub = select("#{quoted_table_name}.#{primary_key}").search_any_tags(tags)
            _tags = tags.map { |tag| tag.downcase }
            
            Tag.select("#{Tag.quoted_table_name}.*, COUNT(#{Tag.quoted_table_name}.id) AS count").
              joins(:taggings).
              where("#{Tagging.table_name}.taggable_type" => base_class.name).
              where("#{Tagging.quoted_table_name}.taggable_id IN (" + sub.to_sql + ")").
              group("#{Tag.quoted_table_name}.name").
              having(Tag.arel_table[:name].does_not_match_all(_tags))
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
          self.class.tag_counts(options.merge(:tags => tag_list))
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

