class DeleteResourcesBuilder < ResourcesBuilder
  def build xml  
    data.each do |key|
      xml.ids key
    end
  end
end