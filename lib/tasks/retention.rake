namespace :opentrust do
  desc "Delete reports and audit logs older than the retention periods in the Privacy Policy"
  task purge_expired: :environment do
    counts = RetentionPurge.call
    puts "Retention purge: #{counts.map { |k, v| "#{k}=#{v}" }.join(' ')}"
  end
end
