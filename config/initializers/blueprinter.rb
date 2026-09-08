# Serialize every datetime as ISO 8601 with millisecond precision.
#
# Without this, Blueprinter leaves `datetime_format` nil and renders through
# `JSON.generate`, which bypasses ActiveSupport's encoder and falls back to
# Ruby's `Time#to_s` — producing "2026-03-09 10:00:00 UTC". Meanwhile the few
# actions that render a plain Hash instead of a Blueprint (client/programs#show,
# coach/subscription, coach/exercise_taxonomy) go through ActiveSupport and
# produce "2026-03-09T10:00:00.000Z". So the same API emitted two different
# datetime encodings, and which one a client got depended on how the controller
# happened to render rather than on anything in the contract.
#
# That is survivable in a browser, where `new Date(str)` parses both, but it is
# hostile to typed clients: Swift's JSONDecoder takes a single date strategy per
# decoder and its ISO-8601 strategy rejects the space-separated form outright.
#
# The values below are byte-identical to what ActiveSupport's encoder already
# produces, so the Hash-rendered actions are unchanged and the Blueprint-rendered
# ones simply converge onto them.
Blueprinter.configure do |config|
  config.datetime_format = lambda do |value|
    # DateTime subclasses Date, so the date-only branch has to exclude it.
    # A Date has no time component and stays "YYYY-MM-DD" — this is what
    # ProgramAssignment#start_date already serialized as.
    if value.is_a?(Date) && !value.is_a?(DateTime)
      value.iso8601
    else
      value.iso8601(3)
    end
  end
end
