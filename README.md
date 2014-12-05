[![Build Status](https://travis-ci.org/pezra/hal-interpretation.png?branch=master)](https://travis-ci.org/pezra/hal-interpretation)
[![Code Climate](https://codeclimate.com/github/pezra/hal-interpretation.png)](https://codeclimate.com/github/pezra/hal-interpretation)

# HalInterpretation

Build ActiveModels from HAL documents with good error messages
for validity issues.

## Usage

`HalInterpretation` provides a DSL for declaring how to build one or
more `ActiveModel` objects from a HAL document.

```ruby
class UserHalInterpreter
  include HalInterpretation

  item_class User

  extract :name
  extract :address_line, from: "address/line1"
  extract :seq, with: ->(_hal_repr) { next_seq_num }
  extract :birthday, coercion: ->(date_str) { Date.iso8601(date_str) } 

  def initialize
    @cur_seq_num = 0
  end

  protected

  def next_seq_num
    @cur_seq_num += 1
  end
end
```

#### Create

To interpret a HAL document simply create a new interpreter from the
JSON document to interpret and then call its `#items` method.

```ruby
class Users < ApplicationController
  def create
    @users = UserHalInterpreter.new_from_json(request.raw_post).items

    @users.each(&:save!)

  rescue HalInterpretation::InvalidRepresentationError => err
    render template: "shared/error", status: 422, locals: { problems: err.problems }
  end
end
```

The `items` method returns an `Enumerable` of valid `item_class` objects.

#### Update

To update and existing record

```ruby

class Users < ApplicationController
  def update
    existing_user = User.find(params[:id])

    @user = UserHalInterpreter.new_from_json(request.raw_post).only_update(existing_user)
              .item

    @user.save!

  rescue HalInterpretation::InvalidRepresentationError => err
    render template: "shared/error", status: 422, locals: { problems: err.problems }
  end
end
```

### Errors

 If the JSON being interpreted is invalid or malformed
`HalInterpretation` provides a list of the problems encountered
through the `#problems` method. Each problem message includes a
[JSON pointer][] to the exact location in the original document that
caused the problem. This is true even when interpreting
[collections][] for example if name of the third user in a collection
is null the problem message would be

    /_embedded/item/2/name cannot be blank

Validity is determined using the `#valid?` method of the models being
built.


## Installation

Add this line to your application's Gemfile:

    gem 'hal-interpretation'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hal-interpretation

## Contributing

1. Fork it ( http://github.com/pezra/hal-interpretation/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Make your improvement
4. Update the version following [semver][] rules
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create new Pull Request


[semver]: http://semver.org/
[json pointer]: http://tools.ietf.org/html/rfc6901
[collections]: https://tools.ietf.org/html/rfc6573