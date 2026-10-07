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

  describe "card commands" do
    let(:client) { instance_double(TrelloTool::TrelloClient) }
    let(:triage) { instance_double(Trello::List, id: "l1", name: "Triage") }
    let(:todo) { instance_double(Trello::List, id: "l2", name: "TO DO") }
    let(:bug) { instance_double(Trello::Label, id: "lab1", name: "bug") }
    let(:board) do
      instance_double(Trello::Board, id: "b1", name: "Main board", lists: [triage, todo], labels: [bug])
    end
    let(:card_url) { "https://trello.com/c/aBcD1234/1-a-card" }
    let(:steps) do
      instance_double(Trello::Checklist, name: "Steps",
                                         check_items: [{ "id" => "i1", "name" => "write the specs", "state" => "incomplete" },
                                                       { "id" => "i2", "name" => "write the code", "state" => "incomplete" }])
    end
    let(:card) do
      instance_double(Trello::Card, id: "c1", name: "A card", desc: "", url: card_url, checklists: [steps], attachments: [],
                                    board_id: "b1", member_ids: [])
    end
    let(:tim) { instance_double(Trello::Member, id: "m1", username: "timdiggins", full_name: "Tim Diggins") }
    let(:dom) { instance_double(Trello::Member, id: "m2", username: "dominicf", full_name: "Dominic Freeman") }
    let(:found) do
      [{ "name" => "Fix the snitch", "url" => "https://trello.com/c/one", "idList" => "l2", "labels" => [{ "name" => "bug" }] },
       { "name" => "Tidy up", "url" => "https://trello.com/c/two", "idList" => "l1", "labels" => [{ "name" => "" }] },
       { "name" => "In an archived list", "url" => "https://trello.com/c/three", "idList" => "gone", "labels" => [] }]
    end

    before do
      allow(client).to receive(:find_board).and_return(board)
      allow(client).to receive(:find_card).with("aBcD1234").and_return(card)
    end

    def thor(options = {})
      TrelloToolThor.new([], options).tap { |instance| allow(instance).to receive(:client).and_return(client) }
    end

    describe "#search" do
      before { allow(client).to receive(:search_cards).with(board, "snitch").and_return(found) }

      it "prints the cards as markdown grouped by list, in board order, without cards of archived lists" do
        expect { thor.search("snitch") }.to output(
          "\n# Triage (1 cards)\n\n* [Tidy up](https://trello.com/c/two)\n" \
          "\n# TO DO (1 cards)\n\n* [Fix the snitch](https://trello.com/c/one) [bug]\n\n"
        ).to_stdout
      end

      it "prints json with --json" do
        expected = [
          { "title" => "Tidy up", "url" => "https://trello.com/c/two", "list" => "Triage", "labels" => [] },
          { "title" => "Fix the snitch", "url" => "https://trello.com/c/one", "list" => "TO DO", "labels" => ["bug"] }
        ]
        expect { thor(json: true).search("snitch") }.to output(satisfy { |json| JSON.parse(json) == expected }).to_stdout
      end

      it "says when nothing matches" do
        allow(client).to receive(:search_cards).and_return([])
        expect { thor.search("snitch") }.to output("no cards found\n").to_stdout
      end
    end

    describe "#cards" do
      it "prints every open card of the board" do
        expect(client).to receive(:open_cards).with(board).and_return(found)
        expect { thor.cards }.to output(/# Triage \(1 cards\).*Tidy up.*# TO DO \(1 cards\).*Fix the snitch/m).to_stdout
      end
    end

    describe "#comment" do
      it "adds the comment to the card" do
        expect(card).to receive(:add_comment).with("see the plan")
        expect { thor.comment(card_url, "see the plan") }.to output("commented on #{card_url}\n").to_stdout
      end

      it "reads the comment from --file" do
        path = File.join(@target_dir, "comment.md")
        File.write(path, "# Findings\n\nlong text")
        expect(card).to receive(:add_comment).with("# Findings\n\nlong text")
        expect { thor(file: path).comment("aBcD1234") }.to output(/commented/).to_stdout
      end

      it "refuses an empty comment, and text plus --file" do
        expect(card).not_to receive(:add_comment)
        expect { thor.comment(card_url, "  ") }.to raise_error(Thor::Error, /empty/)
        expect { thor(file: "x.md").comment(card_url, "text") }.to raise_error(Thor::Error, /not both/)
      end
    end

    describe "#create" do
      let(:created) { { "id" => "aBcD1234", "url" => card_url } }

      before { allow(client).to receive(:search_cards).and_return([]) }

      it "creates the card in the named list and prints it" do
        expect(client).to receive(:create_card).with(todo, title: "A card", description: "why", top: false, label_ids: [])
                                               .and_return(created)
        expect { thor(title: " A card ", desc: "why").create("TO DO") }
          .to output(/\Acreated #{Regexp.escape(card_url)} in "TO DO"\n\{.*"title": "A card"/m).to_stdout
      end

      it "defaults the list to default_list_name_for_new_cards, and takes the description, labels and position" do
        allow(TrelloToolThor.configuration).to receive(:default_list_name_for_new_cards).and_return("Triage")
        path = File.join(@target_dir, "card.md")
        File.write(path, "# Why\n\nbecause")
        expect(client).to receive(:create_card).with(triage, title: "A card", description: "# Why\n\nbecause", top: true,
                                                             label_ids: ["lab1"]).and_return(created)
        expect { thor(title: "A card", desc_file: path, label: ["Bug"], top: true).create }.to output(/in "Triage"/).to_stdout
      end

      it "needs a list when none is configured" do
        expect { thor(title: "A card").create }.to raise_error(Thor::Error, /default_list_name_for_new_cards/)
      end

      it "names the board's lists and labels when one isn't found, creating nothing" do
        expect(client).not_to receive(:create_card)
        expect { thor(title: "A card").create("Nowhere") }.to raise_error(Thor::Error, /no list called "Nowhere".*Triage, TO DO/)
        expect { thor(title: "A card", label: ["nope"]).create("TO DO") }.to raise_error(Thor::Error, /no label called "nope".*bug/)
      end

      it "finds a list that differs only by case" do
        expect(client).to receive(:create_card).with(todo, hash_including(title: "A card")).and_return(created)
        expect { thor(title: "A card").create("to do") }.to output(/in "TO DO"/).to_stdout
      end

      it "stops when a card with that title exists, unless --force" do
        expect(client).to receive(:search_cards).with(board, '"A card"')
                                                .and_return([{ "name" => "a card ", "url" => "https://trello.com/c/dup" }])
        expect(client).not_to receive(:create_card)
        expect { thor(title: "A card").create("TO DO") }.to raise_error(Thor::Error, %r{already exists: https://trello.com/c/dup.*--force})
      end

      it "creates a duplicate with --force without searching" do
        expect(client).not_to receive(:search_cards)
        expect(client).to receive(:create_card).and_return(created)
        expect { thor(title: "A card", force: true).create("TO DO") }.to output(/created/).to_stdout
      end

      it "refuses an empty title, and both --desc and --desc-file" do
        expect { thor(title: " ").create("TO DO") }.to raise_error(Thor::Error, /--title is empty/)
        expect { thor(title: "A card", desc: "x", desc_file: "y.md").create("TO DO") }.to raise_error(Thor::Error, /not both/)
      end
    end

    describe "#checklist" do
      it "adds only the items that aren't there yet, and prints the checklist" do
        expect(steps).to receive(:add_item).with("release", false, "bottom")
        expect { thor(items: ["write the code", "release", "release"]).checklist(card_url, "Steps") }
          .to output(satisfy { |json| JSON.parse(json)["name"] == "Steps" }).to_stdout
      end

      it "creates the checklist when the card has none of that name, ticking the items with --checked" do
        deploy = instance_double(Trello::Checklist, name: "Deploy", check_items: [])
        expect(card).to receive(:create_new_checklist).with("Deploy") do
          allow(card).to receive(:checklists).and_return([steps, deploy])
        end
        expect(deploy).to receive(:add_item).with("migrate", true, "bottom")
        expect { thor(items: ["migrate"], checked: true).checklist(card_url, "Deploy") }.to output(/"name": "Deploy"/).to_stdout
      end
    end

    describe "#check" do
      it "ticks the item with that text" do
        expect(client).to receive(:set_check_item_state).with(card, hash_including("id" => "i2"), complete: true)
        expect { thor.check(card_url, "Write the code") }.to output(%(ticked "write the code" on #{card_url}\n)).to_stdout
      end

      it "finds an item by a part only it has, and unticks with --uncheck" do
        expect(client).to receive(:set_check_item_state).with(card, hash_including("id" => "i1"), complete: false)
        expect { thor(uncheck: true).check(card_url, "specs") }.to output(/unticked "write the specs"/).to_stdout
      end

      it "names the items when none or several match, changing nothing" do
        expect(client).not_to receive(:set_check_item_state)
        expect { thor.check(card_url, "deploy") }
          .to raise_error(Thor::Error, /no item matching "deploy".*"write the specs", "write the code"/)
        expect { thor.check(card_url, "write") }.to raise_error(Thor::Error, /more than one item matching "write"/)
      end

      it "looks only in the named checklist" do
        expect { thor(checklist: "Deploy").check(card_url, "specs") }.to raise_error(Thor::Error, /no checklist called "Deploy"/)
      end
    end

    describe "#move" do
      it "moves the card to the bottom of the list" do
        expect(client).to receive(:move_card).with(card, position: "bottom", list: todo)
        expect { thor.move(card_url, "TO DO") }.to output(%(moved #{card_url} to the bottom of "TO DO"\n)).to_stdout
      end

      it "moves it to the top with --top" do
        expect(client).to receive(:move_card).with(card, position: "top", list: triage)
        expect { thor(top: true).move(card_url, "Triage") }.to output(/to the top of "Triage"/).to_stdout
      end

      it "repositions within the card's own list when no list is named" do
        expect(client).to receive(:move_card).with(card, position: "top", list: nil)
        expect { thor(top: true).move(card_url) }.to output(/to the top of its list/).to_stdout
      end

      it "needs a list or a position, not both positions, and a list that exists" do
        expect(client).not_to receive(:move_card)
        expect { thor.move(card_url) }.to raise_error(Thor::Error, /LIST_NAME, --top or --bottom/)
        expect { thor(top: true, bottom: true).move(card_url, "TO DO") }.to raise_error(Thor::Error, /not both/)
        expect { thor.move(card_url, "Nowhere") }.to raise_error(Thor::Error, /no list called "Nowhere"/)
      end
    end

    describe "#add_member" do
      before do
        allow(client).to receive(:me).and_return(tim)
        allow(client).to receive(:board_members).with(card).and_return([tim, dom])
      end

      it "adds me by default" do
        expect(card).to receive(:add_member).with(tim)
        expect { thor.add_member(card_url) }.to output("added timdiggins (Tim Diggins) to #{card_url}\n").to_stdout
      end

      it "finds a board member by username, full name, or a part of the full name only they have" do
        expect(card).to receive(:add_member).with(dom).exactly(3).times
        expect { thor.add_member(card_url, "DominicF") }.to output(/added dominicf/).to_stdout
        expect { thor.add_member(card_url, "dominic freeman") }.to output(/added dominicf/).to_stdout
        expect { thor.add_member(card_url, "Freeman") }.to output(/added dominicf/).to_stdout
      end

      it "removes with --remove" do
        allow(card).to receive(:member_ids).and_return(%w[m1 m2])
        expect(card).to receive(:remove_member).with(dom)
        expect { thor(remove: true).add_member(card_url, "dominicf") }
          .to output("removed dominicf (Dominic Freeman) from #{card_url}\n").to_stdout
      end

      it "changes nothing when the member is already on the card, or isn't there to remove" do
        expect(card).not_to receive(:add_member)
        expect(card).not_to receive(:remove_member)
        allow(card).to receive(:member_ids).and_return(["m1"])
        expect { thor.add_member(card_url) }.to output(/already a member: timdiggins/).to_stdout
        expect { thor(remove: true).add_member(card_url, "dominicf") }.to output(/not a member: dominicf/).to_stdout
      end

      it "names the board's members when none or several match, changing nothing" do
        expect(card).not_to receive(:add_member)
        expect { thor.add_member(card_url, "nobody") }
          .to raise_error(Thor::Error, /no member matching "nobody".*timdiggins \(Tim Diggins\), dominicf/)
        expect { thor.add_member(card_url, "i") }.to raise_error(Thor::Error, /more than one member matching "i"/)
      end
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
