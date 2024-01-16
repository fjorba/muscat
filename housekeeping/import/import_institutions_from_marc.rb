# Reads from a UTF8 MARC 21 source file and imports the records into the database (and ferret)
# For a completely clean import:
# - Ensure that ferretd is stopped (./script/ferretd/stop && ps ax | grep ferretd)
# - Remove the index files (rm -rf index/i_my/*)
# - Roll back the database (rake db:migrate VERSION=0)
# - Recreate the db (rake db:migrate)
# - Restart ferretd (./script/ferretd/start)
# - Run this script (cd housekeeping/import; ../../script/runner ./import_from_marc.rb ./00000_01000.utf8)
# - Run the post processing script (../../script/runner ./post_process.rb)
# - Done.

#User.current_user = User.find(1)
#@setting.save

# Alternatively, it is possible to import from the command line using the console and the ImportWorker:
# i = ImportWorker.new
# i.import( {:import_file => "zip_file_in_tmp_uploads", :owner => "admin", :owner_id => 1})

class Marc21Import
  
  def initialize(source_file, from = 0)
    @from = from
    @source_file = source_file
    @total_records = 0
    @import_results = Array.new
  end

  def import
    buffer = ""
    line_number = 0
    File.open(@source_file, "r") do |f|
      f.each_line do |line|
        line_number += 1
        if line =~ /^\s+$/
          # ignore
        elsif line =~ /^=000/
          if buffer.length > 0
            create_record(buffer, line_number)
          end
          buffer = line
        else
          buffer += line
        end
      end
      create_record(buffer, line_number)
    end
    puts @import_results
  end

  def create_record(buffer, line_number)
    @total_records += 1
    buffer.gsub!(/[\r\n]+/, ' ')
    buffer.gsub!(/ (=[0-9]{3,3})/, "\n\\1")
    
    if @total_records >= @from
      marc = MarcInstitution.new(buffer)
      # load the source but without resolving externals
      marc.load_source(false)

      if marc.is_valid?(false)
        # p marc.to_s
        # exit
        
        # step 1.  update or create a new manuscript
        manuscript = Institution.find_by_id( marc.get_marc_source_id )
        if !manuscript
          manuscript = Institution.new(:wf_owner => 1, :wf_stage => "published", :wf_audit => "approved")
        end
          
        # step 2. do all the lookups and change marc fields to point to external entities (where applicable) 
        marc.import

        # step 3. associate Marc with Manuscript
        manuscript.marc = marc

        @import_results.concat( marc.results )
        @import_results = @import_results.uniq

        # step 4. insert Manuscript into database
        #manuscript.suppress_update_77x # we should not need to update the 774/773 relationships during the import
        #manuscript.suppress_create_incipit
        #manuscript.suppress_create_incipit
        #manuscript.suppress_reindex
        manuscript.save #rescue puts "save failed"

        puts "Last offset: #{@total_records}, Last RISM ID: #{marc.first_occurance('001').content}"
      else
        puts "failed to import marc record leading up to line #{line_number}"
      end
    end
  end
  
end

# first argument is the file containing marc records
# second is the offset to start from

ap ARGV

if ARGV.length >= 1
  source_file = "rism_ks.marc"
  from = 0
#  from = ARGV[1] if ARGV[1]
  if File.exist?(source_file)
    import = Marc21Import.new(source_file, from.to_i)
    import.import
  else
    puts source_file + " is not a file!"
  end
else
  puts "Bad arguments, specify marc file and ferret index file to use"
end
