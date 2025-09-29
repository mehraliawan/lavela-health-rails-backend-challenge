class CreateProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :providers do |t|
      t.string :name, null: false
      t.string :email, null: false

      t.timestamps
    end
    
    add_index :providers, :email, unique: true
  end
end
