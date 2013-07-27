class ResourcesBuilder < ObjectsBuilder
  def resources
    data[:resources] ||= []
  end

  def attributes

    resource = resources.first || raise('No resources given')

    if !data[:attributes] || data[:attributes].empty?
      att_names = resource.class.properties.map(&:field)
    else
      att_names = data[:attributes].map {|a| a.first.field}
    end

    att_names |= [:Id]

    att_names.inject({}) do |res, f|

      field = connection.field_for(resource.class, f)

      DataMapper.logger.info field

      unless field
        field = resource.class.relationships.each do |rel|

          next unless rel.is_a?(DataMapper::Associations::ManyToOne::Relationship)
          child_key = rel.child_key.find {|k| k.name == f.to_sym}
          break connection.field_for(resource.class, child_key.field) if child_key
        end
      end

      raise "Cant find sf field named '#{f}'" unless field
      res[field] = resource.class.properties.find {|p| p.field == f}
      res
    end
  end

  def storage_name_for resource
    connection.storage_name resource
  end
end
