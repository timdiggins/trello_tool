# frozen_string_literal: true

require "trello_tool"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

module SpecUtils
  # returns full file path to a tmp dir, ensuring it is empty and exists
  def ensure_tmp_dir(dir_name = "target")
    target = File.join(File.expand_path("../tmp", __dir__), dir_name)
    FileUtils.rm_r(target, force: true) if Dir.exist?(target)
    FileUtils.makedirs(target)
    target
  end

  def fixture_path(*dir_names)
    target = File.join(File.expand_path("./fixtures", __dir__), *dir_names)
    # raise "Doesn't exist: #{target}" unless Dir.exist?(target)
    target
  end
end

RSpec.configure do |config|
  config.include(SpecUtils)
end
