class SalesforceAdapter
  def initialize(name, uri_or_options)
    super
    @resource_naming_convention = proc do |value|
      value.split("::").last
    end

    @field_naming_convention = proc do |property|
      connection.field_name_for(property.model, property.field.to_s)
    end
  end

  def connection
    @connection ||= Connection.new(options["username"], options["password"], options["path"])
  end

  def create(resources)
    result = connection.create(resources)
    result.size == resources.size
  end

  def update(attributes, collection)
    connection.update(attributes, collection).size == collection.size
  end


  def delete(collection)
    connection.delete(collection).size == collection.size
  end

  def read(query)

    properties = query.fields
    model = query.model

    response = execute_select(query)
    return [] unless response[:records]

    response_records = [response[:records]].flatten

    rows = response_records.inject([]) do |records, record|

      records << properties.inject({}) do |row, property|
        field_name = connection.field_name_for(query.model, property.field).to_s.underscore.to_sym
        row[property.field] = property.typecast(record[field_name])
        row
      end
    end
    model.load(rows, query)
  end

  def aggregate(query)

    response = execute_select(query)
    result = []

    query.fields.each_with_index do |f, i|
      value = response[:records][:"expr#{i}"]
      result << ((value.include? '.') ? value.to_f : value.to_i)
    end
    result
  end

  private
  def execute_select(query)

    statement = SQLQuery.new(query, :select).to_s
    DataMapper.logger.info(statement)

    result = connection.query(statement)
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
