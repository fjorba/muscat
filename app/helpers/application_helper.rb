module ApplicationHelper
  
  def catalogue_default_autocomplete
    autocomplete_catalogue_name_catalogues_path
  end
  
  def institution_default_autocomplete
    autocomplete_institution_name_institutions_path
  end
  
  def library_default_autocomplete
    autocomplete_library_siglum_libraries_path
  end
  
  def liturgical_feast_default_autocomplete
    autocomplete_liturgical_feast_name_liturgical_feasts_path
  end
  
  def person_default_autocomplete
    autocomplete_person_full_name_people_path
  end
  
  def place_default_autocomplete
    autocomplete_place_name_places_path
  end
  
  def source_default_autocomplete
    autocomplete_source_id_sources_path
  end
  
  def standard_term_default_autocomplete
    autocomplete_standard_term_term_standard_terms_path
  end
  
  def standard_title_default_autocomplete
    autocomplete_standard_title_title_standard_titles_path
  end
  

  # Create a link for a page in a new window
  def application_helper_link_http(value, node)
    result = []
    links = value.split("\n")
    links.each do |link|
      if link.match /(.*)(http:\/\/)([^\s]*)(.*)/
        result << "#{$1}<a href=\"#{$2}#{$3}\" target=\"_blank\">#{$3}</a>#{$4}"
      else
        result << link
      end
    end
    result.join("<br>")
  end
  
  # Link a manuscript by its RISM id
  def application_helper_link_source_id(value)
    link_to( value, { :action => "show", :controller => "sources", :id => value })
  end
  
  #################
  # These methods are placed here for compatibility with muscat 2
  
  def marc_editor_field_name(tag_name, iterator, subfield, s_iterator)
    it = sprintf("%03d", iterator)
    s_it = sprintf("%04d", s_iterator)
    #"marc[#{tag_name}-#{it}][#{subfield}-#{s_it}]"
    "marc_#{tag_name}-#{it}_#{subfield}-#{s_it}"
  end
  
  def marc_editor_ind_name(tag_name, iterator)
    it = sprintf("%03d", iterator)
    "#{tag_name}-#{it}-indicator"  
  end
    
  # This is a safe version of the deprecated link_to_function, left as a transition
  def safe_link_to_function_stub(name, function, html_options={})
    onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function}; return false;".html_safe
    href = html_options[:href] || '#'

    content_tag(:a, name, html_options.merge(:href => href, :onclick => onclick))
  end
  
  
  def edit_user_registration_path
  end
  
end
