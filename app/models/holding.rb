class Holding < ApplicationRecord
  include ForeignLinks
  resourcify

  # class variables for storing the user name and the event from the controller
  @last_user_save
  attr_accessor :last_user_save
  @last_event_save
  attr_accessor :last_event_save
  
  has_paper_trail :on => [:update, :destroy], :only => [:marc_source], :if => Proc.new { |t| VersionChecker.save_version?(t) }

  has_and_belongs_to_many :institutions
  belongs_to :source
	belongs_to :collection, {class_name: "Source", foreign_key: "collection_id"}
  has_many :folder_items, as: :item, dependent: :destroy
  belongs_to :user, :foreign_key => "wf_owner"
  
  has_and_belongs_to_many :people, join_table: "holdings_to_people"
  has_and_belongs_to_many :catalogues, join_table: "holdings_to_catalogues"
  has_and_belongs_to_many :places, join_table: "holdings_to_places"
	
  composed_of :marc, :class_name => "MarcHolding", :mapping => %w(marc_source to_marc)
  
  before_save :set_object_fields
  after_create :scaffold_marc, :fix_ids
  after_save :update_links, :update_774, :reindex
  after_initialize :after_initialize
  before_destroy :update_links
  
  
  attr_accessor :suppress_reindex_trigger
  attr_accessor :suppress_scaffold_marc_trigger
  attr_accessor :suppress_recreate_trigger
  attr_accessor :suppress_update_count_trigger

  def after_initialize
    @old_collection = nil
    @last_user_save = nil
    @last_event_save = "update"
  end

  # Suppresses the solr reindex
  def suppress_reindex
    self.suppress_reindex_trigger = true
  end

  def suppress_scaffold_marc
    self.suppress_scaffold_marc_trigger = true
  end
  
  def suppress_recreate
    self.suppress_recreate_trigger = true
  end 
  
  def suppress_update_count
    self.suppress_update_count_trigger = true
  end
  
  def fix_ids
    #generate_new_id
    # If there is no marc, do not add the id
    return if marc_source == nil

    # The ID should always be sync'ed if it was not generated by the DB
    # If it was scaffolded it is already here
    # If we imported a MARC record into Person, it is already here
    # THis is basically only for when we have a new item from the editor
    marc_source_id = marc.get_marc_source_id
    if !marc_source_id or marc_source_id == "__TEMP__"

      self.marc.set_id self.id
      self.marc_source = self.marc.to_marc
      PaperTrail.request(enabled: false) do
        save
      end
    end
  end
  
  def update_links
    return if self.suppress_recreate_trigger == true
    
    allowed_relations = ["institutions", "catalogues", "people", "places"]
    recreate_links(marc, allowed_relations)
  end
  
  
  def scaffold_marc
    return if self.marc_source != nil  
    return if self.suppress_scaffold_marc_trigger == true
 
    new_marc = MarcCatalogue.new(File.read(ConfigFilePath.get_marc_editor_profile_path("#{Rails.root}/config/marc/#{RISM::MARC}/holding/default.marc")))
    new_marc.load_source true
    
    node = MarcNode.new("holding", "852", "", "##")
    node.add_at(MarcNode.new("holding", "a", self.lib_siglum, nil), 0)
    
    new_marc.root.children.insert(new_marc.get_insert_position("852"), node)

    if self.id != nil
      new_marc.set_id self.id
    end
    
    self.marc_source = new_marc.to_marc
    self.save!
  end


  def set_object_fields
    # This is called always after we tried to add MARC
    # if it was suppressed we do not update it as it
    # will be nil
    return if marc_source == nil
    
    # parent collection source
    collection = marc.get_parent
    # If the 973 link is removed, clear the source_id
    # But before save it so we can update the parent
    # source.
    @old_collection = collection_id if !collection || collection.id != collection_id
    self.collection_id = collection ? collection.id : nil

    # If the source id is present in the MARC field, set it into the
    # db record
    # if the record is NEW this has to be done after the record is created
    marc_source_id = marc.get_marc_source_id
    # If 001 is empty or new (__TEMP__) let the DB generate an id for us
    # this is done in create(), and we can read it from after_create callback
    self.id = marc_source_id if marc_source_id and marc_source_id != "__TEMP__"

    # "Tell fields"
    self.lib_siglum = marc.get_lib_siglum
    
    self.marc_source = self.marc.to_marc
  end
  

  def update_774
    
    # We do NOT have a parent ms in the 773.
    # but we have it in old_parent, it means that
    # the 773 was deleted or modified. Go into the parent and
    # find the reference to the id, then delete it
    if @old_collection
      
      parent_manuscript = Source.find_by_id(@old_collection)
      return if !parent_manuscript
      modified = false
      
      parent_manuscript.paper_trail_event = "Remove 774 link #{id.to_s}"
      
      # check if the 774 tag already exists
      parent_manuscript.marc.each_data_tag_from_tag("774") do |tag|
        subfield = tag.fetch_first_by_tag("w")
        next if !subfield || !subfield.content
        if subfield.content.to_i == id
          puts "Deleting 774 $w#{subfield.content} for #{@old_collection}, from #{id}"
          tag.destroy_yourself
          modified = true
        end
        
      end
      
      if modified
        parent_manuscript.suppress_update_77x
        parent_manuscript.save
        @old_collection = nil
      end
      
    end
    
    # do we have a parent manuscript?
    parent_manuscript_id = marc.first_occurance("973", "u")
    
    # NOTE we evaluate the strings prefixed by 00000
    # as the field may contain legacy values
    
    if parent_manuscript_id
      # We have a parent manuscript in the 773
      # Open it and add, if necessary, the 774 link
    
      parent_manuscript = Source.find_by_id(parent_manuscript_id.content)
      return if !parent_manuscript
      
      parent_manuscript.paper_trail_event = "Add 774 link #{id.to_s}"
      
      # check if the 774 tag already exists
      parent_manuscript.marc.each_data_tag_from_tag("774") do |tag|
        subfield = tag.fetch_first_by_tag("w")
        next if !subfield || !subfield.content
        return if subfield.content.to_i == id
      end
      
      # nothing found, add it in the parent manuscript
      mc = MarcConfigCache.get_configuration("source")
      w774 = MarcNode.new(@model, "774", "", mc.get_default_indicator("774"))
      w774.add_at(MarcNode.new(@model, "w", id.to_s, nil), 0 )
      w774.add_at(MarcNode.new(@model, "4", "holding", nil), 0 )
      
      parent_manuscript.marc.root.add_at(w774, parent_manuscript.marc.get_insert_position("774") )

      parent_manuscript.suppress_update_77x
      parent_manuscript.save
    end
  end


  def reindex
    return if self.suppress_reindex_trigger == true
    self.index
  end

  searchable :auto_index => false do |sunspot_dsl|
    sunspot_dsl.integer :id
    sunspot_dsl.string :lib_siglum_order do
      lib_siglum
    end
    sunspot_dsl.text :lib_siglum
    
    sunspot_dsl.join(:folder_id, :target => FolderItem, :type => :integer, 
              :join => { :from => :item_id, :to => :id })
        
    MarcIndex::attach_marc_index(sunspot_dsl, self.to_s.downcase)
    
  end

  def display_name
    "#{lib_siglum} [#{id}]"
  end

end
