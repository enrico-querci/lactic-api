module Api
  module V1
    # Streams an exercise animation to an authenticated Lactic user.
    #
    # The provider serves media from its own API host and returns 401 without
    # the key, so a browser cannot fetch it directly. Handing the key to the
    # client, or redirecting to a URL carrying it, would disclose it — so Rails
    # makes the upstream request itself and returns the bytes.
    #
    # Shared by coaches and clients rather than living under either namespace,
    # because both render the same media and the visibility rule is the only
    # thing that differs.
    class ExerciseAnimationsController < BaseController
      # GET /api/v1/exercises/:exercise_id/animation
      def show
        exercise = visible_exercises.find(params[:exercise_id])
        medium = approved_animation_for(exercise)
        return render_error("Animation not available", :not_found) if medium.nil?

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        animation = provider.fetch_animation(medium.provider_url)
        log_success(exercise, animation, started)

        send_animation(animation)
      rescue Catalog::Providers::Errors::Base => e
        handle_provider_failure(e, exercise)
      end

      private

      # A client sees their coach's catalog; a coach sees their own. Neither
      # scope is narrowed to assignable exercises: a program may reference an
      # exercise the provider has since retired, and its animation must keep
      # rendering in history.
      def visible_exercises
        if current_user.coach?
          Exercise.for_coach(current_user.id)
        else
          Exercise.for_coach(current_user.coach_id)
        end
      end

      # "Approved" means a provider animation we actually hold a reference for.
      # Custom exercises carry no provider media, so they resolve to nothing
      # rather than reaching upstream.
      def approved_animation_for(exercise)
        exercise.exercise_media
                .animations
                .ordered
                .find { |medium| medium.provider_url.present? }
      end

      def send_animation(animation)
        # Conservative on purpose. Whether Lactic may cache or rehost provider
        # media is an open licensing question, so nothing is stored and nothing
        # is cached until it is answered. When permission arrives, this single
        # line becomes the place to relax it.
        response.set_header("Cache-Control", "private, no-store")

        send_data animation.bytes,
          type: animation.mime_type,
          disposition: "inline"
      end

      # Upstream failures become a stable Lactic contract. The client is told
      # the animation is unavailable and never sees a provider status code, a
      # provider URL, or anything derived from the key.
      def handle_provider_failure(error, exercise)
        # Quota is expected exhaustion, and Transient reaches here only after
        # the provider adapter's own retry loop already gave up on it — both
        # are excluded globally in config/initializers/sentry.rb. Authentication
        # (the key is wrong or the plan lacks this endpoint) and Schema (the
        # response no longer matches what the adapter expects) are the two
        # shapes that mean something is actually broken and stays broken
        # until a human looks at it.
        report_provider_error(error, exercise) if error.is_a?(Catalog::Providers::Errors::Authentication) ||
                                                    error.is_a?(Catalog::Providers::Errors::Schema)

        case error
        when Catalog::Providers::Errors::Quota
          log_failure(exercise, error, 503)
          render_error("Animation temporarily unavailable", :service_unavailable)
        else
          log_failure(exercise, error, 502)
          render_error("Animation unavailable", :bad_gateway)
        end
      end

      def report_provider_error(error, exercise)
        Sentry.capture_exception(error, tags: { exercise_id: exercise&.id.to_s })
      end

      def render_error(message, status)
        response.set_header("Cache-Control", "private, no-store")
        render json: { error: message }, status: status
      end

      def provider
        @provider ||= Catalog::Providers::WorkoutX.new
      end

      # Instrumentation carries ids, sizes and timings — never a key, a URL, or
      # an upstream body.
      def log_success(exercise, animation, started)
        Rails.logger.info(
          "exercise_animation exercise_id=#{exercise.id} status=200 " \
          "bytes=#{animation.byte_size} duration_ms=#{elapsed_ms(started)}"
        )
      end

      def log_failure(exercise, error, status)
        Rails.logger.warn(
          "exercise_animation exercise_id=#{exercise&.id} status=#{status} error=#{error.class}"
        )
      end

      def elapsed_ms(started)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      end
    end
  end
end
