pb = ProgressBar.new(Source.where(record_type: MarcSource::RECORD_TYPES[:print]).count)

Source.where(record_type: MarcSource::RECORD_TYPES[:print]).each do |s|
  source = Source.find(s)
  
  begin
    marc = source.marc
    marc.load_source false
  rescue => e
    $stderr.puts "SplitHoldingRecords: Could not load record #{source.id}"
    $stderr.puts e.message.blue
    next
  end
  
  count = 0
  
  # No 852 or record already processed
  next if marc.by_tags("852").count == 0
  
  marc.each_by_tag("852") do |t|
    
    # Make a nice new holding record
    holding = Holding.new
    new_marc = MarcHolding.new(File.read("#{Rails.root}/config/marc/#{RISM::MARC}/holding/default.marc"))
    new_marc.load_source false
    
    # Kill old 852s
    new_marc.each_by_tag("852") {|t2| t2.destroy_yourself}
    
    new_852 = t.deep_copy
    new_marc.root.children.insert(new_marc.get_insert_position("852"), new_852)
    
    new_marc.suppress_scaffold_links
    new_marc.import
    
    holding.marc = new_marc
    holding.source = source
    
    begin
      holding.save
    rescue => e
      $stderr.puts"SplitHoldingRecords could not save holding record for #{source.id}"
      $stderr.puts e.message.blue
      next
    end
    
    count += 1
  end

  if count != source.holdings.count && count > 0
    $stderr.puts "Modified #{count} records but record has #{source.holdings.count} holdings. [#{source.id}]"
  else
    ts = marc.root.fetch_all_by_tag("852") 
    ts.each {|t2| t2.destroy_yourself}
  end
  
  # suppress the 246 field in A/I prints since it was used for the previous title (now in 775 $t)
  if source.id > 990000000
    ts = marc.root.fetch_all_by_tag("246") 
    ts.each {|t2| t2.destroy_yourself}
    
    # Do more housekeeping
    # Add $8 to sources that need it

    ['593', '260','300', '590', '340', '028', '592','563', '597'].each do |tag|
      marc.each_by_tag(tag) do |t|
        st = t.fetch_first_by_tag("8")
        # Skip if exists
        next if st && st.content
        
        t.add_at(MarcNode.new("source", "8", "01", nil), 0)
        t.sort_alphabetically
      end
    end
    
  end
  
	source.suppress_update_77x
	source.suppress_update_count
  source.suppress_reindex
  
  new_marc_txt = marc.to_marc
  new_marc = MarcSource.new(new_marc_txt, source.record_type)
  
  begin
    source.marc = new_marc
  rescue =>e
    $stderr.puts "SplitHoldingRecords could not add new marc #{source.id}"
    puts e.message.blue
    next
  end
  
  begin
    source.save
  rescue => e
    $stderr.puts "SplitHoldingRecords could not save record #{source.id}"
    puts e.message.blue
  end
  
  pb.increment!
  source = nil
end