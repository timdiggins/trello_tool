# frozen_string_literal: true

require "psych"

module TrelloTool
  # wraps configuration of key features of Trello Tool and automatically pulls in
  # from a yml file in a specific location and can generate on demand
  module DefaultConfiguration
    FILE_NAME = "trello_tool.yml"
    DEFAULTS = {
      main_board_url: nil,
      archive_board_url: nil,
      next_version_list_name: "next version",
      todo_list_name: "TO DO",
      doing_list_name: "-- DOING --",
      initial_list_names: %w[Triage Reference],
      done_list_names: ["Done"],
      version_template: "v%s",
      month_template: "[%s]",
      too_many_doing: 2,
      too_many_todo: 10
    }.freeze
  end
  Configuration = Struct.new(*DefaultConfiguration::DEFAULTS.keys, keyword_init: true) do
    include DefaultConfiguration

    def initialize(root_dir = Dir.pwd)
      @root_dir = root_dir
      super(DefaultConfiguration::DEFAULTS)
      load_from_config_file if config_file_exists?
    end

    # generates a file based on current settings
    def generate
      File.open(config_file, "w") do |f|
        Psych.dump(to_h { |k, v| [k.to_s, v] }, f) # rubocop:disable Style/HashTransformKeys doesn't work
      end
    end

    def config_file_exists?
      File.exist?(config_file)
    end

    def config_file
      File.join(config_dir, DefaultConfiguration::FILE_NAME)
    end

    # an ordered array of expected list names before the version and month names
    def expected_list_names
      @expected_list_names ||= initial_list_names + [todo_list_name,
                                                     doing_list_name] + done_list_names + [next_version_list_name]
    end

    def month_list_names
      @month_list_names ||= Date::MONTHNAMES.compact.map(&method(:month_list_name))
    end

    def version_list_matcher
      @version_list_matcher ||= Regexp.new("\\A#{format(version_template, '\d+[.]\d+[.]\d+')}")
    end

    def month_list_name(name)
      month_template % name.upcase
    end

    protected

    def config_dir
      @config_dir ||= find_config_dir
    end

    def find_config_dir
      [
        File.join(@root_dir, "config"),
        @root_dir
      ].each do |target|
        return target if Dir.exist?(target)
      end
    end

    def load_from_config_file
      Psych.safe_load(File.read(config_file)).each do |key, value|
        send("#{key}=", value)
      end
      self.initial_list_names ||= []
    end
  end
end
