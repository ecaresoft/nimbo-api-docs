require 'minitest/autorun'
require_relative '../scripts/sync-api'

class SyncApiTest < Minitest::Test
  def snapshot
    {'openapi'=>'3.1.0', 'x-nimbo-publication'=>{'audience'=>'public', 'availability'=>'contract_snapshot'}, 'servers'=>[{'url'=>'https://api.example.test'}], 'paths'=>{'/catalog'=>{'get'=>{'operationId'=>'listCatalog'}}}}
  end

  def test_import_is_deterministic_and_records_digest
    raw = YAML.dump(snapshot)
    first = ApiDocsSync.render(raw, 'a' * 40)
    assert_equal first, ApiDocsSync.render(raw, 'a' * 40)
    assert_equal Digest::SHA256.hexdigest(raw), JSON.parse(first.last)['sha256']
  end

  def test_rejects_internal_artifact
    doc = snapshot
    doc.delete('x-nimbo-publication')
    assert_raises(RuntimeError) { ApiDocsSync.render(YAML.dump(doc), 'a' * 40) }
  end

  def test_rejects_internal_metadata_even_in_nested_schemas
    doc = snapshot
    doc['paths']['/catalog']['get']['schema'] = {'x-nimbo-audience'=>['internal']}
    assert_raises(RuntimeError) { ApiDocsSync.validate_public!(doc) }
  end

  def test_rejects_duplicate_operation_ids
    doc = snapshot
    doc['paths']['/other'] = {'get'=>{'operationId'=>'listCatalog'}}
    assert_raises(RuntimeError) { ApiDocsSync.validate_public!(doc) }
  end

  def test_rejects_unpinned_revision_before_git_access
    assert_raises(RuntimeError) { ApiDocsSync.read_source('/unused', 'main') }
  end
end
