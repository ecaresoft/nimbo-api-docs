# frozen_string_literal: true
require_relative 'sync-api' unless defined?(ApiDocsSync)

module ApiReference
  ROOT = ApiDocsSync::ROOT
  module_function

  def key(file, method, path)
    prefix = file == 'nimbo_webhooks.yml' || path.start_with?('/api/v1/') ? '' : '/api/v1'
    method.upcase + ' ' + (prefix + path).gsub(/\{[^}]+\}/, '{}')
  end

  def clean(value)
    case value
    when Hash
      value.each_with_object({}) do |(name, child), result|
        next if name.start_with?('x-nimbo-')
        result[name] = if name == 'description' && child.is_a?(String)
          child.gsub(/\blegacy /i, '')
        else
          clean(child)
        end
      end
    when Array then value.map { |child| clean(child) }
    else value
    end
  end

  def render(root = ROOT)
    policy = JSON.parse(File.read(File.join(root, 'scripts/reference-policy.json')))
    source_lock = JSON.parse(File.read(File.join(root, 'scripts/api-source.json')))
    raise 'Review publication policy for the new API revision' unless source_lock.fetch('revision') == policy.fetch('reviewed_revision')
    inputs = Dir[File.join(root, 'scripts/contracts/*.yml')].sort.to_h { |path| [File.basename(path), YAML.safe_load_file(path)] }
    generated = inputs.fetch('nimbo_public.yml')
    source_ids = ApiDocsSync.operations(generated).map { |_, _, op| op.fetch('operationId') }.sort
    raise 'Every generated operation requires a publication decision' unless source_ids == (policy.fetch('publish') + policy.fetch('defer').keys).sort
    owners = policy.fetch('duplicate_owners')
    known_ids = inputs.values.flat_map { |doc| ApiDocsSync.operations(doc).map { |_, _, op| op.fetch('operationId') } }
    raise 'Unknown duplicate owner' unless (owners.values - known_ids).empty?
    seen = {}
    outputs = inputs.to_h do |file, document|
      document = clean(document)
      document['info']['description'] = 'Nimbo API reference. Use the API host and integration access provided by Nimbo.'
      document['info']['title'] = policy.fetch('titles').fetch(file)
      # Historical inputs can contain trailing whitespace in a path key.
      # Normalize the rendered URL without altering the retained input inventory.
      document['paths'] = document.fetch('paths').each_with_object({}) do |(path, item), paths|
        raise "Duplicate normalized path: #{path.strip}" if paths.key?(path.strip)
        paths[path.strip] = item
      end
      document['paths'].delete_if do |path, item|
        item.delete_if do |method, operation|
          next false unless ApiDocsSync::METHODS.include?(method)
          id = operation.fetch('operationId')
          route = key(file, method, path)
          exclude = file == 'nimbo_public.yml' && !policy.fetch('publish').include?(id)
          exclude ||= owners.key?(route) && owners[route] != id
          next true if exclude
          raise "Duplicate published endpoint: #{route}" if seen.key?(route)
          seen[route] = id
          if file == 'nimbo_public.yml'
            override = policy.fetch('descriptions', {})[id]
            operation['description'] = override if override
          end
          false
        end
        (item.keys & ApiDocsSync::METHODS).empty?
      end
      [File.join('openapi', file), YAML.dump(document)]
    end
    owners.each { |route, id| raise "Selected definition missing: #{route}" unless seen[route] == id }
    # Keep the patient session API together without changing canonical inputs.
    public_file = File.join('openapi', 'nimbo_public.yml')
    auth_file = File.join('openapi', 'nimbo_patient_portal_auth.yml')
    public_doc = YAML.safe_load(outputs.fetch(public_file))
    portal = YAML.safe_load(outputs.delete(auth_file))
    portal['openapi'] = public_doc.fetch('openapi')
    portal['info']['title'] = 'Nimbo patient portal'
    public_doc['paths'].keys.grep(%r{\A/api/v1/patient_portal/}).each do |path|
      raise "Duplicate portal path: #{path}" if portal['paths'].key?(path)
      portal['paths'][path] = public_doc['paths'].delete(path)
    end
    portal['components'] = public_doc.delete('components') if public_doc['components']
    portal['tags'] = [{'name'=>'Patient Portal'}, {'name'=>'Patient portal authentication'}]
    public_doc['tags'] = public_doc.fetch('tags', []).reject { |tag| tag['name'].start_with?('Patient Portal') }
    outputs[public_file] = YAML.dump(public_doc)
    outputs[File.join('openapi', 'nimbo_patient_portal.yml')] = YAML.dump(portal)
    outputs
  end

  def write(check: false)
    render.each do |path, content|
      target = File.join(ROOT, path)
      if check
        raise "Rendered reference drift: #{path}" unless File.binread(target) == content.b
      else
        File.write(target, content)
      end
    end
  end
end

ApiReference.write(check: ARGV.include?('--check')) if $PROGRAM_NAME == __FILE__
