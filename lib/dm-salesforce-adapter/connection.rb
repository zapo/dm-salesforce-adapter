class SalesforceAdapter

  class Connection
    include Errors

    attr_reader :descriptions

    def initialize(username, password, wsdl_path, organization_id = nil)
      @username, @password, @organization_id = URI.unescape(username), password, organization_id


      @descriptions = {}
      @wsdl_path = wsdl_path
      login
    end


    def description model
      storage_name = storage_name(model)
      @descriptions[storage_name.to_sym] ||= describe(storage_name)
    end

    def storage_name model
      model = case
      when model.kind_of?(String)                            then return model
      when model.kind_of?(::DataMapper::Resource)            then model.class
      when model.is_a?(Class)                                then model
      end

      model.storage_name(model.repository.name)
    end

    def sf_id_for resource

      id_prop = resource.class.properties.find {|p| p.name == :Id}

      return id_prop.get(resource) if id_prop

      query_string = "SELECT Id FROM #{storage_name(resource.class)}"
      query_string << " WHERE #{resource.class.key.map {|k| "#{k.field} = #{k.get(resource)}"}.join(') AND (')} LIMIT 1"

      result = query(query_string)
      if result[:records].is_a? Hash
        result[:records][:id]
      end
    end

    def field_name_for(model, column)
      field = field_for(model, column)
      field[:name] if field
    end


    def field_for(model, column)
      fields = [column, Inflector.camelize(column.to_s), "#{Inflector.camelize(column.to_s)}__c", "#{column}__c".downcase]
      options = /^(#{fields.join("|")})$/i

      field = description(model).find {|col| col[:name].to_s.match(options) }

      return field
    end


    def session_headers
      {"SessionHeader" => {"sessionId" => @session_id}}
    end

    def login_scope_headers
      {"LoginScopeHeader" => {"organizationId" => @organization_id}}
    end

    def client
    end

    def query(string)
      result = Savon.client(savon_defaults.merge(:endpoint => @server_url, :headers => session_headers)).call :query do
        message(:queryString => string)
      end

      result.to_hash[:query_response][:result]
    end

    def query_more(locator)
      result = Savon.client(savon_defaults.merge(:endpoint => @server_url, :headers => session_headers)).call :query_more do
        message(:queryLocator => locator)
      end

      result.to_hash[:query_more_response][:result]
    end

    def describe(klass_name)
      field_map = {
        :id                                    => ::DataMapper::Property::Serial,
        :string                                => ::DataMapper::Property::String,
        :reference                             => ::DataMapper::Property::String,
        :phone                                 => ::DataMapper::Property::String,
        :url                                   => ::DataMapper::Property::String,
        :textarea                              => ::DataMapper::Property::Text,
        :boolean                               => ::DataMapper::Property::Boolean,
        :datetime                              => ::DataMapper::Property::DateTime,
        :date                                  => ::DataMapper::Property::Date,
        :double                                => ::DataMapper::Property::Decimal
      }

      result = Savon.client(savon_defaults.merge(:endpoint => @server_url, :headers => session_headers)).call :describe_s_object do
        message('sObjectType' => klass_name)
      end

      fields = result.to_hash[:describe_s_object_response][:result][:fields]

      fields.each do |f|
        type = f[:type].to_s.to_sym
        type = (field_map[type] if field_map.has_key?(type)) || ::DataMapper::Property::String
        f[:dmtype] = type
      end

      fields
    end

    def prepare_resources resources

      resources.map(&:class).uniq.compact.each {|klass| description(klass)}
      resources.map(&:class).uniq.compact.map(&:relationships).flatten.
        find_all {|r| r.is_a?(DataMapper::Associations::ManyToOne::Relationship)}.each do |r|
          description(r.parent_model.storage_name)
      end
    end

    def with_sf_limits_for resources, &block
      result = []
      resources.each_slice(200).to_a.each do |res|
        result << block.call(res)
      end
      result.flatten
    end

    def updatables? resources
      resources.each do |resource|
        raise FieldNotFound.new('Id', resource) unless resource.respond_to? :Id
        resource[:Id] = sf_id_for(resource)
      end
      true
    rescue FieldNotFound
      false
    end

    def upsertables? resources
      resources.all? {|r| description(r.class).any? {|col| col[:external_id] == true }}
    rescue
      false
    end

    def builder_for resources, method
      builder = if upsertables?(resources)
        UpsertResourcesBuilder
      else
        method == :update ? UpdateResourcesBuilder : CreateResourcesBuilder
      end

      raise 'No builder found' unless builder
      builder
    end

    def create(resources)
      prepare_resources(resources)

      builder = builder_for resources, :create
      method  = builder == UpsertResourcesBuilder ? :upsert : :create

      with_sf_limits_for resources do |res|
        result = call_api(method, &builder.new({:resources => res}, self))
        if method == :create
          res.each_with_index do |r, i|
            r.Id = result[i][:id]
          end
        end
      end
    end

    def update(attributes, resources)
      prepare_resources(resources)

      builder = builder_for resources, :update
      method  = builder == UpsertResourcesBuilder ? :upsert : :update

      with_sf_limits_for resources do |res|
        res.each do |resource|
          resource[:Id] = sf_id_for(resource) if method == :update
        end

        call_api(method, &builder.new({:resources => res, :attributes => attributes}, self))
      end
    end

    def delete(collection)
      with_sf_limits_for collection do |resources|
        keys  = resources.map {|r| sf_id_for r }
        call_api(:delete, &DeleteResourcesBuilder.new(keys, self))
      end
    end

    private
    def savon_defaults
      @savon_defaults ||= {
        :logger    => DataMapper.logger.dup,
        :log_level => :info,
        :wsdl      => wsdl_path
      }
    end

    def login
      username, password = @username, @password

      result = Savon.client(savon_defaults).call :login do
        message(:username => username, :password => password)
      end

      response = result.to_hash[:login_response][:result] || {}
      DataMapper.logger.info response
      response.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
    end

    def call_api(method, args = nil, &block)

      body = args || block

      if body.kind_of? Proc
        body = body.call(Builder::XmlMarkup.new).to_s
      end

      result = Savon.client(savon_defaults.merge(:endpoint => @server_url, :headers => session_headers)).call method.to_sym do
        message(body)
      end

      hash_result = result.to_hash
      response = hash_result["#{method}_response".to_sym]
      response = [response[:result]].flatten if response && response[:result]

      raise "Unhandled response: #{result.to_xml}, was expecting a '#{method}_response'" unless response

      if response.all? {|r| r[:success]}
        response
      else
        response.reject {|r| r[:success]}.map {|r| r[:errors]}.flatten.each do |e|

          status_code = e[:status_code].underscore.classify

          if !Errors.const_defined?(status_code)
            Errors.const_set(status_code, Class.new(SOAPError))
          end

          raise Errors.const_get(status_code).new(method, "#{e[:message]}")
        end
      end
    rescue Savon::SOAP::Fault => soap_fault
       message = soap_fault.message
       status_code = soap_fault.class.name.split(':').last.underscore.classify

       if !Errors.const_defined?(status_code)
         Errors.const_set(status_code, Class.new(SOAPError))
       end

       raise Errors.const_get(status_code).new(method, message)
    end

    def wsdl_path
      @wsdl_path
    end
  end
end
