## Make the JSON manifest for the images
## it reads a yml file with the image list
## so the images do not need to be stored on the same system
## and the other system does not need a rails installation
## The YAML is simply a listing of the files + the record in
## for example this script:

# require 'yaml'
#
# out = {}
# ARGV.each do |dir|
#   images = Dir.entries(dir).select{|x| x.match("tif") }.sort
#   out[dir] = images
# end

# File.write("dirs.yml", out.to_yaml)
#####

require 'awesome_print'
require 'iiif/presentation'
require 'yaml'

module Faraday
  module NestedParamsEncoder
    def self.escape(arg)
			#puts "NOTICE - UNESCAPED URL NestedParamsEncoder"
      arg
    end
  end
  module FlatParamsEncoder
    def self.escape(arg)
			#puts "NOTICE - UNESCAPED URL FlatParamsEncoder"
      arg
    end
  end
end

#IIF_PATH="http://d-lib.rism-ch.org/cgi-bin/iipsrv.fcgi?IIIF=/usr/local/images/ch/"
# Should not have a trailing slash!
IIIF_PATH="https://iiif.rism.digital"

if ARGV[0].include?("yml")
  dirs  = YAML.load_file(ARGV[0])
else
  dirs = ARGV
end

dirs.keys.each do |dir|

  #next if !dir.include? "400008043"

  source = nil
  title = "Images for #{dir}"
  
  if dirs.is_a? Array
    images = Dir.entries(dir).select{|x| x.match("tif") }.sort
  else
    images = dirs[dir].sort
  end
  
  if images.length == 0
    puts "no images in #{dir}"
    next
  end
  
  print "Attempting #{dir}... "
  
  # If running in Rails get some ms info
  if defined?(Rails)
    id = dir
    toks = dir.split("-")
    ## if it contains the -xxx just get the ID
    id = toks[0] if toks != [dir]
    begin
      source = Source.find(dir)
    rescue ActiveRecord::RecordNotFound
      puts "SOURCE #{dir} not found".red
      next
    end
    title = source.title
    country = "ch" # TODO: Figure out country code from siglum
  end

  if File.exist?(country + "/" + dir + '.json')
    puts "already exists, skip"
    next
  end

  manifest_id = "#{IIIF_PATH}/manifest/#{country}/#{dir}.json"

  # Create the base manifest file
  related = {
    "@id" => "https://www.rism-ch.org/catalog/#{dir}",
    "format" => "text/html",
    "label" => "RISM Catalogue Record"
  }
  seed = {
      '@id' => manifest_id,
      'label' => title,
      'related' => related
  }
  # Any options you add are added to the object
  manifest = IIIF::Presentation::Manifest.new(seed)
  sequence = IIIF::Presentation::Sequence.new
  manifest.sequences << sequence
  
  images.each_with_index do |image_name, idx|
    canvas = IIIF::Presentation::Canvas.new()
    canvas['@id'] = "#{IIIF_PATH}/canvas/#{country}/#{dir}/#{image_name.chomp(".tif")}"
    canvas.label = "[Image #{idx + 1}]"
    
    image_url = "#{IIIF_PATH}/image/#{country}/#{dir}/#{image_name}"
    
    image = IIIF::Presentation::Annotation.new
    image["on"] = canvas['@id']
    image["@id"] = "#{IIIF_PATH}/annotation/#{country}/#{dir}/#{image_name.chomp(".tif")}"
    ## Uncomment these two prints to see the progress of the HTTP reqs.

    #begin
      image_resource = IIIF::Presentation::ImageResource.create_image_api_image_resource(service_id: image_url, resource_id:"#{image_url}/full/full/0/default.jpg")
    #rescue
    #  puts "Not found #{image_url}"
    #end

    print "."
    image.resource = image_resource
    
    canvas.width = image.resource['width']
    canvas.height = image.resource['height']
    
    canvas.images << image
    sequence.canvases << canvas
    
    # Some obnoxious servers block you after some requests
    # may also be a server/firewall combination
    # comment this if you are positive your server works
    #sleep 0.1
  end
  
  #puts manifest.to_json(pretty: true)
  File.write(country + "/" + dir + '.json', manifest.to_json(pretty: true))
  puts "Wrote #{country}/#{dir}.json"
  next
  if source
    marc = source.marc
    marc.load_source true

    # The source can contain more than one 856
    # as some sources have more image groups
    # -01 -02 etc
    new_tag = MarcNode.new("source", "856", "", "##")
    new_tag.add_at(MarcNode.new("source", "x", "IIIF", nil), 0)
    new_tag.add_at(MarcNode.new("source", "u", manifest_id, nil), 0)

    pi = marc.get_insert_position("856")
    marc.root.children.insert(pi, new_tag)
  
    source.save!
  end

end
