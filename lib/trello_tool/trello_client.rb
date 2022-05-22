# frozen_string_literal: true

module TrelloTool
  # Wrapped client for trello adapting it to things we need it to do
  class TrelloClient < SimpleDelegator
    # @param configuration[TrelloTool::Configuration]
    def initialize(configuration)
      @configuration = configuration
      @client = Trello::Client.new(
        developer_public_key: ENV["TRELLO_DEVELOPER_PUBLIC_KEY"],
        member_token: ENV["TRELLO_MEMBER_TOKEN"]
      )
      super(@client)
    end

    def main_board
      @main_board ||= client.find(:boards, extract_id_from_url(configuration.main_board_url))
    end

    def archive_board
      @archive_board ||= client.find(:boards, extract_id_from_url(ARCHIVE_BOARD_URL))
    end

    def archiveable_list_names_with_index
      @archiveable_list_names_with_index ||= [].tap do |lists|
        all_lists = main_board.lists
        all_lists.reverse.each_with_index do |list, right_index|
          if (month_list?(list) && right_index.zero?) || version_list?(list) # rubocop:disable Style/GuardClause
            left_index = all_lists.length - right_index - 1
            lists << [list.name, left_index]
          else
            break
          end
        end
      end
    end

    protected

    def month_list?(list)
      configuration.month_list_names.include?(list.name)
    end

    def version_list?(list)
      configuration.version_list_matcher.match?(list.name)
    end
  end
end
