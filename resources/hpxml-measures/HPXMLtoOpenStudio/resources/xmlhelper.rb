# frozen_string_literal: true

class XMLHelper
  # Adds the child element with 'element_name' and sets its value. Returns the
  # child element.
  def self.add_element(parent, element_name, value = nil, datatype = nil, defaulted = false)
    added = Oga::XML::Element.new(name: element_name)
    parent.children << added
    if not value.nil?
      if datatype == :integer
        value = to_integer(value, parent, element_name)
      elsif datatype == :float
        value = to_float(value, parent, element_name)
      elsif datatype == :boolean
        value = to_boolean(value, parent, element_name)
      elsif datatype != :string
        # If value provided, datatype required
        fail 'Unexpected datatype.'
      end
      added.inner_text = value.to_s
    end
    if defaulted
      XMLHelper.add_attribute(added, 'dataSource', 'software')
    end
    return added
  end

  # Adds the child element with 'element_name' to a single extension element and
  # sets its value. Returns the extension element.
  def self.add_extension(parent, element_name, value, datatype, defaulted = false)
    extension = XMLHelper.create_elements_as_needed(parent, ['extension'])
    return XMLHelper.add_element(extension, element_name, value, datatype, defaulted)
  end

  # Creates a hierarchy of elements under the parent element based on the supplied
  # list of element names. If a given child element already exists, it is reused.
  # Returns the final element.
  def self.create_elements_as_needed(parent, element_names)
    this_parent = parent
    element_names.each do |element_name|
      if XMLHelper.get_element(this_parent, element_name).nil?
        XMLHelper.add_element(this_parent, element_name)
      end
      this_parent = XMLHelper.get_element(this_parent, element_name)
    end
    return this_parent
  end

  # Deletes the child element with element_name. Returns the deleted element.
  def self.delete_element(parent, element_name)
    element = nil
    while !parent.at_xpath(element_name).nil?
      last_element = element
      element = parent.at_xpath(element_name).remove
    end
    return last_element
  end

  # Returns the value of 'element_name' in the parent element or nil.
  def self.get_value(parent, element_name, datatype)
    element = parent.at_xpath(element_name)
    if element.nil?
      return
    end

    value = element.text

    if datatype == :integer
      value = to_integer_or_nil(value, parent, element_name)
    elsif datatype == :float
      value = to_float_or_nil(value, parent, element_name)
    elsif datatype == :boolean
      value = to_boolean_or_nil(value, parent, element_name)
    elsif datatype != :string
      fail 'Unexpected datatype.'
    end

    return value
  end

  # Returns the value(s) of 'element_name' in the parent element or [].
  def self.get_values(parent, element_name, datatype)
    values = []
    parent.xpath(element_name).each do |value|
      value = value.text

      if datatype == :integer
        value = to_integer_or_nil(value, parent, element_name)
      elsif datatype == :float
        value = to_float_or_nil(value, parent, element_name)
      elsif datatype == :boolean
        value = to_boolean_or_nil(value, parent, element_name)
      elsif datatype != :string
        fail 'Unexpected datatype.'
      end

      values << value
    end

    return values
  end

  # Returns the element in the parent element.
  def self.get_element(parent, element_name)
    return parent.at_xpath(element_name)
  end

  # Returns the element in the parent element.
  def self.get_elements(parent, element_name)
    return parent.xpath(element_name)
  end

  # Returns the name of the first child element of the 'element_name'
  # element on the parent element.
  def self.get_child_name(parent, element_name)
    element = parent.at_xpath(element_name)
    return if element.nil? || element.children.nil?

    element.children.each do |child|
      next unless child.is_a? Oga::XML::Element

      return child.name
    end
  end

  # Returns true if the element exists.
  def self.has_element(parent, element_name)
    element = parent.at_xpath(element_name)
    return !element.nil?
  end

  # Returns the attribute added
  def self.add_attribute(element, attr_name, attr_val)
    added = element.set(attr_name, attr_val)
    return added
  end

  # Returns the value of the attribute
  def self.get_attribute_value(element, attr_name)
    return if element.nil?

    return element.get(attr_name)
  end

  def self.delete_attribute(element, attr_name)
    return if element.nil?

    element.unset(attr_name)
  end

  def self.validate(doc, xsd_path, runner = nil)
    if Gem::Specification::find_all_by_name('nokogiri').any?
      require 'nokogiri'
      xsd = Nokogiri::XML::Schema(File.open(xsd_path))
      doc = Nokogiri::XML(doc)
      return xsd.validate(doc)
    else
      if not runner.nil?
        runner.registerWarning('Could not load nokogiri, no HPXML validation performed.')
      end
      return []
    end
  end

  def self.create_doc(version = nil, encoding = nil, standalone = nil)
    doc = Oga::XML::Document.new(xml_declaration: Oga::XML::XmlDeclaration.new(version: version, encoding: encoding, standalone: standalone)) # Oga.parse_xml
    return doc
  end

  def self.parse_file(hpxml_path)
    file_read = File.read(hpxml_path)
    hpxml_doc = Oga.parse_xml(file_read)
    return hpxml_doc
  end

  def self.write_file(doc, out_path)
    doc_s = doc.to_xml

    # Manually apply pretty-printing (indentation and newlines)
    # Can remove if https://gitlab.com/yorickpeterse/oga/-/issues/75 is implemented
    curr_pos = 1
    level = -1
    indents = {}
    while true
      open_pos = doc_s.index('<', curr_pos)
      close_pos = nil
      if not open_pos.nil?
        close_pos1 = doc_s.index('</', curr_pos)
        close_pos2 = doc_s.index('/>', curr_pos)
        close_pos1 = Float::MAX if close_pos1.nil?
        close_pos2 = Float::MAX if close_pos2.nil?
        close_pos = [close_pos1, close_pos2].min
      end
      break if open_pos.nil? && close_pos.nil?

      if close_pos <= open_pos
        indents[close_pos] = level if doc_s[close_pos - 1] == '>'
        level -= 1
        curr_pos = close_pos + 1
      elsif open_pos < close_pos
        level += 1
        indents[open_pos] = level unless level == 0
        curr_pos = open_pos + 1
      end
    end
    indents.reverse_each do |pos, level|
      doc_s.insert(pos, "\n#{'  ' * level}")
    end
    # Retain REXML-styling
    doc_s.gsub!('"', "'")
    doc_s.gsub!(' />', '/>')
    doc_s.gsub!(' ?>', '?>')
    doc_s.gsub!('&quot;', '"')

    # Write XML file
    if not Dir.exist? File.dirname(out_path)
      FileUtils.mkdir_p(File.dirname(out_path))
    end
    File.open(out_path, 'w', newline: :crlf) do |f|
      f << doc_s
    end
  end
end

def to_float(value, parent, element_name)
  begin
    return Float(value)
  rescue
    fail "Cannot convert '#{value}' to float for #{parent.name}/#{element_name}."
  end
end

def to_integer(value, parent, element_name)
  begin
    value = Float(value)
  rescue
    fail "Cannot convert '#{value}' to integer for #{parent.name}/#{element_name}."
  end
  if value % 1 == 0
    return Integer(value)
  else
    fail "Cannot convert '#{value}' to integer for #{parent.name}/#{element_name}."
  end
end

def to_boolean(value, parent = nil, element_name = nil)
  if value.is_a? TrueClass
    return true
  elsif value.is_a? FalseClass
    return false
  elsif (value.downcase.to_s == 'true') || (value == '1') || (value == 1)
    return true
  elsif (value.downcase.to_s == 'false') || (value == '0') || (value == 0)
    return false
  end

  if (not parent.nil?) && (not element_name.nil?)
    fail "Cannot convert '#{value}' to boolean for #{parent.name}/#{element_name}."
  end
end

def to_float_or_nil(value, parent, element_name)
  return if value.nil?

  return to_float(value, parent, element_name)
end

def to_integer_or_nil(value, parent, element_name)
  return if value.nil?

  return to_integer(value, parent, element_name)
end

def to_boolean_or_nil(value, parent, element_name)
  return if value.nil?

  return to_boolean(value, parent, element_name)
end
