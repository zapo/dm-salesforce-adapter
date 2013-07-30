class UpsertResourcesBuilder < ResourcesBuilder

  def build xml

    external_id_pair = attributes.find {|f, v| f[:external_id] == true}
    raise 'No external_id attribute specified for this resource on salesforce, cant upsert.' unless external_id_pair

    xml.externalIDFieldName(external_id_pair.first[:name])

    resources.each do |resource|

      xml.sObjects(:'xsi:type' => storage_name_for(resource)) do

        attributes.each do |field, property|
          value = data[:attributes][property]

          if property.name == :Id
            value = resource[:Id]
          end

          next unless field && property

          field_name = field[:name].to_sym

          if value.nil? || value.to_s.empty?

            if field[:nillable]
              xml.fieldsToNull(field_name.to_s) unless field_name == :Id
            elsif field[:createable] && field[:updateable]
              xml.tag!(field_name, property.default)
            end

          else
            if field[:type].to_sym == :reference
              next unless resource.class.relationships.map(&:parent_model).map(&:storage_name).include?(field[:reference_to])
              rel_fields = connection.description(field[:reference_to])
              rel_external_id = rel_fields.find {|f| f[:external_id] == true} if rel_fields

              msg =  "External ID not found for #{field[:reference_to]}"
              msg << " when upserting #{storage_name_for(resource)} on its #{field[:reference_to]} relationship(s)" unless rel_external_id

              xml.tag!(field[:relationship_name]) do
                xml.tag!(rel_external_id[:name], property.typecast(value))
              end
            elsif field[:createable] && field[:updateable]
              xml.tag!(field_name, property.typecast(value))
            end
          end
        end
      end
    end
  end
end
