# Gobierto data

Gobierto data is a Ruby gems that contains some classes, constants and helpers to help load data
into [Gobierto](https://gobierto.es) instances.

## How to use this gem

Add this line to your `Gemfile`:

`gem "gobierto_data"`

## Requirements

You should define the following environment variables

- `GOBIERTO_S3_BUCKET_NAME`: S3 bucket name where files will be uploaded
- `GOBIERTO_AWS_REGION`: S3 region name
- `GOBIERTO_AWS_ACCESS_KEY_ID`: S3 access key
- `GOBIERTO_AWS_SECRET_ACCESS_KEY`: S3 secret key
- `ELASTICSEARCH_URL`: Elasticsearch URL
- `POPULATE_DATA_URL`
- `POPULATE_DATA_TOKEN`
- `POPULATE_DATA_ORIGIN`
