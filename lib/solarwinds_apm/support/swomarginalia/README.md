# swomarginalia

This folder contains the code that is copied from original [marginalia](https://github.com/basecamp/marginalia)

## File structure

```console
|-- swomarginalia
|   |-- LICENSE
|   |-- README.md
|   |-- comment.rb
|   |-- railtie.rb
|   |-- load_swomarginalia.rb
|   `-- swomarginalia.rb
```

## Modification

### railitie.rb

1. Moved prepend logic into load_swomarginalia.rb in case that non-rails app using activerecord

### swomarginlia.rb

1. Removed the alias_method to achieve function override; instead, we use prepend.
2. Added step of cleaning-up previous transparent comments

### comment.rb

1. Added the traceparent comment (trace string constructed based on opentelemetry)

### load_swomarginalia.rb

1. (new file) prepend the ActiveRecordInstrumentation to activerecord adapter

### annotation.rb
1. (new file) utilize comment file append the generated traceparent data into sql
2. If sql already contains the same comments, then it won't inject again

## Example

### Sample output of rails application

```console
Post Load (1.1ms)  SELECT `posts`.* FROM `posts` /*application=SqlcommenterRailsDemo,controller=posts,action=index,traceparent=00-a448f096d441e167d12ebd32a927c1a5-a29655a47e430119-01*/
```

## License

This project is licensed under the [MIT License](https://github.com/solarwinds/apm-ruby/blob/main/lib/solarwinds_apm/support/swomarginalia/LICENSE).
