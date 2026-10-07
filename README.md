# TrelloTool

Tool for doing basic things to a dev trello using the api. 
This is for a software development context where the software has explicit version numbers 
(ie. typically not in a Continuous Delivery situation)

The tool envisages a main trello board with the following lists:

* (some optional lists at the beginning -- "Triage" and "Reference" by default)
* "To do"
* "Doing"
* (at least one "done" list -- "Done" by default)
* "Next version" (for things that have been merged but not deployed)
* (a set of lists named after the version numbers e.g. "v1.2.3", "v1.2.2", etc)
* (a divider list starting with `[` and ending with `]` (which might be empty or contain chores done during that time) named after a month or a sprint, e.g. "[ December ]" or "[ Sprint 1st Sep - 13th Sep ]" etc)

And another board where you archive these lists as they become old

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trello_tool', group: :development
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install trello_tool


### Tool Configuration

`bin/trello_tool config` will create a trello_tool.yml file with defaults in it if it doesn't already exist

(This will be in a config directory if you have one, otherwise in the root folder). 
You will want to add this to your repo to allow this to be shared in your project

You need to configure a couple of things:

* `main_board_url` - this will look something like "https://trello.com/b/sOmeBOarDiD/optional-board-name"
* `archive_board_url`

You can also configure some defaults

* `next_version_list_name` = "next version"
* `todo_list_name` = "TO DO"
* `doing_list_name` = "-- DOING --"
* `initial_list_names` = ["Triage", "Reference"]
* `done_list_names` = ["Done"]
* `version_template` = "v%s"
* `divider_template` = "[%s]"
* `too_many_doing` = 2 
* `too_many_todo` = 10
* `default_list_name_for_new_cards` = (none) -- the list `create` puts a card in when no list is named, e.g. "Triage"


### Trello Authorisation

You need to set the following environment variables to give trello_tool access to your lists

* `TRELLO_DEVELOPER_PUBLIC_KEY` -- you can find this at https://trello.com/app-key/
* `TRELLO_MEMBER_TOKEN` -- you can create one at https://trello.com/app-key/ "generate a Token"

You can also read more at https://github.com/jeremytregunna/ruby-trello

## Usage

`bin/trello_tool help` lists every command and `bin/trello_tool help COMMAND` its options. Boards default to
`main_board_url`; cards are given by id or url; lists, labels and checklists by name.

The board:

* `bin/trello_tool health` -- checks whether the main board is "healthy"
* `bin/trello_tool lists (BOARD_URL)` -- the lists of a board
* `bin/trello_tool release (VERSION)`, `archive`, `archive_last (N)` -- rename "next version" on release, and
  move old version lists to the archive board

Reading cards:

* `bin/trello_tool card CARD` -- one card as json (title, description, url, checklists, attachment urls)
* `bin/trello_tool search QUERY (BOARD_URL) (--json)` -- the unarchived cards matching a trello search, grouped by
  list. The query is trello's own, so `label:bug`, `list:"TO DO"` and the like work, and the last word matches as
  a prefix
* `bin/trello_tool cards (BOARD_URL) (--json)` -- every unarchived card in the board, grouped by list
* `bin/trello_tool summarize_as_md`, `summarize_as_md_long`, `summarize_as_urls (LIST_NAME (BOARD_URL))` -- the
  cards of one list

Changing cards:

* `bin/trello_tool comment CARD "text"` or `--file notes.md` -- adds a comment
* `bin/trello_tool create (LIST_NAME (BOARD_URL)) --title "…" (--desc "…" | --desc-file card.md) (--label bug …)
  (--top) (--force)` -- creates a card and prints it as json. Without LIST_NAME it goes in
  `default_list_name_for_new_cards`. It first searches for an unarchived card with the same title and stops with
  that card's url if there is one (`--force` creates another; trello's search can lag a few seconds behind a card
  that was only just created)
* `bin/trello_tool checklist CARD NAME --items "first" "second" (--checked)` -- adds the items to the card's
  checklist of that name, creating the checklist if need be and skipping items already there
* `bin/trello_tool check CARD "item text" (--checklist NAME) (--uncheck)` -- ticks (or unticks) the item with that
  text, or the only item containing it
* `bin/trello_tool move CARD (LIST_NAME (BOARD_URL)) (--top | --bottom)` -- to the bottom (or top) of a list; without
  LIST_NAME, to the top or bottom of the list the card is in
* `bin/trello_tool add_member CARD (MEMBER) (--remove)` -- adds a member of the card's board to the card (or with
  `--remove` takes them off). MEMBER is a username or full name (or a part of the full name only one member has);
  without it, "me", the member the token belongs to. Already there / not there is reported, not an error

A command that can't do what it was asked says why and exits non-zero.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Setup git pre-commit hook

After you clone this repo for the first time you can link in the pre-commit
script so that rubocop is checked before you commit (you can skip the pre-commit hook with )

    ln -nfs $(pwd)/config/githooks/pre-commit ./.git/hooks/pre-commit

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/timdiggins/trello_tool. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/timdiggins/trello_tool/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TrelloTool project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/timdiggins/trello_tool/blob/main/CODE_OF_CONDUCT.md).
