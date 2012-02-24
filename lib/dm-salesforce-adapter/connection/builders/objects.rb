class ObjectsBuilder < Struct.new(:data, :connection); 
  
  def data
    super || {}
  end
  
  def build xml
    raise 'This is an abstract class'
  end
  
  def connection
    super || raise('No Connection given')
  end
  
  def to_proc
    proc {|xml| build(xml); xml.target!}
  end
end