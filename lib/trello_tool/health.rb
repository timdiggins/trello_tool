# frozen_string_literal: true

module TrelloTool
  # Health analysis of a board
  class Health
    attr_reader :board, :configuration, :symbols_and_colours, :unexpected
    attr_accessor :doing_list, :todo_list

    def initialize(board, configuration)
      @board = board
      @configuration = configuration
      @symbols_and_colours = []
      @unexpected = []
      analyze
    end

    def each_issue_with_severity
      unexpected.each do |list, index|
        yield "#{list.name.inspect} @ ##{index + 1}", "Unexpected"
      end
      yield todo_list_issue
      yield doing_list_issue
    end

    protected

    def doing_list_issue
      if !doing_list
        ["No doing list (looking for #{configuration.doing_list_name.inspect})", "Unconfigured"]
      elsif configuration.too_many_doing <= (doing_cards = doing_list.cards).length
        ["Cards in #{doing_list.name.inspect} has #{doing_cards.length} cards (> #{configuration.too_many_doing})", "Bad"]
      end
    end

    def todo_list_issue
      if !todo_list
        ["No to do list (looking for #{configuration.todo_list_name.inspect})", "Unconfigured"]
      elsif configuration.too_many_todo <= (todo_cards = todo_list.cards).length
        ["Cards in #{todo_list.name.inspect} has #{todo_cards.length} cards (> #{configuration.too_many_todo})", "Bad"]
      end
    end

    def analyze
      board.lists.each_with_index do |list, index|
        if list.name == configuration.next_version_list_name
          symbols_and_colours << ["V", Thor::Shell::Color::BOLD]
        elsif list.name == configuration.todo_list_name
          self.todo_list = list
          symbols_and_colours << ["+", Thor::Shell::Color::BOLD]
        elsif list.name == configuration.doing_list_name
          self.doing_list = list
          symbols_and_colours << ["️d", Thor::Shell::Color::BOLD]
        elsif configuration.expected_list_names.include?(list.name)
          symbols_and_colours << [".", Thor::Shell::Color::CYAN]
        elsif configuration.month_list_names.include?(list.name)
          symbols_and_colours << ["M", Thor::Shell::Color::CYAN]
        elsif configuration.version_list_matcher.match?(list.name)
          symbols_and_colours << ["v", Thor::Shell::Color::CYAN]
        else
          symbols_and_colours << ["?", Thor::Shell::Color::RED]
          unexpected << [list, index]
        end
      end
    end
  end
end
