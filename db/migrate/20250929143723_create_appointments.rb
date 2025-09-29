class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :client, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.references :availability, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :duration_minutes, null: false
      t.string :status, null: false, default: 'scheduled'

      t.timestamps
    end
    
    add_index :appointments, [:provider_id, :starts_at, :ends_at]
    add_index :appointments, [:availability_id, :starts_at, :ends_at]
    add_index :appointments, :status
  end
end
