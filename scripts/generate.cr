require "json"
require "http/client"
require "code_writer"

METHODS_OUTPUT = File.expand_path(File.join(File.dirname(__FILE__), "../src/tourmaline/client/api.cr"))
TYPES_OUTPUT   = File.expand_path(File.join(File.dirname(__FILE__), "../src/tourmaline/types/api.cr"))

API_JSON_ENDPOINT = "https://raw.githubusercontent.com/PaulSonOfLars/telegram-bot-api-spec/544a0cec312506e3c9efc58a4e8691e8bba744aa/api.min.json"

BANNER = <<-TEXT
# This file is auto-generated by the scripts/generate.cr script.
# Do not edit this file manually. Changes will be overwritten.
TEXT

DEFAULTS = {
  "InlineQueryResultArticle" => {
    "type" => "article",
  },
  "InlineQueryResultPhoto" => {
    "type" => "photo",
  },
  "InlineQueryResultGif" => {
    "type" => "gif",
  },
  "InlineQueryResultMpeg4Gif" => {
    "type" => "mpeg4_gif",
  },
  "InlineQueryResultVideo" => {
    "type" => "video",
  },
  "InlineQueryResultAudio" => {
    "type" => "audio",
  },
  "InlineQueryResultVoice" => {
    "type" => "voice",
  },
  "InlineQueryResultDocument" => {
    "type" => "document",
  },
  "InlineQueryResultLocation" => {
    "type" => "location",
  },
  "InlineQueryResultVenue" => {
    "type" => "venue",
  },
  "InlineQueryResultContact" => {
    "type" => "contact",
  },
  "InlineQueryResultGame" => {
    "type" => "game",
  },
  "InlineQueryResultCachedPhoto" => {
    "type" => "photo",
  },
  "InlineQueryResultCachedGif" => {
    "type" => "gif",
  },
  "InlineQueryResultCachedMpeg4Gif" => {
    "type" => "mpeg4_gif",
  },
  "InlineQueryResultCachedSticker" => {
    "type" => "sticker",
  },
  "InlineQueryResultCachedDocument" => {
    "type" => "document",
  },
  "InlineQueryResultCachedVideo" => {
    "type" => "video",
  },
  "InlineQueryResultCachedVoice" => {
    "type" => "voice",
  },
  "InlineQueryResultCachedAudio" => {
    "type" => "audio",
  },
  "InputMediaPhoto" => {
    "type" => "photo",
  },
  "InputMediaVideo" => {
    "type" => "video",
  },
  "InputMediaAnimation" => {
    "type" => "animation",
  },
  "InputMediaAudio" => {
    "type" => "audio",
  },
  "InputMediaDocument" => {
    "type" => "document",
  },
  "InputMediaAnimation" => {
    "type" => "animation",
  },
}

class Api
  include JSON::Serializable

  property version : String

  property release_date : String

  property changelog : String

  property methods : Hash(String, Api::TypeDef)

  property types : Hash(String, Api::TypeDef)

  class TypeDef
    include JSON::Serializable

    property name : String

    property href : String

    property description : Array(String)

    property returns : Array(String) = [] of String

    property fields : Array(Api::Field) = [] of Api::Field

    property subtypes : Array(String) = [] of String

    property subtype_of : Array(String) = [] of String
  end

  class Field
    include JSON::Serializable

    property name : String

    property types : Array(String) = [] of String

    property required : Bool

    property description : String

    def default_value(type_name : String)
      DEFAULTS[type_name]?.try(&.[name]?)
    end
  end
end

def get_spec
  spec = HTTP::Client.get(API_JSON_ENDPOINT)
  Api.from_json(spec.body)
end

def type_to_cr(type : String | Array(String))
  if type.is_a?(Array)
    return type.map(&->type_to_cr(String)).join(" | ")
  end

  if type.starts_with?("Array of ")
    return "Array(" + type_to_cr(type.sub("Array of ", "")) + ")"
  end

  case type
  when "Integer"
    "Int32 | Int64"
  when "Float"
    "Float64"
  when "Boolean"
    "Bool"
  when "String"
    "String"
  when "InputFile"
    "::File"
  else
    "Tourmaline::#{type}"
  end
end

def write_methods(writer : CodeWriter, methods : Array(Api::TypeDef))
  writer.comment("Auto generated methods for the Telegram bot API.")
  writer.block("module Tourmaline") do
    writer.block("class Client") do
      writer.block("module Api") do
        methods.each do |method|
          write_method(writer, method)
          writer.newline
        end
      end
    end
  end
end

# Write a single method to the writer
def write_method(writer : CodeWriter, method : Api::TypeDef)
  method.description.each do |line|
    writer.comment(line)
  end

  # Sort the fields by requiredness. Required fields come first. Maintains order.
  fields = method.fields.sort_by { |f| f.required ? -1 : 1 }

  if fields.empty?
    writer.puts("def #{method.name.underscore}")
  else
    writer.puts("def #{method.name.underscore}(").indent do
      fields.each_with_index do |field, i|
        field_name = field.name.underscore
        crystal_type = type_to_cr(field.types)
        writer.print(field_name)

        if field_name == "parse_mode"
          writer.print(" : ParseMode = default_parse_mode")
        else
          writer.print(" : #{crystal_type}")

          if !field.required
            writer.print(" | ::Nil = nil")
          end
        end

        if i < fields.size - 1
          writer.print(", ").newline
        end
      end
    end
    writer.newline.puts(")")
  end

  writer.indent do
    writer.print("request(#{type_to_cr(method.returns)}, \"#{method.name}\"")
    if fields.any?
      writer.puts(", {")
      writer.indent do
        fields.each_with_index do |field, i|
          field_name = field.name.underscore
          if field.description.includes?("JSON-serialized")
            if field.required
              writer.print("#{field_name}: #{field_name}.to_json")
            else
              writer.print("#{field_name}: #{field_name}.try(&.to_json)")
            end
          else
            writer.print("#{field_name}: #{field_name}")
          end
          if i < fields.size - 1
            writer.print(", ").newline
          end
        end
      end
      writer.newline.puts("})")
    else
      writer.puts(")")
    end
  end

  writer.puts(writer.block_end)
end

def write_types(writer : CodeWriter, types : Array(Api::TypeDef))
  writer.comment("Auto generated types for the Telegram bot API.")
  writer.block("module Tourmaline") do
    types.each_with_index do |type, i|
      write_type(writer, type)
      writer.blank_line if i < types.size - 1
    end
  end
end

def write_type(writer : CodeWriter, type : Api::TypeDef)
  type.description.each do |line|
    writer.comment(line)
  end

  # Sort fields so that required fields come first, required fields with default
  # values come next, optional arrays come next, and all other optional fields come last.
  fields = type.fields.sort_by do |f|
    if f.required && !f.default_value(type.name) && !f.types.any? { |t| t.starts_with?("Array of ") }
      0
    elsif f.required && (f.default_value(type.name) || f.types.any? { |t| t.starts_with?("Array of ") })
      1
    else
      2
    end
  end

  if type.subtypes.any?
    writer.print "alias #{type.name} = "
    writer.print type.subtypes.map { |subtype| "Tourmaline::#{subtype}" }.join(" | ")
    writer.newline
    return
  end

  writer.block("class #{type.name}") do
    writer.print("include JSON::Serializable")
    writer.blank_line if fields.any?

    fields.each do |field|
      field_name = field.name.underscore

      writer.comment(field.description)

      crystal_type = type_to_cr(field.types)
      if default = field.default_value(type.name)
        writer.print("property #{field_name} : #{crystal_type} = \"#{default}\"")
      elsif field_name == "parse_mode"
        writer.print("property #{field_name} : ParseMode = ParseMode::Markdown")
      elsif field_name =~ /\b(date|time)\b|_date$|_time$/i
        writer.puts("@[JSON::Field(converter: Time::EpochConverter)]")
        writer.print("property #{field_name} : Time")
        writer.print(" | ::Nil") if !field.required
      elsif crystal_type == "Bool"
        writer.print("property? #{field_name} : #{crystal_type}")
        writer.print(" | ::Nil") if !field.required
      elsif crystal_type.starts_with?("Array(")
        writer.print("property #{field_name} : #{crystal_type}")
        # get the inner type
        inner_type = crystal_type.sub("Array(", "").sub(")", "")
        # if it isn't a primitive type, prepend the module name
        writer.print(" = [] of #{inner_type}")
      else
        writer.print("property #{field_name} : #{crystal_type}")
        writer.print(" | ::Nil") if !field.required
      end

      writer.newline
      writer.newline
    end

    if fields.any?
      writer.puts("def initialize(").indent do
        fields.each_with_index do |field, i|
          crystal_type = type_to_cr(field.types)
          field_name = field.name.underscore
          writer.print("@#{field_name}")
          if default = field.default_value(type.name)
            writer.print(" = \"#{default}\"")
          elsif field_name == "parse_mode"
            writer.print(" : ParseMode = ParseMode::Markdown")
          elsif crystal_type.starts_with?("Array(")
            inner_type = crystal_type.sub("Array(", "").sub(")", "")
            writer.print(" : #{crystal_type} = [] of #{inner_type}")
          elsif !field.required
            writer.print(" : #{crystal_type} | ::Nil = nil")
          end

          if i < fields.size - 1
            writer.print(", ").newline
          end
        end
      end
      writer.newline.puts(")")
      writer.puts(writer.block_end)
    end
  end
end

def main
  types_file = File.open(TYPES_OUTPUT, "w+")
  methods_file = File.open(METHODS_OUTPUT, "w+")

  types_writer = CodeWriter.new(buffer: types_file, tab_count: 2)
  methods_writer = CodeWriter.new(buffer: methods_file, tab_count: 2)

  spec = get_spec
  puts "Generating client for Telegram Bot API #{spec.version} (#{spec.release_date})"
  puts "Changelog: #{spec.changelog}"

  types_writer.puts BANNER
  types_writer.newline

  methods_writer.puts BANNER
  methods_writer.newline

  write_types(types_writer, spec.types.values)
  write_methods(methods_writer, spec.methods.values)
ensure
  types_file.try &.close
  methods_file.try &.close
end

main()
