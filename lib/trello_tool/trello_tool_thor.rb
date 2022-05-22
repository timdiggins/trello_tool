# encoding: UTF-8
# frozen_string_literal: true

require "thor"
require "trello"
require "trello_tool/configuration"

class TrelloToolThor < Thor
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

  desc "archive_last (N)", "archives the last N lists from the end of #{configuration.focus_board_url} to the beginning of #{configuration.archive_board_url}"

  def archive_last(to_archive = "1")
    number_to_archive = to_archive.to_i
    say "archiving #{number_to_archive} lists:"
    lists_reversed = focus_board.lists.reverse
    0.upto(number_to_archive - 1).each do |index|
      say("\r%<count>2s / %<total>s" % {count: index + 1, total: number_to_archive}, Thor::Shell::Color::GREEN, false)
      list = lists_reversed[index]
      break unless list
      list.move_to_board(archive_board)
      say "\r * #{list.name.inspect}#{' ' * 20}\n"
    end
    say
  end

  desc "archive", "archives one month's worth"

  def archive
    archiveable_list_names_with_index.each do |list, index|
      say "* #{list.inspect} @##{index + 1}"
    end
    if yes?("archive them?")
      archive_last(archiveable_list_names_with_index.length)
    end
  end

  desc "health", "checks whether focus is 'healthy'"

  def health
    unexpected = []
    todo_list = nil
    doing_list = nil
    focus_board.lists.each_with_index do |list, index|
      if list.name == NEXT_VERSION_LIST_NAME
        say("V", Thor::Shell::Color::BOLD, false)
      elsif list.name == TODO_LIST_NAME
        todo_list = list
        say("+", Thor::Shell::Color::BOLD, false)
      elsif list.name == DOING_LIST_NAME
        doing_list = list
        say("️d", Thor::Shell::Color::BOLD, false)
      elsif EXPECTED_LIST_NAMES.include?(list.name)
        say(".", Thor::Shell::Color::CYAN, false)
      elsif month_list_names.include?(list.name)
        say("M", Thor::Shell::Color::CYAN, false)
      elsif version_list_matcher.match?(list.name)
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
    if (todo_cards = todo_list.cards).length >= TOO_MANY_TODO
      say("Bad       : Cards in #{todo_list.name.inspect} has #{todo_cards.length} cards (> #{TOO_MANY_TODO})", Thor::Shell::Color::RED)
    end
    if (doing_cards = doing_list.cards).length >= TOO_MANY_DOING
      say("Bad       : Cards in #{doing_list.name.inspect} has #{doing_cards.length} cards (> #{TOO_MANY_DOING})", Thor::Shell::Color::RED)
    end
  end

  desc "lists (board_url)", "prints out lists in a board (defaults to focus board)"

  def lists(url = FOCUS_BOARD_URL)
    board = client.find(:boards, extract_id_from_url(url))
    say board.name
    say url
    say
    board.lists.each do |list|
      say "* #{list.name}"
    end
  end

  private

  def archiveable_list_names_with_index
    @archiveable_list_names_with_index ||= [].tap do |lists|
      all_lists = focus_board.lists
      all_lists.reverse.each_with_index do |list, index|
        indexr = all_lists.length - index - 1
        if month_list_names.include?(list.name) && lists.empty?
          lists << [list.name, indexr]
        elsif version_list_matcher.match?(list.name)
          lists << [list.name, indexr]
        else
          break
        end
      end
    end
  end

  def month_list_names
    @month_list_names ||= Date::MONTHNAMES.compact.map(&method(:month_list_name))
  end

  def version_list_matcher
    @version_list_matcher ||= Regexp.new("\\A#{VERSION_TEMPLATE % ['\d+[.]\d+[.]\d+']}")
  end

  def month_list_name(name)
    MONTH_TEMPLATE % name.upcase
  end

  def focus_board
    @focus_board ||= client.find(:boards, extract_id_from_url(FOCUS_BOARD_URL))
  end

  def archive_board
    @archive_board ||= client.find(:boards, extract_id_from_url(ARCHIVE_BOARD_URL))
  end

  def client
    @client ||= Trello::Client.new(
      developer_public_key: ENV["TRELLO_DEVELOPER_PUBLIC_KEY"], # The "key" from step 1
      member_token: ENV["TRELLO_MEMBER_TOKEN"]
    )
  end

  def extract_id_from_url(url)
    match_data = %r{https://trello.com/b/([a-zA-Z0-9]+)/?.*}.match(url)
    raise "Unexpectedly #{url} doesn't match https://trelloc.om/b/ID/description" unless match_data
    match_data[1]
  end
end
