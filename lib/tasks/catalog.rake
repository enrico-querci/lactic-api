namespace :catalog do
  desc "Seed the reference muscle and equipment taxonomies (idempotent)"
  task seed_taxonomy: :environment do
    report = Catalog::TaxonomySeeder.call
    puts "Seeded catalog taxonomy — #{report}"
    puts "Totals: #{Muscle.count} muscles, #{Equipment.count} equipment"
  end

  desc "Import the provider exercise catalog (idempotent; never touches custom exercises)"
  task sync: :environment do
    provider = Catalog::Providers::WorkoutX.new

    unless provider.configured?
      abort <<~MSG
        WORKOUTX_API_KEY is not set.

        Set it in the environment for this process only. It belongs in Railway
        variables in production and must never be committed.
      MSG
    end

    puts "Seeding taxonomy first so provider values resolve to stable keys..."
    Catalog::TaxonomySeeder.call

    puts "Syncing #{provider.source}..."
    run = Catalog::Sync.call(provider: provider)

    puts "Finished with status #{run.status} in #{run.duration_seconds.round(1)}s"
    puts "  fetched:     #{run.fetched_count}"
    puts "  created:     #{run.created_count}"
    puts "  updated:     #{run.updated_count}"
    puts "  deactivated: #{run.deactivated_count}"
    puts "  rejected:    #{run.rejected_count}"
    puts "  notes:       #{run.error_summary}" if run.error_summary.present?

    # Translation belongs to synchronization, never to a user request, so it
    # runs here rather than being triggered by a read.
    puts
    Rake::Task["catalog:translate"].invoke
  end

  desc "Generate Italian for catalog exercises whose English changed (idempotent)"
  task translate: :environment do
    adapter = Catalog::Translation::GoogleAdapter.new

    unless adapter.configured?
      puts "Skipping translation: GOOGLE_TRANSLATE_API_KEY is not set."
      puts "Italian falls back to English until a provider is configured."
      next
    end

    puts "Translating with #{adapter.name}..."
    report = Catalog::TranslateCatalog.call(adapter: adapter)

    puts "Considered #{report.considered} exercises"
    puts "  translated:      #{report.translated}"
    puts "  already current: #{report.skipped}"
    puts "  human-reviewed:  #{report.protected_count} (left alone)"
    puts "  without english: #{report.no_source}"
    puts "  failed:          #{report.failed}"
    puts "  characters sent: #{report.characters}"
  end
end
