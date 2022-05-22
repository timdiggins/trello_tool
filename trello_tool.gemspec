# frozen_string_literal: true

require_relative "lib/trello_tool/version"

Gem::Specification.new do |spec|
  spec.name = "trello_tool"
  spec.version = TrelloTool::VERSION
  spec.authors = ["Tim Diggins"]
  spec.email = ["tim@red56.uk"]

  spec.summary = "Tool for doing basic things to a dev trello using the api."
  spec.homepage = "https://github.com/timdiggins/trello_tool"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/timdiggins/trello_tool/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "ruby-trello", "~> 3.1"
  spec.add_dependency "thor"
  spec.add_development_dependency "rubocop", "= 1.27.0"
  spec.metadata["rubygems_mfa_required"] = "true"
end
