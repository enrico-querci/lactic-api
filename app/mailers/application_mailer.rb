class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Lactic <onboarding@resend.dev>")
  layout "mailer"
end
