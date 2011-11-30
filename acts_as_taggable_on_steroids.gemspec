Gem::Specification.new do |s|
  s.name     = "bborn-acts_as_taggable_on_steroids"
  s.version  = "2.1"
  s.date     = "2011-11-30"
  s.summary  = "Rails 3 engine that is based on acts_as_taggable by jviney that is based on acts_as_taggable by DHH."
  s.email    = "ysbaddaden@gmail.com"
  s.homepage = "http://github.com/bborn/acts_as_taggable_on_steroids"
  s.description = "Rails plugin that is based on acts_as_taggable by jviney that is based on acts_as_taggable by DHH."
  s.has_rdoc = true
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.rubyforge_project = "acts_as_taggable_on_steroids"
  s.authors  = ["Jonathan Viney", "Julien Portalier", "Bruno Bornsztein"]

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]
    
  s.add_dependency "rails", "~> 3.1.2"
  s.add_development_dependency "sqlite3"
    
end
