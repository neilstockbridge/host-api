
# Host API plugins

 + A plugin is a `.rb` file in `/usr/share/host-api/plugins` that is referenced by `/etc/host-api.yml`
 + The `.rb` defines a single module named after the file but camelized
 + The module:
  + Defines the methods for export as class methods
  + Defines the `NAMESPACE` that clients should use when requesting a context
  + Defines the names of the parameters of each exported method ( and thus which methods in the module should be exported)

## Example

```ruby
module System

  NAMESPACE = "com.example.Calculator"

  PARAMS_OF_METHOD = {
    "add" =>    %w|a b|,
    "negate" => %w|n|,
  }

  class << self

    def add a, b
      a + b
    end

    def negate n
      - n
    end

    def private_method
    end

  end # of class methods
end


```

