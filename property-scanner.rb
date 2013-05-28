#!/usr/bin/env ruby

# NOTE: install required gem:
#   gem install nokogiri

require 'rubygems'
require 'nokogiri'
require 'open-uri'

EXCLUSIONS_FILE = 'property-exclude.list'

LAND = 'Bayern'
TOWN = 'Muenchen'
ROOMS = '2'
KITCHEN = 'true'
FROM = '1990'
TO = '2100'

HOST = 'http://www.immobilienscout24.de'
LINK_BASE = '/Suche/S-T/P-'
LINK_PARAMS = "/Wohnung-Miete/#{LAND}/#{TOWN}/-/#{ROOMS},00-/-/-/-/-/-/#{KITCHEN}/-/-/-/-/-/-/-/#{FROM}bis#{TO}"

def exclusions
  File.read(EXCLUSIONS_FILE).strip.split /\s+/
end

EXCLUSIONS = exclusions

def apartment_links
  links = []
  #(1..1).each do |page_index|
  (1..Float::INFINITY).each do |page_index|
    page_link = "#{HOST}#{LINK_BASE}#{page_index}#{LINK_PARAMS}"
    page = Nokogiri::HTML(open page_link)
    links += page.css('li.is24-res-entry h3 a @href').map { |href| "#{HOST}#{href.text[/[^;]*/]}" }
    result_count = page.css('#resultCount').text.to_i
    page_count = (result_count - 1) / 20 + 1
    puts "Page #{page_index} of #{page_count}"
    break if page_index >= page_count
  end
  links
end

def page_field(page, path)
  fields = page.css(path)
  puts "WARNING: #{fields.size} occurrences of element '#{path}'" if fields.size > 1
  fields.text.gsub(/\s+/, ' ').strip
end

def translate_pets(pets)
  case pets
    when 'Nein'
      'no'
    when 'Ja'
      'yes'
    when 'Nach Vereinbarung'
      'maybe'
    else
      'unknown'
  end
end

def pets_allowed?(pets)
  case pets
    when 'yes', 'maybe' #, 'unknown'
      true
    else
      false
  end
end

def extract_id(link)
  link[/[0-9]+$/]
end

def extract_number(string)
  string[/[0-9,]+/].gsub(/,/, '')
end

doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') { apartments }.doc
doc.root.add_previous_sibling(Nokogiri::XML::ProcessingInstruction.new(doc, 'xml-stylesheet',
                                                                       'type="text/xsl" href="apartments.xslt"'))

apartment_links.each do |link|
  id = extract_id link
  next if EXCLUSIONS.include? id
  page = Nokogiri::HTML(open link)
  pets = translate_pets(page_field(page, '.is24qa-haustiere'))
  cost = page_field(page, '.is24qa-gesamtmiete text()[last()]')
  next unless pets_allowed?(pets) and not cost.empty?
  doc.root << doc.create_element('apartment') do |apartment|
    apartment['id'] = id
    apartment << doc.create_element('link', link)
    apartment << doc.create_element('pets', pets)
    apartment << doc.create_element('cost', cost) { |node| node['number'] = extract_number cost }
  end
  puts "#{link} #{pets}"
end

File.open('apartments.xml', 'w') { |file| file << doc }
