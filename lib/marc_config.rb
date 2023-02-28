require 'yaml'

# Load the Marc Configuration. It is used to define how various tags should be handles
# shown or edited. It also specifies how indicators and subtags are configured.
# The tag config is hardcoded in /config/marc/tag_config.5.0.yml
#
class MarcConfig

  def initialize(tag_config_file_path)
    @model = load_config tag_config_file_path
  end

  private

  def load_config(tag_config_file_path, overlay_path = "")

    @whole_config = Settings.new( YAML::load(File.open(tag_config_file_path)) )

    config_file = File.basename(tag_config_file_path)
    overlay_file = overlay_path #File.join(Rails.root, 'config', 'marc', RISM::MARC, 'local_' + config_file)
    if File.exists?(overlay_file)
      @whole_config.squeeze(Settings.new(YAML::load(File.open(overlay_file))))
    end
    
    @tag_config = @whole_config[:tags]
    # @indexed_tags = Array.new
    @foreign_tags = Array.new
    @foreign_tag_groups = Array.new
    @foreign_dependants = Hash.new
    @has_browsable = Hash.new

    @tag_config.each do |tag, tdata|
      tagless = true
      @has_browsable[tag] = false
      tdata[:fields].each do |subtag, field_data|
        if subtag.to_s.length > 0
          tagless = false
        end

        @has_browsable[tag] = true unless field_data[:no_browse]

        if field_data[:foreign_class]
          @foreign_tag_groups.push(tag) unless @foreign_tag_groups.include? tag
          @foreign_tags.push(tag + subtag)
          if field_data[:foreign_class].match /\^([\w\d])/
            if @foreign_dependants[tag + $1]
              @foreign_dependants[tag + $1] << subtag
            else
              @foreign_dependants[tag + $1] = [subtag]
            end
          end
        end
      end
      @tag_config[tag][:tagless] = tagless
    end
    
    # This is used to import unkown marc in muscat
    # we basically add an overlay of each tag from 000 to 999
    add_fake_config if @whole_config.keys.include?(:add_fake_tags) && @whole_config[:add_fake_tags] == true
    
    return @whole_config[:model]
  end

  # Used to import unknown marc into muscat
  def add_fake_config
    for i in 0..999 do
      tag_str = "%03d" % i
      if has_tag?(tag_str)
        tag = @tag_config[tag_str]
      else
        tag = {master: "a", indicator: "##", occurrences: "?", fields: [], tagless: false}
      end

      range = ("0".."9").to_a + ("a".."z").to_a

      range.each do |subtag|
        next if has_tag?(tag_str) && has_subfield?(tag_str, subtag)
        tag[:fields] << [subtag, {occurrences: "?"}]
      end

      @tag_config[tag_str] = tag
    end
  end

  public

  def add_overlay(tag_config_file_path, overlay_path)
    @model = load_config tag_config_file_path, overlay_path
  end

  def get_model
    @model
  end

  # Return all the configuration as YAML
  def to_yaml
    @whole_config.to_yaml
  end

  # Return if a tag is browsable, i.e. it will be shown to the user
  def tag_is_browsable?(tag)
    @has_browsable[tag]
  end

  # Get the default indicator for a Marc tag
  def get_default_indicator(tag)
    return @tag_config[tag][:indicator][0] if @tag_config[tag][:indicator].is_a? Array
    @tag_config[tag][:indicator]
  end

  # Block to iterate over the indicators for a tag
  def each_indicator(tag)
    if @tag_config[tag][:indicator].is_a? Array
      @tag_config[tag][:indicator].each { |ind| yield ind }
    else
      yield @tag_config[tag][:indicator]
    end
  end

  # Get the all the foreign classes
  def get_foreign_tag_groups
    @foreign_tag_groups
  end

  # Check if a tag and subtag should link to a foreign class (i.e. People)
  def is_foreign?(tag, subtag)
    if tag and subtag
      @foreign_tags.rindex(tag + subtag)
    else
      false
    end
  end

  # Get the foreign class for a tag and subtag
  def disable_create_lookup?(tag, subtag)
    flag = @tag_config[tag][:fields].assoc(subtag)[1][:disable_create_lookup]
    return flag if flag
    false
  end

  # Get the foreign class for a tag and subtag
  def get_foreign_class(tag, subtag)
    @tag_config[tag][:fields].assoc(subtag)[1][:foreign_class]
  end

  # Get the foreign field that is connected to a foreign class
  def get_foreign_field(tag, subtag)
    @tag_config[tag][:fields].assoc(subtag)[1][:foreign_field]
  end

  def get_foreign_alternates(tag, subtag)
    @tag_config[tag][:fields].assoc(subtag)[1][:foreign_alternates]
  end

  def get_foreign_dependants(tag, subtag)
    return @foreign_dependants[tag + subtag]
  end

  def has_foreign_subfields(tag)
    return @foreign_tag_groups.rindex(tag)
  end

  def get_remote_tags_for(link_model)
    remote_tags = []
    get_foreign_tag_groups.each do |foreign_tag|
      each_subtag(foreign_tag) do |subtag|
        tag_letter = subtag[0]
        if is_foreign?(foreign_tag, tag_letter)
          # Note: in the configuration only ID has the Foreign class
          # The others use ^0
          next if get_foreign_class(foreign_tag, tag_letter) != link_model
          remote_tags << foreign_tag if !remote_tags.include? foreign_tag
        end
      end
    end
    
    remote_tags
  end


  def get_all_foreign_classes()
    foreign_classes = []
    get_foreign_tag_groups.each do |foreign_tag|
      each_subtag(foreign_tag) do |subtag|
        tag_letter = subtag[0]
        if is_foreign?(foreign_tag, tag_letter)
          next if get_foreign_class(foreign_tag, tag_letter).include?("^")
          foreign_classes << get_foreign_class(foreign_tag, tag_letter).pluralize.underscore
        end
      end
    end
    
    foreign_classes.uniq
  end

  def has_links_to(tag)
		return false if !@tag_config.include? tag
	  @tag_config[tag][:fields].each do |st|
		  return true if st[1].has_key?(:link_to_model) && st[1].has_key?(:link_to_field)
	  end
	  return false
  end
  
  def each_link_to(tag)
	  @tag_config[tag][:fields].each do |st|
		  yield(st[0], st[1][:link_to_model], st[1][:link_to_field]) if st[1].has_key?(:link_to_model) && st[1].has_key?(:link_to_field)
	  end
  end

  # Get the foreign field 0 padding length for string field (if wanted)
  def get_zero_padding(tag, subtag = "")
    # p tag
    # p subtag
    if subtag.empty?
        @tag_config[tag][:zero_padding] rescue nil
    else
      @tag_config[tag][:fields].assoc(subtag)[1][:zero_padding] rescue nil
    end
  end

  # Check if a tag or subtag can be repeated (* or + mean it is)
  # disable_multiple means that duplication is disable IN EDITOR
  # but the field is allowed to be repeatable IN MARC
  # This is for tag groups: a field should not be repeatable in the group
  # but can be repeated because of multiple groups
  def multiples_allowed?(tag, subtag = "")
    disable_multiple = false
    if subtag.empty?
        occurrences = @tag_config[tag][:occurrences]
        disable_multiple = @tag_config[tag][:disable_multiple] rescue disable_multiple = false
    else
        return false if !@tag_config[tag][:fields].assoc(subtag)
        occurrences = @tag_config[tag][:fields].assoc(subtag)[1][:occurrences]
        disable_multiple = @tag_config[tag][:fields].assoc(subtag)[1][:disable_multiple] rescue disable_multiple = false
    end
    return true if (occurrences == '*' or occurrences == '+') && !disable_multiple
    return false
  end

  def get_relator_code_tag(tag)
    return nil if !@tag_config[tag].include?(:relator_code)
    return @tag_config[tag][:relator_code]
  end

  def use_foreign_links?(tag)
    # By default. all relationships go through foreign_links
    return true if !@tag_config[tag].include?(:foreign_links)
    return @tag_config[tag][:foreign_links]
  end

  def get_master(tag)
    @tag_config[tag][:master]
  end

  def master_optional?(tag)
    @tag_config[tag][:master_optional]
  end

  def has_tag?(tag)
    return @tag_config.include?(tag)
  end

  def has_subfield?(tag, subtag)
    return true if @tag_config[tag][:fields].assoc(subtag)
    return false
  end

  def is_tagless?(tag)
    @tag_config[tag][:tagless]
  end

  # Return if a tag is not browsable
  def show_in_browse?(tag, subtag)
    s = subtag.gsub(/\$/,"")
    !@tag_config[tag][:fields].assoc(s)[1][:no_browse] rescue nil
  end

  # Return if a tag should be hidden
  def always_hide?(tag, subtag)
    s = subtag.gsub(/\$/,"")
    @tag_config[tag][:fields].assoc(s)[1][:no_show] rescue nil
  end

  def browse_inline?(tag, subtag)
    s = subtag.gsub(/\$/,"")
    @tag_config[tag][:fields].assoc(s)[1][:browse_inline] rescue nil
  end

  def get_browse_helper(tag, subtag)
    s = subtag.gsub(/\$/,"")
    @tag_config[tag][:fields].assoc(s)[1][:browse_helper]
  end

  def get_size(tag, subtag)
    s = subtag.gsub(/\$/,"")
    @tag_config[tag][:fields].assoc(s)[1][:size] || 15
  end

  def get_subtag_attribute(tag, subtag, attribute_name)
    pull = @tag_config[tag]
    if pull
      subpull = pull[:fields].assoc(subtag)
      if subpull
        return subpull[1][attribute_name]
      end
    end
    return nil
  end

  def get_indicator(tag, subtag = "")
  #TODO: THIS IS ALL WRONG - indicator is now in top level - FIX!
    if @tag_config[tag][:fields].assoc(subtag)[1][:indicator].is_a? Array
      return @tag_config[tag][:fields].assoc(subtag)[1][:indicator][0]
    else
      return @tag_config[tag][:fields].assoc(subtag)[1][:indicator]
    end
  end

  def each_data_tag
    @tag_config.keys.sort.each { |tag| yield tag if tag.to_i > 8 }
  end

  def each_subtag( tag )
    @tag_config[tag][:fields].each { |subtag| yield subtag }
  end

  def tags_with_subtag( subtag )
    tags = Array.new
    @tag_config.keys.sort.each do |tag|
      tags << tag if @tag_config[tag][:fields].assoc(subtag)
    end
    tags
  end

  def dive(struct, from)
    struct.each do |k, v|
      if v.is_a?(Hash) and from[k]
        dive(v, from[k])
      else
        from[k] = v
      end
    end
  end

  def squeeze(other)
    other.each do |k, v|
      if v.is_a?(Hash) and @whole_config[k]
          dive(v, @whole_config[k])
        else
        update({ k => v })
      end
    end
  end


end
