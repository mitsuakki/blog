#!/usr/bin/env ruby
# frozen_string_literal: true

# sync_projects.rb -- fetch READMEs from GitHub repos,
# detect changes via SHA comparison, generate Jekyll project pages.
#
# Called from GitHub Actions before `jekyll build`.
# Requires GITHUB_TOKEN in environment (PAT with repo + read:org scopes).
#
# Also handles x86-kernel milestones/: each milestone becomes a blog post.

require "net/http"
require "json"
require "base64"
require "fileutils"
require "time"

API_BASE = "https://api.github.com"
USER    = "mitsuakki"
TOKEN   = ENV.fetch("GITHUB_TOKEN", ENV.fetch("GH_TOKEN", ""))

CACHE_FILE   = File.join(__dir__, "..", "_data", "projects_cache.json")
PROJECTS_DIR = File.join(__dir__, "..", "_projects")
POSTS_DIR    = File.join(__dir__, "..", "_posts")
MANIFEST_DIR = File.dirname(CACHE_FILE)
CHANGELOG    = File.join(__dir__, "..", "_data", "projects_changelog.md")

HEADERS = {
  "Accept"        => "application/vnd.github+json",
  "Authorization" => "Bearer #{TOKEN}",
  "User-Agent"    => "blog-sync/1.0",
  "X-GitHub-Api-Version" => "2022-11-28"
}.freeze

$stdout.sync = true

# HTTP helpers ----------------------------------------------------------

def api_get(path, params = {})
  uri = URI("#{API_BASE}#{path}")
  uri.query = URI.encode_www_form(params.reject { |_k, v| v.nil? }) unless params.empty?
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 30
  req = Net::HTTP::Get.new(uri, HEADERS)
  res = http.request(req)
  return JSON.parse(res.body) if res.code.to_i == 200

  warn "  [!] GET #{path} -> #{res.code}"
  nil
end

def api_get_all(path, params = {})
  results = []
  page = 1
  loop do
    paged = api_get(path, params.merge(per_page: 100, page: page))
    break if paged.nil? || paged.empty?

    results.concat(paged)
    page += 1
    break if paged.size < 100
  end
  results
end

# Repo listing ----------------------------------------------------------

# Repos owned by the user (personal account)
def user_repos
  puts "[*] listing repos owned by #{USER}..."
  api_get_all("/users/#{USER}/repos", type: "owner")
end

# All repos in an org
def org_repos(org_login)
  api_get_all("/orgs/#{org_login}/repos", type: "all")
end

# Check if user has at least one commit in a repo
def user_has_commits?(full_name)
  commits = api_get("/repos/#{full_name}/commits", author: USER, per_page: 1)
  commits.is_a?(Array) && commits.any?
end

# README fetching -------------------------------------------------------

def fetch_readme(full_name)
  api_get("/repos/#{full_name}/readme")
end

def fetch_dir_contents(full_name, path, ref: nil)
  params = ref ? { ref: ref } : {}
  api_get("/repos/#{full_name}/contents/#{path}", params)
end

# Cache -----------------------------------------------------------------

def load_cache
  return {} unless File.exist?(CACHE_FILE)

  JSON.parse(File.read(CACHE_FILE))
rescue JSON::ParserError
  warn "  [!] cache corrupted, resetting"
  {}
end

def save_cache(cache)
  FileUtils.mkdir_p(MANIFEST_DIR)
  File.write(CACHE_FILE, JSON.pretty_generate(cache))
  puts "[*] cache saved (#{cache.size} entries)"
end

# Page generation -------------------------------------------------------

def sanitize_filename(name)
  name.downcase.gsub(/[^a-z0-9._-]/, "-").gsub(/-+/, "-").gsub(/\A-|-\z/, "")
end

def project_frontmatter(repo, readme_data, status)
  desc = (repo["description"] || "").gsub('"', '\"')
  topics = (repo["topics"] || []).join(", ")
  lang = repo["language"] || ""
  <<~YAML
    ---
    layout: project
    title: "#{repo["name"]}"
    repo: "#{repo["full_name"]}"
    repo_url: "#{repo["html_url"]}"
    description: "#{desc}"
    language: "#{lang}"
    stars: #{repo["stargazers_count"]}
    updated: "#{repo["updated_at"]}"
    topics: [#{topics}]
    readme_sha: "#{readme_data["sha"]}"
    sync_status: "#{status}"
    archived: #{repo["archived"]}
    lang: en
    ---
  YAML
end

def write_project_page(repo, readme_data, status)
  content = Base64.decode64(readme_data["content"]).force_encoding("UTF-8")
  # strip leading h1 -- layout provides the title
  content = content.sub(/\A\s*#\s+.+?\n/, "\n")

  filename = sanitize_filename(repo["name"])
  frontmatter = project_frontmatter(repo, readme_data, status)

  FileUtils.mkdir_p(PROJECTS_DIR)
  path = File.join(PROJECTS_DIR, "#{filename}.md")
  File.write(path, frontmatter + "\n" + content)
  puts "  [+] wrote #{filename}.md (#{status})"
  path
end

def write_project_page_no_readme(repo, status)
  filename = sanitize_filename(repo["name"])
  desc = (repo["description"] || "").gsub('"', '\"')
  topics = (repo["topics"] || []).join(", ")
  lang = repo["language"] || ""

  frontmatter = <<~YAML
    ---
    layout: project
    title: "#{repo["name"]}"
    repo: "#{repo["full_name"]}"
    repo_url: "#{repo["html_url"]}"
    description: "#{desc}"
    language: "#{lang}"
    stars: #{repo["stargazers_count"]}
    updated: "#{repo["updated_at"]}"
    topics: [#{topics}]
    readme_sha: ""
    sync_status: "#{status}"
    archived: #{repo["archived"]}
    lang: en
    ---

    _No README in this repository._

    [#{repo["full_name"]} on GitHub](#{repo["html_url"]})
  YAML

  FileUtils.mkdir_p(PROJECTS_DIR)
  path = File.join(PROJECTS_DIR, "#{filename}.md")
  File.write(path, frontmatter)
  puts "  [+] wrote #{filename}.md (no README, #{status})"
  path
end

# x86-kernel milestones -------------------------------------------------

def sync_milestones(repo_full_name, repo_data, branch: nil)
  ref_label = branch || "default"
  puts "[*] #{repo_full_name}: fetching milestones/ (branch: #{ref_label})..."
  entries = fetch_dir_contents(repo_full_name, "milestones", ref: branch)
  unless entries.is_a?(Array)
    warn "  [!] milestones/ not found or not a directory"
    return []
  end

  md_files = entries.select { |e| e["type"] == "file" && e["name"].end_with?(".md") && e["name"] != "README.md" }
  puts "  [*] found #{md_files.size} milestone file(s)"

  created = []
  md_files.each_with_index do |file, idx|
    next unless file["download_url"]

    uri = URI(file["download_url"])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    res = http.get(uri)
    next unless res.code.to_i == 200

    body = res.body.force_encoding("UTF-8")
    # Strip **Status:** section (from **Status:** to next --- or ##)
    body = body.gsub(/\*\*Status:\*\*[\s\S]*?(?=\n---|\n##|\n\*\*|$)/, "").strip
    milestone_name = File.basename(file["name"], ".md")
    title = milestone_name.tr("-", " ").gsub(/\b\w/, &:upcase)

    # stable date: kernel repo push date + milestone index offset,
    # so posts keep the same date across syncs
    base = Time.parse(repo_data["pushed_at"] || repo_data["updated_at"])
    post_date = (base + (idx * 3600)).strftime("%Y-%m-%d")

    frontmatter = <<~YAML
      ---
      layout: post
      title: "[x86-kernel] #{title}"
      tags: [x86-kernel, milestone, kernel, osdev]
      repo: "#{repo_full_name}"
      lang: en
      date: #{post_date}
      ---

      _Milestone from [x86-kernel](#{repo_data["html_url"]}) -- bare-metal x86_64 kernel written from scratch, no AI used._

    YAML

    fname = "#{post_date}-x86-kernel-#{milestone_name}.md"
    path = File.join(POSTS_DIR, fname)
    File.write(path, frontmatter + "\n" + body)
    puts "  [+] wrote milestone post: #{fname}"
    created << path
  end
  created
end

# Changelog -------------------------------------------------------------

def write_changelog(changed, new_projects)
  FileUtils.mkdir_p(MANIFEST_DIR)
  lines = [
    "---",
    "layout: none",
    "---",
    "",
    "<!-- auto-generated by sync_projects.rb -->",
    ""
  ]
  if new_projects.any?
    lines << "**New projects:**"
    new_projects.each { |r| lines << "- [#{r[:name]}](#{r[:url]})" }
    lines << ""
  end
  if changed.any?
    lines << "**Updated projects:**"
    changed.each { |r| lines << "- [#{r[:name]}](#{r[:url]})" }
    lines << ""
  end
  if new_projects.empty? && changed.empty?
    lines << "_No changes since last sync (#{Time.now.strftime('%Y-%m-%d %H:%M')})._"
    lines << ""
  end
  File.write(CHANGELOG, lines.join("\n"))
end

# Main ------------------------------------------------------------------

def main
  puts "=" * 60
  puts "  projects sync -- #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  puts "=" * 60

  cache = load_cache
  puts "[*] cache loaded: #{cache.size} cached readmes"

  # Collect repos: personal + org repos where user committed.
  # Personal repos: always included (you own them).
  # Org repos: only included if you have at least one commit.

  repos = user_repos
  puts "[*] #{repos.size} repos owned by #{USER}"

  orgs = api_get_all("/users/#{USER}/orgs")
  org_logins = orgs.map { |o| o["login"] }
  puts "[*] #{org_logins.size} org(s): #{org_logins.join(', ')}"

  orgs.each do |org|
    all_org = org_repos(org["login"])
    puts "  #{org["login"]}: #{all_org.size} repos, checking commits..."

    kept = 0
    all_org.each do |r|
      next if repos.any? { |ex| ex["id"] == r["id"] } # already owned
      if user_has_commits?(r["full_name"])
        repos << r
        kept += 1
      else
        puts "    skip #{r["full_name"]} (no commits)"
      end
    end
    puts "  #{org["login"]}: kept #{kept}/#{all_org.size}"
  end
  puts "[*] #{repos.size} repos total"

  # Filter: skip forks and .github repos. Keep archived (shown with badge).
  active = repos.reject { |r| r["fork"] || r["name"] == ".github" }
  puts "[*] #{active.size} active non-fork repos"

  changed   = []
  new_items = []
  milestone_posts = []
  unchanged = 0
  total     = 0
  no_readme = 0

  # Clean old milestone posts so removed milestones disappear
  Dir.glob(File.join(POSTS_DIR, "*-x86-kernel-*.md")).each { |f| FileUtils.rm(f) }

  active.each do |repo|
    full_name = repo["full_name"]
    repo_key = "#{full_name}/readme"
    print "  #{full_name} ... "

    is_kernel = (repo["name"] == "x86-kernel" || repo["name"] == "x86_kernel")

    if is_kernel
      # x86-kernel: milestones only, no project page
      puts "milestones only"
      milestone_posts.concat(sync_milestones(full_name, repo, branch: "m1-boot"))
      next
    end

    readme = fetch_readme(full_name)

    if readme
      sha = readme["sha"]
      status = if !cache.key?(repo_key)
                 new_items << { name: full_name, url: repo["html_url"] }
                 "new"
               elsif cache[repo_key] != sha
                 changed << { name: full_name, url: repo["html_url"] }
                 "updated"
               else
                 unchanged += 1
                 "unchanged"
               end
      write_project_page(repo, readme, status)
      cache[repo_key] = sha
      total += 1
    else
      status = "no-readme"
      no_readme += 1
      write_project_page_no_readme(repo, status)
      total += 1
    end
  end

  # Remove stale project pages (repos deleted or archived since last sync)
  known = active.map { |r| sanitize_filename(r["name"]) + ".md" }
  if Dir.exist?(PROJECTS_DIR)
    Dir.glob(File.join(PROJECTS_DIR, "*.md")).each do |f|
      unless known.include?(File.basename(f))
        FileUtils.rm(f)
        puts "  [-] removed stale: #{File.basename(f)}"
      end
    end
  end

  save_cache(cache)
  write_changelog(changed, new_items)

  puts
  puts "=" * 60
  puts "  summary"
  puts "=" * 60
  puts "  repos total:         #{total}"
  puts "  with README:          #{total - no_readme}"
  puts "  without README:       #{no_readme}"
  puts "  unchanged:            #{unchanged}"
  puts "  updated:              #{changed.size}"
  puts "  new:                  #{new_items.size}"
  puts "  milestone posts:      #{milestone_posts.size}"
  new_items.each { |r| puts "    + #{r[:name]}" } if new_items.any?
  changed.each   { |r| puts "    ~ #{r[:name]}" } if changed.any?
  puts
end

main if __FILE__ == $PROGRAM_NAME
