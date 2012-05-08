require 'data_objects'
require 'dm-core'
require 'dm-types'
require 'dm-validations'

class SalesforceAdapter < ::DataMapper::Adapters::AbstractAdapter
  Inflector = ::DataMapper::Inflector
end

require 'savon'
require 'dm-salesforce-adapter/resource'
require 'dm-salesforce-adapter/connection/errors'
require 'dm-salesforce-adapter/connection/builders'
require 'dm-salesforce-adapter/connection'
require 'dm-salesforce-adapter/sql_query'
require 'dm-salesforce-adapter/version'
require 'dm-salesforce-adapter/adapter'
require 'dm-salesforce-adapter/property'

Savon.configure do |config|
  config.log_level = :info
  config.log       = DataMapper.logger.dup
end

HTTPI.adapter = :httpclient


# For convenience (WRT the examples)
module DataMapper::Salesforce
    Resource = SalesforceAdapter::Resource
end

::DataMapper::Adapters::SalesforceAdapter = SalesforceAdapter
::DataMapper::Adapters.const_added(:SalesforceAdapter)
