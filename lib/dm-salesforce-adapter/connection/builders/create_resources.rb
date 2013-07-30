class CreateResourcesBuilder < ResourcesBuilder

  def build xml

    resources.each do |resource|

      xml.sObjects(:'xsi:type' => storage_name_for(resource)) do

        attributes.each do |field, property|

          next unless field && property
          value = data[:attributes][property]

          field_name = field[:name].to_sym

          next if field_name == :Id || !field[:createable]

          if value.nil? || value.to_s.empty?

            if field[:nillable]
              xml.fieldsToNull(field_name.to_s)
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
