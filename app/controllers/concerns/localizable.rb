# Resolves the locale for a request.
#
# Order, per the catalog plan: the authenticated user's stored preference,
# then the browser's Accept-Language, then English.
#
# Anything outside the supported set is ignored rather than honoured, so an
# arbitrary Accept-Language cannot reach a query as a locale value.
module Localizable
  extend ActiveSupport::Concern

  SUPPORTED_LOCALES = ExerciseTranslation::LOCALES
  DEFAULT_LOCALE = Exercise::DEFAULT_LOCALE

  def current_locale
    @current_locale ||= user_locale || header_locale || DEFAULT_LOCALE
  end

  private

  def user_locale
    supported(current_user&.locale)
  end

  # Accept-Language looks like "it-IT,it;q=0.9,en-US;q=0.8". Entries are ranked
  # by q, defaulting to 1.0, and the region subtag is dropped so "it-CH" still
  # matches Italian.
  def header_locale
    raw = request.headers["Accept-Language"]
    return nil if raw.blank?

    raw.split(",")
       .filter_map { |part| parse_language_range(part) }
       .sort_by { |_, quality| -quality }
       .filter_map { |tag, _| supported(tag) }
       .first
  end

  def parse_language_range(part)
    tag, *params = part.split(";").map(&:strip)
    return nil if tag.blank?

    quality = params.find { |p| p.start_with?("q=") }&.delete_prefix("q=")&.to_f || 1.0
    [ tag.split("-").first.downcase, quality ]
  end

  def supported(value)
    normalized = value.to_s.strip.downcase.split("-").first
    SUPPORTED_LOCALES.include?(normalized) ? normalized : nil
  end
end
