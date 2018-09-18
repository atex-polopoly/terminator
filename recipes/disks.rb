#
# Cookbook:: terminator
# Recipe:: disks
#
# Copyright:: 2018, The Authors, All Rights Reserved.

ensure_capacity = node['ensure_capacity']
lowest_threshold = node.roles
                       .map { |role| dig(node, role, 'scale_threshold') || node['scale_threshold'] }
                       .min

def get_current_disk_usage
  raw_disk_data = %x(df -h)
  raw_disk_data = raw_disk_data.split '\n'
  raw_disk_data = raw_disk_data
                    .map { |data| data.split(' ')[4:5].reverse }
                    .map { |data| {"#{data[0]}": data[1]} }
end

auto_clean = node['terminator']['disks']['auto_clean']
current_disk_usage = get_current_disk_usage
full_disks = node['terminator']['disks']['clean_thresholds']
              .select{ |constraint| current_disk_usage[constraint['disk']] > constraint['limit'] }
              .map{ |data| data['current'] = current_disk_usage[constraint['disk']]}
clean = full_disks.length > 0

puts "The following disks are full:", full_disk if clean

other_self_destructs = clean ? search(:node,
       "chef_environment:#{node['chef_environment']}",
       :filter_result => {
         'name' => [ 'name' ],
         'planned_self_destruct' => [ 'terminator', 'planned_self_destruct']
       }).select{ |server| server.planned_self_destruct }
         .select{ |server| server.name != node.name } : [] #Exclude ourselves

clear_to_self_destruct = other_self_destructs.size == 0

if !clear_to_self_destruct
  type = node.name.match(/([a-zA-Z]*)[0-9]+.*/)[1]#TODO regexp out front/gui/whatever
  raise "Invalid type: #{type}" unless valid_type? type
  other_self_destructs = other_self_destructs.select { |server| server.name.include? type }
  clear_to_self_destruct = other_self_destructs.size == 0
end

if !clear_to_self_destruct
  number = get_number node.name
  min_number = other_self_destructs.map { |server| get_number server.name }.min
  clear_to_self_destruct = number < min_number
end

ruby_block 'signal planned self destruct' do
  block do
   node.normal['terminator']['planned_self_destruct'] = true
  end
  only_if { auto_clean }
  only_if { clean }
  not_if { node['terminator']['planned_self_destruct'] }
  only_if { other_self_destructs.size == 0 }
end

ensure_capacity 'for termination' do
  scale_threshold lowest_threshold
  prometheus_api_address "#{node['prometheus']['host']}:#{node['prometheus']['api']['port']}#{node['prometheus']['api']['query_path']}"
  only_if { clean }
  only_if { auto_clean }
  only_if { node['terminator']['planned_self_destruct'] }
  only_if { clear_to_self_destruct }
end

self_destruct "due to disk limits violated" do
  only_if { clean }
  only_if { auto_clean }
  only_if { node['terminator']['planned_self_destruct'] }
  only_if { clear_to_self_destruct }
end
