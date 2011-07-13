module SalesforceAdapter::Property
  class Serial < ::DataMapper::Property::String
    accept_options :serial
    serial true

    length 15

    def dump(value)
      value[0..14] unless value.blank?
    end
  end
end
