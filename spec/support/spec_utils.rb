# frozen_string_literal: true

module SpecUtils
  # returns full file path to a tmp dir, ensuring it is empty and exists
  def ensure_tmp_dir(dir_name = "target")
    target = File.join(File.expand_path("../../tmp", __dir__), dir_name)
    FileUtils.rm_r(target, force: true) if Dir.exist?(target)
    FileUtils.makedirs(target)
    target
  end

  def fixture_path(*dir_names)
    File.join(File.expand_path("../fixtures", __dir__), *dir_names)
    # raise "Doesn't exist: #{target}" unless Dir.exist?(target)
  end
end

RSpec.configure do |config|
  config.include(SpecUtils)
end
