class CreateAvailabilities < ActiveRecord::Migration[8.0]
  def change
    create_table :availabilities do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :external_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :source, null: false

      t.timestamps
    end
    
    add_index :availabilities, [:provider_id, :starts_at, :ends_at]
    add_index :availabilities, :external_id, unique: true
  end
end
