class AddTargetIncomesToBscCheckpoints < ActiveRecord::Migration
  def self.up
    add_column :bsc_checkpoints, :target_incomes, :decimal, :precision => 12, :scale => 4, :null => false

    BscCheckpoint.all.each do |chk|
    	chk.target_incomes = (chk.target_expenses / (1.0 - (chk.target_margin / 100.0)))
    	puts "#{chk.id}"
    	puts "#{[chk.target_incomes, chk.target_expenses, chk.target_margin]}"
    	chk.save if chk.target_incomes.present? and !chk.target_incomes.nan? and chk.target_incomes != BigDecimal('Infinity') and chk.target_incomes != BigDecimal('-Infinity')
    end

    remove_column :bsc_checkpoints, :target_margin
  end

  def self.down
  	add_column :bsc_checkpoints, :target_margin, :integer, :null => false

  	BscCheckpoint.all.each do |chk|
    	chk.target_margin = (100.0 * (chk.target_incomes - chk.target_expenses) / (chk.target_incomes))
    	puts "#{chk.id}"
    	puts "#{[chk.target_incomes, chk.target_expenses, chk.target_margin]}"
    	chk.save if chk.target_margin.present? and !chk.target_margin.to_f.nan? and chk.target_margin != BigDecimal('Infinity') and chk.target_margin != BigDecimal('-Infinity')
    end

    remove_column :bsc_checkpoints, :target_incomes
  end
end
