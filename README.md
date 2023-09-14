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


### Trello Authorisation

You need to set the following environment variables to give trello_tool access to your lists

* `TRELLO_DEVELOPER_PUBLIC_KEY` -- you can find this at https://trello.com/app-key/
* `TRELLO_MEMBER_TOKEN` -- you can create one at https://trello.com/app-key/ "generate a Token"

You can also read more at https://github.com/jeremytregunna/ruby-trello

## Usage

* bin/trello/health
trello/health

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/timdiggins/trello_tool. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/timdiggins/trello_tool/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TrelloTool project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/timdiggins/trello_tool/blob/main/CODE_OF_CONDUCT.md).
