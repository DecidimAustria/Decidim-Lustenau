require 'yaml'

def add_few_to_other(yaml_data)
  if yaml_data.is_a?(Hash)
    updated_yaml_data = {}
    yaml_data.each do |key, value|
      if key == 'other'
        updated_yaml_data['few'] = value
        updated_yaml_data['many'] = value
        updated_yaml_data['other'] = value
      else
        updated_yaml_data[key] = add_few_to_other(value)
      end
    end
    updated_yaml_data
  elsif yaml_data.is_a?(Array)
    yaml_data.map { |item| add_few_to_other(item) }
  else
    yaml_data
  end
end

Dir.glob('config/locales/uk.*yml') do |file|
  # Load YAML file
  yaml_data = YAML.load_file(file)

  # Find and add "few" key recursively
  updated_yaml_data = add_few_to_other(yaml_data)

  # Overwrite same file with updated YAML data
  File.write(file, updated_yaml_data.to_yaml)
end