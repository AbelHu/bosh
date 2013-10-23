require 'bosh/dev/stemcell_artifacts'
require 'bosh/dev/promotable_artifact'
require 'bosh/dev/gem_components'
require 'bosh/dev/gem_artifact'

module Bosh::Dev
  class PromotableArtifacts
    def initialize(build)
      @build = build
    end

    def all
      artifacts = gem_artifacts + release_artifacts + stemcell_artifacts
      artifacts << light_stemcell_pointer
    end

    def source
      "s3://bosh-ci-pipeline/#{build.number}/"
    end

    def destination
      's3://bosh-jenkins-artifacts'
    end

    def release_file
      "bosh-#{build.number}.tgz"
    end

    private

    attr_reader :build

    def light_stemcell_pointer
      LightStemcellPointer.new(build.light_stemcell)
    end

    def gem_artifacts
      gem_components = GemComponents.new(build.number)
      gem_components.components.map { |component| GemArtifact.new(component, source, build.number) }
    end

    def release_artifacts
      commands = ["s3cmd --verbose cp #{File.join(source, 'release', release_file)} #{File.join(destination, 'release', release_file)}"]
      commands.map { |command| PromotableArtifact.new(command) }
    end

    def stemcell_artifacts
      stemcell_artifacts = StemcellArtifacts.all(build.number)
      commands = stemcell_artifacts.list.map do |stemcell_archive_filename|
        from = File.join(source, stemcell_archive_filename.to_s)
        to = File.join(destination, stemcell_archive_filename.to_s)
        "s3cmd --verbose cp #{from} #{to}"
      end

      commands.map { |command| PromotableArtifact.new(command) }
    end
  end
end
