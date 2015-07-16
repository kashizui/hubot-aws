# Description:
#   List ec2 instances info
#   Show detail about a instance if specified instance id
#
# Commands:
#   hubot ec2 list - List all instances
#   hubot ec2 list where <filterKey1>=<value1,value2,...> <filterKey2>=<value1,value2,...> ... - List all instances matching filter criteria
#   hubot ec2 list what filters are available - List the filters available
#   hubot ec2 describe <instanceId1> <instanceId2> ... - Describe the specified instance(s)

AsciiTable = require 'ascii-table'
moment     = require 'moment'
util       = require 'util'
_          = require 'underscore'

FILTER_KEYS = 
  "architecture": "The instance architecture (i386 | x86_64).",
  "availability-zone": "The Availability Zone of the instance.",
  "block-device-mapping.attach-time": "The attach time for an EBS volume mapped to the instance, for example, 2010-09-15T17:15:20.000Z.",
  "block-device-mapping.delete-on-termination": "A Boolean that indicates whether the EBS volume is deleted on instance termination.",
  "block-device-mapping.device-name": "The device name for the EBS volume (for example, /dev/sdh or xvdh).",
  "block-device-mapping.status": "The status for the EBS volume (attaching | attached | detaching | detached).",
  "block-device-mapping.volume-id": "The volume ID of the EBS volume.",
  "client-token": "The idempotency token you provided when you launched the instance.",
  "dns-name": "The public DNS name of the instance.",
  "group-id": "The ID of the security group for the instance. EC2-Classic only.",
  "group-name": "The name of the security group for the instance. EC2-Classic only.",
  "hypervisor": "The hypervisor type of the instance (ovm | xen).",
  "iam-instance-profile.arn": "The instance profile associated with the instance. Specified as an ARN.",
  "image-id": "The ID of the image used to launch the instance.",
  "instance-id": "The ID of the instance.",
  "instance-lifecycle": "Indicates whether this is a Spot Instance (spot).",
  "instance-state-code": "The state of the instance, as a 16-bit unsigned integer. The high byte is an opaque internal value and should be ignored. The low byte is set based on the state represented. The valid values are: 0 (pending), 16 (running), 32 (shutting-down), 48 (terminated), 64 (stopping), and 80 (stopped).",
  "instance-state-name": "The state of the instance (pending | running | shutting-down | terminated | stopping | stopped).",
  "instance-type": "The type of instance (for example, t2.micro).",
  "instance.group-id": "The ID of the security group for the instance.",
  "instance.group-name": "The name of the security group for the instance.",
  "ip-address": "The public IP address of the instance.",
  "kernel-id": "The kernel ID.",
  "key-name": "The name of the key pair used when the instance was launched.",
  "launch-index": "When launching multiple instances, this is the index for the instance in the launch group (for example, 0, 1, 2, and so on).",
  "launch-time": "The time when the instance was launched.",
  "monitoring-state": "Indicates whether monitoring is enabled for the instance (disabled | enabled).",
  "owner-id": "The AWS account ID of the instance owner.",
  "placement-group-name": "The name of the placement group for the instance.",
  "platform": "The platform. Use windows if you have Windows instances; otherwise, leave blank.",
  "private-dns-name": "The private DNS name of the instance.",
  "private-ip-address": "The private IP address of the instance.",
  "product-code": "The product code associated with the AMI used to launch the instance.",
  "product-code.type": "The type of product code (devpay | marketplace).",
  "ramdisk-id": "The RAM disk ID.",
  "reason": "The reason for the current state of the instance (for example, shows \"User Initiated [date]\" when you stop or terminate the instance). Similar to the state-reason-code filter.",
  "requester-id": "The ID of the entity that launched the instance on your behalf (for example, AWS Management Console, Auto Scaling, and so on).",
  "reservation-id": "The ID of the instance's reservation. A reservation ID is created any time you launch an instance. A reservation ID has a one-to-one relationship with an instance launch request, but can be associated with more than one instance if you launch multiple instances using the same launch request. For example, if you launch one instance, you'll get one reservation ID. If you launch ten instances using the same launch request, you'll also get one reservation ID.",
  "root-device-name": "The name of the root device for the instance (for example, /dev/sda1 or /dev/xvda).",
  "root-device-type": "The type of root device that the instance uses (ebs | instance-store).",
  "source-dest-check": "Indicates whether the instance performs source/destination checking. A value of true means that checking is enabled, and false means checking is disabled. The value must be false for the instance to perform network address translation (NAT) in your VPC.",
  "spot-instance-request-id": "The ID of the Spot Instance request.",
  "state-reason-code": "The reason code for the state change.",
  "state-reason-message": "A message that describes the state change.",
  "subnet-id": "The ID of the subnet for the instance.",
  "tag:KEY": "The key/value combination of a tag assigned to the resource, where tag:key is the tag's key.",
  "tag-key": "The key of a tag assigned to the resource. This filter is independent of the tag-value filter. For example, if you use both the filter \"tag-key=Purpose\" and the filter \"tag-value=X\", you get any resources assigned both the tag key Purpose (regardless of what the tag's value is), and the tag value X (regardless of what the tag's key is). If you want to list only resources where Purpose is X, see the tag:key=value filter.",
  "tag-value": "The value of a tag assigned to the resource. This filter is independent of the tag-key filter.",
  "tenancy": "The tenancy of an instance (dedicated | default).",
  "virtualization-type": "The virtualization type of the instance (paravirtual | hvm).",
  "vpc-id": "The ID of the VPC that the instance is running in.",
  "network-interface.description": "The description of the network interface.",
  "network-interface.subnet-id": "The ID of the subnet for the network interface.",
  "network-interface.vpc-id": "The ID of the VPC for the network interface.",
  "network-interface.network-interface.id": "The ID of the network interface.",
  "network-interface.owner-id": "The ID of the owner of the network interface.",
  "network-interface.availability-zone": "The Availability Zone for the network interface.",
  "network-interface.requester-id": "The requester ID for the network interface.",
  "network-interface.requester-managed": "Indicates whether the network interface is being managed by AWS.",
  "network-interface.status": "The status of the network interface (available) | in-use).",
  "network-interface.mac-address": "The MAC address of the network interface.",
  "network-interface-private-dns-name": "The private DNS name of the network interface.",
  "network-interface.source-dest-check": "Whether the network interface performs source/destination checking. A value of true means checking is enabled, and false means checking is disabled. The value must be false for the network interface to perform network address translation (NAT) in your VPC.",
  "network-interface.group-id": "The ID of a security group associated with the network interface.",
  "network-interface.group-name": "The name of a security group associated with the network interface.",
  "network-interface.attachment.attachment-id": "The ID of the interface attachment.",
  "network-interface.attachment.instance-id": "The ID of the instance to which the network interface is attached.",
  "network-interface.attachment.instance-owner-id": "The owner ID of the instance to which the network interface is attached.",
  "network-interface.addresses.private-ip-address": "The private IP address associated with the network interface.",
  "network-interface.attachment.device-index": "The device index to which the network interface is attached.",
  "network-interface.attachment.status": "The status of the attachment (attaching | attached | detaching | detached).",
  "network-interface.attachment.attach-time": "The time that the network interface was attached to an instance.",
  "network-interface.attachment.delete-on-termination": "Specifies whether the attachment is deleted when an instance is terminated.",
  "network-interface.addresses.primary": "Specifies whether the IP address of the network interface is the primary private IP address.",
  "network-interface.addresses.association.public-ip": "The ID of the association of an Elastic IP address with a network interface.",
  "network-interface.addresses.association.ip-owner-id": "The owner ID of the private IP address associated with the network interface.",
  "association.public-ip": "The address of the Elastic IP address bound to the network interface.",
  "association.ip-owner-id": "The owner of the Elastic IP address associated with the network interface.",
  "association.allocation-id": "The allocation ID returned when you allocated the Elastic IP address for your network interface.",
  "association.association-id": "The association ID returned when the network interface was associated with an IP address."


module.exports = (robot) ->
  # TODO(skoo): check if this needs to be refreshed
  aws = require('../../aws.coffee').aws()
  ec2 = new aws.EC2({apiversion: '2014-10-01'})

  # Formatting helpers for preformatted text
  pre = (text) ->
    if text
      "```#{text}```"
    else
      ''
  tt = (text) ->
    if text
      "`#{text}`"
    else
      ''

  MAX_BLOB_LENGTH = 4000
  sendBlob = (message, text) ->
    subblobs = []

    # Send as a collapsible attachment
    if text.length <= MAX_BLOB_LENGTH
      robot.adapter.customMessage
        message: message
        attachments:
          fallback: text.substring(0, 20) + '...'
          text: pre(text)
          mrkdwn_in: ['text']
      return

    # Otherwise split into multiple normal messages
    while text.length > 0
      if text.length <= MAX_BLOB_LENGTH
        subblobs.push text
        text = ''
      else
        maxSizeChunk = text.substring(0, MAX_BLOB_LENGTH)
        lastLineBreak = maxSizeChunk.lastIndexOf('\n')
        breakIndex = if lastLineBreak > -1
          lastLineBreak
        else
          MAX_BLOB_LENGTH

        subblobs.push text.substring(0, breakIndex)
        breakIndex++ if breakIndex isnt MAX_BLOB_LENGTH

        text = text.substring(breakIndex, text.length)

    message.send pre(b) for b in subblobs


  robot.respond /ec2 describe (i-\w+)( pretty)?$/i, (msg) ->
    instanceId = msg.match[1]
    ec2.describeInstances {InstanceIds: [instanceId]}, (err, res)->
      if err
        msg.send "DescribeInstancesError: #{err}"
      else
        instance = res.Reservations[0].Instances[0]

        # If pretty print as attachment fields
        if msg.match[2]

          fields = []
          for key, value of instance
            value = switch typeof value
              when 'string'
                if value.length > 0
                  value
                else
                  '_empty_'
              when 'boolean', 'number'
                value.toString()
              else
                value = util.inspect(value, false, null)

            longestLineLength = _.max(_.map(value.split(/\r?\n/), (l) -> l.length))

            fields.push
              title: key
              value: value
              short: longestLineLength <= 40

          robot.adapter.customMessage
            message: msg
            attachments:
              fallback: "Description of EC2 instance #{instance.InstanceId}.",
              fields: fields
              mrkdwn_in: ['fields']

        # Otherwise send as JSON blob
        else
          sendBlob msg, util.inspect(instance, false, null)


  robot.respond /ec2 list(.*)$/i, (msg) ->
    # Parse suffix
    suffix = msg.match[1]
    if suffix
      if (suffix.match /(?: what| which)? filters(?: are there| are available)?\??$/i)?
        msg.send ("#{tt(key)} - #{desc}" for key, desc of FILTER_KEYS).join('\n')
        return
      else if (suffix.match /(?: where)?(?: (?:[\S]+)=(?:\S+))+$/i)
        args = suffix.trim().split(' ')
        args = _.reject args, (arg) -> arg is 'where'
        args = _.map args, (arg) -> arg.split('=')
        args = _.object args
        args = _.mapObject args, (val, key) -> val.split(',')
      else if (suffix.match /( i-\w+)+$/i)
        instanceIds = suffix.trim().split(/\s+/)
        args = {'instance-id': instanceIds}
      else 
        msg.send "I don't know what you mean by #{tt(suffix.trim())}`"
        return

    # Provide some feedback about how the results are filtered
    filterInfo = ("(#{tt(key)} = #{_.map(values, tt).join(' or ')})" for key, values of args).join(' and ')
    if args?
      msg.send "Listing instances where #{filterInfo}..."
    else
      msg.send "Listing all instances..."

    # Build parameters object to AWS API
    params = {}
    if args?
      for key, values of args
        if (tagKeyMatch = key.match /tag:(\w+)/i)
          # If key is of the form tag:tagkey, parse
          # out the tag key accordingly
          params.Filters = [] unless params.Filters?

          params.Filters.push
            Name: "tag:#{tagKeyMatch[1]}"
            Values: values

        else if key of FILTER_KEYS
          # If key is in the list of filter types
          # push filter directly
          params.Filters = [] unless params.Filters?

          params.Filters.push
            Name: key
            Values: values
        else if key.match /name/i
          # Manually handle filters by name
          params.Filters = [] unless params.Filters?

          params.Filters.push
            Name: "tag:Name"
            Values: values
        else
          msg.send "I don't recognize the filter #{tt(key)}. Maybe try
            asking me `ec2 list which filters are available`?"
          return

    # Fire API request
    ec2.describeInstances params, (err, res)->
      if err
        msg.send "DescribeInstancesError: #{err}"
      else
        instances = _.flatten _.pluck res.Reservations, 'Instances'

        if _.isEmpty instances
          msg.send "No matching instances found."
        else
          # TODO(skoo): clean this code up
          rows = []
          for instance in instances
            name = '[NoName]'
            for tag in instance.Tags when tag.Key is 'Name'
              name = tag.Value

            rows.push({
              name:     name || '[NoName]'
              state:    instance.State.Name
              id:       instance.InstanceId
              ip:       instance.PrivateIpAddress
              launched: moment(instance.LaunchTime).format('YYYY-MM-DD HH:mm:ssZ')
            })

          rows.sort (a, b) ->
            moment(b.launched) - moment(a.launched)

          headings = [
            'name'
            'state'
            'id'
            'ip'
            'launched'
          ]

          table = new AsciiTable
          table.setHeading headings

          for row in rows
            table.addRow (row[key] for key in headings)

          sendBlob msg, table.toString()

