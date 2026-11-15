# The one mail sent to someone who may not have an account yet: a sign-in code.
# Sent inline by Auth::RequestCodeService (a code cannot wait for a queue) and
# subject to the operator's mail switch like every other mail.
class SignInMailer < ApplicationMailer
  def code(sign_in_code:, code:, link:)
    @code = "#{code[0, 3]} #{code[3, 3]}"
    @minutes = (SignInCode::TTL / 60).to_i
    I18n.with_locale(sign_in_code.locale) do
      @link = sign_in_link_url(token: link, locale: sign_in_code.locale)
      mail(to: sign_in_code.destination, subject: t(".subject", code: @code, app_name: t("app_name")))
    end
  end
end
