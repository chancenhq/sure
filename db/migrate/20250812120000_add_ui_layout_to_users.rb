class AddUiLayoutToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :ui_layout, :string, null: false, default: "dashboard"
    add_index :users, :ui_layout
  end
end
