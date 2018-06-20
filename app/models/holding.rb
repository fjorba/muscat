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
  has_many :folder_items, as: :item, dependent: :destroy
  belongs_to :user, :foreign_key => "wf_owner"
  
  has_and_belongs_to_many :people, join_table: "holdings_to_people"
  has_and_belongs_to_many :catalogues, join_table: "holdings_to_catalogues"
  has_and_belongs_to_many :places, join_table: "holdings_to_places"
	
  composed_of :marc, :class_name => "MarcHolding", :mapping => %w(marc_source to_marc)
  
  before_save :set_object_fields
  after_create :scaffold_marc, :fix_ids
  after_save :update_links, :reindex
  after_initialize :after_initialize
  before_destroy :update_links
  
  
  attr_accessor :suppress_reindex_trigger
  attr_accessor :suppress_scaffold_marc_trigger
  attr_accessor :suppress_recreate_trigger
  attr_accessor :suppress_update_count_trigger

  def after_initialize
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
      paper_trail.without_versioning :save
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
 
    new_marc = MarcCatalogue.new(File.read("#{Rails.root}/config/marc/#{RISM::MARC}/holding/default.marc"))
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
