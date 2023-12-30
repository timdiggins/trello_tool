# frozen_string_literal: true

require File.expand_path("../../lib/trello_tool/util.rb", __dir__)

RSpec.describe TrelloTool::Util do
  let(:subject_klass) do
    stub_const("UtilImplementation", Class.new).tap do |klass|
      klass.include(TrelloTool::Util)
    end
  end

  subject { subject_klass.new }

  describe "#find_list_by_list_name" do
    let(:board) { instance_double(Trello::Board, lists: lists) }
    context "with a match" do
      let(:list) { instance_double(Trello::List, name: "the name") }
      let(:lists) { [instance_double(Trello::List, name: "flong"), instance_double(Trello::List, name: "flang"), list] }
      it "finds it" do
        expect(subject.send(:find_list_by_list_name, board, "the name")).to eq(list)
      end
    end
    context "without a match" do
      let(:lists) { [] }
      let(:board) { instance_double(Trello::Board, lists: []) }
      it "fails well" do
        expect(subject.send(:find_list_by_list_name, board, "the name")).to be_nil
      end
    end
  end

  describe "#find_pos_before_list" do
    let(:board) { instance_double(Trello::Board, lists: lists) }
    let(:target_list) { instance_double(Trello::List, name: "the name", pos: 200) }
    context "with a match" do
      let(:lists) do
        [instance_double(Trello::List, name: "flong", pos: 1), instance_double(Trello::List, name: "flang", pos: 100), target_list]
      end
      it "finds it" do
        expect(subject.send(:find_pos_before_list, board, target_list)).to be_within(20).of(150)
      end
    end
    context "as first list" do
      let(:lists) { [target_list, instance_double(Trello::List, name: "flong", pos: 1000)] }
      it "finds it" do
        expect(subject.send(:find_pos_before_list, board, target_list)).to be_within(20).of(100)
      end
    end
    context "without a match" do
      let(:board) { instance_double(Trello::Board, lists: []) }
      it "fails well" do
        expect(subject.send(:find_pos_before_list, board, target_list)).to be_nil
      end
    end
  end
end
