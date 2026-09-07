require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../scripts/build-reference'

class ReferenceTest < Minitest::Test
  def with_policy
    Dir.mktmpdir do |root|
      FileUtils.cp_r(File.join(ApiDocsSync::ROOT, 'scripts'), root)
      path = File.join(root, 'scripts/reference-policy.json')
      policy = JSON.parse(File.read(path))
      yield root, path, policy
    end
  end

  def test_one_reference_preserves_existing_definitions_for_deferred_replacements
    outputs = ApiReference.render
    ids = outputs.values.flat_map { |raw| ApiDocsSync.operations(YAML.safe_load(raw)).map { |_, _, op| op['operationId'] } }
    assert_equal 98, ids.size
    assert_includes ids, 'legacy_nimbo_api_get__specialties_specialty_id'
    assert_includes ids, 'legacy_nimbo_api_get__waiting_rooms_waiting_room_slug'
    %w[getSpecialty showSiteAccount showPortalAgendaLocation showWaitingRoomBySlug].each { |id| refute_includes ids, id }
    assert_includes ids, 'listCountryStates'
    refute_includes ids, 'legacy_nimbo_api_get__countries_country_id_states'
  end

  def test_new_revision_requires_review
    with_policy do |root, path, policy|
      policy['reviewed_revision'] = 'b' * 40
      File.write(path, JSON.generate(policy))
      error = assert_raises(RuntimeError) { ApiReference.render(root) }
      assert_match(/Review publication policy/, error.message)
    end
  end

  def test_duplicate_definitions_fail_without_explicit_ownership
    with_policy do |root, path, policy|
      policy['duplicate_owners'].delete('GET /api/v1/countries')
      File.write(path, JSON.generate(policy))
      error = assert_raises(RuntimeError) { ApiReference.render(root) }
      assert_match(/Duplicate published endpoint/, error.message)
    end
  end

  def test_served_prose_and_metadata_do_not_expose_backend_migration
    walk = lambda do |node|
      case node
      when Hash
        node.each do |key, value|
          refute key.start_with?('x-nimbo-'), "Internal metadata leaked: #{key}"
          refute_match(/legacy|replacement|migration|preview|divergence/i, value) if %w[description summary title].include?(key) && value.is_a?(String)
          walk.call(value)
        end
      when Array then node.each { |value| walk.call(value) }
      end
    end
    ApiReference.render.each_value { |raw| walk.call(YAML.safe_load(raw)) }
  end
end
