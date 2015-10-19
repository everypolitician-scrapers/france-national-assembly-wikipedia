#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def wikiname_from(a)
  return if a.attr('class') == 'new'
  return a.attr('title')
end

def scrape_term(term, source)
  noko = noko_for(source)
  rows = noko.xpath('.//table[.//th[contains(.,"Circonscription")]]//tr[td]')
  raise "No rows in source" if rows.count.zero?

  rows.each do |tr|
    headings = tr.parent.xpath('tr[th]//th').map(&:text).map(&:downcase)
    headers = Hash[headings.zip(0 .. headings.size)]

    tr.css('sup.reference').remove
    tds = tr.css('td')

    who = tds[ headers['député'] ].css('a') 
    next if who.count.zero?
    raise "Bad name in #{tr} col #{headers['député']}" unless who.count == 1

    group = tds[ headers['groupe'] ].css('a') 
    next if group.count.zero?
    raise "Bad group in #{tr} col #{headers['groupe']}" unless group.count == 1

    data = { 
      name: who.text.tidy,
      sort_name: who.first.parent.css('span[style*="display:none"]').text.tidy,
      wikiname: wikiname_from(who.first),
      area: tds[ headers['circonscription'] ].text.tidy,
      faction: tds[ headers['groupe'] ].text.tidy,
      faction_wikiname: wikiname_from(group.first),
      term: term,
      source: source.to_s,
    }
    puts data
    ScraperWiki.save_sqlite([:name, :area, :faction, :term], data)
  end
end

terms = {
  14 => 'Liste_des_députés_de_la_XIVe_législature_de_la_Cinquième_République'
}

terms.each { |id, url| scrape_term(id, URI.join('https://fr.wikipedia.org/wiki/', URI.encode(url))) }
