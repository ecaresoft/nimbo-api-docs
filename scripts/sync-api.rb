#!/usr/bin/env ruby
# frozen_string_literal: true
require 'yaml'
require 'json'
require 'digest'
require 'open3'
require 'optparse'

module ApiDocsSync
  SOURCE_PATH = 'docs/api/generated/openapi.public.yaml'
  METHODS = %w[get post put patch delete options head trace].freeze
  ROOT = File.expand_path('..', __dir__)
  module_function

  def operations(document)
    document.fetch('paths').flat_map do |path, item|
      item.filter_map { |method, op| [method, path, op] if METHODS.include?(method) }
    end
  end

  def validate_public!(document)
    raise 'Expected a public contract snapshot' unless document['x-nimbo-publication'] == {'audience'=>'public', 'availability'=>'contract_snapshot'}
    raise 'Expected the reference-only server' unless document.fetch('servers').map { |server| server.fetch('url') } == ['https://api.example.test']
    ops = operations(document)
    raise 'Empty public contract' if ops.empty?
    ids = ops.map { |_, _, op| op.fetch('operationId') }
    raise 'Duplicate operation IDs' unless ids.uniq == ids
    walk = lambda do |value|
      case value
      when Hash
        value.each do |key, child|
          raise "Unapproved metadata or unresolved reference: #{key}" if %w[x-nimbo-audience x-nimbo-migration x-nimbo-llm $ref].include?(key)
          walk.call(child)
        end
      when Array
        value.each { |child| walk.call(child) }
      end
    end
    walk.call(document)
    ops
  end

  def render(raw, revision)
    document = YAML.safe_load(raw)
    ops = validate_public!(document)
    provenance = {'repository'=>'ecaresoft/nimbo-api', 'revision'=>revision, 'path'=>SOURCE_PATH, 'sha256'=>Digest::SHA256.hexdigest(raw)}
    document['x-nimbo-source'] = provenance
    lock = provenance.merge('document_sha256'=>Digest::SHA256.hexdigest(JSON.generate(document.reject { |key, _| key == 'x-nimbo-source' })), 'operations'=>ops.map { |method, path, op| {'method'=>method.upcase, 'path'=>path, 'operationId'=>op.fetch('operationId')} })
    [YAML.dump(document), JSON.pretty_generate(lock)+"\n"]
  end

  def read_source(source, revision)
    raise 'Use a full 40-character commit SHA' unless revision&.match?(/\A[0-9a-f]{40}\z/)
    raw, _, status = Open3.capture3('git', '-C', source, 'show', "#{revision}:#{SOURCE_PATH}")
    raise 'Cannot read the committed public artifact at that revision; run bin/openapi and commit it in nimbo-api first' unless status.success?
    raw
  end

  def main(argv)
    options = {}
    OptionParser.new do |parser|
      parser.banner = 'Usage: ruby scripts/sync-api.rb --source /path/to/nimbo-api --revision FULL_SHA [--check]'
      parser.on('--source PATH') { |v| options[:source] = v }
      parser.on('--revision SHA') { |v| options[:revision] = v }
      parser.on('--check') { options[:check] = true }
    end.parse!(argv)
    raise 'Provide --source and --revision' unless options[:source] && options[:revision]
    spec, lock = render(read_source(options[:source], options[:revision]), options[:revision])
    outputs = {'openapi/nimbo_public.yml'=>spec, 'scripts/api-source.json'=>lock}
    outputs.each do |path, content|
      target = File.join(ROOT, path)
      if options[:check]
        raise "Contract drift: #{path}" unless File.exist?(target) && File.binread(target) == content
      else
        File.write(target, content)
      end
    end
    puts "Public contract #{options[:check] ? 'verified' : 'imported'} at #{options[:revision]}"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    ApiDocsSync.main(ARGV)
  rescue StandardError => e
    warn e.message
    exit 1
  end
end
