def valid_type?(type)
  return node['layers'].include? type
end

def dig(hash, *path)
  path.inject hash do |location, key|
    location.respond_to?(:keys) ? location[key] : nil
  end
end
