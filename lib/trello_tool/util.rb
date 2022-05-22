# frozen_string_literal: true

module TrelloTool
  # small utility methods for handling trello urls
  module Util
    def extract_id_from_url(trello_board_url)
      match_data = %r{https://trello.com/b/([a-zA-Z0-9]+)/?.*}.match(trello_board_url)
      raise "Unexpectedly #{trello_board_url} doesn't match https://trelloc.om/b/ID/description" unless match_data

      match_data[1]
    end
  end
end
