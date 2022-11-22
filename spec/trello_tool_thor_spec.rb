# frozen_string_literal: true

require "spec_helper"
require "thor"
require "fileutils"

RSpec.describe "TrelloToolThor" do
  around do |example|
    @target_dir = ensure_tmp_dir
    FileUtils.cp_r(fixture_path("root_dir_partial/."), @target_dir)
    Dir.chdir(@target_dir) do
      load File.expand_path("../lib/trello_tool_thor.rb", __dir__)
      example.run
    end
  end

  subject { TrelloToolThor.new }

  describe "#extract_id_from_url" do
    it "works" do
      expect(subject.send(:extract_id_from_url, "https://trello.com/b/dqz4FA0K/fnc-focus")).to eq("dqz4FA0K")
    end
    it "raises" do
      expect do
        subject.send(:extract_id_from_url, "https://wherever.com/any-old-rubbish")
      end.to raise_error(/any-old-rubbish/)
    end
  end

  describe "#config" do
    let(:config_filepath) { File.join(@target_dir, TrelloTool::DefaultConfiguration::FILE_NAME) }
    context "with no config file" do
      before do
        File.unlink(config_filepath)
      end
      it "outputs file" do
        expect { subject.config }.to change { File.exist?(config_filepath) }.from(be_falsey)
      end
      it "mentions" do
        expect { subject.config }.to output(/Generated/).to_stdout
      end
    end
    context "with config file" do
      before do
        FileUtils.copy_file(fixture_path("root_dir_bad", "trello_tool.yml"), config_filepath)
      end
      it "doesn't output file" do
        expect { subject.config }.not_to change { TrelloTool::Configuration.new(@target_dir).to_h }
      end

      it "doesn't mention" do
        expect { subject.config }.not_to output(/Generated/).to_stdout
      end
      it "mentions fields needing configuration" do
        expect { subject.config }.not_to output(/main_board_url.*archive_board_url/).to_stdout
      end
    end
  end
end
