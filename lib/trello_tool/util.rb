# frozen_string_literal: true

module TrelloTool
  # small utility methods for handling trello urls
  module Util
    private

    def extract_id_from_url(trello_board_url)
      match_data = %r{https://trello.com/b/([a-zA-Z0-9]+)/?.*}.match(trello_board_url)
      raise "Unexpectedly #{trello_board_url} doesn't match https://trelloc.om/b/ID/description" unless match_data

      match_data[1]
    end

    # @param board [Trello::Board]
    # @param list_name [String]
    # @return [Trello::List]
    def find_list_by_list_name(board, list_name)
      list = board.lists.detect { |l| l.name == list_name }
      return list if list

      say("couldn't find list called #{list_name.inspect}. found:")
      lists(url)
      nil
    end

    def find_pos_before_list(board, target_list)
      previous_list_pos = nil
      board.lists.each do |this_list|
        return previous_list_pos && ((target_list.pos + previous_list_pos) / 2) if this_list == target_list

        previous_list_pos = this_list.pos
      end

      say("couldn't find list")
      nil
    end
  end
end
