require 'dm-salesforce-adapter/connection/errors'

class SalesforceAdapter
  
  class ObjectsBuilder < Struct.new(:data, :connection); end
  
  class UpdateObjectsBuilder < ObjectsBuilder
    
    def data
      super || {}
    end
    
    def to_proc

      proc do |xml|
        body = nil

        default = {
          :resources => [], 
          :attributes => []
        }
        _data = default.merge(data)

        _data[:resources].each do |resource|
          storage_name = resource.class.storage_name(resource.repository.name)
          body = xml.sObjects(:'xsi:type' => storage_name) do

            att_names = _data[:attributes].map {|a| a.first.name} | [:Id]
            
            attributes = resource.attributes.find_all {|name, value| att_names.include?(name)}
            attributes.each do |field, value|
              field = connection.field_name_for(storage_name, field).to_sym
              if value.nil? or value.empty?
                xml.fieldsToNull(field)
              else
                xml.__send__(field, value.to_s)
              end
            end
          end
        end
        body
      end
    end    
  end
  
  class DeleteObjectsBuilder < ObjectsBuilder
    def to_proc
      proc do |xml|
        body = nil
        
        data.each do |key|
          body = xml.ids key
        end
        body
      end
    end
  end
  
  class Connection
    include Errors

    def initialize(username, password, wsdl_path, organization_id = nil)
      @username, @password, @organization_id = URI.unescape(username), password, organization_id
      @driver = Savon::Client.new(wsdl_path)
      @descriptions = {}
      login
    end
    
    def description klass_name
      @descriptions[klass_name.to_sym] ||= describe klass_name
    end
    
    def sf_id_for resource
      query_string = "SELECT Id FROM #{resource.class.storage_name(resource.repository.name)}"
      query_string << " WHERE #{resource.class.key.map {|k| "#{k.field} = #{k.get(resource)}"}.join(') AND (')} LIMIT 1"

      result = query(query_string)
      if result[:records].is_a? Hash
        result[:records][:id]
      end
    end

    def field_name_for(klass_name, column)
      fields = [column, Inflector.camelize(column.to_s), "#{Inflector.camelize(column.to_s)}__c", "#{column}__c".downcase]
      options = /^(#{fields.join("|")})$/i
      
      field = description(klass_name).find {|col| col[:name].to_s.match(options) }
      
      return field[:name] if field
      
      raise FieldNotFound,
        "You specified #{column} as a field, but none of the expected field names exist: #{fields.join(", ")}. " \
        "Either manually specify the field name with :field, or check to make sure you have " \
        "provided a correct field name."
      
    end
    
    
    def session_headers ns = 'wsdl'
      {"#{ns}:SessionHeader" => {"#{ns}:sessionId" => @session_id}}
    end
    
    def login_scope_headers ns = 'wsdl'
      {"#{ns}:LoginScopeHeader" => {"#{ns}:organizationId" => @organization_id}} 
    end

    def query(string)
      result = driver.request :query do
        soap.header = session_headers
        soap.body = {:queryString => string}
      end
      
      result.to_hash[:query_response][:result]
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

      result = driver.request :wsdl, :describe_s_object do
        soap.header = session_headers
        soap.body =  {'wsdl:sObjectType' => klass_name}
      end

      result.to_hash[:describe_s_object_response][:result][:fields].inject([]) do |fields, f|

        type = f[:type].to_s.to_sym
        type = (field_map[type] if field_map.has_key?(type)) || ::DataMapper::Property::String

        fields << {:name => f[:name], :type => type}
        fields
      end
    end
    
    def prepare_resources resources
      resources.each do |resource|
        description resource.class.storage_name(resource.repository.name)
      end
    end

    def create(resources)
      prepare_resources(resources)
      call_api(:create, CreateError, "creating", &UpdateObjectsBuilder.new({:resources => resources}, self))
    end

    def update(attributes, resources)
      prepare_resources(resources)
      
      resources.each do |resource|
        raise FieldNotFound.new('Id'), resource unless resource.respond_to? :Id
        resource[:Id] = sf_id_for(resource) unless resource[:Id].nil? or resource[:Id].empty?
      end
      
      call_api(:update, UpdateError, "updating", &UpdateObjectsBuilder.new({:resources => resources, :attributes => attributes}, self))
    end

    def delete(collection)
      
      keys  = collection.map do |r| 
        if r.respond_to?(:Id)
          r.Id
        else
          connection.sf_id_for r
        end

      end.flatten.uniq
      
      call_api(:delete, DeleteError, "deleting", &DeleteObjectsBuilder.new(keys, self))
    end

    private
    def driver; @driver; end

    def login
      username, password = @username, @password

      result = driver.request :login do
        soap.body = {:username => username, :password => password}
      end

      response = result.to_hash[:login_response][:result] || {}
      response.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
      
      driver.wsdl.endpoint = @server_url
      driver
    end

    def call_api(method, exception_class, message, args = nil, &block)
      result = driver.request method.to_sym do
        soap.header = session_headers
        
        if args
          case 
          when args.kind_of?(Enumerable)
            soap.body = args
          when args.kind_of?(Proc)
            soap.body do |xml|
              args.call xml
            end
          end
        end
        
        soap.body &block if block
      end
            
      result = [result.to_hash["#{method}_response".to_sym][:result]].flatten
                  
      if result.all? {|r| r[:success]}
        result
      else
        # TODO: be smarter about exceptions here
        raise exception_class.new(message, result)
      end
    end
    
    def with_reconnection(&block)
      yield
    end
  end
end
