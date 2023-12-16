# frozen_string_literal: true

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

    def next_version_list
      @next_version_list ||= find_list_by_list_name(main_board, configuration.next_version_list_name)
    end

    protected

    def divider_list?(list)
      configuration.divider_list_matcher.match?(list.name)
    end

    def version_list?(list)
      configuration.version_list_matcher.match?(list.name)
    end
  end
end
