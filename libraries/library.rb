CPU_LOAD = Struct.new(:average, :server_count)

def get_cpu_load(server, layer, environment, group)

  query = '100 - (avg by (instance) (irate(node_cpu{job=~"' + layer +
          '[\\\d]*-' + environment + '-' + group + '",mode="idle"}[5m])) * 100)'
  escaped = CGI.escape query
  uri = URI.parse "#{server}?query=#{escaped}"

  data = Net::HTTP.get uri
  data = JSON.parse data
  # Check that response is valid, crash otherwise
  total = data['data']['result']
            .select{ |result| result['value'][1]}
            .sum
  server_count = data['data']['result'].length
  CPU_LOAD.new((total/server_count).round, server_count)
end

def aws_region
  @_aws_az = Net::HTTP.get(URI.parse('http://169.254.169.254/latest/meta-data/placement/availability-zone/')) if @_aws_az.nil?
  # i.e. eu-west-1b -> eu-west-1
  @_aws_az[0..-2]
end

def _get_ec2_client
  @_ec2_client ||= Aws::EC2::Client.new
end

def _get_elb_client()
  @_elb_client ||= Aws::ElasticLoadBalancingV2::Client.new
end


def instance_id
  @_instance_id = Net::HTTP.get(URI.parse('http://169.254.169.254/latest/meta-data/instance-id')) if @_instance_id.nil?
  @_instance_id
end

def get_ec2_tags()

  @_instance_tags ||= _get_ec2_client
    .describe_tags(
      filters: [
        {
          :name => 'resource-id',
          :values => [instance_id]
        }])
    .to_h[:tags]
    .each { |hsh| hsh.delete :resource_id }
    .each { |hsh| hsh.delete :resource_type }
    .map(&:values)
    .to_h
    .select { |key,_|  %w(Group Environment Layer).include? key }
end

def find_target_group_arn(instance_id)
  instance_tags = get_ec2_tags()
  raise 'Found no EC2 instance tags!' if instance_tags.empty?
  elb_client = _get_elb_client

  elb_client
    .describe_tags(resource_arns: _get_target_group_arns)
    .tag_descriptions
    .map { |desc| desc.to_h }
    .map { |desc| {desc[:resource_arn] => desc[:tags]} }
    .reduce({}) { |memo, hsh| memo.merge hsh }
    .each_pair do |arn, tags|
      tags =
        tags.map(&:values)
            .to_h
            .select { |key,_| %w(Group Environment Layer).include? key }
      return arn if tags == instance_tags
    end
  nil
end

def get_target_group_health
  target_group_arn = find_target_group_arn instance_id
  client = _get_elb_client
  client.describe_target_health({
    target_group_arn: target_group_arn,
  }).target_health_descriptions
end
