# frozen_string_literal: true

# Checks config/evidence/credits.yml against the code, so the credits cannot drift from what Aluni really calls.
#
# Offline (default):
#   1. every external host in the code (app/, config/initializers, docs/proposal/validation/fetch.rb) belongs to an entry
#   2. every `code` match of every entry is really in that file (the product, version and parameters are the ones used)
#   3. every required attribution is shown: on the map or image itself where `attribution_at: map` (in the English
#      locale file and its Spanish twin, both containing `must_include`), otherwise on the public /credits page
#   4. every reference has an author, a year (or n.d.) and a title-like part; every DOI is well formed
# Online (--online; Luis runs it, Claude has no web access):
#   5. each DOI is resolved at doi.org as APA text and compared with `apa` (title words and year)
#   6. each NASA product's DOI is read from NASA CMR by short name (and version) and compared with `doi`
#   Results go to docs/proposal/credits_online.json.
#
# Exit 1 when a host is uncovered, a code match is missing, a DOI is malformed or (online) a DOI disagrees.
# Attribution GAPs are listed but do not fail the run: they are work for the app, not drift.
#
# Run: mise exec -- ruby docs/proposal/credits_audit.rb [--online]

require "json"
require "net/http"
require "uri"
require "yaml"

ROOT = File.expand_path("../..", __dir__)
credits = YAML.safe_load_file(File.join(ROOT, "config/evidence/credits.yml"))
ignore = credits.delete("ignore_hosts") || []
failures = []

# 1. Hosts in the code
scan = Dir.glob(File.join(ROOT, "{app,config/initializers,lib}/**/*.{rb,js,erb}")) + [ File.join(__dir__, "validation/fetch.rb") ]
found = Hash.new { |h, k| h[k] = [] }
scan.each do |file|
  File.read(file).scan(%r{https?://([a-z0-9.-]+\.[a-z]{2,})}i).flatten.uniq.each { |host| found[host.downcase] << file.delete_prefix("#{ROOT}/") }
end
covered = credits.values.flat_map { |c| Array(c["hosts"]) } + ignore
uncovered = found.keys.reject { |h| covered.include?(h) }
puts "1. External hosts in the code: #{found.size}; covered by credits.yml: #{found.size - uncovered.size}"
uncovered.each { |h| failures << "host #{h} (#{found[h].first}) has no credit" }

# 2. Code matches
checks = credits.sum { |_, c| Array(c["code"]).size }
credits.each do |id, c|
  Array(c["code"]).each do |file, text|
    path = File.join(ROOT, file)
    failures << "#{id}: #{file} is missing" and next unless File.exist?(path)
    failures << "#{id}: #{file} does not contain #{text.inspect}" unless File.read(path).include?(text)
  end
end
puts "2. Code matches: #{checks - failures.count { |f| f.include?('contain') || f.include?('missing') }}/#{checks}"

# 3. Attributions: on the map itself, or on the /credits page, which renders every entry's reference and attribution
page = %w[app/controllers/credits_controller.rb app/views/credits/show.html.erb].all? { |p| File.exist?(File.join(ROOT, p)) } &&
       File.read(File.join(ROOT, "app/controllers/credits_controller.rb")).include?("config/evidence/credits.yml") &&
       File.read(File.join(ROOT, "app/views/credits/show.html.erb")).include?(%(dig("attribution", "required")))
read = ->(file) { p = File.join(ROOT, file); File.exist?(p) ? File.read(p) : "" }
gaps = []
asked = credits.select { |_, c| c.dig("attribution", "required") }
asked.each do |id, c|
  att = c["attribution"]
  if c["attribution_at"] == "map"
    ok = Array(att["shown"]).any? do |file, text|
      es = file.sub("/en/", "/es/").sub("/en.", "/es.")
      read.(file).include?(text) && text.include?(att["must_include"].to_s) && (es == file || read.(es).include?(att["must_include"].to_s))
    end
    gaps << [ id, "not on the map (en and es)", att["required"] ] unless ok
  elsif !page
    gaps << [ id, "no /credits page renders it", att["required"] ]
  end
end
puts "3. Attributions asked for: #{asked.size} (#{asked.count { |_, c| c["attribution_at"] == "map" }} on maps, the rest on /credits#{page ? "" : ", page missing"}); gaps: #{gaps.size}"
gaps.each { |id, state, wording| puts "   GAP #{id.ljust(20)} #{state}\n       asks: #{wording}" }

# 4. Reference shape
DOI = %r{\A10\.\d{4,9}/\S+\z}
credits.each do |id, c|
  apa = c["apa"].to_s
  failures << "#{id}: reference has no year" unless apa.match?(/\((\d{4}|n\.d\.)\)/)
  failures << "#{id}: reference has no author before the year" unless apa.match?(/\A[^(]{3,}\((\d{4}|n\.d\.)\)/)
  %w[doi also_doi data_doi].each do |k|
    failures << "#{id}: #{k} #{c[k]} is malformed" if c[k] && !c[k].to_s.match?(DOI)
    failures << "#{id}: #{k} #{c[k]} is not in the reference" if k == "doi" && c[k] && !apa.include?(c[k].to_s)
  end
end
unverified = credits.select { |_, c| c["verify"] }.keys
puts "4. References: #{credits.size} (#{credits.count { |_, c| c['doi'] }} with a DOI); still to confirm against the provider: #{unverified.join(', ')}"

# 5, 6. Online
if ARGV.include?("--online")
  get = lambda do |url, accept, hops = 5|
    uri = URI(url)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 15, read_timeout: 30) do |http|
      http.get(uri.request_uri, "Accept" => accept, "User-Agent" => "aluni-credits-audit/1.0")
    end
    res.is_a?(Net::HTTPRedirection) && hops.positive? ? get.(URI.join(url, res["location"]).to_s, accept, hops - 1) : res
  end
  words = ->(s) { s.to_s.downcase.scan(/[a-z0-9]{4,}/).uniq }
  online = {}
  dois = credits.flat_map { |id, c| %w[doi also_doi data_doi].filter_map { |k| c[k] && [ id, k, c[k].to_s ] } }
  puts "5. DOIs at doi.org (#{dois.size}):"
  dois.each do |id, key, doi|
    res = get.("https://doi.org/#{doi}", "text/x-bibliography; style=apa; locale=en-US")
    if res.is_a?(Net::HTTPSuccess)
      registry = res.body.force_encoding("UTF-8").strip
      ours = key == "doi" ? credits[id]["apa"] : credits[id]["also_cite"].to_s
      year_ok = registry[/\((\d{4})/, 1].nil? || ours.include?(registry[/\((\d{4})/, 1].to_s) || key == "data_doi"
      overlap = (words.(registry) & words.(ours)).size.fdiv([ words.(registry).size, 1 ].max).round(2)
      ok = key == "data_doi" || (year_ok && overlap >= 0.5)
      failures << "#{id}: #{doi} resolves to a different reference (overlap #{overlap}, year #{year_ok ? 'ok' : 'differs'})" unless ok
      puts "   #{ok ? 'ok  ' : 'DIFF'} #{id} #{doi}\n        registry: #{registry[0, 300]}"
      online[doi] = { "id" => id, "status" => ok ? "ok" : "differs", "overlap" => overlap, "registry_apa" => registry }
    else
      failures << "#{id}: #{doi} does not resolve (HTTP #{res.code})"
      puts "   FAIL #{id} #{doi} HTTP #{res.code}"
      online[doi] = { "id" => id, "status" => "HTTP #{res.code}" }
    end
  end
  puts "6. NASA CMR collection DOIs:"
  credits.each do |id, c|
    next unless c["cmr"]

    q = { short_name: c.dig("cmr", "short_name"), version: c.dig("cmr", "version") }.compact
    res = get.("https://cmr.earthdata.nasa.gov/search/collections.umm_json?#{URI.encode_www_form(q)}", "application/json")
    items = res.is_a?(Net::HTTPSuccess) ? JSON.parse(res.body).fetch("items", []) : []
    cmr = items.map { |i| [ i.dig("umm", "DOI", "DOI"), i.dig("umm", "Version"), i.dig("umm", "EntryTitle") ] }.uniq
    match = cmr.any? { |d, _, _| d && c["doi"] && d.casecmp?(c["doi"].to_s) }
    status = if cmr.empty? then "not found (HTTP #{res.code})"
    elsif c["doi"].nil? then "no DOI in credits.yml; CMR has #{cmr.map(&:first).compact.join(', ')}"
    elsif match then "ok"
    else "differs: CMR has #{cmr.map(&:first).compact.join(', ')}"
    end
    failures << "#{id}: CMR #{status}" if status.start_with?("differs")
    puts "   #{id.ljust(12)} #{q.values.join(' v')}: #{status}#{" (#{cmr.first[2]})" if cmr.any?}"
    online["cmr:#{id}"] = { "query" => q, "status" => status, "cmr" => cmr }
  end
  File.write(File.join(__dir__, "credits_online.json"), JSON.pretty_generate(online) + "\n")
else
  puts "5-6. Online DOI and CMR checks skipped (run with --online)"
end

puts
if failures.empty?
  puts "credits.yml matches the code: #{credits.size} entries, #{gaps.size} attribution gaps to fix in the app."
else
  puts "#{failures.size} problem(s):"
  failures.each { |f| puts "   - #{f}" }
  exit 1
end
