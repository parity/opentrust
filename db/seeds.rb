# This repo is public: never fall back to a known password outside development.
# `db:prepare` runs this automatically on a brand-new database (the first deploy), so in production we must not
# fail when no password is given. We just skip creating the admin, and say so.
if Rails.env.production? && (ENV["ADMIN_PASSWORD"].blank? || ENV["ADMIN_EMAIL"].blank?)
  puts "Seeds: skipped creating the first admin. Run `ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=... bin/rails db:seed` once to create it."
else
  admin = AdminUser.find_or_initialize_by(email: ENV.fetch("ADMIN_EMAIL", "admin@opentrust.in"))
  admin.password = ENV.fetch("ADMIN_PASSWORD", "change-me-now") if admin.new_record?
  admin.save!
end

if Rails.env.development?
  m = Merchant.find_or_create_by!(contact_email: "demo@shop.example") { |x| x.name = "Demo Owner"; x.business_name = "Demo Shop"; x.phone = "9876500000" }
  MerchantUser.find_or_create_by!(merchant: m, email: m.contact_email) { |u| u.password = "password123"; u.email_verified_at = Time.current }
  MerchantApproval.approve!(m, admin) if m.pending?
end
