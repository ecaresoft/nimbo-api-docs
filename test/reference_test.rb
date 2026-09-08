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
    assert_equal 111, ids.size
    assert_includes ids, 'legacy_nimbo_api_get__specialties_specialty_id'
    assert_includes ids, 'legacy_nimbo_api_get__waiting_rooms_waiting_room_slug'
    %w[getSpecialty showSiteAccount showPortalAgendaLocation showWaitingRoomBySlug].each { |id| refute_includes ids, id }
    assert_includes ids, 'listCountryStates'
    refute_includes ids, 'legacy_nimbo_api_get__countries_country_id_states'
  end

  def test_customer_patient_portal_coverage_and_security_are_preserved
    outputs = ApiReference.render
    portal = YAML.safe_load(outputs.fetch('openapi/nimbo_patient_portal.yml'))
    operations = ApiDocsSync.operations(portal)
    assert_equal 13, operations.size
    expected_reads = %w[listPatientPortalPeople showPatientPortalPersonOrganization
      listPatientPortalPersonConsultations listPatientPortalPersonAttachments
      showPatientPortalPersonLabTests listPatientPortalPersonPrescriptions
      showPatientPortalPersonVitalSigns showPatientPortalPersonMedicalHistory
      listPatientPortalPersonConsultationSchedules listPatientPortalPersonConsultationRequests
      listPatientPortalPersonOrganizationPortals]
    assert_equal (expected_reads + %w[customerPatientPortalAuth customerPatientPortalValidate]).sort,
      operations.map { |_, _, operation| operation.fetch('operationId') }.sort
    operations.each do |method, _, operation|
      assert_equal(method == 'get' ? [{'PatientPortalToken'=>[]}] : [], operation.fetch('security'))
    end
    assert_equal 'bearer', portal.dig('components', 'securitySchemes', 'PatientPortalToken', 'scheme')
    catalogs = YAML.safe_load(outputs.fetch('openapi/nimbo_public.yml'))
    refute catalogs.fetch('paths').keys.any? { |path| path.include?('/patient_portal/') }
    assert_match(/creates a new medical history/, operations.find { |_, _, op| op['operationId'] == 'showPatientPortalPersonMedicalHistory' }.last['description'])
  end

  def test_committed_reference_bytes_match_with_utf8_descriptions
    # The patient portal schema includes the customer-visible label “Mis médicos”.
    ApiReference.write(check: true)
  end

  def test_functional_navigation_includes_every_served_operation_once
    docs = JSON.parse(File.read(File.join(ApiDocsSync::ROOT, 'docs.json')))
    groups = docs.fetch('navigation').fetch('tabs').find { |tab| tab['tab'] == 'API reference' }.fetch('groups')
    assert_equal ['Patients', 'Appointments', 'Clinical records'], groups.first(3).map { |group| group.fetch('group') }
    assert_equal 'Catalogs', groups.last.fetch('group')
    entries = []
    walk = lambda do |nodes|
      nodes.each do |node|
        if node.is_a?(String)
          if node.start_with?('api-reference/')
            page = File.read(File.join(ApiDocsSync::ROOT, "#{node}.mdx"))
            entries << YAML.safe_load(page.split('---')[1]).fetch('openapi')
          else
            entries << node
          end
        else
          refute_includes ['API Reference', 'Core API', 'ERP'], node['group']
          walk.call(node.fetch('pages'))
        end
      end
    end
    walk.call(groups)
    expected = ApiReference.render.flat_map do |file, raw|
      ApiDocsSync.operations(YAML.safe_load(raw)).map { |method, path, _| "#{file} #{method.upcase} #{path}" }
    end
    assert_equal expected.sort, entries.sort
    assert_equal entries.uniq, entries
    refute File.exist?(File.join(ApiDocsSync::ROOT, 'guides/patient-portal.mdx'))
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

  def test_imported_endpoint_descriptions_are_preserved
    with_policy do |root, _, _|
      path = File.join(root, 'scripts/contracts/nimbo_erp.yml')
      doc = YAML.safe_load_file(path)
      operation = ApiDocsSync.operations(doc).first.last
      description = 'Returns the consultation and its invoice relationships.'
      operation['description'] = description
      File.write(path, YAML.dump(doc))
      rendered = YAML.safe_load(ApiReference.render(root).fetch('openapi/nimbo_erp.yml'))
      assert_equal description, ApiDocsSync.operations(rendered).first.last.fetch('description')
    end
  end

  def test_imported_sources_do_not_repeat_migration_disclaimers
    Dir[File.join(ApiDocsSync::ROOT, 'scripts/contracts/*.yml')].each do |path|
      refute_match(/This imported contract has not been verified/i, File.read(path))
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
