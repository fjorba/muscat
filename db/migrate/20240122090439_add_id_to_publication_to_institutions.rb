class AddIdToPublicationToInstitutions < ActiveRecord::Migration[7.0]
  def self.up
    execute("ALTER TABLE `publications_to_institutions` ADD `id` BIGINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST")
    execute("ALTER TABLE `publications_to_institutions` ADD UNIQUE INDEX `unique_records` (`marc_tag`, `relator_code`, `publication_id`, `institution_id`);")
  end

  def self.down
    execute("ALTER TABLE `publications_to_institutions` DROP INDEX `unique_records`;")
    execute("ALTER TABLE `publications_to_institutions` CHANGE `id` `id` BIGINT  UNSIGNED  NOT NULL;")
    execute("ALTER TABLE `publications_to_institutions` DROP PRIMARY KEY;")
    execute("ALTER TABLE `publications_to_institutions` DROP `id`")
  end
end
