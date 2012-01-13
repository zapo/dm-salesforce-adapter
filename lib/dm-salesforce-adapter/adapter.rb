class SalesforceAdapter
  include SQL

  def initialize(name, uri_or_options)
    super
    @resource_naming_convention = proc do |value|
      value.split("::").last
    end
    
    @field_naming_convention = proc do |property|
      connection.field_name_for(property.model.storage_name(name), property.name.to_s)
    end
  end

  def connection
    @connection ||= Connection.new(options["username"], options["password"], options["path"])
  end

  # FIXME: DM Adapters customarily throw exceptions when they experience errors,
  # otherwise failed operations (e.g. Resource#save) still return true and thus
  # confuse the caller.
  #
  # Someone needs to make a decision about legacy support and the consequences
  # of changing the behaviour from broken-but-typical to
  # correct-but-maybe-unexpected.  Maybe a config file option about whether to
  # raise exceptions or for the user to always check Model#valid? +
  # Model#salesforce_errors?
  #
  # Needs to be applied to all CRUD operations.
  def create(resources)

    result = connection.create(resources)
    result.size == resources.size

#  rescue Connection::SOAPError => e
#    handle_server_outage(e)
  end

  def update(attributes, collection)
    connection.update(attributes, collection).size == collection.size
  rescue Connection::SOAPError => e
    handle_server_outage(e)
  end
  

  def delete(collection)
    connection.delete(collection).size == collection.size

  rescue Connection::SOAPError => e
    handle_server_outage(e)
  end

  def handle_server_outage(error)
    if error.server_unavailable?
      raise Connection::ServerUnavailable, "The salesforce server is currently unavailable"
    else
      raise error
    end
  end

  # Reading responses back from SELECTS:
  #   In the typical case, response.size reflects the # of records returned.
  #   In the aggregation case, response.size reflects the count.
  #
  # Interpretation of this field requires knowledge of whether we are expecting
  # an aggregate result, thus the response from execute_select() is processed
  # differently depending on invocation (read vs. aggregate).
  def read(query)
    
    properties = query.fields
    repository = query.repository
    model = query.model
    storage_name = model.storage_name(repository.name)

    response = execute_select(query)
    return [] unless response[:records]

    response_records = [response[:records]].flatten

    rows = response_records.inject([]) do |records, record|

      records << properties.inject({}) do |row, property|
        field_name = connection.field_name_for(storage_name, property.field).to_s.to_sym
        row[property.field] = property.typecast(record[field_name.downcase])
        row
      end
    end
    
    model.load(rows, query)
  end

  # http://www.salesforce.com/us/developer/docs/api90/Content/sforce_api_calls_soql.htm
  # SOQL doesn't support anything but count(), so we catch it here and interpret
  # the result.  Requires 'dm-aggregates' to be loaded.
  def aggregate(query)
    query.fields.each do |f|
      unless f.target == :all && f.operator == :count
        raise ArgumentError, %{Aggregate function #{f.operator} not supported in SOQL}
      end
    end

    [ execute_select(query).size ]
  end

  private
  def execute_select(query)
        
    repository = query.repository
    conditions = query.conditions.map {|c| conditions_statement(c, repository)}.compact.join(") AND (")

    fields = query.fields.map do |f|
      case f
      when DataMapper::Property
        f.field
      when DataMapper::Query::Operator
        %{#{f.operator}()}
      else
        raise ArgumentError, "Unknown query field #{f.class}: #{f.inspect}"
      end
    end.join(", ")
    
    sql = "SELECT #{fields} FROM #{query.model.storage_name(repository.name)}"
    sql << " WHERE (#{conditions})" unless conditions.empty?
    sql << " ORDER BY #{order(query.order[0])}" unless query.order.nil? or query.order.empty?
    sql << " LIMIT #{query.limit}" if query.limit

    result = connection.query(sql)
    done = result[:done]
    locator = result[:query_locator]
    
    while(!done)

      more_result = connection.query_more(locator)
      done        = more_result[:done]
      locator     = more_result[:query_locator]
      
      result[:records] += more_result[:records]
    end
    
    result
  end
end


