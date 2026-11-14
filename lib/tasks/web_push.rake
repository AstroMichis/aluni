# Prints a fresh VAPID key pair for Web Push. Paste it into the credentials as
# web_push.public_key / private_key, with web_push.subject set to a mailto: or
# https: contact. Run it yourself; the keys are secrets.
namespace :web_push do
  desc "Print a new VAPID key pair for Web Push"
  task vapid_keys: :environment do
    key = WebPush.generate_key
    puts "web_push:"
    puts "  public_key: #{key.public_key}"
    puts "  private_key: #{key.private_key}"
    puts "  subject: mailto:hello@#{APP_DOMAIN}"
  end
end
