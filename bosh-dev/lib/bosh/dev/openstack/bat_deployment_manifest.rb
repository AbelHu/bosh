require 'bosh/dev/openstack'
require 'bosh/dev/bat/deployment_manifest'
require 'membrane'

module Bosh::Dev::Openstack
  class BatDeploymentManifest < Bosh::Dev::Bat::DeploymentManifest

    def schema
      new_schema = super

      new_schema.schemas['cpi'] = value_schema('openstack')

      properties = new_schema.schemas['properties']

      # properties.vip is required
      properties.schemas['vip'] = string_schema

      # properties.key_name is optional
      properties.schemas['key_name'] = string_schema
      properties.optional_keys << 'key_name'

      network_schema = new_schema.schemas['properties'].schemas['networks'].elem_schema.schemas
      network_schema['cloud_properties'] = strict_record({
        'net_id' => string_schema,
        'security_groups' => list_schema(string_schema)
      })

      new_schema
    end

    private

    def optional(key)
      Membrane::SchemaParser::Dsl::OptionalKeyMarker.new(key)
    end

  end
end
