Gem::Specification.new do |s|
  s.name     = "bborn-acts_as_taggable_on_steroids"
  s.version  = "2.0.beta3"
  s.date     = "2011-02-07"
  s.summary  = "Rails 3 plugin that is based on acts_as_taggable by jviney that is based on acts_as_taggable by DHH."
  s.email    = "ysbaddaden@gmail.com"
  s.homepage = "http://github.com/ysbaddaden/acts_as_taggable_on_steroids"
  s.description = "Rails plugin that is based on acts_as_taggable by jviney that is based on acts_as_taggable by DHH."
  s.has_rdoc = true
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.rubyforge_project = "acts_as_taggable_on_steroids"
  s.authors  = ["Jonathan Viney", "Julien Portalier"]
  s.files    = [
    "acts_as_taggable_on_steroids.gemspec",
    "CHANGELOG",
    "init.rb",
    "lib/acts_as_taggable.rb",
    "lib/generators/acts_as_taggable_migration",
    "lib/generators/acts_as_taggable_migration/acts_as_taggable_migration_generator.rb",
    "lib/generators/acts_as_taggable_migration/templates",
    "lib/generators/acts_as_taggable_migration/templates/migration.rb",
    "lib/tag.rb",
    "lib/tag_list.rb",
    "lib/tagging.rb",
    "lib/tags_helper.rb",
    "MIT-LICENSE",
    "Rakefile",
    "README",
    ]
  s.test_files = [  
    "test/abstract_unit.rb",
    "test/acts_as_taggable_test.rb",
    "test/database.yml",
    "test/fixtures",
    "test/fixtures/magazine.rb",
    "test/fixtures/magazines.yml",
    "test/fixtures/photo.rb",
    "test/fixtures/photos.yml",
    "test/fixtures/post.rb",
    "test/fixtures/posts.yml",
    "test/fixtures/special_post.rb",
    "test/fixtures/subscription.rb",
    "test/fixtures/subscriptions.yml",
    "test/fixtures/taggings.yml",
    "test/fixtures/tags.yml",
    "test/fixtures/user.rb",
    "test/fixtures/users.yml",
    "test/schema.rb",
    "test/tag_list_test.rb",
    "test/tag_test.rb",
    "test/tagging_test.rb",
    "test/tags_helper_test.rb"
    ]
end
