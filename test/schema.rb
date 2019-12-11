ActiveRecord::Schema.define(:version => 1) do
  create_table :posts do |t|
    t.integer :position # example of untranslated field
    t.timestamps
  end

  create_table :post_translations do |t|
    t.references :post
    t.string :locale
    t.string :title
    t.text :text
    t.timestamps
  end
end
