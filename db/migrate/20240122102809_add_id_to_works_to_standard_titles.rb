class AddIdToWorksToStandardTitles < ActiveRecord::Migration[7.0]
  def self.up
    execute("TRUNCATE TABLE `works_to_standard_titles`;")
    execute("ALTER TABLE `works_to_standard_titles` DROP `id`")

    execute("ALTER TABLE `works_to_standard_titles` ADD `id` BIGINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST")
    execute("ALTER TABLE `works_to_standard_titles` ADD UNIQUE INDEX `unique_records` (`marc_tag`, `relator_code`, `work_id`, `standard_title_id`);")
  end

  def self.down
    execute("ALTER TABLE `works_to_standard_titles` DROP INDEX `unique_records`;")
    execute("ALTER TABLE `works_to_standard_titles` CHANGE `id` `id` BIGINT  UNSIGNED  NOT NULL;")
    execute("ALTER TABLE `works_to_standard_titles` DROP PRIMARY KEY;")
    execute("ALTER TABLE `works_to_standard_titles` DROP `id`")
  end
end

