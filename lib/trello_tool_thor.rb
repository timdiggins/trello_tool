# frozen_string_literal: true

require "thor"
require "trello_tool/configuration"
require "trello_tool/health"
require "trello_tool/trello_client"
require "trello_tool/util"

# The thor class
class TrelloToolThor < Thor
  include TrelloTool::Util

  def self.configuration
    @configuration ||= TrelloTool::Configuration.new
  end

  no_commands do
    delegate :configuration, to: :class
  end

  namespace :trello_tool

  desc "config", "generates default config file unless already present"

  def config
    if configuration.config_file_exists?
      say("Configuration already exists at #{configuration.config_file}")
    else
      configuration.generate
      say("Generated configuration at #{configuration.config_file}. You will need to specify trello urls")
    end
  end

  desc "archive_last (N)",
       "archives the last N lists from the end of #{configuration.main_board_url} to the beginning of #{configuration.archive_board_url}"

  def archive_last(to_archive = "1")
    number_to_archive = to_archive.to_i
    say "archiving #{number_to_archive} lists:"
    lists_reversed = client.main_board.lists.reverse
    0.upto(number_to_archive - 1).each do |index|
      say(format("\r%<count>2s / %<total>s", count: index + 1, total: number_to_archive), Thor::Shell::Color::GREEN,
          false)
      list = lists_reversed[index]
      break unless list

      list.move_to_board(archive_board)
      say "\r * #{list.name.inspect}#{' ' * 20}\n"
    end
    say
  end

  desc "archive", "archives one month's worth"

  def archive
    client.archiveable_list_names_with_index.each do |list, index|
      say "* #{list.inspect} @##{index + 1}"
    end
    archive_last(client.archiveable_list_names_with_index.length) if yes?("archive them?")
  end

  desc "health", "checks whether focus is 'healthy'"

  def health
    health = TrelloTool::Health.new(client.main_board, configuration)
    health.symbols_and_colours.each do |symbol, colour|
      say(symbol, colour, false)
    end
    say
    health.each_issue_with_severity do |issue, severity|
      say(format("%-15s", "#{severity}:"), Thor::Shell::Color::RED, false)
      say(issue)
    end
  end

  desc "lists (board_url)", "prints out lists in a board (defaults to focus board)"

  def lists(url = configuration.main_board_url)
    board = client.find(:boards, extract_id_from_url(url))
    say board.name
    say url
    say
    board.lists.each do |list|
      say "* #{list.name}"
    end
  end

  private

  def client
    TrelloTool::TrelloClient.new(configuration)
  end
end
