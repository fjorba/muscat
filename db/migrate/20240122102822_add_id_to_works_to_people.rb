class AddIdToWorksToPeople < ActiveRecord::Migration[7.0]
  def self.up
    execute("ALTER TABLE `works_to_people` ADD `id` BIGINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST")
    execute("ALTER TABLE `works_to_people` ADD UNIQUE INDEX `unique_records` (`marc_tag`, `relator_code`, `work_id`, `person_id`);")
  end

  def self.down
    execute("ALTER TABLE `works_to_people` DROP INDEX `unique_records`;")
    execute("ALTER TABLE `works_to_people` CHANGE `id` `id` BIGINT  UNSIGNED  NOT NULL;")
    execute("ALTER TABLE `works_to_people` DROP PRIMARY KEY;")
    execute("ALTER TABLE `works_to_people` DROP `id`")
  end
end

