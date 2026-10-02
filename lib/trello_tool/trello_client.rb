# frozen_string_literal: true

require "json"
require "trello"
require "trello_tool/util"

module TrelloTool
  # Wrapped client for trello adapting it to things we need it to do
  class TrelloClient < SimpleDelegator
    include TrelloTool::Util
    attr_reader :client, :configuration

    # @param configuration[TrelloTool::Configuration]
    def initialize(configuration)
      @configuration = configuration
      @client = Trello::Client.new(
        developer_public_key: ENV["TRELLO_DEVELOPER_PUBLIC_KEY"],
        member_token: ENV["TRELLO_MEMBER_TOKEN"]
      )
      super(@client)
    end

    def authorized(&block)
      Trello.configure do |config|
        config.developer_public_key = ENV["TRELLO_DEVELOPER_PUBLIC_KEY"]
        config.member_token = ENV["TRELLO_MEMBER_TOKEN"]
      end
      block.call
      Trello.configure do |config|
        config.developer_public_key = nil
        config.member_token = nil
      end
    end

    def main_board
      @main_board ||= client.find(:boards, extract_id_from_url(configuration.main_board_url))
    end

    def archive_board
      @archive_board ||= client.find(:boards, extract_id_from_url(configuration.archive_board_url))
    end

    # @return [Array] of list names with left index, ordered from right
    def archiveable_list_names_with_index
      @archiveable_list_names_with_index ||= [].tap do |lists|
        all_lists = main_board.lists
        all_lists.reverse.each_with_index do |list, right_index|
          if (divider_list?(list) && right_index.zero?) || version_list?(list) # rubocop:disable Style/GuardClause
            left_index = all_lists.length - right_index - 1
            lists << [list.name, left_index]
          else
            break
          end
        end
      end
    end

    # @param card_id [String]
    # @return [Trello::Card]
    def find_card(card_id)
      client.find(:cards, card_id)
    end

    # @return [Trello::Board]
    def find_board(board_url)
      client.find(:boards, extract_id_from_url(board_url))
    end

    # the card fields the listing commands need, as trello names them
    CARD_FIELDS = "name,url,idList,labels,closed"

    # Unarchived cards of a board matching a trello search (operators such as label: and list: work, and the
    # last word matches as a prefix)
    # @return [Array<Hash>] cards as trello returns them: "name", "url", "idList", "labels"
    def search_cards(board, query, limit: 50)
      response = client.get("/search", "query" => query, "idBoards" => board.id, "modelTypes" => "cards",
                                       "cards_limit" => limit.to_s, "card_fields" => CARD_FIELDS, "partial" => "true")
      JSON.parse(response.body).fetch("cards", []).reject { |card| card["closed"] }
    end

    # Every unarchived card in an unarchived list of a board, in one request
    # @return [Array<Hash>] as #search_cards
    def open_cards(board)
      JSON.parse(client.get("/boards/#{board.id}/cards/visible", "fields" => CARD_FIELDS).body)
    end

    # @param list [Trello::List]
    # @return [Hash] the new card as trello returns it ("id", "url"...)
    def create_card(list, title:, description: "", top: false, label_ids: [])
      body = { name: title, desc: description, idList: list.id, pos: top ? "top" : "bottom" }
      body[:idLabels] = label_ids.join(",") if label_ids.any?
      JSON.parse(client.post("/cards", body).body)
    end

    # @param item [Hash] a checklist's check item ("id", "name", "state")
    def set_check_item_state(card, item, complete:)
      client.put("/cards/#{card.id}/checkItem/#{item['id']}", state: complete ? "complete" : "incomplete")
    end

    # @param position [String] "top" or "bottom"
    # @param list [Trello::List, nil] nil to reposition the card within its list
    def move_card(card, position:, list: nil)
      body = { pos: position }
      body[:idList] = list.id if list
      client.put("/cards/#{card.id}", body)
    end

    def next_version_list
      @next_version_list ||= find_list_by_list_name(main_board, configuration.next_version_list_name)
    end

    protected

    def divider_list?(list)
      configuration.divider_list_name?(list.name)
    end

    def version_list?(list)
      configuration.version_list_name?(list.name)
    end
  end
end
