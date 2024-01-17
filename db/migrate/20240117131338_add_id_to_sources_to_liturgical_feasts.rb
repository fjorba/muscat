class AddIdToSourcesToLiturgicalFeasts < ActiveRecord::Migration[7.0]
  def self.up
    execute("ALTER TABLE `sources_to_liturgical_feasts` ADD `id` BIGINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST")
    execute("ALTER TABLE `sources_to_liturgical_feasts` ADD UNIQUE INDEX `unique_records` (`marc_tag`, `relator_code`, `liturgical_feast_id`, `source_id`);")
  end

  def self.down
    execute("ALTER TABLE `sources_to_liturgical_feasts` DROP INDEX `unique_records`;")
    execute("ALTER TABLE `sources_to_liturgical_feasts` CHANGE `id` `id` BIGINT  UNSIGNED  NOT NULL;")
    execute("ALTER TABLE `sources_to_liturgical_feasts` DROP PRIMARY KEY;")
    execute("ALTER TABLE `sources_to_liturgical_feasts` DROP `id`")
  end
end
