class AddIndexToPagesOnAvailable < ActiveRecord::Migration
  using(:processor, :processor_one, :processor_two, :processor_three, :processor_four)

  def change
    add_index :pages, [:crawl_id, :available]
  end
end
