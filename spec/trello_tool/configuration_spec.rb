# frozen_string_literal: true

require "fileutils"
require File.expand_path("../../lib/trello_tool/configuration.rb", __dir__)

RSpec.describe TrelloTool::Configuration do
  let(:defaults) do
    {
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
    }
  end
  let(:configured) do
    {
      main_board_url: "somewhere-over-the-rainbow",
      archive_board_url: "unconfigured",
      next_version_list_name: "Prochaine version",
      todo_list_name: "A faire",
      doing_list_name: "En cours",
      initial_list_names: [],
      done_list_names: ["Accomplis"],
      version_template: "v-%s",
      month_template: "[ %s ]",
      too_many_doing: 10,
      too_many_todo: 14
    }
  end

  it "can generate an empty configuration" do
    config = TrelloTool::Configuration.new
    defaults.each do |k, v|
      expect(config.send(k)).to eq(v), "#{k}: expected #{v.inspect}, but got #{config.send(k)}"
    end
    expect(config.to_h).to include(**defaults)
    expect(config.to_h.keys).to contain_exactly(*defaults.keys)
  end

  it "can read from a config folder when it exists" do
    config = TrelloTool::Configuration.new(fixture_path("config_dir_bad"))
    expect(config.to_h).to include(configured)
  end
  it "can read from a root folder" do
    config = TrelloTool::Configuration.new(fixture_path("root_dir_bad"))
    expect(config.to_h).to include(configured)
  end
  it "can read a partial and it should be filled in with defaults" do
    full = TrelloTool::Configuration.new(fixture_path("root_dir_good"))
    partial = TrelloTool::Configuration.new(fixture_path("root_dir_partial"))
    expect(full.to_h.keys).to contain_exactly(*partial.to_h.keys)
    expect(full.to_h.sort).to eq(partial.to_h.sort)
  end

  it "can output to a standard folder" do
    dir = ensure_tmp_dir
    config = TrelloTool::Configuration.new(dir)
    expect { config.generate }.to change {
                                    File.exist?(File.join(dir, "trello_tool.yml"))
                                  }.from(be_falsey).to(be_truthy)
  end
end
