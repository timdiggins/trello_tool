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

  describe "cards" do
    let(:trello_client) { TrelloTool::TrelloClient.new(configuration) }
    let(:board) { instance_double(Trello::Board, id: "b1") }
    let(:list) { instance_double(Trello::List, id: "l1") }
    let(:card) { instance_double(Trello::Card, id: "c1") }

    # what Trello::Client#get / #post return: a response, whose body is the json
    def response(data)
      Trello::Response.new(200, {}, JSON.generate(data))
    end

    it "searches the board's cards, leaving out archived ones" do
      expect(trello_client.client).to receive(:get)
        .with("/search", hash_including("query" => "snitch is:open", "idBoards" => "b1", "modelTypes" => "cards", "cards_limit" => "50"))
        .and_return(response("cards" => [{ "name" => "open", "closed" => false }, { "name" => "archived", "closed" => true }]))
      expect(trello_client.search_cards(board, "snitch is:open")).to eq([{ "name" => "open", "closed" => false }])
    end

    it "lists the board's visible cards in one request" do
      expect(trello_client.client).to receive(:get).with("/boards/b1/cards/visible", "fields" => "name,url,idList,labels,closed")
                                                   .and_return(response([{ "name" => "a card" }]))
      expect(trello_client.open_cards(board)).to eq([{ "name" => "a card" }])
    end

    it "creates a card at the bottom of a list, or the top, with labels" do
      expect(trello_client.client).to receive(:post).with("/cards", { name: "A card", desc: "", idList: "l1", pos: "bottom" })
                                                    .and_return(response("id" => "c1", "url" => "https://trello.com/c/x"))
      expect(trello_client.create_card(list, title: "A card")).to eq("id" => "c1", "url" => "https://trello.com/c/x")

      expect(trello_client.client).to receive(:post)
        .with("/cards", { name: "A card", desc: "why", idList: "l1", pos: "top", idLabels: "lab1,lab2" }).and_return(response({}))
      trello_client.create_card(list, title: "A card", description: "why", top: true, label_ids: %w[lab1 lab2])
    end

    it "sets a check item's state" do
      expect(trello_client.client).to receive(:put).with("/cards/c1/checkItem/i1", { state: "complete" })
      trello_client.set_check_item_state(card, { "id" => "i1" }, complete: true)
      expect(trello_client.client).to receive(:put).with("/cards/c1/checkItem/i1", { state: "incomplete" })
      trello_client.set_check_item_state(card, { "id" => "i1" }, complete: false)
    end

    it "moves a card to a list and position, or just repositions it" do
      expect(trello_client.client).to receive(:put).with("/cards/c1", { pos: "top", idList: "l1" })
      trello_client.move_card(card, position: "top", list: list)
      expect(trello_client.client).to receive(:put).with("/cards/c1", { pos: "bottom" })
      trello_client.move_card(card, position: "bottom")
    end
  end
end
