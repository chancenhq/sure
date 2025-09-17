class AddUiModeToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :ui_mode, :string, default: "intro", null: false
  end
end
