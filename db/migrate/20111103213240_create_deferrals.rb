class CreateDeferrals < ActiveRecord::Migration
  def self.up
    create_table :deferrals do |t|
      t.date :approval_date
      t.string :obs
      t.references :enrollment
      t.references :deferral_type

      t.timestamps
    end
  end

  def self.down
    drop_table :deferrals
  end
end