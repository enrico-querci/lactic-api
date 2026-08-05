namespace :catalog do
  desc "Seed the reference muscle and equipment taxonomies (idempotent)"
  task seed_taxonomy: :environment do
    report = Catalog::TaxonomySeeder.call
    puts "Seeded catalog taxonomy — #{report}"
    puts "Totals: #{Muscle.count} muscles, #{Equipment.count} equipment"
  end
end
