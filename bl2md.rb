#! /usr/bin/env ruby
# coding: utf-8

# These codes are licensed under CC0.
# http://creativecommons.org/publicdomain/zero/1.0/deed.ja

require 'open-uri'
require 'mechanize'
require 'pandoc-ruby'
require 'awesome_print'
require 'pry'
require 'date'

require "./environment.rb"

class BL

    def initialize(user_id, password, domain, project)
        @user_id  = user_id
        @password = password
        @domain   = domain
        @project  = project

        @agent                  = Mechanize.new
        @agent.user_agent_alias = "Mac Safari"
        @agent.max_history      = 1
    end

    def login(isWithAuth=false, id='', pass='')
        @agent.add_auth("https://#{@domain}", id, pass) if isWithAuth
        page = @agent.get("https://#{@domain}/LoginDisplay.action")
        form = page.forms[0]
        form.field_with(id: "userId").value   = @user_id
        form.field_with(id: "password").value = @password
        @agent.submit(form, form.buttons.first)
    end

end

class OldBL < BL

    def get_wiki_url_list()
        page = @agent.get("https://#{@domain}/wiki/#{@project}/Home")
        wikipagelist = page.at('#wikipagelist')
        @links = wikipagelist.search('a').map { |a|
            a.attributes['href'].value
        }
    end

    def get_wiki_html(link)
        page  = @agent.get("https://#{@domain}" + link)
        title = page.at('#mainTitle').text.gsub(/(\n|\t)/, '').gsub(/\s+https.*$/, '')
        article = page.at('#loom').to_s
        {title: title, article: article}
    end

end

class NewBL < BL

    def to_markdown(html)
        @converter = PandocRuby.new(html, :from => :html, :to => :markdown)
        md = @converter.convert
    end

    def work_around(text)
        while /\A<div.*?>/ =~ text
            text.gsub!(/^<div.*?>/, '')
            text.gsub!(/<\/div>$/, '')
        end
        text.gsub!(/^\\$\n/, '')
        text.gsub!(/{.[-a-zA-Z]*}/, '')
        text
    end

    def post_wiki(title, article)
        page = @agent.get("https://#{@domain}/NewWiki.action?projectKey=#{@project}")
        form = page.forms[3]
        form.field_with(id: "page.name").value    = title
        form.field_with(id: "page.content").value = work_around(article)
        form.checkbox_with(name: 'mailNotify').uncheck
        # binding.pry
        page = @agent.submit(form, form.buttons.first)
        # binding.pry
    end
end

if __FILE__ == $0
    old_i = OldBL.new(OLD_USER_ID, OLD_PASS, OLD_DOMAIN, OLD_PROJECT)
    old_i.login
    new_i = NewBL.new(NEW_USER_ID, NEW_PASS, NEW_DOMAIN, NEW_PROJECT)
    new_i.login(true, NEW_BASIC_ID, NEW_BASIC_PASS)

    links = old_i.get_wiki_url_list

    links.each do |link|
        wiki = old_i.get_wiki_html(link)
        md   = new_i.to_markdown(wiki[:article])
        puts wiki[:title]
        new_i.post_wiki(wiki[:title], md)
        sleep 3
    end
end
