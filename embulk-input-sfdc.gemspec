Gem::Specification.new do |spec|
  spec.name          = "embulk-input-sfdc"
  spec.version       = "0.0.0"
  spec.authors       = ["yoshihara", "uu59"]
  spec.summary       = "Salesforce.com input plugin for Embulk"
  spec.description   = "Loads sObjects using SOQL from Salesforce.com"
  spec.email         = ["h.yoshihara@everyleaf.com", "k@uu59.org"]

  spec.licenses      = ["Apache2"]
  spec.metadata      = {"source_url" => "https://github.com/treasure-data/embulk-input-sfdc_obsoleted"}

  spec.files         = `git ls-files`.split("\n") + Dir["classpath/*.jar"]
  spec.test_files    = spec.files.grep(%r{^(test|spec)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', ['~> 1.0']
  spec.add_development_dependency 'rake', ['>= 10.0']
  spec.add_development_dependency 'embulk', [">= 0.8.6", '< 1.0']
end
