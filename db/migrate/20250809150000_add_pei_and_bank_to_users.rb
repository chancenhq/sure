class AddPeiAndBankToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :pei, :string
    add_column :users, :bank, :string
  end
end
