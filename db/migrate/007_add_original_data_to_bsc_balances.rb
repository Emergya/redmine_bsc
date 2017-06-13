class AddOriginalDataToBscBalances < ActiveRecord::Migration
  def self.up
    add_column :bsc_balances, :original_income_details, :text
    add_column :bsc_balances, :original_expense_details, :text
  end

  def self.down
    remove_column :bsc_balances, :original_income_details
    remove_column :bsc_balances, :original_expense_details
  end
end
