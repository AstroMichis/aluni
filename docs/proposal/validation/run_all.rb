# frozen_string_literal: true

# Runs the eight hindcast studies in order (V4 before V7, which reads its rotation effect) and prints
# one verdict table from validation_out.json. Data must have been fetched with fetch.rb.
#
# Run: mise exec -- ruby docs/proposal/validation/run_all.rb

require "json"
require "rbconfig"

dir = __dir__
studies = %w[v1_data v2_yield v3_crop_choice v4_rotation v5_pests v6_erosion v7_economics v8_timeline]
logs = File.join(dir, "logs")
Dir.mkdir(logs) unless Dir.exist?(logs)
studies.each do |s|
  print "#{s} ... "
  ok = system(RbConfig.ruby, File.join(dir, "#{s}.rb"), out: File.join(logs, "#{s}.txt"), err: %i[child out])
  puts ok ? "done (logs/#{s}.txt)" : "ERROR, see logs/#{s}.txt"
end

out = JSON.parse(File.read(File.join(dir, "validation_out.json")))
puts "\n#{'Study'.ljust(5)} #{'Verdict'.ljust(10)} Question / result"
out.sort.each do |id, r|
  puts "#{id.ljust(5)} #{r['verdict'].to_s[0, 10].ljust(10)} #{r['question']}"
  puts "#{' ' * 17}#{r['summary']}"
end
