# frozen_string_literal: true

module TrelloTool
  # Health analysis of a board
  class Health
    attr_reader :board, :configuration, :symbols_and_colours, :unexpected, :expected_lists

    def initialize(board, configuration)
      @board = board
      @configuration = configuration
      @symbols_and_colours = []
      @unexpected = []
      @expected_lists = {}
      analyze
    end

    def each_issue_with_severity
      unexpected.each do |list, index|
        yield list.name.inspect, "Unexpected @ ##{index + 1}"
      end
      yield todo_list_issue if todo_list_issue
      yield doing_list_issue if doing_list_issue
    end

    def each_expected_list_with_length
      expected_lists.each do |name, value|
        yield name, value[:length]
      end
    end

    protected

    def todo_list
      expected_lists[configuration.todo_list_name]
    end

    def doing_list
      expected_lists[configuration.doing_list_name]
    end

    def doing_list_issue
      if !doing_list
        ["No doing list (looking for #{configuration.doing_list_name.inspect})", "Unconfigured"]
      elsif configuration.too_many_doing <= doing_list[:length]
        ["Cards in #{configuration.doing_list_name.inspect} has #{doing_list[:length]} cards (> #{configuration.too_many_doing})", "Bad"]
      end
    end

    def todo_list_issue
      if !todo_list
        ["No to do list (looking for #{configuration.todo_list_name.inspect})", "Unconfigured"]
      elsif configuration.too_many_todo <= todo_list[:length]
        ["Cards in #{configuration.todo_list_name.inspect} has #{todo_list[:length]} cards (> #{configuration.too_many_todo})", "Bad"]
      end
    end

    def analyze
      board.lists.each_with_index do |list, index|
        if list.name == configuration.next_version_list_name
          add_expected_list(list, "V", Thor::Shell::Color::BOLD)
        elsif list.name == configuration.todo_list_name
          add_expected_list(list, "+", Thor::Shell::Color::BOLD)
        elsif list.name == configuration.doing_list_name
          add_expected_list(list, "d", Thor::Shell::Color::BOLD)
        elsif configuration.expected_list_names.include?(list.name)
          add_expected_list(list, ".", Thor::Shell::Color::CYAN)
        elsif configuration.divider_list_matcher.match?(list.name)
          symbols_and_colours << ["|", Thor::Shell::Color::CYAN]
        elsif configuration.version_list_matcher.match?(list.name)
          symbols_and_colours << ["v", Thor::Shell::Color::CYAN]
        else
          add_unexpected_list(list, index)
        end
      end
    end

    def add_expected_list(list, symbol, colour)
      expected_lists[list.name] = { length: list.cards.length }
      symbols_and_colours << [symbol, colour]
    end

    def add_unexpected_list(list, index)
      unexpected << [list, index]
      symbols_and_colours << ["?", Thor::Shell::Color::RED]
    end
  end
end
