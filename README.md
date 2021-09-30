# Gobierto data

Gobierto data is a Ruby gems that contains some classes, constants and helpers to help load data
into [Gobierto](https://gobierto.es) instances.

## How to use this gem

Add this line to your `Gemfile`:

`gem "gobierto_budgets_data"`

## Requirements

You should define the following environment variables in the application:

- `GOBIERTO_S3_BUCKET_NAME`: S3 bucket name where files will be uploaded
- `GOBIERTO_AWS_REGION`: S3 region name
- `GOBIERTO_AWS_ACCESS_KEY_ID`: S3 access key
- `GOBIERTO_AWS_SECRET_ACCESS_KEY`: S3 secret key
- `ELASTICSEARCH_URL`: Elasticsearch URL
- `ELASTICSEARCH_WRITING_URL`: Elasticsearch URL with write enabled
- `POPULATE_DATA_URL`: Populate Data URL for automatic updates
- `POPULATE_DATA_TOKEN`: Populate Data token for automatic updates
- `POPULATE_DATA_ORIGIN`: Populate Data origin for automatic updates

If you want to load Rake tasks you should include this snippet in the `Rakefile`:

```
# Load tasks from gobierto_budgets_data
spec = Gem::Specification.find_by_name "gobierto_budgets_data"
load "#{spec.gem_dir}/lib/tasks/data.rake"
```
