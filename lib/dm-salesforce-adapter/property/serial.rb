module SalesforceAdapter::Property
  class Serial < ::DataMapper::Property::String
    accept_options :serial
    serial true

    def dump(value)
      value unless value.blank?
    end
  end
end
