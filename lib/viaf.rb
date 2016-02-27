# This module provides an Interface to the VIAF 

module Viaf

  # A List of VIAF providers sorted by rank
  CONFIG = YAML::load(File.open("config/viaf/person.yml"))
  SELECT_PROVIDER = CONFIG.keys.select{|e| e unless e =~ /marc/}

  # This class provides the main search functionality
  class Interface
    NAMESPACE={'marc' => "http://www.loc.gov/MARC21/slim"}
    require 'rexml/document'
    include REXML
    require 'open-uri'

    def self.search(term, model)
      result = []
      query = JSON.load(open(URI.escape("http://viaf.org/viaf/AutoSuggest?query="+term)))
      r = query["result"].map{|e| e if e['nametype']=='personal'}.compact
      agency = ""
      provider_doc = ""
      r.each do |record|
        SELECT_PROVIDER.each do |provider|
          puts provider
          if record[provider.downcase]
            provider_id=record[provider.downcase]
          else
            next
          end
          provider_url="http://viaf.org/processed/#{provider}%7C#{provider_id}?httpAccept=application/xml"
          begin
            provider_doc = Nokogiri::XML(open(provider_url))
            puts record["displayForm"]
            agency = provider
            if provider_doc.xpath('//marc:datafield[@tag="100"]', NAMESPACE).empty?
              next
            end
            break
          rescue
            next
          end
        end

        viaf_id = record["viafid"]
        node = MarcNode.new(model)
        node.add(MarcNode.new(model, "001", viaf_id))
        node.add(MarcNode.new(model, "024"))
        node.fetch_first_by_tag("024").add(MarcNode.new(model, "a", viaf_id))
        node.fetch_first_by_tag("024").add(MarcNode.new(model, "2", "VIAF"))
        if provider_doc && provider_doc != ""
          CONFIG[agency]["format"].each do |key,v|
            target = v.select{|c| c if c[c.keys.first]["target"]}
            target_tag = target.empty? ? key : target.first[target.first.keys.first]["target"]["tag"]
            break if node.fetch_first_by_tag(target_tag)
            tag = provider_doc.xpath('//marc:datafield[@tag="' + key + '"]', NAMESPACE)
            v.each do |code|
              print code
              subfield_code = code.keys.first
              target_code = code[code.keys.first]["target"] ? code[code.keys.first]["target"]["code"] : code.keys.first
              if tag && tag.xpath('marc:subfield', NAMESPACE).size > 0
                node.add(MarcNode.new(model, target_tag)) unless node.fetch_first_by_tag(target_tag)
                subfield = tag.xpath('marc:subfield[@code="' + subfield_code + '"]', NAMESPACE)
                node.fetch_first_by_tag(target_tag).add(MarcNode.new(model, target_code, subfield.first.content)) unless subfield.empty?
              end
            end
          end
        end
        if node.fetch_first_by_tag("100") 
          marc_json = {"leader" => "01471cjm a2200349 a 4500", "fields" => []}
          node.children.each do |k|
            marc_json["fields"] << k.to_json
          end
          result << marc_json
        end
      end
      return result
    end
  end
end
