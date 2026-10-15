# frozen_string_literal: true

require "json"
require "thor"
require "trello_tool/configuration"
require "trello_tool/health"
require "trello_tool/trello_client"
require "trello_tool/util"

# The thor class
# rubocop:disable-next Metrics/ClassLength
class TrelloToolThor < Thor
  include TrelloTool::Util

  def self.configuration
    @configuration ||= TrelloTool::Configuration.new
  end

  # a command that can't do what it was asked (raises Thor::Error) exits non-zero
  def self.exit_on_failure?
    true
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

      list.move_to_board(client.archive_board)
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

  desc "health", "checks whether main board is 'healthy'"

  def health
    health = TrelloTool::Health.new(client.main_board, configuration)
    health.symbols_and_colours.each do |symbol, colour|
      say(symbol, colour, false)
    end
    say
    health.each_issue_with_severity do |issue, severity|
      say(format("%-20s", "#{severity}:"), Thor::Shell::Color::RED, false)
      say(issue)
    end
    health.each_expected_list_with_length do |list_name, length|
      say(" * #{list_name} (#{length})")
    end
  end

  desc "lists (BOARD_URL)", "prints out lists in a board (defaults to main board)"

  def lists(url = configuration.main_board_url)
    board = client.find(:boards, extract_id_from_url(url))
    say board.name
    say url
    say
    board.lists.each do |list|
      say "* #{list.name}"
    end
  end

  desc "card CARD_ID_OR_URL",
       "prints out a card as json (title, description, url, list, members, labels, checklists, attachment urls, comments)"

  def card(card_id_or_url)
    card = client.find_card(extract_card_id(card_id_or_url))
    say JSON.pretty_generate(card_as_hash(card))
  end

  desc "release (VERSION)",
       "rename next_version to VERSION and create next_version. If VERSION isn't specified use whatever is in ./.RELEASE_NEW_VERSION"

  def release(version = nil)
    version ||= File.exist?(".RELEASE_NEW_VERSION") && File.read(".RELEASE_NEW_VERSION").strip
    unless version
      say("Usage: release VERSION # or put version number in .RELEASE_NEW_VERSION")
      return
    end

    next_version_list = client.next_version_list
    next_version_list.name = version
    next_version_list.save
    client.authorized do
      Trello::List.create(name: configuration.next_version_list_name, board_id: client.main_board.id,
                          pos: find_pos_before_list(client.main_board, next_version_list))
    end
  end

  desc "summarize_as_md (LIST_NAME (BOARD_URL))",
       "prints out markdown summarizing all cards in a list in a board (defaults to 'to do' list of main board)"

  def summarize_as_md(list_name = configuration.todo_list_name, url = configuration.main_board_url)
    board = client.find(:boards, extract_id_from_url(url))
    list = find_list_by_list_name(board, list_name)
    return unless list

    cards = list.cards
    say "\n# #{list.name} (#{cards.length} cards)\n\n"
    list.cards.each do |card|
      say "* [#{card.name}](#{card.url})"
    end
    say "\n"
  end

  desc "summarize_as_md_long (LIST_NAME (BOARD_URL))",
       "prints out markdown summarizing all cards in a list in a board" \
       "(defaults to 'to do' list of main board) -- includes attachment urls"

  def summarize_as_md_long(list_name = configuration.todo_list_name, url = configuration.main_board_url)
    board = client.find(:boards, extract_id_from_url(url))
    list = find_list_by_list_name(board, list_name)
    return unless list

    cards = list.cards
    say "\n# #{list.name} (#{cards.length} cards)\n\n"
    list.cards.each do |card|
      labels = card.labels.map { |label| "[#{label.name}]" }.join(" ")
      say "* #{card.name} #{labels}\n  #{card.url}"
      card.attachments.each do |attachment|
        next unless (url = attachment.url)
        next if %w[pdf png jpg].include?(url.split(".").last&.downcase)

        say "  - #{url}"
      end
    end
    say "\n"
  end
  desc "summarize_as_urls (LIST_NAME (BOARD_URL))",
       "prints out urls summarizing all cards in a list in a board (defaults to 'to do' list of main board)"
  def summarize_as_urls(list_name = configuration.todo_list_name, url = configuration.main_board_url)
    board = client.find(:boards, extract_id_from_url(url))
    list = find_list_by_list_name(board, list_name)
    return unless list

    cards = list.cards
    say "\n#{list.name} (#{cards.length} cards)\n\n"
    list.cards.each do |card|
      say card.url
    end
    say "\n"
  end

  desc "search QUERY (BOARD_URL)",
       "prints the unarchived cards matching a trello search, grouped by list " \
       "(operators like label: and list: work) -- markdown, or --json"
  method_option :json, type: :boolean, default: false, desc: "print json instead of markdown"

  def search(query, url = configuration.main_board_url)
    board = client.find_board(url)
    print_cards(board, client.search_cards(board, query))
  end

  desc "cards (BOARD_URL)", "prints every unarchived card in a board, grouped by list -- markdown, or --json"
  method_option :json, type: :boolean, default: false, desc: "print json instead of markdown"

  def cards(url = configuration.main_board_url)
    board = client.find_board(url)
    print_cards(board, client.open_cards(board))
  end

  desc "comment CARD_ID_OR_URL (TEXT)", "adds a comment to a card (the text inline, or from --file)"
  method_option :file, type: :string, desc: "read the comment from this file"

  def comment(card_id_or_url, text = nil)
    raise Thor::Error, "give the comment either inline or with --file, not both" if text && options[:file]

    text = File.read(options[:file]) if options[:file]
    raise Thor::Error, "the comment is empty" if text.to_s.strip.empty?

    card = client.find_card(extract_card_id(card_id_or_url))
    card.add_comment(text)
    say "commented on #{card.url}"
  end

  desc "create (LIST_NAME (BOARD_URL)) --title TITLE (--desc TEXT | --desc-file PATH) (--label NAME ...) (--top) (--force)",
       "creates a card at the bottom (or --top) of LIST_NAME (default: default_list_name_for_new_cards) and " \
       "prints it as json; stops if an unarchived card already has that title, unless --force"
  method_option :title, type: :string, required: true
  method_option :desc, type: :string, desc: "the description"
  method_option :desc_file, type: :string, desc: "read the description (markdown) from this file"
  method_option :label, type: :array, default: [], desc: "names of labels of the board"
  method_option :top, type: :boolean, default: false, desc: "at the top of the list rather than the bottom"
  method_option :force, type: :boolean, default: false, desc: "create even if a card with this title exists"

  def create(list_name = configuration.default_list_name_for_new_cards, url = configuration.main_board_url)
    title = title_option!
    description = description_option!
    no_list = "give a LIST_NAME, or set default_list_name_for_new_cards in #{configuration.config_file}"
    raise Thor::Error, no_list unless list_name

    board = client.find_board(url)
    list = find_list!(board, list_name)
    label_ids = label_ids!(board, Array(options[:label]))
    refuse_duplicate!(board, title) unless options[:force]
    created = client.create_card(list, title: title, description: description, top: options[:top] ? true : false,
                                       label_ids: label_ids)
    say "created #{created['url']} in #{list.name.inspect}"
    card(created["id"])
  end

  desc "checklist CARD_ID_OR_URL NAME --items ITEM ...",
       "adds items to the card's checklist of that name (creating it if need be), skipping items already there; " \
       "prints the checklist as json"
  method_option :items, type: :array, default: [], desc: "the items to add"
  method_option :checked, type: :boolean, default: false, desc: "add the items already ticked"

  def checklist(card_id_or_url, name)
    card_id = extract_card_id(card_id_or_url)
    list = find_checklist(card_id, name) || create_checklist(card_id, name)
    existing = list.check_items.map { |item| item["name"] }
    (Array(options[:items]).uniq - existing).each { |item| list.add_item(item, options[:checked] ? true : false, "bottom") }
    say JSON.pretty_generate(checklist_as_hash(find_checklist(card_id, name)))
  end

  desc "check CARD_ID_OR_URL ITEM_TEXT (--checklist NAME) (--uncheck)",
       "ticks (or with --uncheck unticks) the checklist item with that text (the whole text, or a part only it has)"
  method_option :checklist, type: :string, desc: "only look in the checklist of this name"
  method_option :uncheck, type: :boolean, default: false, desc: "untick instead"

  def check(card_id_or_url, item_text)
    card = client.find_card(extract_card_id(card_id_or_url))
    item = find_check_item!(card, item_text)
    client.set_check_item_state(card, item, complete: !options[:uncheck])
    say "#{options[:uncheck] ? 'unticked' : 'ticked'} #{item['name'].inspect} on #{card.url}"
  end

  desc "move CARD_ID_OR_URL (LIST_NAME (BOARD_URL)) (--top | --bottom)",
       "moves a card to the bottom (or --top) of a list; without LIST_NAME, to the top or bottom of the list it is in"
  method_option :top, type: :boolean, default: false
  method_option :bottom, type: :boolean, default: false

  def move(card_id_or_url, list_name = nil, url = configuration.main_board_url)
    position = position_option!(list_name)
    card = client.find_card(extract_card_id(card_id_or_url))
    list = find_list!(client.find_board(url), list_name) if list_name
    return say("already in #{list.name.inspect}: #{card.url}") if list && card.list_id == list.id

    client.move_card(card, position: position, list: list)
    say "moved #{card.url} to the #{position} of #{list ? list.name.inspect : 'its list'}"
  end

  desc "add_member CARD_ID_OR_URL (MEMBER) (--remove)",
       "adds a member to a card (or with --remove takes them off): MEMBER is a username or full name of a member " \
       "of the card's board, or \"me\" (the default), the member the token belongs to"
  method_option :remove, type: :boolean, default: false, desc: "remove the member instead"

  def add_member(card_id_or_url, member_name = "me")
    card = client.find_card(extract_card_id(card_id_or_url))
    member = find_member!(card, member_name)
    on_card = Array(card.member_ids).include?(member.id)
    who = "#{member.username} (#{member.full_name})"
    if options[:remove]
      card.remove_member(member) if on_card
      say "#{on_card ? 'removed' : 'not a member:'} #{who} #{on_card ? 'from' : 'on'} #{card.url}"
    else
      card.add_member(member) unless on_card
      say "#{on_card ? 'already a member:' : 'added'} #{who} #{on_card ? 'on' : 'to'} #{card.url}"
    end
  end

  desc "label CARD_ID_OR_URL NAME ...", "adds labels of the card's board to a card; labels already on it are reported, not errors"

  def label(card_id_or_url, *names)
    raise Thor::Error, "give at least one label name" if names.empty?

    card = client.find_card(extract_card_id(card_id_or_url))
    labels = find_labels!(client.board_of(card), names)
    on_card_ids = card.labels.map(&:id)
    present, missing = labels.partition { |label| on_card_ids.include?(label.id) }
    missing.each { |label| card.add_label(label) }
    say_labelled(card, present, missing)
  end

  desc "attach CARD_ID_OR_URL URL_OR_PATH (--name TEXT)",
       "attaches a link to a card, or uploads a file when URL_OR_PATH is an existing file; " \
       "a link already attached is reported, not added again"
  method_option :name, type: :string, default: "", desc: "a name for the attachment"

  def attach(card_id_or_url, url_or_path)
    card = client.find_card(extract_card_id(card_id_or_url))
    name = options[:name].to_s
    if File.file?(url_or_path)
      response = File.open(url_or_path) { |file| card.add_attachment(file, name) }
      say "attached #{File.basename(url_or_path)} to #{card.url}: #{attachment_url(response)}"
    elsif card.attachments.any? { |attachment| attachment.url == url_or_path }
      say "already attached: #{url_or_path} on #{card.url}"
    else
      card.add_attachment(url_or_path, name)
      say "attached #{url_or_path} to #{card.url}"
    end
  end

  desc "rename_item CARD_ID_OR_URL ITEM_TEXT NEW_TEXT (--checklist NAME)",
       "renames the checklist item with that text (the whole text, or a part only it has)"
  method_option :checklist, type: :string, desc: "only look in the checklist of this name"

  def rename_item(card_id_or_url, item_text, new_text)
    raise Thor::Error, "the new text is empty" if new_text.to_s.strip.empty?

    card = client.find_card(extract_card_id(card_id_or_url))
    item = find_check_item!(card, item_text)
    client.rename_check_item(card, item, name: new_text)
    say "renamed #{item['name'].inspect} to #{new_text.inspect} on #{card.url}"
  end

  desc "remove_item CARD_ID_OR_URL ITEM_TEXT (--checklist NAME)",
       "deletes the checklist item with that text (the whole text, or a part only it has)"
  method_option :checklist, type: :string, desc: "only look in the checklist of this name"

  def remove_item(card_id_or_url, item_text)
    card = client.find_card(extract_card_id(card_id_or_url))
    item = find_check_item!(card, item_text)
    client.remove_check_item(card, item)
    say "removed #{item['name'].inspect} from #{card.url}"
  end

  desc "rename_checklist CARD_ID_OR_URL NAME NEW_NAME", "renames the card's checklist of that name"

  def rename_checklist(card_id_or_url, name, new_name)
    raise Thor::Error, "the new name is empty" if new_name.to_s.strip.empty?

    card = client.find_card(extract_card_id(card_id_or_url))
    checklist = card.checklists.detect { |candidate| candidate.name == name }
    unless checklist
      raise Thor::Error, "no checklist called #{name.inspect} on #{card.url}. " \
                         "Checklists: #{card.checklists.map { |candidate| candidate.name.inspect }.join(', ')}"
    end

    client.rename_checklist(checklist, name: new_name)
    say "renamed checklist #{name.inspect} to #{new_name.inspect} on #{card.url}"
  end

  private

  # @param present [Array<Trello::Label>] labels the card already had
  # @param missing [Array<Trello::Label>] labels just added
  def say_labelled(card, present, missing)
    say "labelled #{card.url} with #{missing.map(&:name).join(', ')}" if missing.any?
    say "already labelled #{present.map(&:name).join(', ')}: #{card.url}" if present.any?
  end

  # @param response [Trello::Response]
  # @return [String, nil] the url of the attachment trello created
  def attachment_url(response)
    JSON.parse(response.body)["url"]
  rescue JSON::ParserError, NoMethodError, TypeError
    nil
  end

  def client
    TrelloTool::TrelloClient.new(configuration)
  end

  # @return [Trello::Member] me for "me", otherwise the board member with that username or full name, or failing
  #   that the one whose full name contains it
  def find_member!(card, name)
    return client.me if name.casecmp?("me")

    members = client.board_members(card)
    matches = matching_members(members, name)
    return matches.first if matches.size == 1

    problem = matches.empty? ? "no member matching" : "more than one member matching"
    candidates = (matches.empty? ? members : matches).map { |member| "#{member.username} (#{member.full_name})" }
    raise Thor::Error, "#{problem} #{name.inspect} on the board of #{card.url}. Members: #{candidates.join(', ')}"
  end

  # @return [Array<Trello::Member>] those whose username or full name is name, or failing that whose full name contains it
  def matching_members(members, name)
    exact = members.select { |member| member.username.to_s.casecmp?(name) || member.full_name.to_s.casecmp?(name) }
    return exact if exact.any?

    members.select { |member| member.full_name.to_s.downcase.include?(name.downcase) }
  end

  # @param cards [Array<Hash>] as trello returns them ("name", "url", "idList", "labels"); cards whose list is
  #   archived (not among the board's lists) are left out
  def print_cards(board, cards)
    # in the board's list order
    rows = board.lists.flat_map { |list| cards.filter_map { |found| card_row(found, [list]) } }
    return say(JSON.pretty_generate(rows)) if options[:json]
    return say("no cards found") if rows.empty?

    print_cards_as_markdown(rows)
  end

  def print_cards_as_markdown(rows)
    rows.group_by { |row| row[:list] }.each do |list_name, in_list|
      say "\n# #{list_name} (#{in_list.length} cards)\n\n"
      in_list.each { |row| say "* [#{row[:title]}](#{row[:url]})#{row[:labels].map { |label| " [#{label}]" }.join}" }
    end
    say "\n"
  end

  def title_option!
    title = options[:title].to_s.strip
    raise Thor::Error, "--title is empty" if title.empty?

    title
  end

  def description_option!
    both = "give the description either with --desc or with --desc-file, not both"
    raise Thor::Error, both if options[:desc] && options[:desc_file]

    options[:desc_file] ? File.read(options[:desc_file]) : options[:desc].to_s
  end

  # @return [String] "top" or "bottom" (the default when the card is going to another list)
  def position_option!(list_name)
    raise Thor::Error, "--top or --bottom, not both" if options[:top] && options[:bottom]
    raise Thor::Error, "give a LIST_NAME, --top or --bottom" unless list_name || options[:top] || options[:bottom]

    options[:top] ? "top" : "bottom"
  end

  # @return [Hash, nil] nil when the card's list isn't one of lists
  def card_row(found, lists)
    list = lists.detect { |candidate| candidate.id == found["idList"] }
    return nil unless list

    { title: found["name"], url: found["url"], list: list.name,
      labels: (found["labels"] || []).map { |label| label["name"].to_s }.reject(&:empty?) }
  end

  # the list of that name (exactly, or failing that the only one that differs just by case)
  def find_list!(board, list_name)
    lists = board.lists
    list = lists.detect { |candidate| candidate.name == list_name }
    list ||= lists.select { |candidate| candidate.name.casecmp?(list_name) }.then { |found| found.first if found.size == 1 }
    list || raise(Thor::Error, "no list called #{list_name.inspect} in #{board.name}. Lists: #{lists.map(&:name).join(', ')}")
  end

  def label_ids!(board, names)
    find_labels!(board, names).map(&:id)
  end

  # @return [Array<Trello::Label>] the board's labels with those names (case-insensitively)
  def find_labels!(board, names)
    return [] if names.empty?

    labels = board.labels
    names.map do |name|
      labels.detect { |candidate| candidate.name.to_s.casecmp?(name) } ||
        raise(Thor::Error, "no label called #{name.inspect} in #{board.name}. " \
                           "Labels: #{labels.map { |candidate| candidate.name.to_s }.reject(&:empty?).join(', ')}")
    end
  end

  def refuse_duplicate!(board, title)
    duplicate = client.search_cards(board, %("#{title.delete('"')}")).detect { |found| found["name"].to_s.strip.casecmp?(title) }
    return unless duplicate

    raise Thor::Error, "a card called #{title.inspect} already exists: #{duplicate['url']} (--force to create another)"
  end

  # always from a fresh read of the card, so it sees a checklist or item that was just added
  def find_checklist(card_id, name)
    client.find_card(card_id).checklists.detect { |candidate| candidate.name == name }
  end

  def create_checklist(card_id, name)
    client.find_card(card_id).create_new_checklist(name)
    find_checklist(card_id, name) || raise(Thor::Error, "couldn't create the checklist #{name.inspect}")
  end

  # @return [Hash] the one check item whose name is item_text, or failing that the one containing it
  def find_check_item!(card, item_text)
    items = check_items!(card)
    matches = items.select { |item| item["name"].casecmp?(item_text) }
    matches = items.select { |item| item["name"].downcase.include?(item_text.downcase) } if matches.empty?
    return matches.first if matches.size == 1

    problem = matches.empty? ? "no item matching" : "more than one item matching"
    candidates = (matches.empty? ? items : matches).map { |item| item["name"].inspect }.join(", ")
    raise Thor::Error, "#{problem} #{item_text.inspect} on #{card.url}. Items: #{candidates}"
  end

  # @return [Array<Hash>] the check items of the card's checklists (of the --checklist one, if given)
  def check_items!(card)
    name = options[:checklist]
    checklists = card.checklists.select { |candidate| name.nil? || candidate.name == name }
    raise Thor::Error, "no checklist#{" called #{name.inspect}" if name} on #{card.url}" if checklists.empty?

    checklists.flat_map(&:check_items)
  end

  # @param card [Trello::Card]
  # @return [Hash]
  def card_as_hash(card)
    {
      title: card.name,
      description: card.desc,
      url: card.url,
      list: card.list.name,
      members: card.members.map { |member| "#{member.username} (#{member.full_name})" },
      labels: card.labels.map(&:name),
      checklists: card.checklists.map { |checklist| checklist_as_hash(checklist) },
      attachment_urls: card.attachments.map(&:url),
      comments: client.card_comments(card)
    }
  end

  # @param checklist [Trello::Checklist]
  # @return [Hash]
  def checklist_as_hash(checklist)
    {
      name: checklist.name,
      items: checklist.check_items.map do |item|
        { name: item["name"], complete: item["state"] == "complete" }
      end
    }
  end
end
