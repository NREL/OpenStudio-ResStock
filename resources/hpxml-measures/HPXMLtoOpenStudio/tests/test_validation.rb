# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'

class HPXMLtoOpenStudioValidationTest < MiniTest::Test
  def setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))

    # load the Schematron xml
    @stron_path = File.join(@root_path, 'HPXMLtoOpenStudio', 'resources', 'EPvalidator.xml')
    @stron_doc = XMLHelper.parse_file(@stron_path)

    # Load all HPXMLs
    hpxml_file_dirs = [File.absolute_path(File.join(@root_path, 'workflow', 'sample_files')),
                       File.absolute_path(File.join(@root_path, 'workflow', 'sample_files', 'hvac_autosizing')),
                       File.absolute_path(File.join(@root_path, 'workflow', 'tests', 'ASHRAE_Standard_140'))]
    @hpxml_docs = {}
    hpxml_file_dirs.each do |hpxml_file_dir|
      Dir["#{hpxml_file_dir}/*.xml"].sort.each do |xml|
        @hpxml_docs[File.basename(xml)] = HPXML.new(hpxml_path: File.join(hpxml_file_dir, File.basename(xml)), building_id: 'MyBuilding').to_oga()
      end
    end

    # Build up expected error messages hashes by parsing EPvalidator.xml
    @expected_assertions_by_addition = {}
    @expected_assertions_by_deletion = {}
    @expected_assertions_by_alteration = {}
    XMLHelper.get_elements(@stron_doc, '/sch:schema/sch:pattern/sch:rule').each do |rule|
      rule_context = XMLHelper.get_attribute_value(rule, 'context')
      context_xpath = rule_context.gsub('h:', '')

      XMLHelper.get_elements(rule, 'sch:assert').each do |assertion|
        assertion_message = assertion.inner_text
        element_name = _get_element_name_for_assertion_test(assertion)
        key = [context_xpath, element_name]

        if assertion_message.start_with?('Expected 0 element')
          # Skipping for now
        elsif assertion_message.start_with?('Expected 0 or ')
          @expected_assertions_by_addition[key] = _get_expected_error_msg(context_xpath, assertion_message, 'addition')
        elsif assertion_message.start_with?('Expected 1 ')
          @expected_assertions_by_deletion[key] = _get_expected_error_msg(context_xpath, assertion_message, 'deletion')
          @expected_assertions_by_addition[key] = _get_expected_error_msg(context_xpath, assertion_message, 'addition')
        elsif assertion_message.include?("Expected #{element_name} to be")
          @expected_assertions_by_alteration[key] = _get_expected_error_msg(context_xpath, assertion_message, 'alteration')
        elsif assertion_message.include?('There must be at least one') || assertion_message.include?('A location is specified as') || assertion_message.include?('sum of')
          # Skip these complex rules
        else
          fail "Unexpected assertion: '#{assertion_message}'."
        end
      end
    end
  end

  def test_role_attributes
    puts
    puts 'Checking for correct role attributes...'

    # check that every assert element has a role attribute
    XMLHelper.get_elements(@stron_doc, '/sch:schema/sch:pattern/sch:rule/sch:assert').each do |assert_element|
      assert_test = XMLHelper.get_attribute_value(assert_element, 'test').gsub('h:', '')
      role_attribute = XMLHelper.get_attribute_value(assert_element, 'role')
      if role_attribute.nil?
        fail "No attribute \"role='ERROR'\" found for assertion test: #{assert_test}"
      end

      assert_equal('ERROR', role_attribute)
    end

    # check that every report element has a role attribute
    XMLHelper.get_elements(@stron_doc, '/sch:schema/sch:pattern/sch:rule/sch:report').each do |report_element|
      report_test = XMLHelper.get_attribute_value(report_element, 'test').gsub('h:', '')
      role_attribute = XMLHelper.get_attribute_value(report_element, 'role')
      if role_attribute.nil?
        fail "No attribute \"role='WARN'\" found for report test: #{report_test}"
      end

      assert_equal('WARN', role_attribute)
    end
  end

  def test_sample_files
    puts
    puts "Testing #{@hpxml_docs.size} HPXML files..."
    @hpxml_docs.each do |xml, hpxml_doc|
      print '.'

      # Test validation
      _test_schema_validation(hpxml_doc, xml)
      _test_schematron_validation(hpxml_doc)
    end
    puts
  end

  def test_schematron_asserts_by_deletion
    puts
    puts "Testing #{@expected_assertions_by_deletion.size} Schematron asserts by deletion..."

    # Tests by element deletion
    @expected_assertions_by_deletion.each do |key, expected_error_msg|
      print '.'
      hpxml_doc, parent_element = _get_hpxml_doc_and_parent_element(key)
      child_element_name = key[1]
      XMLHelper.delete_element(parent_element, child_element_name)

      # Test validation
      _test_schematron_validation(hpxml_doc, expected_error_msg)
    end
    puts
  end

  def test_schematron_asserts_by_addition
    puts
    puts "Testing #{@expected_assertions_by_addition.size} Schematron asserts by addition..."

    # Tests by element addition (i.e. zero_or_one, zero_or_two, etc.)
    @expected_assertions_by_addition.each do |key, expected_error_msg|
      print '.'
      hpxml_doc, parent_element = _get_hpxml_doc_and_parent_element(key)
      child_element_name = key[1]

      # modify parent element
      additional_parent_element_name = child_element_name.gsub(/\[text().*?\]/, '').split('/')[0...-1].reject(&:empty?).join('/').chomp('/') # remove text that starts with 'text()' within brackets (e.g. [text()=foo or ...]) and select elements from the first to the second last
      _balance_brackets(additional_parent_element_name)
      mod_parent_element = additional_parent_element_name.empty? ? parent_element : XMLHelper.get_element(parent_element, additional_parent_element_name)

      if not expected_error_msg.nil?
        max_number_of_elements_allowed = 1
      else # handles cases where expected error message starts with "Expected 0 or more" or "Expected 1 or more". In these cases, 2 elements will be added for the element addition test.
        max_number_of_elements_allowed = 2 # arbitrary number
      end

      # Copy the child_element by the maximum allowed number.
      duplicated = _deep_copy_object(XMLHelper.get_element(parent_element, child_element_name))
      (max_number_of_elements_allowed + 1).times { mod_parent_element.children << duplicated }

      # Test validation
      _test_schematron_validation(hpxml_doc, expected_error_msg)
    end
    puts
  end

  def test_schematron_asserts_by_alteration
    puts "Testing #{@expected_assertions_by_alteration.size} Schematron asserts by alteration..."

    # Tests by element alteration
    @expected_assertions_by_alteration.each do |key, expected_error_msg|
      print '.'
      hpxml_doc, parent_element = _get_hpxml_doc_and_parent_element(key)
      child_element_name = key[1]
      element_to_be_altered = XMLHelper.get_element(parent_element, child_element_name)
      element_to_be_altered.inner_text = element_to_be_altered.inner_text + 'foo' # add arbitrary string to make the value invalid

      # Test validation
      _test_schematron_validation(hpxml_doc, expected_error_msg)
    end
    puts
  end

  def test_schematron_validation
    # Check that the schematron file is valid

    hpxml_stron_path = File.join(@root_path, 'HPXMLtoOpenStudio', 'resources', 'HPXMLvalidator.xml')

    begin
      require 'schematron-nokogiri'

      [@stron_path, hpxml_stron_path].each do |s_path|
        xml_doc = Nokogiri::XML(File.open(s_path)) do |config|
          config.options = Nokogiri::XML::ParseOptions::STRICT
        end
        stron_doc = SchematronNokogiri::Schema.new(xml_doc)
      end
    rescue LoadError
    end
  end

  private

  def _test_schematron_validation(hpxml_doc, expected_error_msg = nil)
    # Validate via validator.rb
    errors, warnings = Validator.run_validators(hpxml_doc, [@stron_path], include_id: false)
    idx_of_msg = errors.index { |i| i == expected_error_msg }
    if expected_error_msg.nil?
      assert_nil(idx_of_msg)
    else
      if idx_of_msg.nil?
        puts "Did not find expected error message '#{expected_error_msg}' in #{errors}."
      end
      refute_nil(idx_of_msg)
    end
  end

  def _test_schema_validation(hpxml_doc, xml)
    # TODO: Remove this when schema validation is included with CLI calls
    schemas_dir = File.absolute_path(File.join(@root_path, 'HPXMLtoOpenStudio', 'resources'))
    errors = XMLHelper.validate(hpxml_doc.to_xml, File.join(schemas_dir, 'HPXML.xsd'), nil)
    if errors.size > 0
      puts "#{xml}: #{errors}"
    end
    assert_equal(0, errors.size)
  end

  def _get_hpxml_doc_and_parent_element(key)
    context_xpath, element_name = key

    # Find a HPXML file that contains the specified elements.
    @hpxml_docs.each do |xml, hpxml_doc|
      if context_xpath.include? 'HeatPump[HeatPumpType="water-loop-to-air"]'
        next unless xml.include? 'boiler-only'
      end

      parent_elements = XMLHelper.get_elements(hpxml_doc, context_xpath)
      next if parent_elements.nil?

      parent_elements.each do |parent_element|
        next unless XMLHelper.has_element(parent_element, element_name)

        # Return copies so we don't modify the original object and affect subsequent tests.
        hpxml_doc = _deep_copy_object(hpxml_doc)
        parent_element = XMLHelper.get_elements(hpxml_doc, context_xpath).select { |el| el.text == parent_element.text }[0]
        return hpxml_doc, parent_element
      end
    end

    fail "Could not find an HPXML file with #{element_name} in #{context_xpath}. Add this to a HPXML file so that it's tested."
  end

  def _get_expected_error_msg(parent_xpath, assertion_message, mode)
    if assertion_message.start_with?('Expected 0 or more')
      return
    elsif assertion_message.start_with?('Expected 1 or more') && (mode == 'addition')
      return
    else
      return [assertion_message, "[context: #{parent_xpath}]"].join(' ') # return "Expected x element(s) for xpath: foo... [context: bar/baz/...]"
    end
  end

  def _get_element_name_for_assertion_test(assertion)
    # From the assertion, get the element name to be added or deleted for the assertion test.
    if assertion.inner_text.start_with?('Expected') && assertion.inner_text.include?('to be')
      test_attr = assertion.get('test')
      element_name = test_attr[/not\((.*?)\)/m, 1].gsub('h:', '') # pull text between "not(" and ")" (i.e. "foo" from "not(h:foo)")

      return element_name
    else
      test_attr = assertion.get('test')
      element_name = test_attr[/(?<=\().*(?=\))/].gsub('h:', '').partition(') + count').first # pull text between the first opening and the last closing parenthesis. (i.e. "foo" from "count(foo) + count(bar)...")
      _balance_brackets(element_name)

      return element_name
    end
  end

  def _balance_brackets(element_name)
    if element_name.count('[') != element_name.count(']')
      diff = element_name.count('[') - element_name.count(']')
      diff.times { element_name.concat(']') }
    end

    return element_name
  end

  def _deep_copy_object(obj)
    return Marshal.load(Marshal.dump(obj))
  end
end
