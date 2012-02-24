class SalesforceAdapter::Connection
  module Errors
    class FieldNotFound     < StandardError
      def initialize(field, resource)
        super("Field \"#{field}\" not defined for resource #{resource}")
      end
    end

    class SOAPError      < StandardError
      def initialize(method, message)
        super("#{method}: #{message}")
      end
    end
    
    class RequestLimitExceeded < SOAPError
    end
  end
end
