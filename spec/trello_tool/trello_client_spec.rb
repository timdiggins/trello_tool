# frozen_string_literal: true

require File.expand_path("../../lib/trello_tool/trello_client.rb", __dir__)
require File.expand_path("../../lib/trello_tool/configuration.rb", __dir__)

RSpec.describe TrelloTool::TrelloClient do
  let(:configuration) { TrelloTool::Configuration.new(File.expand_path("../../fixtures/root_dir_good")) }
  describe "#archiveable_list_names_with_index" do
    let(:trello_client) { TrelloTool::TrelloClient.new(configuration) }
    let(:main_board) { instance_double(Trello::Board, lists: lists) }
    before do
      allow(trello_client).to receive(:main_board).and_return(main_board)
    end
    context "with only non archiveable lists" do
      let(:lists) { [instance_double(Trello::List, name: "flong 1"), instance_double(Trello::List, name: "flong 2")] }

      it "returns empty" do
        expect(trello_client.archiveable_list_names_with_index).to eq([])
      end
    end
    context "with only version lists" do
      let(:lists) { [instance_double(Trello::List, name: "v1.1.1"), instance_double(Trello::List, name: "v2.2.2")] }
      it "returns all" do
        expect(trello_client.archiveable_list_names_with_index).to eq([["v2.2.2", 1], ["v1.1.1", 0]])
      end
    end
    context "with divider then version lists" do
      let(:lists) do
        [instance_double(Trello::List, name: "[whatever]"), instance_double(Trello::List, name: "v1.1.1"),
         instance_double(Trello::List, name: "v2.2.2")]
      end
      it "returns version lists" do
        expect(trello_client.archiveable_list_names_with_index).to eq([["v2.2.2", 2], ["v1.1.1", 1]])
      end
    end
    context "with divider then version then divider" do
      let(:lists) do
        [instance_double(Trello::List, name: "[whatever]"), instance_double(Trello::List, name: "v1.1.1"),
         instance_double(Trello::List, name: "[other]")]
      end
      it "returns divider and version" do
        expect(trello_client.archiveable_list_names_with_index).to eq([["[other]", 2], ["v1.1.1", 1]])
      end
    end
  end
end
