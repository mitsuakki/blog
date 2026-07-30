# frozen_string_literal: true

# Jekyll generator: creates one page per tag at /tag/<tagname>/
module TagGenerator
  class TagPageGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      return unless site.layouts.key?("tag")

      tags = {}
      site.posts.docs.each do |post|
        next unless post.data["tags"].is_a?(Array)

        post.data["tags"].each do |tag|
          slug = tag.to_s.downcase.strip.gsub(/\s+/, "-").gsub(/[^a-z0-9-]/, "")
          tags[slug] ||= { "name" => tag.to_s, "slug" => slug, "posts" => [] }
          tags[slug]["posts"] << post
        end
      end

      tags.each_value do |tag_data|
        site.pages << TagPage.new(site, site.source, tag_data)
      end

      site.config["tag_data"] = tags

      # Store popular tags sorted by post count
      popular = tags.values.sort_by { |t| -t["posts"].size }.map { |t|
        { "name" => t["name"], "slug" => t["slug"], "count" => t["posts"].size }
      }
      site.config["popular_tags"] = popular
    end
  end

  class TagPage < Jekyll::Page
    def initialize(site, base, tag_data)
      @site = site
      @base = base
      @dir  = File.join("tag", tag_data["slug"])
      @name = "index.html"

      process(@name)
      read_yaml(File.join(base, "_layouts"), "tag.html")

      data["title"]     = "posts tagged: #{tag_data["name"]}"
      data["tag"]       = tag_data["name"]
      data["tag_slug"]  = tag_data["slug"]
      data["posts"]     = tag_data["posts"]
      data["permalink"] = "/tag/#{tag_data["slug"]}/"
    end
  end
end
