class UpdateResourcesBuilder < ResourcesBuilder

  def build xml

    resources.each do |resource|
            
      xml.sObjects(:'xsi:type' => storage_name_for(resource)) do

        attributes.each do |field, property|
                        
          next unless field && property
          value = property.get(resource)
          
          field_name = field[:name].to_sym
          
          next if field_name != :Id && !field[:updateable]
          
          if value.nil? || value.to_s.empty?
            if field[:nillable]
              xml.fieldsToNull(field_name.to_s) unless field_name == :Id
            else
              xml.tag!(field_name, property.default)
            end
          else
            xml.tag!(field_name, property.typecast(value))
          end
        end
      end
    end 
  end
end