#!/usr/bin/env ruby
require_relative 'sync-api'

root = ApiDocsSync::ROOT
lock = JSON.parse(File.read(File.join(root, 'scripts/api-source.json')))
spec = YAML.safe_load_file(File.join(root, 'scripts/contracts/nimbo_public.yml'))
ApiDocsSync.validate_public!(spec)
raise 'Invalid source revision' unless lock.fetch('revision').match?(/\A[0-9a-f]{40}\z/)
raise 'Provenance mismatch' unless spec.fetch('x-nimbo-source') == lock.reject { |key, _| %w[operations document_sha256].include?(key) }
actual = ApiDocsSync.operations(spec).map { |method, path, op| {'method'=>method.upcase, 'path'=>path, 'operationId'=>op.fetch('operationId')} }
raise 'Public operation inventory drift' unless actual == lock.fetch('operations')
# Check semantic integrity independently of the Ruby/Psych YAML emitter version.
spec.delete('x-nimbo-source')
raise 'Public artifact was edited; reimport it from nimbo-api' unless Digest::SHA256.hexdigest(JSON.generate(spec)) == lock.fetch('document_sha256')

inventory = JSON.parse(File.read(File.join(root, 'scripts/legacy-inventory.json')))
inventory.fetch('files').each do |file, expected|
  doc = YAML.safe_load_file(File.join(root, 'scripts/contracts', file))
  ops = ApiDocsSync.operations(doc)
  raise "Legacy coverage changed: #{file}" unless ops.size == expected.fetch('operations')
  method_paths = ops.map { |method, path, _| method.upcase + " " + path }.sort
  raise "Legacy operation changed: #{file}" unless method_paths == expected.fetch('method_paths')
  raise "Captured record ID in #{file}" if doc.fetch('paths').keys.any? { |path| path.match?(/\/\d+(?:\/|$)/) }
  walk = lambda do |node|
    case node
    when Hash
      raise "Captured example in #{file}" if (node.keys & %w[example examples]).any?
      node.each_value { |child| walk.call(child) }
    when Array
      node.each { |child| walk.call(child) }
    end
  end
  walk.call(doc)
end
raise 'Unreviewed historical patient spec must not be restored' if File.exist?(File.join(root, 'openapi/nimbo_patient_web_app.yml'))
puts "Contracts checked: #{actual.size} generated input operations; #{inventory.fetch('files').values.sum { |v| v.fetch('operations') }} legacy operations"

require_relative "build-reference"
ApiReference.write(check: true)
puts "Published reference verified: no duplicate endpoints and no unapproved generated contracts"
