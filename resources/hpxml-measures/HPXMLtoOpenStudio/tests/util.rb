# frozen_string_literal: true

def get_ems_values(ems_objects, name)
  values = {}
  ems_objects.each do |ems_object|
    next unless ems_object.name.to_s.include? name.gsub(' ', '_')

    ems_object.lines.each do |line|
      next unless line.downcase.start_with? 'set'

      lhs, rhs = line.split('=')
      lhs = lhs.gsub('Set', '').gsub('set', '').strip
      rhs = rhs.gsub(',', '').gsub(';', '').strip
      values[lhs] = [] if values[lhs].nil?
      # eg. "Q = Q + 1.5"
      if rhs.include? '+'
        rhs_els = rhs.split('+')
        rhs = rhs_els.map { |s| s.to_f }.sum(0.0)
      else
        rhs = rhs.to_f
      end
      values[lhs] << rhs
    end
  end
  return values
end
