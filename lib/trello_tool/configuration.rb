# frozen_string_literal: true

require "ostruct"
# require "yaml"
require "psych"
module TrelloTool
  class Configuration < OpenStruct
    FILE_NAME = "trello_tool.yml"
    def initialize(root_dir = Dir.pwd)
      @root_dir = root_dir
      super(defaults)
      if config_file_exists?
        Psych.safe_load(File.read(config_file)).each do |key, value|
          send("#{key}=", value)
        end
      end
    end

    def defaults
      {
        main_board_url: nil,
        archive_board_url: nil,
        next_version_list_name: "next version",
        todo_list_name: "TO DO",
        doing_list_name: "-- DOING --",
        initial_list_names: ["Triage", "Reference"],
        done_list__names: ["Done"],
        version_template: "v%s",
        month_template: "[%s]",
        too_many_doing: 2,
        too_many_todo: 10
      }
    end

    # generates a file based on current settings
    def generate
      File.open(config_file, "w") do |f|
        Psych.dump(to_h{|k, v| [k.to_s, v]}, f)
      end
    end

    def config_file_exists?
      File.exist?(config_file)
    end

    def config_file
      File.join(config_dir, FILE_NAME)
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
  end
end
