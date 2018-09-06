#
# Cookbook:: terminator
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

require 'aws-sdk'



Aws.config[:region] = aws_region()
