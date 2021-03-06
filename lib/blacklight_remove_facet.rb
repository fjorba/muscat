# frozen_string_literal: true
module Blacklight
    class Configuration
      # This mixin provides Blacklight::Configuration with generic
      # solr fields configuration
      module Fields
        extend ActiveSupport::Concern
  
        alias_method :"old_add_blacklight_field", :"add_blacklight_field"
  
        
        def add_blacklight_field config_key, *args, &block
            override = false
            insert_position = 0
            sub_array = nil

            if args.count > 1 && args[1].is_a?(Hash)
                if args[1].include?(:override) && args[1][:override] == true
                    override = true
                    # Get the current position to insert it later
                    sub_array = self[config_key.pluralize].to_a
                    insert_position = sub_array.index(sub_array.assoc(args[0]))
                    # Remove from hash
                    self[config_key.pluralize].delete(args[0])
                    sub_array.delete_at(insert_position) # also here!

                end
            end

            # Call the original function, unless :override is set
            # it is just pass-through
            old_add_blacklight_field config_key, *args, &block

            # Move the facet to the current posision
            if override
                # Save the newly created element
                element = self[config_key.pluralize][args[0]]
                # Remove it
                self[config_key.pluralize].delete(args[0])
                # Insert it back at te right posision
                self[config_key.pluralize] = Hash[sub_array.insert(insert_position, [args[0], element])]
            end

        end
  
      end
    end
  end
  