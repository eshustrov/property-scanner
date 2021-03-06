#!/usr/bin/env ruby

# NOTE: install required gem:
#   gem install nokogiri

require 'rubygems'
require 'nokogiri'
require 'open-uri'

EXCLUSIONS_FILE = 'property-exclude.list'

LAND1 = 'Umkreissuche'
TOWN1 = 'M_fcnchen_20_28Kreis_29/-/118984/2024595/-/-'
LAND2 = 'Bayern'
TOWN2 = 'Muenchen'
#TOWN = 'Rosenheim'
#TOWN = 'Augsburg'
#TOWN = 'Dachau-Kreis'
#LAND = 'Hamburg'
#TOWN = 'Hamburg'
#LAND = 'Hessen'
#TOWN = 'Frankfurt-am-Main'
#LAND = 'Baden-Wuerttemberg'
#TOWN = 'Karlsruhe'
#LAND = 'Berlin'
#TOWN = 'Berlin'
RADIUS1 = '20'
RADIUS2 = '-'
ROOMS = '3'
KITCHEN = 'true'
FROM = '2000'
TILL = '2100'

HOST = 'http://www.immobilienscout24.de'
LINK_BASE = '/Suche/S-T/P-'
LINK_PARAMS = [
    "/Wohnung-Miete/#{LAND1}/#{TOWN1}/#{RADIUS1}/#{ROOMS},00-/-/-/-/-/-/#{KITCHEN}/-/-/-/-/-/-/-/#{FROM}bis#{TILL}",
    "/Wohnung-Miete/#{LAND2}/#{TOWN2}/#{RADIUS2}/#{ROOMS},00-/-/-/-/-/-/#{KITCHEN}/-/-/-/-/-/-/-/#{FROM}bis#{TILL}"
]

def exclusions
  File.read(EXCLUSIONS_FILE).strip.split /\s+/
end

EXCLUSIONS = exclusions

def apartment_links
  links = []
  LINK_PARAMS.each do |link_param|
    #(1..1).each do |page_index|
    (1..Float::INFINITY).each do |page_index|
      page_link = "#{HOST}#{LINK_BASE}#{page_index}#{link_param}"
      page = Nokogiri::HTML(open page_link)
      links += page.css('.medialist__heading a @href').map { |href| "#{HOST}#{href.text[/[^;]*/]}" }
      result_count = page.css('#resultCount').text.to_i
      page_count = (result_count - 1) / 20 + 1
      puts "Page #{page_index} of #{page_count}"
      break if page_index >= page_count
    end
  end
  links.sort!.uniq!
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

def to_number(string)
  (extract_number string).to_i
end

doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') { apartments }.doc
doc.root.add_previous_sibling(Nokogiri::XML::ProcessingInstruction.new(doc, 'xml-stylesheet',
                                                                       'type="text/xsl" href="apartments.xslt"'))

total_number = 0
total_costs = []
possible_number = 0
possible_costs = []
allowed_number = 0
allowed_costs = []
apartment_links.each do |link|
  total_number += 1
  id = extract_id link
  next if EXCLUSIONS.include? id
  page = Nokogiri::HTML(open link)
  pets = translate_pets(page_field(page, '.is24qa-haustiere'))
  cost = page_field(page, '.is24qa-gesamtmiete text()[last()]')
  total_costs << to_number(cost) unless cost.empty?
  next unless pets_allowed?(pets) and not cost.empty?
  possible_number += 1
  possible_costs << to_number(cost)
  if pets == 'yes'
    allowed_number += 1
    allowed_costs << to_number(cost)
  end
  doc.root << doc.create_element('apartment') do |apartment|
    apartment['id'] = id
    apartment << doc.create_element('link', link)
    apartment << doc.create_element('pets', pets)
    apartment << doc.create_element('cost', cost) { |node| node['number'] = extract_number cost }
  end
  puts "#{link} #{pets}"
end

File.open('apartments.xml', 'w') { |file| file << doc }

possible_ratio = (possible_number * 1000 + total_number / 2) / total_number / 10.0
allowed_possible_ratio = (allowed_number * 1000 + possible_number / 2) / possible_number / 10.0
allowed_total_ratio = (allowed_number * 1000 + total_number / 2) / total_number / 10.0

def array_element(array, index)
  if index >= array.size
    '-'
  else
    array[index]
  end
end

def first(array)
  array_element(array, 0)
end

def second(array)
  array_element(array, 1)
end

total_costs.sort!
possible_costs.sort!
allowed_costs.sort!
puts "total:    #{total_number} @ [1]:#{first total_costs}, [2]:#{second total_costs}"
puts "possible: #{possible_number} (#{possible_ratio}%) @ [1]:#{first possible_costs}, [2]:#{second possible_costs}"
puts "allowed:  #{allowed_number} (#{allowed_possible_ratio}% / #{allowed_total_ratio}%) @ [1]:#{first allowed_costs}, [2]:#{second allowed_costs}"
