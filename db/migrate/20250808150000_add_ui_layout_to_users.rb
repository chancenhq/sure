class AddUiLayoutToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :ui_layout, :string, null: false, default: "intro"
    execute <<~SQL.squish
      UPDATE users SET ui_layout = 'dashboard'
    SQL
  end

  def down
    remove_column :users, :ui_layout
  end
end
