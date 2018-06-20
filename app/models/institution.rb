# Describes a Library linked with a Source
#
# === Fields
# * <tt>siglum</tt> - RISM sigla of the lib
# * <tt>name</tt> -  Fullname of the lib
# * <tt>address</tt>
# * <tt>url</tt>
# * <tt>phone</tt> 
# * <tt>email</tt>
# * <tt>src_count</tt> - The number of manuscript that reference this lib.
#
# the other standard wf_* fields are not shown.
# The class provides the same functionality as similar models, see Catalogue

class Institution < ApplicationRecord
  include ForeignLinks
  include MarcIndex
  include AuthorityMerge
  resourcify
  
  # class variables for storing the user name and the event from the controller
  @last_user_save
  attr_accessor :last_user_save
  @last_event_save
  attr_accessor :last_event_save
  
  has_paper_trail :on => [:update, :destroy], :only => [:marc_source], :if => Proc.new { |t| VersionChecker.save_version?(t) }
  
  has_and_belongs_to_many(:referring_sources, class_name: "Source", join_table: "sources_to_institutions")
  has_and_belongs_to_many(:referring_people, class_name: "Person", join_table: "people_to_institutions")
  has_and_belongs_to_many(:referring_catalogues, class_name: "Catalogue", join_table: "catalogues_to_institutions")
  has_and_belongs_to_many :people, join_table: "institutions_to_people"
  has_and_belongs_to_many :catalogues, join_table: "institutions_to_catalogues"
  has_and_belongs_to_many :places, join_table: "institutions_to_places"
  has_and_belongs_to_many :standard_terms, join_table: "institutions_to_standard_terms"
  
  has_and_belongs_to_many :holdings
  #has_many :folder_items, as: :item, dependent: :destroy
  has_many :delayed_jobs, -> { where parent_type: "Institution" }, class_name: 'Delayed::Backend::ActiveRecord::Job', foreign_key: "parent_id"
  has_and_belongs_to_many :workgroups
  belongs_to :user, :foreign_key => "wf_owner"
  
  composed_of :marc, :class_name => "MarcInstitution", :mapping => %w(marc_source to_marc)
  
  # Institutions also can link to themselves
  # This is the forward link
  has_and_belongs_to_many(:institutions,
    :class_name => "Institution",
    :foreign_key => "institution_a_id",
    :association_foreign_key => "institution_b_id")
  
  # This is the backward link
  has_and_belongs_to_many(:referring_institutions,
    :class_name => "Institution",
    :foreign_key => "institution_b_id",
    :association_foreign_key => "institution_a_id")
  
  #validates_presence_of :siglum    
  
  validates_uniqueness_of :siglum, :allow_nil => true
  
  #include NewIds
  
  before_destroy :check_dependencies
  
  #before_create :generate_new_id
  after_save :update_links, :reindex
  after_create :scaffold_marc, :fix_ids, :update_workgroups
  after_initialize :after_initialize
  
  before_validation :set_object_fields
  
  attr_accessor :suppress_reindex_trigger
  attr_accessor :suppress_scaffold_marc_trigger
  attr_accessor :suppress_recreate_trigger
  attr_accessor :suppress_update_workgroups_trigger

  alias_attribute :id_for_fulltext, :id

  enum wf_stage: [ :inprogress, :published, :deleted ]
  enum wf_audit: [ :full, :abbreviated, :retro, :imported ]
  

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

	def suppress_update_workgroups
		self.suppress_update_workgroups_trigger = true
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

    allowed_relations = ["institutions", "people", "places", "catalogues", "standard_terms"]
    recreate_links(marc, allowed_relations)
  end

  def scaffold_marc
    return if self.marc_source != nil  
    return if self.suppress_scaffold_marc_trigger == true
  
    new_marc = MarcInstitution.new(File.read("#{Rails.root}/config/marc/#{RISM::MARC}/institution/default.marc"))
    new_marc.load_source true
    
    new_100 = MarcNode.new("institution", "110", "", "1#")
    new_100.add_at(MarcNode.new("institution", "c", self.place, nil), 0) if self.place != nil
    new_100.add_at(MarcNode.new("institution", "g", self.siglum, nil), 0) if self.siglum != nil
    new_100.add_at(MarcNode.new("institution", "a", self.name, nil), 0)
    
    new_marc.root.children.insert(new_marc.get_insert_position("110"), new_100)
    
    if self.alternates != nil and !self.alternates.empty?
      new_400 = MarcNode.new("institution", "410", "", "1#")
      new_400.add_at(MarcNode.new("institution", "a", self.alternates, nil), 0)
    
      new_marc.root.children.insert(new_marc.get_insert_position("410"), new_400)
    end
    
    if self.url || self.address
      new_371 = MarcNode.new("institution", "371", "", "1#")
      new_371.add_at(MarcNode.new("institution", "u", self.url, nil), 0) if self.url
      new_371.add_at(MarcNode.new("institution", "a", self.address, nil), 0) if self.address
    
      new_marc.root.children.insert(new_marc.get_insert_position("371"), new_371)
    end
    
    if self.notes != nil and !self.notes.empty?
      new_field = MarcNode.new("institution", "680", "", "1#")
      new_field.add_at(MarcNode.new("institution", "a", self.notes, nil), 0)
    
      new_marc.root.children.insert(new_marc.get_insert_position("680"), new_field)
    end
    
    

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

    # std_title
    self.name, self.place = marc.get_name_and_place
    self.address, self.url = marc.get_address_and_url
    self.siglum = marc.get_siglum
    self.marc_source = self.marc.to_marc
  end
  


  def reindex
    return if self.suppress_reindex_trigger == true
    self.index
  end

  searchable :auto_index => false do |sunspot_dsl|
    sunspot_dsl.integer :id
    sunspot_dsl.text :id_text do
      id_for_fulltext
    end

    sunspot_dsl.string :siglum_order do
      siglum
    end
    sunspot_dsl.text :siglum
    
    sunspot_dsl.string :name_order do
      name
    end
    sunspot_dsl.text :name
    
    sunspot_dsl.string :place_order do
      place
    end
    sunspot_dsl.text :place
    
    sunspot_dsl.text :address
    sunspot_dsl.text :url
    sunspot_dsl.text :phone
    sunspot_dsl.text :email
    
    sunspot_dsl.join(:folder_id, :target => FolderItem, :type => :integer, 
              :join => { :from => :item_id, :to => :id })
    
    sunspot_dsl.integer :src_count_order, :stored => true do 
      Institution.count_by_sql("select count(*) from sources_to_institutions where institution_id = #{self[:id]}")
    end
    sunspot_dsl.time :updated_at
    sunspot_dsl.time :created_at

    MarcIndex::attach_marc_index(sunspot_dsl, self.to_s.downcase)
    
  end
  
  def check_dependencies
    if self.referring_sources.count > 0 || self.referring_institutions.count > 0 ||
         self.referring_catalogues.count > 0 || self.referring_people.count > 0
      errors.add :base, %{The institution could not be deleted because it is used by
        #{self.referring_sources.count} sources,
        #{self.referring_institutions.count} institutions, 
        #{self.referring_catalogues.count} catalogues and 
        #{self.referring_people.count} people}
      return false
    end
  end

  def update_workgroups
    return if self.suppress_update_workgroups_trigger == true || self.siglum.blank?
    Workgroup.all.each do |wg|
      patterns = wg.libpatterns.split(",")
      patterns.each do |pattern|
        wg.save if Regexp.new(pattern.strip).match(self.siglum)
      end
    end
  end
  
  def autocomplete_label
    sigla = siglum != nil && !siglum.empty? ? "#{siglum} " : ""
    "#{sigla}#{name}"
  end
  
  def autocomplete_label_siglum
    "#{siglum} (#{name})"
  end
  
  def autocomplete_label_name
    sigla = siglum != nil && !siglum.empty? ? " [#{siglum}]" : ""
    "#{name}#{sigla}"
  end
 
  ransacker :"110g_facet", proc{ |v| } do |parent| parent.table[:id] end
  
  def get_deposita
    #FIXME Search should not test for siglum; intermediate hack to speed up institutions show
    if self.siglum
      MarcSearch.select(Institution, '580$x', siglum.to_s).to_a
    else
      return []
    end
  end
 
end
