# encoding: UTF-8
# frozen_string_literal: true

require "thor"
require "trello"
require "trello_tool/configuration"
require "trello_tool/util"

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
    lists_reversed = main_board.lists.reverse
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
    unexpected = []
    todo_list = nil
    doing_list = nil
    main_board.lists.each_with_index do |list, index|
      if list.name == configuration.next_version_list_name
        say("V", Thor::Shell::Color::BOLD, false)
      elsif list.name == configuration.todo_list_name
        todo_list = list
        say("+", Thor::Shell::Color::BOLD, false)
      elsif list.name == configuration.doing_list_name
        doing_list = list
        say("️d", Thor::Shell::Color::BOLD, false)
      elsif configuration.expected_list_names.include?(list.name)
        say(".", Thor::Shell::Color::CYAN, false)
      elsif configuration.month_list_names.include?(list.name)
        say("M", Thor::Shell::Color::CYAN, false)
      elsif configuration.version_list_matcher.match?(list.name)
        say("v", Thor::Shell::Color::CYAN, false)
      else
        say("?", Thor::Shell::Color::RED, false)
        unexpected << [list, index]
      end
    end
    say
    unexpected.each do |list, index|
      say("Unexpected: #{list.name.inspect} @##{index + 1}", Thor::Shell::Color::RED)
    end
    if (todo_cards = todo_list.cards).length >= configuration.too_many_todo
      say("Bad       : Cards in #{todo_list.name.inspect} has #{todo_cards.length} cards (> #{configuration.too_many_todo})",
          Thor::Shell::Color::RED)
    end
    if (doing_cards = doing_list.cards).length >= configuration.too_many_doing
      say("Bad       : Cards in #{doing_list.name.inspect} has #{doing_cards.length} cards (> #{configuration.too_many_doing})",
          Thor::Shell::Color::RED)
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
