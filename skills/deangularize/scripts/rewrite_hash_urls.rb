#!/usr/bin/env ruby
# frozen_string_literal: true

# Rewrites legacy SPA hash URLs in specs, e.g. admin_path(anchor: '/tags/1/edit'), to route
# helpers of the server-rendered admin, driven by a YAML mapping. Lists anchors it cannot map.
#
#   ruby rewrite_hash_urls.rb [--dry-run] <config.yml> <file>...
#   ruby rewrite_hash_urls.rb docs/hash_urls.yml $(grep -rl "anchor:" spec)
#
# config.yml:
#   calls: ["admin_path(anchor: "]        # code before the quoted anchor; the call ends with ")"
#   extra_args: "host: admin_host"        # appended to every generated helper call (optional)
#   ignore: ["/test"]                     # anchor prefixes to leave alone silently (optional)
#   routes:                               # first match wins; ":name" captures one segment
#     "/tags": admin_tags_url
#     "/tags/new": new_admin_tag_url
#     "/tags/:id/edit": "edit_admin_tag_url(:id)"
#     "/pages/:id/edit?version_id=:version": "edit_admin_page_url(:id, version_id: :version)"
#
# Quote helpers that contain ": ". A captured number stays a number, an interpolation #{expr}
# (double quotes only) becomes expr, any other literal a quoted string. Afterwards review
# `git diff --stat`: comments and examples in unrelated files get rewritten too.

require 'yaml'

USAGE = File.read(__FILE__).lines[3..21].map { |line| line.sub(/^# ?/, '') }.join

class HashUrlRewriter
  Route = Struct.new(:segments, :query, :helper)
  QUOTED = /'([^'\\]*)'|"((?:\#\{[^}]*\}|[^"\\]|\\.)*)"/

  attr_reader :rewritten, :unmapped

  def initialize(config)
    @calls = Array(config.fetch('calls'))
    @extra = config['extra_args']
    @ignore = Array(config['ignore'])
    @routes = config.fetch('routes').map { |template, helper| parse_route(template, helper) }
    @rewritten = 0
    @unmapped = Hash.new(0)
  end

  def rewrite_source(source, file)
    @calls.reduce(source) do |text, call|
      text.gsub(/#{Regexp.escape(call)}\s*(?:#{QUOTED.source})\s*\)/) do |match|
        single, double = Regexp.last_match(1), Regexp.last_match(2)
        anchor = single || double
        replacement = rewrite(anchor, interpolate: !double.nil?)
        if replacement
          @rewritten += 1
          replacement
        else
          @unmapped["#{anchor}  (#{file})"] += 1 unless @ignore.any? { |prefix| anchor.start_with?(prefix) }
          match
        end
      end
    end
  end

  private

  def parse_route(template, helper)
    path, query = template.split('?', 2)
    Route.new(path.delete_prefix('/').split('/'), parse_query(query), helper)
  end

  def parse_query(query)
    return {} unless query

    query.split('&').to_h { |pair| pair.split('=', 2) }
  end

  def rewrite(anchor, interpolate:)
    path, query = anchor.split('?', 2)
    segments = path.delete_prefix('/').scan(/(?:\#\{[^}]*\}|[^\/])+/)
    query = parse_query(query)
    @routes.each do |route|
      captures = match(route, segments, query, interpolate)
      return build(route.helper, captures) if captures
    end
    nil
  end

  def match(route, segments, query, interpolate)
    return unless route.segments.size == segments.size && route.query.keys.sort == query.keys.sort

    pairs = route.segments.zip(segments) + route.query.map { |key, template| [template, query[key]] }
    pairs.each_with_object({}) do |(template, actual), captures|
      if template.start_with?(':')
        captures[template[1..]] = expression(actual, interpolate)
      elsif template != actual
        return nil
      end
    end
  end

  def expression(segment, interpolate)
    if interpolate && (inner = segment[/\A\#\{(.+)\}\z/, 1])
      inner
    elsif segment.match?(/\A\d+\z/)
      segment
    else
      "'#{segment}'"
    end
  end

  def build(helper, captures)
    call = helper.gsub(/(?<![\w:]):(\w+)/) { captures.fetch(Regexp.last_match(1), Regexp.last_match(0)) }
    return call unless @extra

    if call.end_with?('()') then call.sub(/\(\)\z/, "(#{@extra})")
    elsif call.end_with?(')') then call.sub(/\)\z/, ", #{@extra})")
    else "#{call}(#{@extra})"
    end
  end
end

dry_run = ARGV.delete('--dry-run')
config_path, *files = ARGV
abort USAGE if config_path.nil? || files.empty?

rewriter = HashUrlRewriter.new(YAML.safe_load_file(config_path))
files.each do |file|
  source = File.read(file)
  result = rewriter.rewrite_source(source, file)
  next if result == source

  dry_run ? puts("would change #{file}") : File.write(file, result)
end

puts "#{dry_run ? 'would rewrite' : 'rewritten'}: #{rewriter.rewritten}"
unless rewriter.unmapped.empty?
  puts 'unmapped:'
  rewriter.unmapped.sort.each { |anchor, count| puts "  #{count}x #{anchor}" }
end
