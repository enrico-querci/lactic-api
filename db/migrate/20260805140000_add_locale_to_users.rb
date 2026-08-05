# Optional per-user language preference.
#
# Nullable on purpose: a null means "no explicit preference", which lets the
# request fall through to Accept-Language and then to English. Defaulting it to
# "en" would make every existing user look like they had actively chosen
# English and would suppress their browser's own preference.
class AddLocaleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :locale, :string
  end
end
