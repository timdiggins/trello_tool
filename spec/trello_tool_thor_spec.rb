# frozen_string_literal: true

require "spec_helper"
require "thor"
require "fileutils"
require "json"

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

  describe "#card" do
    let(:client) { instance_double(TrelloTool::TrelloClient) }
    let(:checklists) do
      [instance_double(Trello::Checklist, name: "Steps",
                                          check_items: [{ "name" => "step one", "state" => "complete" },
                                                        { "name" => "step two", "state" => "incomplete" }])]
    end
    let(:attachments) do
      [instance_double(Trello::Attachment, url: "https://example.com/doc.pdf")]
    end
    let(:card) do
      instance_double(Trello::Card, name: "A card", desc: "Some description",
                                    url: "https://trello.com/c/aBcD1234/1-a-card",
                                    checklists: checklists, attachments: attachments)
    end

    before do
      allow(subject).to receive(:client).and_return(client)
      allow(client).to receive(:find_card).with("aBcD1234").and_return(card)
    end

    def output_of_card(card_id)
      output = StringIO.new
      $stdout = output
      subject.card(card_id)
      output.string
    ensure
      $stdout = STDOUT
    end

    it "outputs json with title, description and url" do
      expect(JSON.parse(output_of_card("aBcD1234"))).to include(
        "title" => "A card",
        "description" => "Some description",
        "url" => "https://trello.com/c/aBcD1234/1-a-card"
      )
    end

    it "outputs checklists with item completion state" do
      expect(JSON.parse(output_of_card("aBcD1234"))["checklists"]).to eq(
        [{ "name" => "Steps",
           "items" => [{ "name" => "step one", "complete" => true },
                       { "name" => "step two", "complete" => false }] }]
      )
    end

    it "outputs attachment urls" do
      expect(JSON.parse(output_of_card("aBcD1234"))["attachment_urls"]).to eq(["https://example.com/doc.pdf"])
    end

    it "accepts a card url instead of an id" do
      expect(JSON.parse(output_of_card("https://trello.com/c/aBcD1234/1-a-card"))).to include("title" => "A card")
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
